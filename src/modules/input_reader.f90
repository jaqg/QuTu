! =============================================================================
! Module: input_reader
! Description: Unified INPUT file parser for NH3 quantum tunneling simulation
!              Reads key=value format with comments support
! Author: Jose Antonio Quinonero Gris
! Created: 2026-01-20
! =============================================================================
module input_reader
    use constants, only: dp
    implicit none
    private

    ! Public derived type for input parameters
    type, public :: input_params_t
        integer :: N_max
        real(dp) :: xe
        real(dp) :: Vb
        real(dp) :: mass_H
        real(dp) :: mass_N
        real(dp) :: xmin
        real(dp) :: xmax
        real(dp) :: dx
        ! Output verbosity: 0=minimal, 1=full OUTPUT (default), 2=full OUTPUT + dat files
        integer :: print_level
        ! Alpha values for 4-state wavepacket calculations
        real(dp), allocatable :: alpha_values(:)
        integer :: n_alpha_values
    end type input_params_t

    ! Public procedures
    public :: read_input_file

contains

    ! -------------------------------------------------------------------------
    ! Parse comma-separated real values
    ! -------------------------------------------------------------------------
    subroutine parse_real_array(value_str, values, n_values, ierr)
        character(len=*), intent(in) :: value_str
        real(dp), allocatable, intent(out) :: values(:)
        integer, intent(out) :: n_values
        integer, intent(out) :: ierr

        integer :: i, comma_pos, n_commas
        character(len=len(value_str)) :: remaining

        ierr = 0
        n_values = 0

        ! Count commas to determine array size
        n_commas = 0
        do i = 1, len_trim(value_str)
            if (value_str(i:i) == ',') n_commas = n_commas + 1
        end do
        n_values = n_commas + 1

        ! Allocate array
        if (allocated(values)) deallocate(values)
        allocate(values(n_values))

        ! Parse values
        remaining = adjustl(value_str)
        do i = 1, n_values
            if (i < n_values) then
                comma_pos = index(remaining, ',')
                if (comma_pos == 0) then
                    ierr = 1
                    return
                end if
                read(remaining(1:comma_pos-1), *, iostat=ierr) values(i)
                if (ierr /= 0) return
                remaining = adjustl(remaining(comma_pos+1:))
            else
                ! Last value
                read(remaining, *, iostat=ierr) values(i)
                if (ierr /= 0) return
            end if
        end do

    end subroutine parse_real_array

    ! -------------------------------------------------------------------------
    ! Read unified INPUT file
    ! -------------------------------------------------------------------------
    subroutine read_input_file(filename, params, ierr)
        character(len=*), intent(in) :: filename
        type(input_params_t), intent(out) :: params
        integer, intent(out) :: ierr

        integer :: unit_num, io_stat, parse_ierr
        character(len=256) :: line, key, value_str
        integer :: eq_pos, comment_pos
        logical :: found_N_max, found_xe, found_Vb, found_mass_H, found_mass_N
        logical :: found_xmin, found_xmax, found_dx, found_alpha_values

        ! Initialize flags and defaults
        params%print_level = 1
        found_N_max = .false.
        found_xe = .false.
        found_Vb = .false.
        found_mass_H = .false.
        found_mass_N = .false.
        found_xmin = .false.
        found_xmax = .false.
        found_dx = .false.
        found_alpha_values = .false.
        ierr = 0

        ! Initialize alpha_values with defaults (single value: 0.0)
        params%n_alpha_values = 1
        if (allocated(params%alpha_values)) deallocate(params%alpha_values)
        allocate(params%alpha_values(1))
        params%alpha_values = [0.0_dp]

        ! Open INPUT file
        open(newunit=unit_num, file=filename, status='old', action='read', iostat=ierr)
        if (ierr /= 0) then
            write(*,'(A)') '======================================================'
            write(*,'(A)') ' ERROR: Cannot open INPUT file'
            write(*,'(A)') '======================================================'
            write(*,'(A,A)') ' Expected file: ', trim(filename)
            write(*,'(A)') ' Please create an INPUT file in the current directory'
            write(*,'(A)') ' with the required parameters (see documentation).'
            write(*,'(A)') '======================================================'
            return
        end if

        ! Read file line by line
        do
            read(unit_num, '(A)', iostat=io_stat) line
            if (io_stat /= 0) exit  ! End of file or error

            ! Remove leading/trailing whitespace
            line = adjustl(line)

            ! Skip empty lines
            if (len_trim(line) == 0) cycle

            ! Skip comment lines
            if (line(1:1) == '#') cycle

            ! Remove inline comments
            comment_pos = index(line, '#')
            if (comment_pos > 0) then
                line = line(1:comment_pos-1)
            end if

            ! Find the '=' sign
            eq_pos = index(line, '=')
            if (eq_pos == 0) cycle  ! No '=' found, skip line

            ! Extract key and value
            key = adjustl(trim(line(1:eq_pos-1)))
            value_str = adjustl(trim(line(eq_pos+1:)))

            ! Parse based on key
            select case (trim(key))
                case ('N_max')
                    read(value_str, *, iostat=io_stat) params%N_max
                    if (io_stat == 0) found_N_max = .true.

                case ('xe')
                    read(value_str, *, iostat=io_stat) params%xe
                    if (io_stat == 0) found_xe = .true.

                case ('Vb')
                    read(value_str, *, iostat=io_stat) params%Vb
                    if (io_stat == 0) found_Vb = .true.

                case ('mass_H')
                    read(value_str, *, iostat=io_stat) params%mass_H
                    if (io_stat == 0) found_mass_H = .true.

                case ('mass_N')
                    read(value_str, *, iostat=io_stat) params%mass_N
                    if (io_stat == 0) found_mass_N = .true.

                case ('xmin')
                    read(value_str, *, iostat=io_stat) params%xmin
                    if (io_stat == 0) found_xmin = .true.

                case ('xmax')
                    read(value_str, *, iostat=io_stat) params%xmax
                    if (io_stat == 0) found_xmax = .true.

                case ('dx')
                    read(value_str, *, iostat=io_stat) params%dx
                    if (io_stat == 0) found_dx = .true.

                case ('print_level')
                    read(value_str, *, iostat=io_stat) params%print_level

                case ('alpha_values')
                    call parse_real_array(value_str, params%alpha_values, params%n_alpha_values, parse_ierr)
                    if (parse_ierr == 0) then
                        found_alpha_values = .true.
                    else
                        write(*,'(A)') ' Warning: Failed to parse alpha_values, using defaults'
                    end if

                case default
                    ! Unknown key, just skip with a warning
                    write(*,'(A,A)') ' Warning: Unknown parameter in INPUT file: ', trim(key)
            end select
        end do

        close(unit_num)

        ! Validate that all required parameters were found
        if (.not. found_N_max) then
            write(*,'(A)') 'ERROR: Missing required parameter: N_max'
            ierr = 1
        end if
        if (.not. found_xe) then
            write(*,'(A)') 'ERROR: Missing required parameter: xe'
            ierr = 1
        end if
        if (.not. found_Vb) then
            write(*,'(A)') 'ERROR: Missing required parameter: Vb'
            ierr = 1
        end if
        if (.not. found_mass_H) then
            write(*,'(A)') 'ERROR: Missing required parameter: mass_H'
            ierr = 1
        end if
        if (.not. found_mass_N) then
            write(*,'(A)') 'ERROR: Missing required parameter: mass_N'
            ierr = 1
        end if
        if (.not. found_xmin) then
            write(*,'(A)') 'ERROR: Missing required parameter: xmin'
            ierr = 1
        end if
        if (.not. found_xmax) then
            write(*,'(A)') 'ERROR: Missing required parameter: xmax'
            ierr = 1
        end if
        if (.not. found_dx) then
            write(*,'(A)') 'ERROR: Missing required parameter: dx'
            ierr = 1
        end if

        if (ierr /= 0) then
            write(*,'(A)') '======================================================'
            write(*,'(A)') ' Please check your INPUT file and try again.'
            write(*,'(A)') '======================================================'
        end if

    end subroutine read_input_file

end module input_reader
