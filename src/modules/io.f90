! =============================================================================
! Module: io
! Description: Input/Output routines for reading parameters and writing results
!              in the NH3 quantum tunneling simulation.
! Author: Jose Antonio Quinonero Gris
! =============================================================================
module io
    use constants, only: dp, RBOHR, EUACM
    use types, only: system_params_t, grid_params_t, time_params_t
    implicit none
    private

    ! Public procedures
    ! NOTE: read_system_input, read_grid_params, and read_masses are deprecated
    ! Use input_reader module instead for unified INPUT file reading
    public :: read_system_input  ! DEPRECATED - kept for reference only
    public :: read_grid_params   ! DEPRECATED - kept for reference only
    public :: read_masses        ! DEPRECATED - kept for reference only
    public :: write_energies
    public :: write_wavefunction
    public :: write_potential
    public :: write_convergence
    public :: write_survival_probability
    public :: write_expectation_value
    public :: write_wavepacket
    public :: write_recurrence_time
    public :: write_turning_points
    public :: write_coefficients

contains

    ! -------------------------------------------------------------------------
    ! Read system input parameters (N, xe, Vb)
    ! -------------------------------------------------------------------------
    subroutine read_system_input(filename, N, xe_A, Vb_cm, ierr)
        character(len=*), intent(in) :: filename
        integer, intent(out) :: N
        real(dp), intent(out) :: xe_A, Vb_cm
        integer, intent(out) :: ierr
        integer :: unit_num

        open(newunit=unit_num, file=filename, status='old', action='read', iostat=ierr)
        if (ierr /= 0) then
            write(*,'(A,A)') 'Error: Cannot open file ', trim(filename)
            return
        end if

        read(unit_num, *, iostat=ierr)  ! Skip header line
        if (ierr /= 0) then
            close(unit_num)
            return
        end if

        read(unit_num, *, iostat=ierr) N, xe_A, Vb_cm
        close(unit_num)
    end subroutine read_system_input

    ! -------------------------------------------------------------------------
    ! Read grid parameters (xmin, xmax, dx)
    ! -------------------------------------------------------------------------
    subroutine read_grid_params(filename, xmin, xmax, dx, ierr)
        character(len=*), intent(in) :: filename
        real(dp), intent(out) :: xmin, xmax, dx
        integer, intent(out) :: ierr
        integer :: unit_num

        open(newunit=unit_num, file=filename, status='old', action='read', iostat=ierr)
        if (ierr /= 0) then
            write(*,'(A,A)') 'Error: Cannot open file ', trim(filename)
            return
        end if

        read(unit_num, *, iostat=ierr)  ! Skip header
        if (ierr /= 0) then
            close(unit_num)
            return
        end if

        read(unit_num, *, iostat=ierr) xmin, xmax, dx
        close(unit_num)
    end subroutine read_grid_params

    ! -------------------------------------------------------------------------
    ! Read atomic masses (mH, mN in amu)
    ! -------------------------------------------------------------------------
    subroutine read_masses(filename, mH, mN, ierr)
        character(len=*), intent(in) :: filename
        real(dp), intent(out) :: mH, mN
        integer, intent(out) :: ierr
        integer :: unit_num

        open(newunit=unit_num, file=filename, status='old', action='read', iostat=ierr)
        if (ierr /= 0) then
            write(*,'(A,A)') 'Error: Cannot open file ', trim(filename)
            return
        end if

        read(unit_num, *, iostat=ierr)  ! Skip header
        if (ierr /= 0) then
            close(unit_num)
            return
        end if

        read(unit_num, *, iostat=ierr) mH, mN
        close(unit_num)
    end subroutine read_masses

    ! -------------------------------------------------------------------------
    ! Write energies to file
    ! -------------------------------------------------------------------------
    subroutine write_energies(filename, energies, unit_label, header, ierr)
        character(len=*), intent(in) :: filename
        real(dp), intent(in) :: energies(:)
        character(len=*), intent(in) :: unit_label  ! e.g., "Ha" or "cm-1"
        character(len=*), intent(in), optional :: header
        integer, intent(out) :: ierr
        integer :: unit_num, i

        open(newunit=unit_num, file=filename, status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        if (present(header)) then
            write(unit_num, '(A)') trim(header)
        end if

        write(unit_num, '(A,A,A)') '  n    E (', trim(unit_label), ')'
        write(unit_num, '(A)') repeat('-', 40)

        do i = 1, size(energies)
            write(unit_num, '(I4, F18.8)') i - 1, energies(i)
        end do

        close(unit_num)
    end subroutine write_energies

    ! -------------------------------------------------------------------------
    ! Write wavefunction to file
    ! -------------------------------------------------------------------------
    subroutine write_wavefunction(filename, x, psi, header, x_label, ierr)
        character(len=*), intent(in) :: filename
        real(dp), intent(in) :: x(:), psi(:)
        character(len=*), intent(in), optional :: header, x_label
        integer, intent(out) :: ierr
        integer :: unit_num, i
        character(len=16) :: x_unit

        x_unit = "a0"
        if (present(x_label)) x_unit = x_label

        open(newunit=unit_num, file=filename, status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        if (present(header)) then
            write(unit_num, '(A)') trim(header)
        end if

        write(unit_num, '(A,A,A)') '  x (', trim(x_unit), ')        psi(x)         |psi(x)|^2'
        write(unit_num, '(A)') repeat('-', 60)

        do i = 1, size(x)
            write(unit_num, '(F12.4, 2E18.8)') x(i), psi(i), psi(i)**2
        end do

        close(unit_num)
    end subroutine write_wavefunction

    ! -------------------------------------------------------------------------
    ! Write potential to file
    ! -------------------------------------------------------------------------
    subroutine write_potential(filename, x, V, x_label, V_label, ierr)
        character(len=*), intent(in) :: filename
        real(dp), intent(in) :: x(:), V(:)
        character(len=*), intent(in) :: x_label, V_label
        integer, intent(out) :: ierr
        integer :: unit_num, i

        open(newunit=unit_num, file=filename, status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        write(unit_num, '(A)') repeat('-', 40)
        write(unit_num, '(6X, A, A, A, 12X, A, A, A)') 'x (', trim(x_label), ')', 'V(x) (', trim(V_label), ')'

        do i = 1, size(x)
            write(unit_num, '(F10.3, F15.5)') x(i), V(i)
        end do

        close(unit_num)
    end subroutine write_potential

    ! -------------------------------------------------------------------------
    ! Write convergence data
    ! -------------------------------------------------------------------------
    subroutine write_convergence(filename, n_levels, N_conv, E_conv, E_max, &
                                  unit_label, ierr)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: n_levels
        integer, intent(in) :: N_conv(:)
        real(dp), intent(in) :: E_conv(:), E_max(:)
        character(len=*), intent(in) :: unit_label
        integer, intent(out) :: ierr
        integer :: unit_num, i

        open(newunit=unit_num, file=filename, status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        write(unit_num, '(A,A,A)') '  n   N_conv    E_conv (', trim(unit_label), ')      E_max'
        write(unit_num, '(A)') repeat('-', 60)

        do i = 1, n_levels
            write(unit_num, '(I3, I7, 2F15.5)') i - 1, N_conv(i), E_conv(i), E_max(i)
        end do

        close(unit_num)
    end subroutine write_convergence

    ! -------------------------------------------------------------------------
    ! Write survival probability data
    ! -------------------------------------------------------------------------
    subroutine write_survival_probability(filename, t, Ps, header, ierr)
        character(len=*), intent(in) :: filename
        real(dp), intent(in) :: t(:), Ps(:)
        character(len=*), intent(in), optional :: header
        integer, intent(out) :: ierr
        integer :: unit_num, i

        open(newunit=unit_num, file=filename, status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        if (present(header)) then
            write(unit_num, '(A)') trim(header)
            write(unit_num, '(A)') repeat('-', 40)
        end if

        write(unit_num, '(A)') 't (ps)      Ps(t)'

        do i = 1, size(t)
            write(unit_num, '(F8.4, F15.5)') t(i), Ps(i)
        end do

        close(unit_num)
    end subroutine write_survival_probability

    ! -------------------------------------------------------------------------
    ! Write expectation value <x>(t)
    ! -------------------------------------------------------------------------
    subroutine write_expectation_value(filename, t, x_exp, header, ierr)
        character(len=*), intent(in) :: filename
        real(dp), intent(in) :: t(:), x_exp(:)
        character(len=*), intent(in), optional :: header
        integer, intent(out) :: ierr
        integer :: unit_num, i

        open(newunit=unit_num, file=filename, status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        if (present(header)) then
            write(unit_num, '(A)') trim(header)
            write(unit_num, '(A)') repeat('-', 40)
        end if

        write(unit_num, '(A)') '  t (ps)       <x>t (A)'

        do i = 1, size(t)
            write(unit_num, '(F8.4, F15.5)') t(i), x_exp(i)
        end do

        close(unit_num)
    end subroutine write_expectation_value

    ! -------------------------------------------------------------------------
    ! Write wavepacket data (x, psi, |psi|^2) with energy and alpha
    ! -------------------------------------------------------------------------
    subroutine write_wavepacket(filename, alpha, E_cm, x, psi, header, ierr)
        character(len=*), intent(in) :: filename
        real(dp), intent(in) :: alpha, E_cm
        real(dp), intent(in) :: x(:), psi(:)
        character(len=*), intent(in), optional :: header
        integer, intent(out) :: ierr
        integer :: unit_num, i

        open(newunit=unit_num, file=filename, status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        if (present(header)) then
            write(unit_num, '(A)') repeat('=', 70)
            write(unit_num, '(A)') trim(header)
            write(unit_num, '(A)') repeat('-', 70)
        end if

        write(unit_num, '(A)') 'alfa      E (cm-1)      x (A)         psi(x)        |psi(x)|^2'

        do i = 1, size(x)
            write(unit_num, '(F4.1, F15.5, F10.3, 2F15.5)') alpha, E_cm, x(i), psi(i), psi(i)**2
        end do

        close(unit_num)
    end subroutine write_wavepacket

    ! -------------------------------------------------------------------------
    ! Write recurrence time
    ! -------------------------------------------------------------------------
    subroutine write_recurrence_time(filename, labels, tr_ps, ierr)
        character(len=*), intent(in) :: filename
        character(len=*), intent(in) :: labels(:)
        real(dp), intent(in) :: tr_ps(:)
        integer, intent(out) :: ierr
        integer :: unit_num, i

        open(newunit=unit_num, file=filename, status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        write(unit_num, '(A)') 'Psi                          tr (ps)'

        do i = 1, size(labels)
            write(unit_num, '(A, F15.5)') labels(i), tr_ps(i)
        end do

        close(unit_num)
    end subroutine write_recurrence_time

    ! -------------------------------------------------------------------------
    ! Write turning points
    ! -------------------------------------------------------------------------
    subroutine write_turning_points(filename, alpha_arr, E_arr, x1, x2, x3, x4, ierr)
        character(len=*), intent(in) :: filename
        real(dp), intent(in) :: alpha_arr(:), E_arr(:)
        real(dp), intent(in) :: x1(:), x2(:), x3(:), x4(:)
        integer, intent(out) :: ierr
        integer :: unit_num, i

        open(newunit=unit_num, file=filename, status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        write(unit_num, '(A)') repeat('=', 70)
        write(unit_num, '(2X, A)') 'alfa      E (cm-1)        Turning points (A)'
        write(unit_num, '(A)') repeat('-', 70)

        do i = 1, size(alpha_arr)
            write(unit_num, '(F6.1, 5F15.5)') alpha_arr(i), E_arr(i), x1(i), x2(i), x3(i), x4(i)
        end do

        close(unit_num)
    end subroutine write_turning_points

    ! -------------------------------------------------------------------------
    ! Write variational coefficients
    ! -------------------------------------------------------------------------
    subroutine write_coefficients(filename, coeffs, parity, ierr)
        character(len=*), intent(in) :: filename
        real(dp), intent(in) :: coeffs(:,:)
        character(len=*), intent(in) :: parity  ! "even" or "odd"
        integer, intent(out) :: ierr
        integer :: unit_num, i, j, n_basis, n_states

        n_basis = size(coeffs, 1)
        n_states = min(size(coeffs, 2), 3)  ! Print first 3 states

        open(newunit=unit_num, file=filename, status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        if (trim(parity) == "even") then
            write(unit_num, '(2X,A,6X,A,5X,A,5X,A)') 'i', 'c_i(Phi_0)', 'c_i(Phi_2)', 'c_i(Phi_4)'
            do j = 1, n_basis
                write(unit_num, '(I3, 100F15.5)') 2 * (j - 1), (coeffs(j, i), i = 1, n_states)
            end do
        else
            write(unit_num, '(2X,A,6X,A,5X,A,5X,A)') 'i', 'c_i(Phi_1)', 'c_i(Phi_3)', 'c_i(Phi_5)'
            do j = 1, n_basis
                write(unit_num, '(I3, 100F15.5)') 2 * j - 1, (coeffs(j, i), i = 1, n_states)
            end do
        end if

        close(unit_num)
    end subroutine write_coefficients

end module io
