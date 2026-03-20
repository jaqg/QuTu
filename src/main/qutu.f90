! =============================================================================
! Program: Quantum Tunneling (QuTu)
! Description: Quantum tunneling simulation in double-well potentials.
!              Solves the Schrodinger equation using variational method
!              with harmonic oscillator basis functions.
!              Calculations are performed in atomic units and later converted
!              to SI units.
!
! Author: Jose Antonio Quinonero Gris
!
! Creation date v0: 28/05/2022
! + Update v1.0.0: 20/01/2026:
!     - Refactored code (modules, types) and added comments
! =============================================================================
program qutu
    use constants
    use types
    use harmonic_oscillator
    use hamiltonian
    use wavepacket
    use io
    use input_reader
    implicit none

    ! System parameters
    type(system_params_t) :: params
    type(grid_params_t) :: grid
    type(input_params_t) :: input_params

    ! Input parameters
    integer :: N_max
    real(dp) :: xe_A, Vb_cm, xmin, xmax, dx, mH_uma, mN_uma

    ! Hamiltonian matrices and eigenvalues
    real(dp), allocatable :: H_even(:,:), H_odd(:,:)
    real(dp), allocatable :: H_full(:,:)               ! full N×N (polynomial/asymmetric path)
    real(dp), allocatable :: E_even(:), E_odd(:), E_all(:), E_all_cm(:)
    real(dp), allocatable :: work(:)
    integer :: lwork, info

    ! Reduced mass in atomic units (computed from whichever mass method is used)
    real(dp) :: mass_au

    ! Coefficient matrices (eigenvectors from diagonalization)
    real(dp), allocatable :: c_full(:,:)

    ! Grid arrays
    real(dp), allocatable :: x_grid(:), x_grid_A(:), V_grid(:), V_grid_cm(:)

    ! Wavefunction arrays
    real(dp), allocatable :: psi_even(:,:), psi_odd(:,:)
    real(dp), allocatable :: psi_even_A(:,:), psi_odd_A(:,:)

    ! Position matrix for expectation values
    real(dp), allocatable :: x_matrix(:,:)

    ! Turning points
    real(dp), allocatable :: alpha_4EE(:)
    real(dp), allocatable :: tp_x1(:), tp_x2(:), tp_x3(:), tp_x4(:), tp_E(:)

    ! Loop variables and indices
    integer :: i, j, ierr, N_loop
    integer :: n_steps_x, n_alpha

    ! Convergence analysis
    real(dp), allocatable :: E_arr(:,:)
    integer, allocatable :: N_conv(:)
    real(dp), allocatable :: E_conv(:), E_max(:)
    real(dp) :: E_sup, E_inf, delta_E

    ! Output
    integer :: ou                       ! OUTPUT file unit
    integer :: print_level              ! verbosity level
    character(len=256) :: data_dir      ! directory for dat files (print_level=2)

    ! =========================================================================
    ! INITIALIZATION
    ! =========================================================================

    ! Read unified INPUT file
    call read_input_file("INPUT", input_params, ierr)
    if (ierr /= 0) stop "Error reading INPUT file"

    ! Extract parameters
    N_max       = input_params%N_max
    xe_A        = input_params%xe
    Vb_cm       = input_params%Vb
    mH_uma      = input_params%mass_H
    mN_uma      = input_params%mass_N
    xmin        = input_params%xmin
    xmax        = input_params%xmax
    dx          = input_params%dx
    print_level = input_params%print_level

    data_dir = "data/"

    ! Open OUTPUT file
    open(newunit=ou, file='OUTPUT', status='replace', action='write', iostat=ierr)
    if (ierr /= 0) stop "Error: cannot open OUTPUT file"

    ! Write program banner
    call write_banner()

    write(*,'(A)') ' Reading INPUT file...'

    ! -------------------------------------------------------------------------
    ! Section 1: INPUT PARAMETERS
    ! -------------------------------------------------------------------------
    call write_section_header('1', 'INPUT PARAMETERS')
    write(ou,'(2X,A,T20,I0)')        'N_max       =', N_max
    write(ou,'(2X,A,T20,F8.4,2X,A)') 'xmin        =', xmin, 'a0'
    write(ou,'(2X,A,T20,F8.4,2X,A)') 'xmax        =', xmax, 'a0'
    write(ou,'(2X,A,T20,F6.4,2X,A)') 'dx          =', dx,   'a0'
    write(ou,'(2X,A,T20,I0)')        'print_level =', print_level
    if (input_params%use_polynomial) then
        write(ou,'(2X,A)') 'Mode        = polynomial'
        write(ou,'(2X,A,T20,I0)') 'poly_degree =', input_params%poly_degree
        block
            integer :: kk
            do kk = 0, input_params%poly_degree
                write(ou,'(2X,A,I0,A,T22,ES14.6,2X,A)') &
                    'v_poly(', kk, ')  =', input_params%v_poly(kk+1), 'Ha/a0^k'
            end do
        end block
        if (input_params%found_mass) then
            write(ou,'(2X,A,T20,F14.8,2X,A)') 'mass        =', input_params%mass, 'amu'
        else if (input_params%found_xyn_mass) then
            write(ou,'(2X,A,T20,F14.8,2X,A)') 'mass_central=', input_params%mass_central, 'amu'
            write(ou,'(2X,A,T20,F14.8,2X,A)') 'mass_ligand =', input_params%mass_ligand,  'amu'
            write(ou,'(2X,A,T20,I0)')          'n_ligands   =', input_params%n_ligands
        else
            write(ou,'(2X,A,T20,F14.11,2X,A)') 'mass_H      =', mH_uma, 'amu'
            write(ou,'(2X,A,T20,F14.11,2X,A)') 'mass_N      =', mN_uma, 'amu'
        end if
        if (input_params%alpha_override /= 0.0_dp) &
            write(ou,'(2X,A,T20,F10.5,2X,A)') 'alpha       =', input_params%alpha_override, 'a0^-2'
    else
        write(ou,'(2X,A)') 'Mode        = legacy (xe/Vb)'
        write(ou,'(2X,A,T20,F10.5,2X,A)')  'xe          =', xe_A,  'A'
        write(ou,'(2X,A,T20,F10.4,2X,A)')  'Vb          =', Vb_cm, 'cm-1'
        write(ou,'(2X,A,T20,F14.11,2X,A)') 'mass_H      =', mH_uma, 'amu'
        write(ou,'(2X,A,T20,F14.11,2X,A)') 'mass_N      =', mN_uma, 'amu'
    end if
    write(ou,'(A)') ''

    ! -------------------------------------------------------------------------
    ! Initialize system parameters (dispatch on mode)
    ! -------------------------------------------------------------------------
    if (input_params%use_polynomial) then
        ! Compute reduced mass in a.u. using priority: mass > XYn > legacy NH3
        if (input_params%found_mass) then
            mass_au = input_params%mass * UMA_TO_AU
        else if (input_params%found_xyn_mass) then
            block
                real(dp) :: mX, mY
                integer  :: nL
                mX = input_params%mass_central * UMA_TO_AU
                mY = input_params%mass_ligand  * UMA_TO_AU
                nL = input_params%n_ligands
                mass_au = real(nL, dp) * mY * mX / (real(nL, dp) * mY + mX)
            end block
        else
            block
                real(dp) :: mH_au, mN_au
                mH_au = mH_uma * UMA_TO_AU
                mN_au = mN_uma * UMA_TO_AU
                mass_au = (3.0_dp * mH_au * mN_au) / (3.0_dp * mH_au + mN_au)
            end block
        end if
        ! Determine alpha: user override or auto-compute from V''(0)
        if (input_params%alpha_override /= 0.0_dp) then
            call init_system_params_poly(params, N_max, mass_au, &
                                         input_params%v_poly, input_params%alpha_override)
        else
            block
                real(dp) :: alpha_auto
                alpha_auto = compute_optimal_alpha_poly(input_params%v_poly, mass_au, 0.0_dp)
                call init_system_params_poly(params, N_max, mass_au, &
                                             input_params%v_poly, alpha_auto)
            end block
        end if
        params%alpha_angstrom = params%alpha / RBOHR**2
    else
        call init_system_params(params, N_max, xe_A, Vb_cm, mH_uma, mN_uma)
        params%alpha = compute_optimal_alpha(params%mass, params%xe, params%Vb)
        params%alpha_angstrom = params%alpha / RBOHR**2
    end if

    ! Initialize grid
    call init_grid_params(grid, xmin, xmax, dx)
    n_steps_x = grid%n_points

    ! -------------------------------------------------------------------------
    ! Section 2: SYSTEM PARAMETERS
    ! -------------------------------------------------------------------------
    call write_section_header('2', 'SYSTEM PARAMETERS')
    if (params%use_polynomial) then
        write(ou,'(2X,A,T22,A)') 'Potential      =', 'polynomial V(x) = Σ vk*x^k'
        write(ou,'(2X,A,T22,L1)') 'is_symmetric   =', params%is_symmetric
    else
        write(ou,'(2X,A,T22,F10.5,2X,A,T42,F10.5,2X,A)') &
            'xe             =', params%xe,           'a0', params%xe_angstrom, 'A'
        write(ou,'(2X,A,T22,F10.8,2X,A,T42,F10.4,2X,A)') &
            'Vb             =', params%Vb,           'Ha', params%Vb_cm,       'cm-1'
        write(ou,'(2X,A,T22,E12.5,2X,A)') &
            'a (V coeff.)   =', params%Vb/params%xe**4,          'Ha/a0^4'
        write(ou,'(2X,A,T22,E12.5,2X,A)') &
            'b (V coeff.)   =', 2.0_dp*params%Vb/params%xe**2,   'Ha/a0^2'
    end if
    write(ou,'(2X,A,T22,F10.5,2X,A)') 'Reduced mass   =', params%mass, 'a.u.'
    write(ou,'(2X,A,T22,F10.5,2X,A,T42,F10.5,2X,A)') &
        'alpha (opt.)   =', params%alpha, 'a0^-2', params%alpha_angstrom, 'A^-2'
    write(ou,'(2X,A,T22,I0)') 'N_max          =', N_max
    write(ou,'(A)') ''

    write(*,'(A)') ' Initialising system...'

    ! =========================================================================
    ! GRID AND POTENTIAL SETUP
    ! =========================================================================
    allocate(x_grid(n_steps_x), x_grid_A(n_steps_x))
    allocate(V_grid(n_steps_x), V_grid_cm(n_steps_x))

    do i = 1, n_steps_x
        x_grid(i)   = xmin + dx * real(i - 1, dp)
        x_grid_A(i) = x_grid(i) * RBOHR
        if (params%use_polynomial) then
            V_grid(i) = potential_poly(x_grid(i), params%v_poly)
        else
            V_grid(i) = potential(x_grid(i), params%xe, params%Vb)
        end if
        V_grid_cm(i) = V_grid(i) * EUACM
    end do

    ! -------------------------------------------------------------------------
    ! Section 3: POTENTIAL ENERGY
    ! -------------------------------------------------------------------------
    call write_section_header('3', 'POTENTIAL ENERGY')
    if (print_level >= 1) then
        write(ou,'(A)') '$BEGIN POTENTIAL'
        write(ou,'(A)') '# columns: x(a0)   x(A)   V(Ha)   V(cm-1)'
        write(ou,'(A)') '#'
        do i = 1, n_steps_x
            write(ou,'(F10.4,F10.4,F18.8,F14.4)') &
                x_grid(i), x_grid_A(i), V_grid(i), V_grid_cm(i)
        end do
        write(ou,'(A)') '$END POTENTIAL'
        write(ou,'(A)') ''
    else
        write(ou,'(2X,A)') '(grid data suppressed at print_level=0)'
        write(ou,'(A)') ''
    end if

    if (print_level >= 2) then
        call write_potential(trim(data_dir)//"out-potencial_hartrees.dat", &
                             x_grid, V_grid, "a0", "Ha", ierr)
        call write_potential(trim(data_dir)//"out-potencial_cm-1.dat", &
                             x_grid_A, V_grid_cm, "A", "cm-1", ierr)
    end if

    ! =========================================================================
    ! VARIATIONAL METHOD - Loop over basis sizes
    ! =========================================================================
    write(*,'(A)') ' Running variational calculation...'

    allocate(E_arr(N_max - 1, N_max))
    E_arr = 0.0_dp

    do N_loop = 2, N_max
        params%N = N_loop
        params%N_odd  = params%N / 2
        params%N_even = params%N - params%N_odd

        allocate(E_all(params%N))

        if (params%use_polynomial .and. .not. params%is_symmetric) then
            ! ------------------------------------------------------------------
            ! Full N×N path — polynomial asymmetric/general case
            ! ------------------------------------------------------------------
            call build_hamiltonian_full(params, H_full)

            lwork = 3 * params%N
            if (allocated(work)) deallocate(work)
            allocate(work(lwork))

            call dsyev('V', 'U', params%N, H_full, params%N, E_all, work, lwork, info)
            if (info /= 0) then
                write(*,*) 'Error: Full matrix diagonalization failed, info =', info
                stop
            end if
            ! No Vb shift — constant term is already inside the polynomial matrix

        else
            ! ------------------------------------------------------------------
            ! Block-diagonal path — legacy or symmetric polynomial case
            ! ------------------------------------------------------------------
            call build_hamiltonian_matrices(params, H_even, H_odd)

            lwork = 3 * params%N
            if (allocated(work)) deallocate(work)
            allocate(work(lwork))

            allocate(E_even(params%N_even))
            call dsyev('V', 'U', params%N_even, H_even, params%N_even, E_even, work, lwork, info)
            if (info /= 0) then
                write(*,*) 'Error: Even matrix diagonalization failed, info =', info
                stop
            end if

            allocate(E_odd(params%N_odd))
            call dsyev('V', 'U', params%N_odd, H_odd, params%N_odd, E_odd, work, lwork, info)
            if (info /= 0) then
                write(*,*) 'Error: Odd matrix diagonalization failed, info =', info
                stop
            end if

            ! Combine energies (interleave even and odd)
            do i = 1, params%N_even
                ! Add Vb shift only in legacy mode (polynomial constant term is in the matrix)
                if (params%use_polynomial) then
                    E_all(2*i - 1) = E_even(i)
                else
                    E_all(2*i - 1) = E_even(i) + params%Vb
                end if
            end do
            do i = 1, params%N_odd
                if (params%use_polynomial) then
                    E_all(2*i) = E_odd(i)
                else
                    E_all(2*i) = E_odd(i) + params%Vb
                end if
            end do

            if (allocated(E_even)) deallocate(E_even)
            if (allocated(E_odd))  deallocate(E_odd)
        end if

        ! Store for convergence analysis
        do i = 1, params%N
            E_arr(params%N - 1, i) = E_all(i)
        end do

        ! -----------------------------------------------------------------
        ! At N_max: compute all properties and write sections 4-10
        ! -----------------------------------------------------------------
        if (params%N == N_max) then
            write(*,'(A)') ' Computing properties at N_max...'

            allocate(E_all_cm(N_max))
            E_all_cm = E_all * EUACM

            ! -----------------------------------------------------------------
            ! Section 4: ENERGIES
            ! -----------------------------------------------------------------
            call write_section_header('4', 'VARIATIONAL ENERGIES')
            write(ou,'(2X,A,I0)') 'N_max = ', N_max
            write(ou,'(A)') ''
            write(ou,'(A)') '$BEGIN ENERGIES'
            if (params%is_symmetric) then
                write(ou,'(A)') '# columns: n   parity   E(Ha)   E(cm-1)'
            else
                write(ou,'(A)') '# columns: n   E(Ha)   E(cm-1)'
            end if
            write(ou,'(A)') '#'
            do i = 1, N_max
                if (params%is_symmetric) then
                    if (mod(i-1, 2) == 0) then
                        write(ou,'(I4,3X,A4,3X,F18.10,F16.4)') i-1, 'even', E_all(i), E_all_cm(i)
                    else
                        write(ou,'(I4,3X,A4,3X,F18.10,F16.4)') i-1, 'odd ', E_all(i), E_all_cm(i)
                    end if
                else
                    write(ou,'(I4,3X,F18.10,F16.4)') i-1, E_all(i), E_all_cm(i)
                end if
            end do
            write(ou,'(A)') '$END ENERGIES'
            write(ou,'(A)') ''

            ! -----------------------------------------------------------------
            ! Section 5: CONVERGENCE ANALYSIS
            ! -----------------------------------------------------------------
            allocate(N_conv(21), E_conv(21), E_max(21))

            do j = 1, 21
                N_conv(j) = N_max   ! default: not converged within loop
                do i = 1, N_max - 1
                    E_sup   = E_arr(N_max - 1, j)
                    E_inf   = E_arr(i, j)
                    delta_E = E_inf - E_sup
                    if (abs(delta_E) < ENERGY_CONV_THRESHOLD) then
                        N_conv(j) = i + 1
                        E_conv(j) = E_inf
                        exit
                    end if
                end do
                E_max(j) = E_arr(N_max - 1, j)
            end do

            call write_section_header('5', 'CONVERGENCE ANALYSIS')

            write(ou,'(A)') '$BEGIN CONVERGENCE'
            write(ou,'(A)') '# columns: n   N_conv   E_conv(Ha)   E_conv(cm-1)   E_max(Ha)   E_max(cm-1)'
            write(ou,'(A)') '#'
            do i = 1, 21
                write(ou,'(I3,I7,2F18.10,2F16.4)') &
                    i-1, N_conv(i), E_conv(i), E_conv(i)*EUACM, E_max(i), E_max(i)*EUACM
            end do
            write(ou,'(A)') '$END CONVERGENCE'
            write(ou,'(A)') ''

            call write_subsection_header('5.1  N vs Energy (first 4 levels, cm-1)')
            write(ou,'(A)') '$BEGIN N_VS_ENERGY'
            write(ou,'(A)') '# columns: N   W0(cm-1)   W1(cm-1)   W2(cm-1)   W3(cm-1)'
            write(ou,'(A)') '#'
            do i = 2, N_max, 2
                if (i - 1 <= size(E_arr, 1) .and. 4 <= size(E_arr, 2)) then
                    write(ou,'(I4,4F16.4)') i, &
                        E_arr(i-1,1)*EUACM, E_arr(i-1,2)*EUACM, &
                        E_arr(i-1,3)*EUACM, E_arr(i-1,4)*EUACM
                end if
            end do
            write(ou,'(A)') '$END N_VS_ENERGY'
            write(ou,'(A)') ''

            if (print_level >= 2) then
                call write_convergence(trim(data_dir)//"out-conver_energias_hartrees.dat", &
                                       21, N_conv, E_conv, E_max, "Ha", ierr)
                E_conv = E_conv * EUACM
                E_max  = E_max  * EUACM
                call write_convergence(trim(data_dir)//"out-conver_energias_cm-1.dat", &
                                       21, N_conv, E_conv, E_max, "cm-1", ierr)
                call write_N_vs_W_files(data_dir, E_arr, N_max, N_conv, ierr)
            end if

            deallocate(N_conv, E_conv, E_max)

            ! -----------------------------------------------------------------
            ! Wavefunctions & wavepackets
            ! -----------------------------------------------------------------
            if (params%is_symmetric) then
                ! Symmetric path: use existing even/odd wavefunction routines
                call build_coefficient_matrix(H_even, H_odd, params%N_even, params%N_odd, c_full)
                call compute_wavefunctions(params, H_even, H_odd, x_grid, x_grid_A, &
                                           psi_even, psi_odd, psi_even_A, psi_odd_A)

                ! Section 6: EIGENSTATES
                call write_eigenstates(x_grid, x_grid_A, psi_even, psi_odd, &
                                       psi_even_A, psi_odd_A)

                ! Section 7 + 8: TWO-STATE WAVEPACKETS + SURVIVAL PROBABILITY
                call write_two_state_sections(E_all, psi_even, psi_odd, &
                                              psi_even_A, psi_odd_A, x_grid, x_grid_A)
            else
                ! Asymmetric path: full eigenvectors in H_full
                call compute_wavefunctions_full(params, H_full, x_grid, x_grid_A, &
                                                psi_even, psi_odd, psi_even_A, psi_odd_A)

                ! Section 6: EIGENSTATES (using unified psi arrays)
                call write_eigenstates(x_grid, x_grid_A, psi_even, psi_odd, &
                                       psi_even_A, psi_odd_A)

                ! Section 7 + 8: TWO-STATE WAVEPACKETS
                call write_two_state_sections(E_all, psi_even, psi_odd, &
                                              psi_even_A, psi_odd_A, x_grid, x_grid_A)
            end if

            ! -----------------------------------------------------------------
            ! 4-state wavepacket calculations with varying alpha
            ! (symmetric path only — uses legacy turning_points with xe/Vb)
            ! -----------------------------------------------------------------
            if (params%is_symmetric) then
                n_alpha = input_params%n_alpha_values
                allocate(alpha_4EE(n_alpha))
                alpha_4EE = input_params%alpha_values

                allocate(tp_x1(n_alpha), tp_x2(n_alpha), tp_x3(n_alpha), tp_x4(n_alpha), tp_E(n_alpha))

                ! Build position matrix for expectation values
                call build_position_matrix(params%N, params%alpha_angstrom, x_matrix)

                ! Section 9: FOUR-STATE WAVEPACKETS
                call write_four_state_sections(params, E_all, alpha_4EE, &
                                               psi_even_A, psi_odd_A, x_grid_A, &
                                               c_full, x_matrix, &
                                               tp_E, tp_x1, tp_x2, tp_x3, tp_x4)

                deallocate(alpha_4EE, tp_x1, tp_x2, tp_x3, tp_x4, tp_E)
            end if

            ! Section 10: COEFFICIENTS (symmetric path only)
            if (params%is_symmetric) then
                call write_coefficients_section(H_even, H_odd, params%N_even, params%N_odd)
                if (print_level >= 2) then
                    call write_coefficients(trim(data_dir)//"out-coeficientes_par.dat", &
                                            H_even, "even", ierr)
                    call write_coefficients(trim(data_dir)//"out-coeficientes_impar.dat", &
                                            H_odd, "odd", ierr)
                end if
            end if
        end if

        ! Cleanup for next iteration
        if (allocated(H_even)) deallocate(H_even)
        if (allocated(H_odd))  deallocate(H_odd)
        if (allocated(H_full)) deallocate(H_full)
        deallocate(E_all)
    end do

    ! =========================================================================
    ! COMPLETION
    ! =========================================================================
    write(ou,'(A)') ''
    write(ou,'(A)') repeat('=', 80)
    write(ou,'(2X,A)') 'CALCULATION COMPLETED SUCCESSFULLY'
    write(ou,'(A)') repeat('=', 80)
    write(ou,'(A)') ''

    close(ou)

    ! Cleanup
    deallocate(x_grid, x_grid_A, V_grid, V_grid_cm)
    deallocate(E_arr)
    if (allocated(E_all_cm)) deallocate(E_all_cm)
    if (allocated(c_full)) deallocate(c_full)
    if (allocated(psi_even)) deallocate(psi_even)
    if (allocated(psi_odd)) deallocate(psi_odd)
    if (allocated(psi_even_A)) deallocate(psi_even_A)
    if (allocated(psi_odd_A)) deallocate(psi_odd_A)
    if (allocated(x_matrix)) deallocate(x_matrix)
    if (allocated(work)) deallocate(work)

    write(*,'(A)') ' Program completed successfully.'
    write(*,'(A)') ' Results written to: OUTPUT'
    if (print_level >= 2) write(*,'(A,A)') ' Debug dat files written to: ', trim(data_dir)

contains

    ! =========================================================================
    ! ASCII formatting helpers
    ! =========================================================================

    subroutine write_banner()
        write(ou,'(A)') repeat('#', 80)
        write(ou,'(A)') '#' // repeat(' ', 78) // '#'
        write(ou,'(A)') '#   QuTu  -  Quantum Tunneling Simulation' // repeat(' ', 38) // '#'
        write(ou,'(A)') '#   Version: 1.0.0-dev' // repeat(' ', 57) // '#'
        write(ou,'(A)') '#' // repeat(' ', 78) // '#'
        write(ou,'(A)') '#   Author : Jose Antonio Quinonero Gris' // repeat(' ', 39) // '#'
        write(ou,'(A)') '#' // repeat(' ', 78) // '#'
        write(ou,'(A)') repeat('#', 80)
        write(ou,'(A)') ''
    end subroutine write_banner

    subroutine write_section_header(num, title)
        character(len=*), intent(in) :: num, title
        write(ou,'(A)') ''
        write(ou,'(A)') repeat('=', 80)
        write(ou,'(2X,A,A,2X,A)') trim(num), '.', trim(title)
        write(ou,'(A)') repeat('=', 80)
        write(ou,'(A)') ''
    end subroutine write_section_header

    subroutine write_subsection_header(title)
        character(len=*), intent(in) :: title
        write(ou,'(A)') ''
        write(ou,'(4X,A)') repeat('-', 50)
        write(ou,'(4X,A)') trim(title)
        write(ou,'(4X,A)') repeat('-', 50)
        write(ou,'(A)') ''
    end subroutine write_subsection_header

    ! =========================================================================
    ! Build full coefficient matrix from even/odd diagonalization results
    ! =========================================================================
    subroutine build_coefficient_matrix(H_even, H_odd, N_even, N_odd, c_full)
        real(dp), intent(in) :: H_even(:,:), H_odd(:,:)
        integer, intent(in) :: N_even, N_odd
        real(dp), allocatable, intent(out) :: c_full(:,:)
        integer :: ii, jj, N_total

        N_total = N_even + N_odd
        allocate(c_full(N_total, N_total))
        c_full = 0.0_dp

        do jj = 1, N_even
            if (jj == 1) then
                do ii = 1, N_even
                    c_full(2*ii - 1, 2*jj - 1) = -H_even(ii, jj)
                end do
            else
                do ii = 1, N_even
                    c_full(2*ii - 1, 2*jj - 1) = H_even(ii, jj)
                end do
            end if
        end do

        do jj = 1, N_odd
            if (jj == 1 .or. jj == 2) then
                do ii = 1, N_odd
                    c_full(2*ii, 2*jj) = -H_odd(ii, jj)
                end do
            else
                do ii = 1, N_odd
                    c_full(2*ii, 2*jj) = H_odd(ii, jj)
                end do
            end if
        end do
    end subroutine build_coefficient_matrix

    ! =========================================================================
    ! Compute wavefunctions on grid
    ! =========================================================================
    subroutine compute_wavefunctions(params, H_even, H_odd, x_grid, x_grid_A, &
                                     psi_even, psi_odd, psi_even_A, psi_odd_A)
        type(system_params_t), intent(in) :: params
        real(dp), intent(in) :: H_even(:,:), H_odd(:,:)
        real(dp), intent(in) :: x_grid(:), x_grid_A(:)
        real(dp), allocatable, intent(out) :: psi_even(:,:), psi_odd(:,:)
        real(dp), allocatable, intent(out) :: psi_even_A(:,:), psi_odd_A(:,:)
        integer :: ii, jj, k, n_x, n_states
        real(dp) :: coeff, alpha_A, sign_factor

        n_x      = size(x_grid)
        n_states = 3
        alpha_A  = params%alpha_angstrom

        allocate(psi_even(n_x, n_states), psi_odd(n_x, n_states))
        allocate(psi_even_A(n_x, n_states), psi_odd_A(n_x, n_states))
        psi_even   = 0.0_dp
        psi_odd    = 0.0_dp
        psi_even_A = 0.0_dp
        psi_odd_A  = 0.0_dp

        do ii = 1, n_x
            do jj = 1, n_states
                sign_factor = merge(-1.0_dp, 1.0_dp, jj == 1)
                do k = 1, params%N_even
                    coeff = H_even(k, jj) * sign_factor
                    if (abs(coeff) > COEFF_THRESHOLD) then
                        psi_even(ii, jj)   = psi_even(ii, jj)   + coeff * phi(2*(k-1), params%alpha, x_grid(ii))
                        psi_even_A(ii, jj) = psi_even_A(ii, jj) + coeff * phi(2*(k-1), alpha_A,       x_grid_A(ii))
                    end if
                end do
            end do
        end do

        do ii = 1, n_x
            do jj = 1, min(n_states, params%N_odd)
                sign_factor = merge(-1.0_dp, 1.0_dp, jj <= 2)
                do k = 1, params%N_odd
                    coeff = H_odd(k, jj) * sign_factor
                    if (abs(coeff) > COEFF_THRESHOLD) then
                        psi_odd(ii, jj)   = psi_odd(ii, jj)   + coeff * phi(2*k-1, params%alpha, x_grid(ii))
                        psi_odd_A(ii, jj) = psi_odd_A(ii, jj) + coeff * phi(2*k-1, alpha_A,       x_grid_A(ii))
                    end if
                end do
            end do
        end do
    end subroutine compute_wavefunctions

    ! =========================================================================
    ! Compute wavefunctions on grid — full N×N path (asymmetric/general case)
    !
    ! H_full(:,:) on input contains the eigenvectors from dsyev (column jj =
    ! eigenvector for eigenstate jj-1, expressed in the HO basis n = 0..N-1).
    ! Outputs psi_even/psi_odd holding the first 3 states each, matching the
    ! interface expected by write_eigenstates and write_two_state_sections.
    ! =========================================================================
    subroutine compute_wavefunctions_full(params, H_full, x_grid, x_grid_A, &
                                          psi_even, psi_odd, psi_even_A, psi_odd_A)
        type(system_params_t), intent(in) :: params
        real(dp), intent(in) :: H_full(:,:)
        real(dp), intent(in) :: x_grid(:), x_grid_A(:)
        real(dp), allocatable, intent(out) :: psi_even(:,:), psi_odd(:,:)
        real(dp), allocatable, intent(out) :: psi_even_A(:,:), psi_odd_A(:,:)
        integer :: ii, jj, k, n_x, n_states
        real(dp) :: coeff, alpha_A

        n_x      = size(x_grid)
        n_states = 3
        alpha_A  = params%alpha_angstrom

        allocate(psi_even(n_x, n_states), psi_odd(n_x, n_states))
        allocate(psi_even_A(n_x, n_states), psi_odd_A(n_x, n_states))
        psi_even   = 0.0_dp;  psi_odd    = 0.0_dp
        psi_even_A = 0.0_dp;  psi_odd_A  = 0.0_dp

        ! Map: psi_even(:,jj) = state 2*(jj-1)   (n=0, 2, 4)
        !      psi_odd (:,jj) = state 2*jj-1      (n=1, 3, 5)
        do jj = 1, n_states
            do ii = 1, n_x
                do k = 1, params%N
                    coeff = H_full(k, 2*(jj-1)+1)   ! even state index
                    if (abs(coeff) > COEFF_THRESHOLD) then
                        psi_even(ii, jj)   = psi_even(ii, jj)   + coeff * phi(k-1, params%alpha, x_grid(ii))
                        psi_even_A(ii, jj) = psi_even_A(ii, jj) + coeff * phi(k-1, alpha_A,       x_grid_A(ii))
                    end if
                    if (2*jj <= params%N) then
                        coeff = H_full(k, 2*jj)        ! odd state index
                        if (abs(coeff) > COEFF_THRESHOLD) then
                            psi_odd(ii, jj)   = psi_odd(ii, jj)   + coeff * phi(k-1, params%alpha, x_grid(ii))
                            psi_odd_A(ii, jj) = psi_odd_A(ii, jj) + coeff * phi(k-1, alpha_A,       x_grid_A(ii))
                        end if
                    end if
                end do
            end do
        end do
    end subroutine compute_wavefunctions_full

    ! =========================================================================
    ! Section 6: EIGENSTATES
    ! =========================================================================
    subroutine write_eigenstates(x_grid, x_grid_A, psi_even, psi_odd, &
                                  psi_even_A, psi_odd_A)
        real(dp), intent(in) :: x_grid(:), x_grid_A(:)
        real(dp), intent(in) :: psi_even(:,:), psi_odd(:,:)
        real(dp), intent(in) :: psi_even_A(:,:), psi_odd_A(:,:)
        integer :: ii, unit_num, io_err
        integer :: n_x

        n_x = size(x_grid)

        call write_section_header('6', 'EIGENSTATES')

        ! ------------------------------------------------------------------
        ! 6.1 Wavefunctions
        ! ------------------------------------------------------------------
        call write_subsection_header('6.1  Wavefunctions')
        if (print_level >= 1) then
            write(ou,'(A)') '$BEGIN WAVEFUNCTIONS'
            write(ou,'(A)') '# Phi0,Phi2,Phi4 are even-parity; Phi1,Phi3,Phi5 are odd-parity'
            write(ou,'(A)') '# columns: x(a0)   x(A)   Phi0   Phi1   Phi2   Phi3   Phi4   Phi5'
            write(ou,'(A)') '#'
            do ii = 1, n_x
                write(ou,'(F10.4,F10.4,6F14.6)') &
                    x_grid(ii), x_grid_A(ii), &
                    psi_even(ii,1), psi_odd(ii,1), &
                    psi_even(ii,2), psi_odd(ii,2), &
                    psi_even(ii,3), psi_odd(ii,3)
            end do
            write(ou,'(A)') '$END WAVEFUNCTIONS'
            write(ou,'(A)') ''
        else
            write(ou,'(2X,A)') '(grid data suppressed at print_level=0)'
            write(ou,'(A)') ''
        end if

        ! ------------------------------------------------------------------
        ! 6.2 Probability densities
        ! ------------------------------------------------------------------
        call write_subsection_header('6.2  Probability densities')
        if (print_level >= 1) then
            write(ou,'(A)') '$BEGIN DENSITIES'
            write(ou,'(A)') '# columns: x(a0)   x(A)   |Phi0|^2   |Phi1|^2   |Phi2|^2   |Phi3|^2   |Phi4|^2   |Phi5|^2'
            write(ou,'(A)') '#'
            do ii = 1, n_x
                write(ou,'(F10.4,F10.4,6F14.6)') &
                    x_grid(ii), x_grid_A(ii), &
                    psi_even(ii,1)**2, psi_odd(ii,1)**2, &
                    psi_even(ii,2)**2, psi_odd(ii,2)**2, &
                    psi_even(ii,3)**2, psi_odd(ii,3)**2
            end do
            write(ou,'(A)') '$END DENSITIES'
            write(ou,'(A)') ''
        else
            write(ou,'(2X,A)') '(grid data suppressed at print_level=0)'
            write(ou,'(A)') ''
        end if

        if (print_level >= 2) then
            open(newunit=unit_num, file=trim(data_dir)//"out-funciones_pares_hartrees.dat", &
                 status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(6X,A,11X,A,8X,A,8X,A)') 'x (a0)', 'Phi0(x)', 'Phi2(x)', 'Phi4(x)'
            do ii = 1, n_x
                write(unit_num,'(F10.3,3F15.5)') x_grid(ii), psi_even(ii,1), psi_even(ii,2), psi_even(ii,3)
            end do
            close(unit_num)

            open(newunit=unit_num, file=trim(data_dir)//"out-densidad_prob_pares_hartrees.dat", &
                 status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(6X,A,11X,A,7X,A,7X,A)') 'x (a0)', '|Phi0|^2', '|Phi2|^2', '|Phi4|^2'
            do ii = 1, n_x
                write(unit_num,'(F10.3,3F15.5)') x_grid(ii), psi_even(ii,1)**2, psi_even(ii,2)**2, psi_even(ii,3)**2
            end do
            close(unit_num)

            open(newunit=unit_num, file=trim(data_dir)//"out-funciones_impares_hartrees.dat", &
                 status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(6X,A,11X,A,8X,A,8X,A)') 'x (a0)', 'Phi1(x)', 'Phi3(x)', 'Phi5(x)'
            do ii = 1, n_x
                write(unit_num,'(F10.3,3F15.5)') x_grid(ii), psi_odd(ii,1), psi_odd(ii,2), psi_odd(ii,3)
            end do
            close(unit_num)

            open(newunit=unit_num, file=trim(data_dir)//"out-densidad_prob_impares_hartrees.dat", &
                 status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(6X,A,11X,A,7X,A,7X,A)') 'x (a0)', '|Phi1|^2', '|Phi3|^2', '|Phi5|^2'
            do ii = 1, n_x
                write(unit_num,'(F10.3,3F15.5)') x_grid(ii), psi_odd(ii,1)**2, psi_odd(ii,2)**2, psi_odd(ii,3)**2
            end do
            close(unit_num)

            open(newunit=unit_num, file=trim(data_dir)//"out-funciones_pares_A.dat", &
                 status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(6X,A,12X,A,8X,A,8X,A)') 'x (A)', 'Phi0(x)', 'Phi2(x)', 'Phi4(x)'
            do ii = 1, n_x
                write(unit_num,'(F10.3,3F15.5)') x_grid_A(ii), psi_even_A(ii,1), psi_even_A(ii,2), psi_even_A(ii,3)
            end do
            close(unit_num)

            open(newunit=unit_num, file=trim(data_dir)//"out-densidad_prob_pares_A.dat", &
                 status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(6X,A,12X,A,7X,A,7X,A)') 'x (A)', '|Phi0|^2', '|Phi2|^2', '|Phi4|^2'
            do ii = 1, n_x
                write(unit_num,'(F10.3,3F15.5)') x_grid_A(ii), psi_even_A(ii,1)**2, psi_even_A(ii,2)**2, psi_even_A(ii,3)**2
            end do
            close(unit_num)

            open(newunit=unit_num, file=trim(data_dir)//"out-funciones_impares_A.dat", &
                 status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(6X,A,12X,A,8X,A,8X,A)') 'x (A)', 'Phi1(x)', 'Phi3(x)', 'Phi5(x)'
            do ii = 1, n_x
                write(unit_num,'(F10.3,3F15.5)') x_grid_A(ii), psi_odd_A(ii,1), psi_odd_A(ii,2), psi_odd_A(ii,3)
            end do
            close(unit_num)

            open(newunit=unit_num, file=trim(data_dir)//"out-densidad_prob_impares_A.dat", &
                 status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(6X,A,12X,A,7X,A,7X,A)') 'x (A)', '|Phi1|^2', '|Phi3|^2', '|Phi5|^2'
            do ii = 1, n_x
                write(unit_num,'(F10.3,3F15.5)') x_grid_A(ii), psi_odd_A(ii,1)**2, psi_odd_A(ii,2)**2, psi_odd_A(ii,3)**2
            end do
            close(unit_num)
        end if
    end subroutine write_eigenstates

    ! =========================================================================
    ! Sections 7 & 8: TWO-STATE WAVEPACKETS + SURVIVAL PROBABILITY
    ! =========================================================================
    subroutine write_two_state_sections(E_all, psi_even, psi_odd, &
                                         psi_even_A, psi_odd_A, x_grid, x_grid_A)
        real(dp), intent(in) :: E_all(:)
        real(dp), intent(in) :: psi_even(:,:), psi_odd(:,:)
        real(dp), intent(in) :: psi_even_A(:,:), psi_odd_A(:,:)
        real(dp), intent(in) :: x_grid(:), x_grid_A(:)

        integer :: ii, unit_num, io_err, n_x, n_steps
        real(dp) :: c1, c2, E_psi1, E_psi1_cm, E_psi2, E_psi2_cm
        real(dp) :: tr1, tr2
        real(dp) :: t0, tf, dt, t_val, Ps
        real(dp) :: c_wp(2), E_wp(2)
        real(dp), allocatable :: Psi_A(:), Psi_B(:), Psi_C(:), Psi_D(:)
        real(dp), allocatable :: Psi_A_a(:), Psi_B_a(:), Psi_C_a(:), Psi_D_a(:)
        character(len=256) :: fname

        n_x = size(x_grid)
        c1  = 1.0_dp / sqrt(2.0_dp)
        c2  = 1.0_dp / sqrt(2.0_dp)

        allocate(Psi_A(n_x), Psi_B(n_x), Psi_C(n_x), Psi_D(n_x))
        allocate(Psi_A_a(n_x), Psi_B_a(n_x), Psi_C_a(n_x), Psi_D_a(n_x))

        ! Psi_A = (Phi0 + Phi1)/sqrt(2), Psi_B = (Phi0 - Phi1)/sqrt(2)
        Psi_A   = c1 * psi_even(:,1) + c2 * psi_odd(:,1)
        Psi_B   = c1 * psi_even(:,1) - c2 * psi_odd(:,1)
        Psi_A_a = c1 * psi_even_A(:,1) + c2 * psi_odd_A(:,1)
        Psi_B_a = c1 * psi_even_A(:,1) - c2 * psi_odd_A(:,1)

        ! Psi_C = (Phi2 + Phi3)/sqrt(2), Psi_D = (Phi2 - Phi3)/sqrt(2)
        Psi_C   = c1 * psi_even(:,2) + c2 * psi_odd(:,2)
        Psi_D   = c1 * psi_even(:,2) - c2 * psi_odd(:,2)
        Psi_C_a = c1 * psi_even_A(:,2) + c2 * psi_odd_A(:,2)
        Psi_D_a = c1 * psi_even_A(:,2) - c2 * psi_odd_A(:,2)

        E_psi1    = 0.5_dp * E_all(1) + 0.5_dp * E_all(2)
        E_psi1_cm = E_psi1 * EUACM
        E_psi2    = 0.5_dp * E_all(3) + 0.5_dp * E_all(4)
        E_psi2_cm = E_psi2 * EUACM

        tr1 = recurrence_time(E_all(1), E_all(2)) * 1.0e12_dp  ! ps
        tr2 = recurrence_time(E_all(3), E_all(4)) * 1.0e12_dp

        ! ---------------------------------------------------------------
        ! Section 7: TWO-STATE WAVEPACKETS
        ! ---------------------------------------------------------------
        call write_section_header('7', 'TWO-STATE WAVEPACKETS')

        write(ou,'(2X,A,F12.4,2X,A,F14.5,2X,A)') &
            'Psi_A = (Phi0 + Phi1)/sqrt(2)    E =', E_psi1_cm, 'cm-1    tr =', tr1, 'ps'
        write(ou,'(2X,A,F12.4,2X,A)') &
            'Psi_B = (Phi0 - Phi1)/sqrt(2)    E =', E_psi1_cm, 'cm-1'
        write(ou,'(2X,A,F12.4,2X,A,F14.5,2X,A)') &
            'Psi_C = (Phi2 + Phi3)/sqrt(2)    E =', E_psi2_cm, 'cm-1    tr =', tr2, 'ps'
        write(ou,'(2X,A,F12.4,2X,A)') &
            'Psi_D = (Phi2 - Phi3)/sqrt(2)    E =', E_psi2_cm, 'cm-1'
        write(ou,'(A)') ''

        if (print_level >= 1) then
            write(ou,'(A)') '$BEGIN WAVEPACKETS_2STATE'
            write(ou,'(A)') '# columns: x(a0)   x(A)   Psi_A   |Psi_A|^2' // &
                            '   Psi_B   |Psi_B|^2   Psi_C   |Psi_C|^2   Psi_D   |Psi_D|^2'
            write(ou,'(A)') '#'
            do ii = 1, n_x
                write(ou,'(F10.4,F10.4,8F12.5)') &
                    x_grid(ii), x_grid_A(ii), &
                    Psi_A(ii), Psi_A(ii)**2, &
                    Psi_B(ii), Psi_B(ii)**2, &
                    Psi_C(ii), Psi_C(ii)**2, &
                    Psi_D(ii), Psi_D(ii)**2
            end do
            write(ou,'(A)') '$END WAVEPACKETS_2STATE'
            write(ou,'(A)') ''
        else
            write(ou,'(2X,A)') '(grid data suppressed at print_level=0)'
            write(ou,'(A)') ''
        end if

        ! ---------------------------------------------------------------
        ! Section 8: SURVIVAL PROBABILITY (two-state)
        ! ---------------------------------------------------------------
        call write_section_header('8', 'SURVIVAL PROBABILITY  [two-state wavepackets]')

        t0      = 0.0_dp
        tf      = 100.0_dp
        dt      = 0.1_dp
        n_steps = int((tf - t0) / dt) + 1

        if (print_level >= 1) then
            write(ou,'(A)') '$BEGIN SURVIVAL_2STATE'
            write(ou,'(A)') '# Psi_A = (Phi0+Phi1)/sqrt(2)   Psi_C = (Phi2+Phi3)/sqrt(2)'
            write(ou,'(A)') '# columns: t(ps)   Ps_A(t)   Ps_C(t)'
            write(ou,'(A)') '#'

            c_wp = [c1, c2]
            do ii = 1, n_steps
                t_val = t0 + dt * real(ii - 1, dp)
                E_wp  = [E_all(1), E_all(2)]
                Ps    = survival_probability(c_wp, E_wp, t_val)
                write(ou,'(F8.4,F15.6)', advance='no') t_val, Ps
                E_wp  = [E_all(3), E_all(4)]
                Ps    = survival_probability(c_wp, E_wp, t_val)
                write(ou,'(F15.6)') Ps
            end do
            write(ou,'(A)') '$END SURVIVAL_2STATE'
            write(ou,'(A)') ''
        else
            write(ou,'(2X,A)') '(time-series data suppressed at print_level=0)'
            write(ou,'(A)') ''
        end if

        if (print_level >= 2) then
            ! psi1..psi4 individual dat files (atomic units)
            open(newunit=unit_num, file=trim(data_dir)//"out-psi1.dat", status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('=', 70)
            write(unit_num,'(5X,A)') 'psi = 1/dsqrt(2) Phi_0 + 1/dsqrt(2) Phi_1'
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(8X,A,8X,A,11X,A,8X,A)') 'E (Ha)', 'x (a0)', 'psi(x)', '|psi(x)|^2'
            do ii = 1, n_x
                write(unit_num,'(F15.5,F10.3,2F15.5)') E_psi1, x_grid(ii), Psi_A(ii), Psi_A(ii)**2
            end do
            close(unit_num)

            open(newunit=unit_num, file=trim(data_dir)//"out-psi2.dat", status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('=', 70)
            write(unit_num,'(5X,A)') 'psi = 1/dsqrt(2) Phi_0 - 1/dsqrt(2) Phi_1'
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(8X,A,8X,A,11X,A,8X,A)') 'E (Ha)', 'x (a0)', 'psi(x)', '|psi(x)|^2'
            do ii = 1, n_x
                write(unit_num,'(F15.5,F10.3,2F15.5)') E_psi1, x_grid(ii), Psi_B(ii), Psi_B(ii)**2
            end do
            close(unit_num)

            open(newunit=unit_num, file=trim(data_dir)//"out-psi3.dat", status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('=', 70)
            write(unit_num,'(5X,A)') 'psi = 1/dsqrt(2) Phi_2 + 1/dsqrt(2) Phi_3'
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(8X,A,8X,A,11X,A,8X,A)') 'E (Ha)', 'x (a0)', 'psi(x)', '|psi(x)|^2'
            do ii = 1, n_x
                write(unit_num,'(F15.5,F10.3,2F15.5)') E_psi2, x_grid(ii), Psi_C(ii), Psi_C(ii)**2
            end do
            close(unit_num)

            open(newunit=unit_num, file=trim(data_dir)//"out-psi4.dat", status='replace', iostat=io_err)
            write(unit_num,'(A)') repeat('=', 70)
            write(unit_num,'(5X,A)') 'psi = 1/dsqrt(2) Phi_2 - 1/dsqrt(2) Phi_3'
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(8X,A,8X,A,11X,A,8X,A)') 'E (Ha)', 'x (a0)', 'psi(x)', '|psi(x)|^2'
            do ii = 1, n_x
                write(unit_num,'(F15.5,F10.3,2F15.5)') E_psi2, x_grid(ii), Psi_D(ii), Psi_D(ii)**2
            end do
            close(unit_num)

            ! Angstrom versions
            fname = trim(data_dir)//"out-psi1_A.dat"
            open(newunit=unit_num, file=trim(fname), status='replace', iostat=io_err)
            write(unit_num,'(5X,A)') 'psi = 1/dsqrt(2) Phi_0 + 1/dsqrt(2) Phi_1'
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(5X,A,6X,A,9X,A,8X,A)') 'E (cm-1)', 'x (A)', 'psi(x)', '|psi(x)|^2'
            do ii = 1, n_x
                write(unit_num,'(F15.5,F10.3,2F15.5)') E_psi1_cm, x_grid_A(ii), Psi_A_a(ii), Psi_A_a(ii)**2
            end do
            close(unit_num)

            fname = trim(data_dir)//"out-psi2_A.dat"
            open(newunit=unit_num, file=trim(fname), status='replace', iostat=io_err)
            write(unit_num,'(5X,A)') 'psi = 1/dsqrt(2) Phi_0 - 1/dsqrt(2) Phi_1'
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(5X,A,6X,A,9X,A,8X,A)') 'E (cm-1)', 'x (A)', 'psi(x)', '|psi(x)|^2'
            do ii = 1, n_x
                write(unit_num,'(F15.5,F10.3,2F15.5)') E_psi1_cm, x_grid_A(ii), Psi_B_a(ii), Psi_B_a(ii)**2
            end do
            close(unit_num)

            fname = trim(data_dir)//"out-psi3_A.dat"
            open(newunit=unit_num, file=trim(fname), status='replace', iostat=io_err)
            write(unit_num,'(5X,A)') 'psi = 1/dsqrt(2) Phi_2 + 1/dsqrt(2) Phi_3'
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(5X,A,6X,A,9X,A,8X,A)') 'E (cm-1)', 'x (A)', 'psi(x)', '|psi(x)|^2'
            do ii = 1, n_x
                write(unit_num,'(F15.5,F10.3,2F15.5)') E_psi2_cm, x_grid_A(ii), Psi_C_a(ii), Psi_C_a(ii)**2
            end do
            close(unit_num)

            fname = trim(data_dir)//"out-psi4_A.dat"
            open(newunit=unit_num, file=trim(fname), status='replace', iostat=io_err)
            write(unit_num,'(5X,A)') 'psi = 1/dsqrt(2) Phi_2 - 1/dsqrt(2) Phi_3'
            write(unit_num,'(A)') repeat('-', 70)
            write(unit_num,'(5X,A,6X,A,9X,A,8X,A)') 'E (cm-1)', 'x (A)', 'psi(x)', '|psi(x)|^2'
            do ii = 1, n_x
                write(unit_num,'(F15.5,F10.3,2F15.5)') E_psi2_cm, x_grid_A(ii), Psi_D_a(ii), Psi_D_a(ii)**2
            end do
            close(unit_num)

            ! Survival probability dat files
            t0      = 0.0_dp; tf = 100.0_dp; dt = 0.1_dp
            n_steps = int((tf - t0) / dt) + 1
            c_wp    = [c1, c2]

            open(newunit=unit_num, file=trim(data_dir)//"out-probabilidad_supervivencia_Psi0.dat", &
                 status='replace', iostat=io_err)
            write(unit_num,'(A)') 't (ps)      Ps(t)'
            do ii = 1, n_steps
                t_val = t0 + dt * real(ii - 1, dp)
                E_wp  = [E_all(1), E_all(2)]
                Ps    = survival_probability(c_wp, E_wp, t_val)
                write(unit_num,'(F6.2,F15.5)') t_val, Ps
            end do
            close(unit_num)

            tf      = 1.0_dp; dt = 0.01_dp
            n_steps = int((tf - t0) / dt) + 1

            open(newunit=unit_num, file=trim(data_dir)//"out-probabilidad_supervivencia_Psi1.dat", &
                 status='replace', iostat=io_err)
            write(unit_num,'(A)') 't (ps)      Ps(t)'
            do ii = 1, n_steps
                t_val = t0 + dt * real(ii - 1, dp)
                E_wp  = [E_all(3), E_all(4)]
                Ps    = survival_probability(c_wp, E_wp, t_val)
                write(unit_num,'(F6.2,F15.5)') t_val, Ps
            end do
            close(unit_num)
        end if

        deallocate(Psi_A, Psi_B, Psi_C, Psi_D)
        deallocate(Psi_A_a, Psi_B_a, Psi_C_a, Psi_D_a)
    end subroutine write_two_state_sections

    ! =========================================================================
    ! Section 9: FOUR-STATE WAVEPACKETS (consolidated alpha loop)
    ! =========================================================================
    subroutine write_four_state_sections(params, E_all, alpha_arr, &
                                          psi_even_A, psi_odd_A, x_grid_A, &
                                          c_matrix, x_matrix, &
                                          tp_E, tp_x1, tp_x2, tp_x3, tp_x4)
        type(system_params_t), intent(in) :: params
        real(dp), intent(in) :: E_all(:), alpha_arr(:)
        real(dp), intent(in) :: psi_even_A(:,:), psi_odd_A(:,:)
        real(dp), intent(in) :: x_grid_A(:)
        real(dp), intent(in) :: c_matrix(:,:), x_matrix(:,:)
        real(dp), intent(out) :: tp_E(:), tp_x1(:), tp_x2(:), tp_x3(:), tp_x4(:)

        integer :: ii, jj, n_x, n_alpha, n_steps, unit_ps, unit_x, unit_psi, io_err
        real(dp) :: alpha_deg, alpha_rad, cos_a, sin_a
        real(dp) :: c_4(4), E_4(4), E_total, E_total_cm
        real(dp) :: t0, tf, dt, t_val, Ps, x_exp
        real(dp), allocatable :: psi_4(:)
        character(len=256) :: fname
        character(len=16) :: alpha_str

        n_x     = size(x_grid_A)
        n_alpha = size(alpha_arr)
        allocate(psi_4(n_x))

        E_4 = [E_all(1), E_all(2), E_all(3), E_all(4)]

        t0      = 0.0_dp
        tf      = 50.0_dp
        dt      = 5.0e-3_dp
        n_steps = int((tf - t0) / dt) + 1

        call write_section_header('9', 'FOUR-STATE WAVEPACKETS  [mixing angle alpha scan]')
        write(ou,'(2X,A)') &
            'Psi(alpha) = cos(alpha)/sqrt(2)*(Phi0+Phi1) + sin(alpha)/sqrt(2)*(Phi2+Phi3)'
        write(ou,'(A)') ''

        ! ------------------------------------------------------------------
        ! 9.1 Wavepackets
        ! ------------------------------------------------------------------
        call write_subsection_header('9.1  Wavepackets')
        if (print_level >= 1) then
            write(ou,'(A)') '$BEGIN WAVEPACKETS_4STATE'
            write(ou,'(A)') '# columns: alpha(deg)   x(A)   Psi   |Psi|^2   E(cm-1)'
            write(ou,'(A)') '#'
        end if

        do jj = 1, n_alpha
            alpha_deg = alpha_arr(jj)
            alpha_rad = alpha_deg * PI / 180.0_dp
            cos_a     = cos(alpha_rad)
            sin_a     = sin(alpha_rad)

            c_4(1) = cos_a / sqrt(2.0_dp)
            c_4(2) = cos_a / sqrt(2.0_dp)
            c_4(3) = sin_a / sqrt(2.0_dp)
            c_4(4) = sin_a / sqrt(2.0_dp)

            E_total    = c_4(1)**2*E_all(1) + c_4(2)**2*E_all(2) + &
                         c_4(3)**2*E_all(3) + c_4(4)**2*E_all(4)
            E_total_cm = E_total * EUACM

            ! Turning points
            call turning_points(E_total_cm, params%Vb_cm, params%xe_angstrom, &
                                tp_x1(jj), tp_x2(jj), tp_x3(jj), tp_x4(jj))
            tp_E(jj) = E_total_cm

            psi_4 = c_4(1)*psi_even_A(:,1) + c_4(2)*psi_odd_A(:,1) + &
                    c_4(3)*psi_even_A(:,2) + c_4(4)*psi_odd_A(:,2)

            if (print_level >= 1) then
                do ii = 1, n_x
                    write(ou,'(F8.2,F10.4,2F14.6,F14.4)') &
                        alpha_deg, x_grid_A(ii), psi_4(ii), psi_4(ii)**2, E_total_cm
                end do
            end if

            if (print_level >= 2) then
                write(alpha_str,'(I0)') int(alpha_deg)
                fname = trim(data_dir)//"out-psi_4EE_alfa="//trim(alpha_str)//".dat"
                open(newunit=unit_psi, file=trim(fname), status='replace', iostat=io_err)
                write(unit_psi,'(A)') repeat('=', 70)
                write(unit_psi,'(A)') 'Psi = cos(alfa)/dsqrt(2)*(Phi0+Phi1) + sen(alfa)/dsqrt(2)*(Phi2+Phi3)'
                write(unit_psi,'(A)') repeat('-', 70)
                write(unit_psi,'(A,6X,A,6X,A,9X,A,8X,A)') 'alfa', 'E (cm-1)', 'x (A)', 'psi(x)', '|psi(x)|^2'
                do ii = 1, n_x
                    write(unit_psi,'(F4.1,F15.5,F10.3,2F15.5)') &
                        alpha_deg, E_total_cm, x_grid_A(ii), psi_4(ii), psi_4(ii)**2
                end do
                close(unit_psi)
            end if
        end do

        if (print_level >= 1) then
            write(ou,'(A)') '$END WAVEPACKETS_4STATE'
            write(ou,'(A)') ''
        else
            write(ou,'(2X,A)') '(grid data suppressed at print_level=0)'
            write(ou,'(A)') ''
        end if

        ! ------------------------------------------------------------------
        ! 9.2 Survival probability
        ! ------------------------------------------------------------------
        call write_subsection_header('9.2  Survival probability')
        if (print_level >= 1) then
            write(ou,'(A)') '$BEGIN SURVIVAL_4STATE'
            write(ou,'(A)') '# columns: alpha(deg)   t(ps)   Ps(t)'
            write(ou,'(A)') '#'
        end if

        do jj = 1, n_alpha
            alpha_deg = alpha_arr(jj)
            alpha_rad = alpha_deg * PI / 180.0_dp
            cos_a     = cos(alpha_rad)
            sin_a     = sin(alpha_rad)

            c_4(1) = cos_a / sqrt(2.0_dp)
            c_4(2) = cos_a / sqrt(2.0_dp)
            c_4(3) = sin_a / sqrt(2.0_dp)
            c_4(4) = sin_a / sqrt(2.0_dp)

            if (print_level >= 2) then
                write(alpha_str,'(I0)') int(alpha_deg)
                fname = trim(data_dir)//"out-prob_sup_alfa="//trim(alpha_str)//".dat"
                open(newunit=unit_ps, file=trim(fname), status='replace', iostat=io_err)
                write(unit_ps,'(A)') repeat('=', 70)
                write(unit_ps,'(A,A,F5.1,A)') '---', ' alfa =', alpha_deg, ' ---'
                write(unit_ps,'(A)') repeat('-', 70)
                write(unit_ps,'(A)') 't (ps)      Ps(t)'
            end if

            do ii = 1, n_steps
                t_val = t0 + dt * real(ii - 1, dp)
                Ps    = survival_probability(c_4, E_4, t_val)
                if (print_level >= 1) &
                    write(ou,'(F8.2,F12.5,F15.6)') alpha_deg, t_val, Ps
                if (print_level >= 2) &
                    write(unit_ps,'(F8.4,F15.5)') t_val, Ps
            end do

            if (print_level >= 2) close(unit_ps)
        end do

        if (print_level >= 1) then
            write(ou,'(A)') '$END SURVIVAL_4STATE'
            write(ou,'(A)') ''
        else
            write(ou,'(2X,A)') '(time-series data suppressed at print_level=0)'
            write(ou,'(A)') ''
        end if

        ! ------------------------------------------------------------------
        ! 9.3 Position expectation value
        ! ------------------------------------------------------------------
        call write_subsection_header('9.3  Position expectation value')
        if (print_level >= 1) then
            write(ou,'(A)') '$BEGIN EXPECTATION_X'
            write(ou,'(A)') '# columns: alpha(deg)   t(ps)   <x>(A)'
            write(ou,'(A)') '#'
        end if

        do jj = 1, n_alpha
            alpha_deg = alpha_arr(jj)
            alpha_rad = alpha_deg * PI / 180.0_dp
            cos_a     = cos(alpha_rad)
            sin_a     = sin(alpha_rad)

            c_4(1) = cos_a / sqrt(2.0_dp)
            c_4(2) = cos_a / sqrt(2.0_dp)
            c_4(3) = sin_a / sqrt(2.0_dp)
            c_4(4) = sin_a / sqrt(2.0_dp)

            if (print_level >= 2) then
                write(alpha_str,'(I0)') int(alpha_deg)
                fname = trim(data_dir)//"out-val_esp_x_alfa="//trim(alpha_str)//".dat"
                open(newunit=unit_x, file=trim(fname), status='replace', iostat=io_err)
                write(unit_x,'(A)') repeat('=', 70)
                write(unit_x,'(A,A,F5.1,A)') '---', ' alfa =', alpha_deg, ' ---'
                write(unit_x,'(A)') repeat('-', 70)
                write(unit_x,'(2X,A,7X,A)') 't (ps)', '<x>t (A)'
            end if

            do ii = 1, n_steps
                t_val = t0 + dt * real(ii - 1, dp)
                x_exp = expectation_value_x(params%N, c_4, E_4, t_val, c_matrix, x_matrix)
                if (print_level >= 1) &
                    write(ou,'(F8.2,F12.5,F15.6)') alpha_deg, t_val, x_exp
                if (print_level >= 2) &
                    write(unit_x,'(F8.4,F15.5)') t_val, x_exp
            end do

            if (print_level >= 2) close(unit_x)
        end do

        if (print_level >= 1) then
            write(ou,'(A)') '$END EXPECTATION_X'
            write(ou,'(A)') ''
        else
            write(ou,'(2X,A)') '(time-series data suppressed at print_level=0)'
            write(ou,'(A)') ''
        end if

        ! ------------------------------------------------------------------
        ! 9.4 Turning points
        ! ------------------------------------------------------------------
        call write_subsection_header('9.4  Turning points')
        write(ou,'(A)') '$BEGIN TURNING_POINTS'
        write(ou,'(A)') '# columns: alpha(deg)   E(cm-1)   x1(A)   x2(A)   x3(A)   x4(A)'
        write(ou,'(A)') '#'
        do jj = 1, n_alpha
            write(ou,'(F8.2,F14.4,4F12.5)') &
                alpha_arr(jj), tp_E(jj), tp_x1(jj), tp_x2(jj), tp_x3(jj), tp_x4(jj)
        end do
        write(ou,'(A)') '$END TURNING_POINTS'
        write(ou,'(A)') ''

        if (print_level >= 2) then
            call write_turning_points(trim(data_dir)//"out-puntos_corte.dat", &
                                      alpha_arr, tp_E, tp_x1, tp_x2, tp_x3, tp_x4, io_err)
        end if

        deallocate(psi_4)
    end subroutine write_four_state_sections

    ! =========================================================================
    ! Section 10: COEFFICIENTS (even + odd merged)
    ! =========================================================================
    subroutine write_coefficients_section(H_even, H_odd, N_even, N_odd)
        real(dp), intent(in) :: H_even(:,:), H_odd(:,:)
        integer, intent(in) :: N_even, N_odd

        integer :: ii, jj, n_states_even, n_states_odd

        n_states_even = min(size(H_even, 2), 3)
        n_states_odd  = min(size(H_odd,  2), 3)

        call write_section_header('10', 'VARIATIONAL COEFFICIENTS')

        write(ou,'(A)') '$BEGIN COEFFICIENTS'
        write(ou,'(A)') '# Even states (Phi0, Phi2, Phi4): basis index = 0, 2, 4, ...'
        write(ou,'(A)') '# Odd  states (Phi1, Phi3, Phi5): basis index = 1, 3, 5, ...'
        write(ou,'(A)') '# columns: i   parity   c_i(Phi0)   c_i(Phi2)   c_i(Phi4)   c_i(Phi1)   c_i(Phi3)   c_i(Phi5)'
        write(ou,'(A)') '#'

        ! Write even and odd side by side, using the larger of the two as the row count
        do jj = 1, max(N_even, N_odd)
            ! Even row
            if (jj <= N_even) then
                write(ou,'(I4,3X,A4,3X,3F15.6)', advance='no') &
                    2*(jj-1), 'even', (H_even(jj, ii), ii = 1, n_states_even)
            else
                write(ou,'(I4,3X,A4,3X,3(15X))', advance='no') 2*(jj-1), 'even'
            end if
            ! Odd row on same line
            if (jj <= N_odd) then
                write(ou,'(3X,I4,3X,A4,3X,3F15.6)') &
                    2*jj-1, 'odd ', (H_odd(jj, ii), ii = 1, n_states_odd)
            else
                write(ou,'(A)') ''
            end if
        end do

        write(ou,'(A)') '$END COEFFICIENTS'
        write(ou,'(A)') ''
    end subroutine write_coefficients_section

    ! =========================================================================
    ! Write N vs W files (print_level >= 2 only)
    ! =========================================================================
    subroutine write_N_vs_W_files(data_dir, E_arr, N_max, N_conv, ierr)
        character(len=*), intent(in) :: data_dir
        real(dp), intent(in) :: E_arr(:,:)
        integer, intent(in) :: N_max
        integer, intent(in) :: N_conv(:)
        integer, intent(out) :: ierr
        integer :: unit_num, ii, level
        character(len=256) :: filename
        character(len=8) :: level_str

        do level = 0, 3
            write(level_str,'(I0)') level
            filename = trim(data_dir)//"out-N_vs_W"//trim(level_str)//".dat"
            open(newunit=unit_num, file=trim(filename), status='replace', iostat=ierr)
            write(unit_num,'(2X,A,I3,2X,A,I3)') 'n =', level+1, 'Nconverg. =', N_conv(level+1)
            write(unit_num,'(2X,A,8X,A,I0)') 'N', 'W', level
            do ii = 2, N_max, 2
                if (ii-1 <= size(E_arr,1) .and. level+1 <= size(E_arr,2)) then
                    write(unit_num,'(I3,F15.5)') ii, E_arr(ii-1, level+1) * EUACM
                end if
            end do
            close(unit_num)
        end do
    end subroutine write_N_vs_W_files

end program qutu
