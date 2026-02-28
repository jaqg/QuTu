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
    real(dp), allocatable :: E_even(:), E_odd(:), E_all(:), E_all_cm(:)
    real(dp), allocatable :: work(:)
    integer :: lwork, info

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
    real(dp) :: x_val

    ! Convergence analysis
    real(dp), allocatable :: E_arr(:,:)
    integer, allocatable :: N_conv(:)
    real(dp), allocatable :: E_conv(:), E_max(:)
    real(dp) :: E_sup, E_inf, delta_E

    character(len=256) :: data_dir

    ! =========================================================================
    ! INITIALIZATION
    ! =========================================================================

    ! Read unified INPUT file
    call read_input_file("INPUT", input_params, ierr)
    if (ierr /= 0) stop "Error reading INPUT file"

    ! Extract parameters from input structure
    N_max = input_params%N_max
    xe_A = input_params%xe
    Vb_cm = input_params%Vb
    mH_uma = input_params%mass_H
    mN_uma = input_params%mass_N
    xmin = input_params%xmin
    xmax = input_params%xmax
    dx = input_params%dx

    ! Set output directory
    data_dir = "data/"

    ! Print input confirmation
    write(*,'(A)') ''
    write(*,'(A)') '======================================================'
    write(*,'(A)') ' INPUT file read successfully'
    write(*,'(A)') '======================================================'

    ! Initialize system parameters
    call init_system_params(params, N_max, xe_A, Vb_cm, mH_uma, mN_uma)

    ! Compute optimal alpha
    params%alpha = compute_optimal_alpha(params%mass, params%xe, params%Vb)
    params%alpha_angstrom = params%alpha / RBOHR**2

    ! Initialize grid
    call init_grid_params(grid, xmin, xmax, dx)
    n_steps_x = grid%n_points

    ! Print system information
    write(*,'(A)') '=================================================='
    write(*,'(A)') ' NH3 Double-Well Quantum Tunneling Simulation'
    write(*,'(A)') '=================================================='
    write(*,'(A,F10.5,A)') ' xe = ', params%xe, ' a0'
    write(*,'(A,F10.5,A)') ' Vb = ', params%Vb, ' Ha'
    write(*,'(A,F12.5,A)') ' a  = ', params%Vb/params%xe**4, ' Ha/a0^4'
    write(*,'(A,F12.5,A)') ' b  = ', 2.0_dp*params%Vb/params%xe**2, ' Ha/a0^2'
    write(*,'(A,F12.5)')   ' Reduced mass = ', params%mass
    write(*,'(A,F12.5,A)') ' Alpha = ', params%alpha, ' a0^-2'
    write(*,'(A,I6)')      ' N_max = ', N_max
    write(*,'(A)') '=================================================='

    ! Write mass and alpha parameters
    call write_mass_alpha(params, data_dir, ierr)

    ! =========================================================================
    ! GRID AND POTENTIAL SETUP
    ! =========================================================================
    allocate(x_grid(n_steps_x), x_grid_A(n_steps_x))
    allocate(V_grid(n_steps_x), V_grid_cm(n_steps_x))

    ! create a grid over the 'x' dimension
    do i = 1, n_steps_x
        x_val = xmin + dx * real(i - 1, dp)  ! value of 'x' at grid point
        x_grid(i) = x_val  ! store in an array
        x_grid_A(i) = x_val * RBOHR  ! value of 'x' in Angstrom
        V_grid(i) = potential(x_val, params%xe, params%Vb) ! value of the potential
        V_grid_cm(i) = V_grid(i) * EUACM  ! value of the potential in cm-1
    end do

    ! Write potential to output files
    call write_potential(trim(data_dir)//"out-potencial_hartrees.dat", &
                         x_grid, V_grid, "a0", "Ha", ierr)
    call write_potential(trim(data_dir)//"out-potencial_cm-1.dat", &
                         x_grid_A, V_grid_cm, "A", "cm-1", ierr)

    ! =========================================================================
    ! VARIATIONAL METHOD - Loop over basis sizes
    ! =========================================================================
    allocate(E_arr(N_max - 1, N_max))
    E_arr = 0.0_dp

    ! Split the loop by symmetry of the bais functions
    do N_loop = 2, N_max
        params%N = N_loop
        params%N_odd = params%N / 2
        params%N_even = params%N - params%N_odd

        ! ---------------------------------------------------------------------
        ! Hamiltonian
        ! ---------------------------------------------------------------------
        ! Build Hamiltonian matrices
        call build_hamiltonian_matrices(params, H_even, H_odd)

        ! Diagonalize Hamiltonian matrices with DSYEV subroutine form LAPACK
        ! First, allocate work array (dummy array needed for DSYEV)
        lwork = 3 * params%N
        if (allocated(work)) deallocate(work)
        allocate(work(lwork))

        ! Diagonalize even matrix
        allocate(E_even(params%N_even))
        call dsyev('V', 'U', params%N_even, H_even, params%N_even, E_even, work, lwork, info)
        if (info /= 0) then
            write(*,*) 'Error: Even matrix diagonalization failed, info =', info
            stop
        end if

        ! Diagonalize odd matrix
        allocate(E_odd(params%N_odd))
        call dsyev('V', 'U', params%N_odd, H_odd, params%N_odd, E_odd, work, lwork, info)
        if (info /= 0) then
            write(*,*) 'Error: Odd matrix diagonalization failed, info =', info
            stop
        end if
        ! ---------------------------------------------------------------------

        ! ---------------------------------------------------------------------
        ! Energy
        ! ---------------------------------------------------------------------
        ! Combine energies (interleave even and odd)
        allocate(E_all(params%N))
        do i = 1, params%N_even
            E_all(2*i - 1) = E_even(i) + params%Vb
        end do
        do i = 1, params%N_odd
            E_all(2*i) = E_odd(i) + params%Vb
        end do

        ! Store for convergence analysis
        do i = 1, params%N
            E_arr(params%N - 1, i) = E_all(i)
        end do
        ! ---------------------------------------------------------------------

        ! At N_max: compute and save all results
        if (params%N == N_max) then
            ! Store final energies
            allocate(E_all_cm(N_max))
            E_all_cm = E_all * EUACM  ! convert to cm-1

            ! Build full coefficient matrix
            call build_coefficient_matrix(H_even, H_odd, params%N_even, params%N_odd, c_full)

            ! Write coefficients
            call write_coefficients(trim(data_dir)//"out-coeficientes_par.dat", &
                                    H_even, "even", ierr)
            call write_coefficients(trim(data_dir)//"out-coeficientes_impar.dat", &
                                    H_odd, "odd", ierr)

            ! -----------------------------------------------------------------
            ! Wavefunctions & wavepackets
            ! -----------------------------------------------------------------
            ! Compute wavefunctions on grid
            call compute_wavefunctions(params, H_even, H_odd, x_grid, x_grid_A, &
                                       psi_even, psi_odd, psi_even_A, psi_odd_A)

            ! Write wavefunctions
            call write_wavefunctions_to_files(data_dir, x_grid, x_grid_A, &
                                              psi_even, psi_odd, psi_even_A, psi_odd_A, ierr)

            ! Compute and write wavepackets (Phi0 +/- Phi1, Phi2 +/- Phi3)
            call compute_and_write_wavepackets(data_dir, E_all, &
                                               psi_even, psi_odd, psi_even_A, psi_odd_A, &
                                               x_grid, x_grid_A, ierr)
            ! -----------------------------------------------------------------

            ! -----------------------------------------------------------------
            ! Properties
            ! -----------------------------------------------------------------
            ! Recurrence time calculations
            call compute_and_write_recurrence_times(data_dir, E_all, ierr)

            ! Survival probability for first two wavepackets
            call compute_and_write_survival_prob(data_dir, E_all, ierr)

            ! Build position matrix in Angstrom for expectation values
            call build_position_matrix(params%N, params%alpha_angstrom, x_matrix)
            ! -----------------------------------------------------------------

            ! -----------------------------------------------------------------
            ! 4-state wavepacket calculations with varying alpha
            ! Use alpha values from INPUT file (or defaults if not specified)
            ! -----------------------------------------------------------------
            n_alpha = input_params%n_alpha_values
            allocate(alpha_4EE(n_alpha))
            alpha_4EE = input_params%alpha_values

            allocate(tp_x1(n_alpha), tp_x2(n_alpha), tp_x3(n_alpha), tp_x4(n_alpha), tp_E(n_alpha))

            call compute_4state_wavepackets(data_dir, params, E_all, alpha_4EE, &
                                            psi_even_A, psi_odd_A, x_grid_A, &
                                            c_full, x_matrix, tp_E, tp_x1, tp_x2, tp_x3, tp_x4, ierr)

            ! Write turning points
            call write_turning_points(trim(data_dir)//"out-puntos_corte.dat", &
                                      alpha_4EE, tp_E, tp_x1, tp_x2, tp_x3, tp_x4, ierr)

            deallocate(alpha_4EE, tp_x1, tp_x2, tp_x3, tp_x4, tp_E)
            ! -----------------------------------------------------------------
        end if

        ! Cleanup for next iteration
        deallocate(H_even, H_odd, E_even, E_odd, E_all)
    end do
    ! =========================================================================

    ! =========================================================================
    ! CONVERGENCE ANALYSIS
    ! =========================================================================
    allocate(N_conv(21), E_conv(21), E_max(21))

    do j = 1, 21
        do i = 1, N_max - 1
            E_sup = E_arr(N_max - 1, j)
            E_inf = E_arr(i, j)
            delta_E = E_inf - E_sup
            if (abs(delta_E) < ENERGY_CONV_THRESHOLD) then
                N_conv(j) = i + 1
                E_conv(j) = E_inf
                exit
            end if
        end do
        E_max(j) = E_arr(N_max - 1, j)
    end do

    ! Write convergence data
    call write_convergence(trim(data_dir)//"out-conver_energias_hartrees.dat", &
                           21, N_conv, E_conv, E_max, "Ha", ierr)

    E_conv = E_conv * EUACM  ! convert to cm-1
    E_max = E_max * EUACM    ! convert to cm-1
    call write_convergence(trim(data_dir)//"out-conver_energias_cm-1.dat", &
                           21, N_conv, E_conv, E_max, "cm-1", ierr)

    ! Write N vs W files for first 4 levels
    call write_N_vs_W_files(data_dir, E_arr, N_max, N_conv, ierr)

    ! =========================================================================
    ! CLEANUP
    ! =========================================================================
    deallocate(x_grid, x_grid_A, V_grid, V_grid_cm)
    deallocate(E_arr, N_conv, E_conv, E_max)
    if (allocated(E_all_cm)) deallocate(E_all_cm)
    if (allocated(c_full)) deallocate(c_full)
    if (allocated(psi_even)) deallocate(psi_even)
    if (allocated(psi_odd)) deallocate(psi_odd)
    if (allocated(psi_even_A)) deallocate(psi_even_A)
    if (allocated(psi_odd_A)) deallocate(psi_odd_A)
    if (allocated(x_matrix)) deallocate(x_matrix)
    if (allocated(work)) deallocate(work)

    write(*,'(A)') 'Program completed successfully.'

contains

    ! -------------------------------------------------------------------------
    ! Write mass and alpha parameters
    ! -------------------------------------------------------------------------
    subroutine write_mass_alpha(params, data_dir, ierr)
        type(system_params_t), intent(in) :: params
        character(len=*), intent(in) :: data_dir
        integer, intent(out) :: ierr
        integer :: unit_num

        open(newunit=unit_num, file=trim(data_dir)//"out-masa_red_alfa.dat", &
             status='replace', action='write', iostat=ierr)
        if (ierr /= 0) return

        write(unit_num, '(3X, A, 17X, A, 11X, A)') &
              'mu (a.m.)', 'alpha (a0^{-2})', 'alpha (A^{-2})'
        write(unit_num, *) params%mass, params%alpha, params%alpha_angstrom

        close(unit_num)
    end subroutine write_mass_alpha

    ! -------------------------------------------------------------------------
    ! Build full coefficient matrix from even/odd diagonalization results
    ! -------------------------------------------------------------------------
    subroutine build_coefficient_matrix(H_even, H_odd, N_even, N_odd, c_full)
        real(dp), intent(in) :: H_even(:,:), H_odd(:,:)
        integer, intent(in) :: N_even, N_odd
        real(dp), allocatable, intent(out) :: c_full(:,:)
        integer :: i, j, N_total

        N_total = N_even + N_odd
        allocate(c_full(N_total, N_total))
        c_full = 0.0_dp

        ! Even states (columns 1, 3, 5, ...) -> rows 1, 3, 5, ... of c_full
        do j = 1, N_even
            ! Flip sign for first state (Phi_0)
            if (j == 1) then
                do i = 1, N_even
                    c_full(2*i - 1, 2*j - 1) = -H_even(i, j)
                end do
            else
                do i = 1, N_even
                    c_full(2*i - 1, 2*j - 1) = H_even(i, j)
                end do
            end if
        end do

        ! Odd states (columns 2, 4, 6, ...) -> rows 2, 4, 6, ... of c_full
        do j = 1, N_odd
            ! Flip sign for first two odd states (Phi_1, Phi_3)
            if (j == 1 .or. j == 2) then
                do i = 1, N_odd
                    c_full(2*i, 2*j) = -H_odd(i, j)
                end do
            else
                do i = 1, N_odd
                    c_full(2*i, 2*j) = H_odd(i, j)
                end do
            end if
        end do
    end subroutine build_coefficient_matrix

    ! -------------------------------------------------------------------------
    ! Compute wavefunctions on grid
    ! -------------------------------------------------------------------------
    subroutine compute_wavefunctions(params, H_even, H_odd, x_grid, x_grid_A, &
                                     psi_even, psi_odd, psi_even_A, psi_odd_A)
        type(system_params_t), intent(in) :: params
        real(dp), intent(in) :: H_even(:,:), H_odd(:,:)
        real(dp), intent(in) :: x_grid(:), x_grid_A(:)
        real(dp), allocatable, intent(out) :: psi_even(:,:), psi_odd(:,:)
        real(dp), allocatable, intent(out) :: psi_even_A(:,:), psi_odd_A(:,:)
        integer :: i, j, k, n_x, n_states
        real(dp) :: coeff, alpha_A, sign_factor

        n_x = size(x_grid)
        n_states = 3  ! Compute first 3 states of each parity
        alpha_A = params%alpha_angstrom

        allocate(psi_even(n_x, n_states), psi_odd(n_x, n_states))
        allocate(psi_even_A(n_x, n_states), psi_odd_A(n_x, n_states))

        psi_even = 0.0_dp
        psi_odd = 0.0_dp
        psi_even_A = 0.0_dp
        psi_odd_A = 0.0_dp

        ! Even states (Phi_0, Phi_2, Phi_4)
        do i = 1, n_x
            do j = 1, n_states
                ! Sign adjustment for eigenvector normalization
                if (j == 1) then
                    sign_factor = -1.0_dp
                else
                    sign_factor = 1.0_dp
                end if

                do k = 1, params%N_even
                    coeff = H_even(k, j) * sign_factor
                    if (abs(coeff) > COEFF_THRESHOLD) then
                        psi_even(i, j) = psi_even(i, j) + coeff * phi(2*(k-1), params%alpha, x_grid(i))
                        psi_even_A(i, j) = psi_even_A(i, j) + coeff * phi(2*(k-1), alpha_A, x_grid_A(i))
                    end if
                end do
            end do
        end do

        ! Odd states (Phi_1, Phi_3, Phi_5)
        do i = 1, n_x
            do j = 1, min(n_states, params%N_odd)
                ! Sign adjustment
                if (j <= 2) then
                    sign_factor = -1.0_dp
                else
                    sign_factor = 1.0_dp
                end if

                do k = 1, params%N_odd
                    coeff = H_odd(k, j) * sign_factor
                    if (abs(coeff) > COEFF_THRESHOLD) then
                        psi_odd(i, j) = psi_odd(i, j) + coeff * phi(2*k-1, params%alpha, x_grid(i))
                        psi_odd_A(i, j) = psi_odd_A(i, j) + coeff * phi(2*k-1, alpha_A, x_grid_A(i))
                    end if
                end do
            end do
        end do
    end subroutine compute_wavefunctions

    ! -------------------------------------------------------------------------
    ! Write wavefunctions to output files
    ! -------------------------------------------------------------------------
    subroutine write_wavefunctions_to_files(data_dir, x_grid, x_grid_A, &
                                            psi_even, psi_odd, psi_even_A, psi_odd_A, ierr)
        character(len=*), intent(in) :: data_dir
        real(dp), intent(in) :: x_grid(:), x_grid_A(:)
        real(dp), intent(in) :: psi_even(:,:), psi_odd(:,:)
        real(dp), intent(in) :: psi_even_A(:,:), psi_odd_A(:,:)
        integer, intent(out) :: ierr
        integer :: unit_num, i

        ! Even states in atomic units
        open(newunit=unit_num, file=trim(data_dir)//"out-funciones_pares_hartrees.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(6X, A, 11X, A, 8X, A, 8X, A)') 'x (a0)', 'Phi0(x)', 'Phi2(x)', 'Phi4(x)'
        do i = 1, size(x_grid)
            write(unit_num, '(F10.3, 3F15.5)') x_grid(i), psi_even(i, 1), psi_even(i, 2), psi_even(i, 3)
        end do
        close(unit_num)

        ! Even densities in atomic units
        open(newunit=unit_num, file=trim(data_dir)//"out-densidad_prob_pares_hartrees.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(6X, A, 11X, A, 7X, A, 7X, A)') 'x (a0)', '|Phi0|^2', '|Phi2|^2', '|Phi4|^2'
        do i = 1, size(x_grid)
            write(unit_num, '(F10.3, 3F15.5)') x_grid(i), psi_even(i,1)**2, psi_even(i,2)**2, psi_even(i,3)**2
        end do
        close(unit_num)

        ! Odd states in atomic units
        open(newunit=unit_num, file=trim(data_dir)//"out-funciones_impares_hartrees.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(6X, A, 11X, A, 8X, A, 8X, A)') 'x (a0)', 'Phi1(x)', 'Phi3(x)', 'Phi5(x)'
        do i = 1, size(x_grid)
            write(unit_num, '(F10.3, 3F15.5)') x_grid(i), psi_odd(i, 1), psi_odd(i, 2), psi_odd(i, 3)
        end do
        close(unit_num)

        ! Odd densities in atomic units
        open(newunit=unit_num, file=trim(data_dir)//"out-densidad_prob_impares_hartrees.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(6X, A, 11X, A, 7X, A, 7X, A)') 'x (a0)', '|Phi1|^2', '|Phi3|^2', '|Phi5|^2'
        do i = 1, size(x_grid)
            write(unit_num, '(F10.3, 3F15.5)') x_grid(i), psi_odd(i,1)**2, psi_odd(i,2)**2, psi_odd(i,3)**2
        end do
        close(unit_num)

        ! Even states in Angstrom
        open(newunit=unit_num, file=trim(data_dir)//"out-funciones_pares_A.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(6X, A, 12X, A, 8X, A, 8X, A)') 'x (A)', 'Phi0(x)', 'Phi2(x)', 'Phi4(x)'
        do i = 1, size(x_grid_A)
            write(unit_num, '(F10.3, 3F15.5)') x_grid_A(i), psi_even_A(i, 1), psi_even_A(i, 2), psi_even_A(i, 3)
        end do
        close(unit_num)

        ! Even densities in Angstrom
        open(newunit=unit_num, file=trim(data_dir)//"out-densidad_prob_pares_A.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(6X, A, 12X, A, 7X, A, 7X, A)') 'x (A)', '|Phi0|^2', '|Phi2|^2', '|Phi4|^2'
        do i = 1, size(x_grid_A)
            write(unit_num, '(F10.3, 3F15.5)') x_grid_A(i), psi_even_A(i,1)**2, psi_even_A(i,2)**2, psi_even_A(i,3)**2
        end do
        close(unit_num)

        ! Odd states in Angstrom
        open(newunit=unit_num, file=trim(data_dir)//"out-funciones_impares_A.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(6X, A, 12X, A, 8X, A, 8X, A)') 'x (A)', 'Phi1(x)', 'Phi3(x)', 'Phi5(x)'
        do i = 1, size(x_grid_A)
            write(unit_num, '(F10.3, 3F15.5)') x_grid_A(i), psi_odd_A(i, 1), psi_odd_A(i, 2), psi_odd_A(i, 3)
        end do
        close(unit_num)

        ! Odd densities in Angstrom
        open(newunit=unit_num, file=trim(data_dir)//"out-densidad_prob_impares_A.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(6X, A, 12X, A, 7X, A, 7X, A)') 'x (A)', '|Phi1|^2', '|Phi3|^2', '|Phi5|^2'
        do i = 1, size(x_grid_A)
            write(unit_num, '(F10.3, 3F15.5)') x_grid_A(i), psi_odd_A(i,1)**2, psi_odd_A(i,2)**2, psi_odd_A(i,3)**2
        end do
        close(unit_num)
    end subroutine write_wavefunctions_to_files

    ! -------------------------------------------------------------------------
    ! Compute and write two-state wavepackets
    ! -------------------------------------------------------------------------
    subroutine compute_and_write_wavepackets(data_dir, E_all, &
                                             psi_even, psi_odd, psi_even_A, psi_odd_A, &
                                             x_grid, x_grid_A, ierr)
        character(len=*), intent(in) :: data_dir
        real(dp), intent(in) :: E_all(:)
        real(dp), intent(in) :: psi_even(:,:), psi_odd(:,:)
        real(dp), intent(in) :: psi_even_A(:,:), psi_odd_A(:,:)
        real(dp), intent(in) :: x_grid(:), x_grid_A(:)
        integer, intent(out) :: ierr
        integer :: unit_num, i
        real(dp) :: c1, c2, E_psi, E_psi_cm
        real(dp), allocatable :: psi1(:), psi2(:), psi3(:), psi4(:)
        real(dp), allocatable :: psi1_A(:), psi2_A(:), psi3_A(:), psi4_A(:)
        integer :: n_x

        n_x = size(x_grid)
        c1 = 1.0_dp / sqrt(2.0_dp)
        c2 = 1.0_dp / sqrt(2.0_dp)

        allocate(psi1(n_x), psi2(n_x), psi3(n_x), psi4(n_x))
        allocate(psi1_A(n_x), psi2_A(n_x), psi3_A(n_x), psi4_A(n_x))

        ! Psi1 = (Phi0 + Phi1)/sqrt(2), Psi2 = (Phi0 - Phi1)/sqrt(2)
        psi1 = c1 * psi_even(:,1) + c2 * psi_odd(:,1)
        psi2 = c1 * psi_even(:,1) - c2 * psi_odd(:,1)
        psi1_A = c1 * psi_even_A(:,1) + c2 * psi_odd_A(:,1)
        psi2_A = c1 * psi_even_A(:,1) - c2 * psi_odd_A(:,1)

        ! Psi3 = (Phi2 + Phi3)/sqrt(2), Psi4 = (Phi2 - Phi3)/sqrt(2)
        psi3 = c1 * psi_even(:,2) + c2 * psi_odd(:,2)
        psi4 = c1 * psi_even(:,2) - c2 * psi_odd(:,2)
        psi3_A = c1 * psi_even_A(:,2) + c2 * psi_odd_A(:,2)
        psi4_A = c1 * psi_even_A(:,2) - c2 * psi_odd_A(:,2)

        ! Energy of first wavepacket
        E_psi = 0.5_dp * E_all(1) + 0.5_dp * E_all(2)
        E_psi_cm = E_psi * EUACM

        ! Write psi1 (atomic units)
        open(newunit=unit_num, file=trim(data_dir)//"out-psi1.dat", status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('=', 70)
        write(unit_num, '(5X, A)') 'psi = 1/dsqrt(2) Phi_0 + 1/dsqrt(2) Phi_1'
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(8X, A, 8X, A, 11X, A, 8X, A)') 'E (Ha)', 'x (a0)', 'psi(x)', '|psi(x)|^2'
        do i = 1, n_x
            write(unit_num, '(F15.5, F10.3, 2F15.5)') E_psi, x_grid(i), psi1(i), psi1(i)**2
        end do
        close(unit_num)

        ! Write psi2 (atomic units)
        open(newunit=unit_num, file=trim(data_dir)//"out-psi2.dat", status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('=', 70)
        write(unit_num, '(5X, A)') 'psi = 1/dsqrt(2) Phi_0 - 1/dsqrt(2) Phi_1'
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(8X, A, 8X, A, 11X, A, 8X, A)') 'E (Ha)', 'x (a0)', 'psi(x)', '|psi(x)|^2'
        do i = 1, n_x
            write(unit_num, '(F15.5, F10.3, 2F15.5)') E_psi, x_grid(i), psi2(i), psi2(i)**2
        end do
        close(unit_num)

        ! Energy of second wavepacket
        E_psi = 0.5_dp * E_all(3) + 0.5_dp * E_all(4)
        E_psi_cm = E_psi * EUACM

        ! Write psi3 (atomic units)
        open(newunit=unit_num, file=trim(data_dir)//"out-psi3.dat", status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('=', 70)
        write(unit_num, '(5X, A)') 'psi = 1/dsqrt(2) Phi_2 + 1/dsqrt(2) Phi_3'
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(8X, A, 8X, A, 11X, A, 8X, A)') 'E (Ha)', 'x (a0)', 'psi(x)', '|psi(x)|^2'
        do i = 1, n_x
            write(unit_num, '(F15.5, F10.3, 2F15.5)') E_psi, x_grid(i), psi3(i), psi3(i)**2
        end do
        close(unit_num)

        ! Write psi4 (atomic units)
        open(newunit=unit_num, file=trim(data_dir)//"out-psi4.dat", status='replace', iostat=ierr)
        write(unit_num, '(A)') repeat('=', 70)
        write(unit_num, '(5X, A)') 'psi = 1/dsqrt(2) Phi_2 - 1/dsqrt(2) Phi_3'
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(8X, A, 8X, A, 11X, A, 8X, A)') 'E (Ha)', 'x (a0)', 'psi(x)', '|psi(x)|^2'
        do i = 1, n_x
            write(unit_num, '(F15.5, F10.3, 2F15.5)') E_psi, x_grid(i), psi4(i), psi4(i)**2
        end do
        close(unit_num)

        ! Write Angstrom versions (psi1_A through psi4_A)
        E_psi = 0.5_dp * E_all(1) + 0.5_dp * E_all(2)
        E_psi_cm = E_psi * EUACM

        open(newunit=unit_num, file=trim(data_dir)//"out-psi1_A.dat", status='replace', iostat=ierr)
        write(unit_num, '(5X, A)') 'psi = 1/dsqrt(2) Phi_0 + 1/dsqrt(2) Phi_1'
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(5X, A, 6X, A, 9X, A, 8X, A)') 'E (cm-1)', 'x (A)', 'psi(x)', '|psi(x)|^2'
        do i = 1, n_x
            write(unit_num, '(F15.5, F10.3, 2F15.5)') E_psi_cm, x_grid_A(i), psi1_A(i), psi1_A(i)**2
        end do
        close(unit_num)

        open(newunit=unit_num, file=trim(data_dir)//"out-psi2_A.dat", status='replace', iostat=ierr)
        write(unit_num, '(5X, A)') 'psi = 1/dsqrt(2) Phi_0 - 1/dsqrt(2) Phi_1'
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(5X, A, 6X, A, 9X, A, 8X, A)') 'E (cm-1)', 'x (A)', 'psi(x)', '|psi(x)|^2'
        do i = 1, n_x
            write(unit_num, '(F15.5, F10.3, 2F15.5)') E_psi_cm, x_grid_A(i), psi2_A(i), psi2_A(i)**2
        end do
        close(unit_num)

        E_psi = 0.5_dp * E_all(3) + 0.5_dp * E_all(4)
        E_psi_cm = E_psi * EUACM

        open(newunit=unit_num, file=trim(data_dir)//"out-psi3_A.dat", status='replace', iostat=ierr)
        write(unit_num, '(5X, A)') 'psi = 1/dsqrt(2) Phi_2 + 1/dsqrt(2) Phi_3'
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(5X, A, 6X, A, 9X, A, 8X, A)') 'E (cm-1)', 'x (A)', 'psi(x)', '|psi(x)|^2'
        do i = 1, n_x
            write(unit_num, '(F15.5, F10.3, 2F15.5)') E_psi_cm, x_grid_A(i), psi3_A(i), psi3_A(i)**2
        end do
        close(unit_num)

        open(newunit=unit_num, file=trim(data_dir)//"out-psi4_A.dat", status='replace', iostat=ierr)
        write(unit_num, '(5X, A)') 'psi = 1/dsqrt(2) Phi_2 - 1/dsqrt(2) Phi_3'
        write(unit_num, '(A)') repeat('-', 70)
        write(unit_num, '(5X, A, 6X, A, 9X, A, 8X, A)') 'E (cm-1)', 'x (A)', 'psi(x)', '|psi(x)|^2'
        do i = 1, n_x
            write(unit_num, '(F15.5, F10.3, 2F15.5)') E_psi_cm, x_grid_A(i), psi4_A(i), psi4_A(i)**2
        end do
        close(unit_num)

        deallocate(psi1, psi2, psi3, psi4)
        deallocate(psi1_A, psi2_A, psi3_A, psi4_A)
    end subroutine compute_and_write_wavepackets

    ! -------------------------------------------------------------------------
    ! Compute and write recurrence times
    ! -------------------------------------------------------------------------
    subroutine compute_and_write_recurrence_times(data_dir, E_all, ierr)
        character(len=*), intent(in) :: data_dir
        real(dp), intent(in) :: E_all(:)
        integer, intent(out) :: ierr
        integer :: unit_num
        real(dp) :: tr1, tr2

        tr1 = recurrence_time(E_all(1), E_all(2)) * 1.0e12_dp  ! Convert to ps
        tr2 = recurrence_time(E_all(3), E_all(4)) * 1.0e12_dp

        open(newunit=unit_num, file=trim(data_dir)//"out-tiempo_recurrencia.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A, 26X, A)') 'Psi', 'tr (ps)'
        write(unit_num, '(A, 2X, F15.5)') '(Phi0+-Phi1)/dsqrt(2)', tr1
        write(unit_num, '(A, 2X, F15.5)') '(Phi2+-Phi3)/dsqrt(2)', tr2
        close(unit_num)
    end subroutine compute_and_write_recurrence_times

    ! -------------------------------------------------------------------------
    ! Compute and write survival probability for two-state wavepackets
    ! -------------------------------------------------------------------------
    subroutine compute_and_write_survival_prob(data_dir, E_all, ierr)
        character(len=*), intent(in) :: data_dir
        real(dp), intent(in) :: E_all(:)
        integer, intent(out) :: ierr
        integer :: unit_num, i, n_steps
        real(dp) :: t0, tf, dt, t_val, Ps
        real(dp) :: c_wp(2), E_wp(2)

        ! First wavepacket: (Phi0 + Phi1)/sqrt(2)
        c_wp = [1.0_dp/sqrt(2.0_dp), 1.0_dp/sqrt(2.0_dp)]
        E_wp = [E_all(1), E_all(2)]

        t0 = 0.0_dp
        tf = 100.0_dp
        dt = 0.1_dp
        n_steps = int((tf - t0) / dt) + 1

        open(newunit=unit_num, file=trim(data_dir)//"out-probabilidad_supervivencia_Psi0.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A)') 't (ps)      Ps(t)'
        do i = 1, n_steps
            t_val = t0 + dt * real(i - 1, dp)
            Ps = survival_probability(c_wp, E_wp, t_val)
            write(unit_num, '(F6.2, F15.5)') t_val, Ps
        end do
        close(unit_num)

        ! Second wavepacket: (Phi2 + Phi3)/sqrt(2)
        E_wp = [E_all(3), E_all(4)]

        t0 = 0.0_dp
        tf = 1.0_dp
        dt = 0.01_dp
        n_steps = int((tf - t0) / dt) + 1

        open(newunit=unit_num, file=trim(data_dir)//"out-probabilidad_supervivencia_Psi1.dat", &
             status='replace', iostat=ierr)
        write(unit_num, '(A)') 't (ps)      Ps(t)'
        do i = 1, n_steps
            t_val = t0 + dt * real(i - 1, dp)
            Ps = survival_probability(c_wp, E_wp, t_val)
            write(unit_num, '(F6.2, F15.5)') t_val, Ps
        end do
        close(unit_num)
    end subroutine compute_and_write_survival_prob

    ! -------------------------------------------------------------------------
    ! Compute 4-state wavepackets with varying mixing angle alpha
    ! -------------------------------------------------------------------------
    subroutine compute_4state_wavepackets(data_dir, params, E_all, alpha_arr, &
                                          psi_even_A, psi_odd_A, x_grid_A, &
                                          c_matrix, x_matrix, tp_E, tp_x1, tp_x2, tp_x3, tp_x4, ierr)
        character(len=*), intent(in) :: data_dir
        type(system_params_t), intent(in) :: params
        real(dp), intent(in) :: E_all(:), alpha_arr(:)
        real(dp), intent(in) :: psi_even_A(:,:), psi_odd_A(:,:)
        real(dp), intent(in) :: x_grid_A(:)
        real(dp), intent(in) :: c_matrix(:,:), x_matrix(:,:)
        real(dp), intent(out) :: tp_E(:), tp_x1(:), tp_x2(:), tp_x3(:), tp_x4(:)
        integer, intent(out) :: ierr

        integer :: unit_psi, unit_ps, unit_x, i, j, n_x, n_alpha, n_steps
        real(dp) :: alpha_deg, alpha_rad, cos_a, sin_a
        real(dp) :: c_4(4), E_4(4), E_total, E_total_cm
        real(dp), allocatable :: psi_4(:)
        real(dp) :: t0, tf, dt, t_val, Ps, x_exp
        character(len=256) :: filename
        character(len=16) :: alpha_str

        n_x = size(x_grid_A)
        n_alpha = size(alpha_arr)
        allocate(psi_4(n_x))

        E_4 = [E_all(1), E_all(2), E_all(3), E_all(4)]

        ! Alpha values correspond to file numbers: 90+j, 110+j, 130+j
        do j = 1, n_alpha
            alpha_deg = alpha_arr(j)
            alpha_rad = alpha_deg * PI / 180.0_dp
            cos_a = cos(alpha_rad)
            sin_a = sin(alpha_rad)

            ! Coefficients: a0 = a1 = cos(alpha)/sqrt(2), a2 = a3 = sin(alpha)/sqrt(2)
            c_4(1) = cos_a / sqrt(2.0_dp)
            c_4(2) = cos_a / sqrt(2.0_dp)
            c_4(3) = sin_a / sqrt(2.0_dp)
            c_4(4) = sin_a / sqrt(2.0_dp)

            ! Total energy
            E_total = c_4(1)**2 * E_all(1) + c_4(2)**2 * E_all(2) + &
                      c_4(3)**2 * E_all(3) + c_4(4)**2 * E_all(4)
            E_total_cm = E_total * EUACM

            ! Turning points
            call turning_points(E_total_cm, params%Vb_cm, params%xe_angstrom, &
                               tp_x1(j), tp_x2(j), tp_x3(j), tp_x4(j))
            tp_E(j) = E_total_cm

            ! Compute wavepacket
            psi_4 = c_4(1) * psi_even_A(:,1) + c_4(2) * psi_odd_A(:,1) + &
                    c_4(3) * psi_even_A(:,2) + c_4(4) * psi_odd_A(:,2)

            ! Write wavepacket file
            write(alpha_str, '(I0)') int(alpha_deg)
            filename = trim(data_dir)//"out-psi_4EE_alfa="//trim(alpha_str)//".dat"
            open(newunit=unit_psi, file=trim(filename), status='replace', iostat=ierr)
            write(unit_psi, '(A)') repeat('=', 70)
            write(unit_psi, '(A)') 'Psi = cos(alfa)/dsqrt(2)*(Phi0 + Phi1) + sen(alfa)/dsqrt(2)*(Phi2 + Phi3)'
            write(unit_psi, '(A)') repeat('-', 70)
            write(unit_psi, '(A, 6X, A, 6X, A, 9X, A, 8X, A)') 'alfa', 'E (cm-1)', 'x (A)', 'psi(x)', '|psi(x)|^2'
            do i = 1, n_x
                write(unit_psi, '(F4.1, F15.5, F10.3, 2F15.5)') &
                      alpha_deg, E_total_cm, x_grid_A(i), psi_4(i), psi_4(i)**2
            end do
            close(unit_psi)

            ! Time dynamics
            t0 = 0.0_dp
            tf = 50.0_dp
            dt = 5.0e-3_dp
            n_steps = int((tf - t0) / dt) + 1

            ! Write survival probability
            filename = trim(data_dir)//"out-prob_sup_alfa="//trim(alpha_str)//".dat"
            open(newunit=unit_ps, file=trim(filename), status='replace', iostat=ierr)
            write(unit_ps, '(A)') repeat('=', 70)
            write(unit_ps, '(A, A, F5.1, A)') '---', ' alfa =', alpha_deg, ' ---'
            write(unit_ps, '(A)') repeat('-', 70)
            write(unit_ps, '(A)') 't (ps)      Ps(t)'
            do i = 1, n_steps
                t_val = t0 + dt * real(i - 1, dp)
                Ps = survival_probability(c_4, E_4, t_val)
                write(unit_ps, '(F8.4, F15.5)') t_val, Ps
            end do
            close(unit_ps)

            ! Write expectation value <x>(t)
            filename = trim(data_dir)//"out-val_esp_x_alfa="//trim(alpha_str)//".dat"
            open(newunit=unit_x, file=trim(filename), status='replace', iostat=ierr)
            write(unit_x, '(A)') repeat('=', 70)
            write(unit_x, '(A, A, F5.1, A)') '---', ' alfa =', alpha_deg, ' ---'
            write(unit_x, '(A)') repeat('-', 70)
            write(unit_x, '(2X, A, 7X, A)') 't (ps)', '<x>t (A)'
            do i = 1, n_steps
                t_val = t0 + dt * real(i - 1, dp)
                x_exp = expectation_value_x(params%N, c_4, E_4, t_val, c_matrix, x_matrix)
                write(unit_x, '(F8.4, F15.5)') t_val, x_exp
            end do
            close(unit_x)
        end do

        deallocate(psi_4)
    end subroutine compute_4state_wavepackets

    ! -------------------------------------------------------------------------
    ! Write N vs W files for convergence visualization
    ! -------------------------------------------------------------------------
    subroutine write_N_vs_W_files(data_dir, E_arr, N_max, N_conv, ierr)
        character(len=*), intent(in) :: data_dir
        real(dp), intent(in) :: E_arr(:,:)
        integer, intent(in) :: N_max
        integer, intent(in) :: N_conv(:)
        integer, intent(out) :: ierr
        integer :: unit_num, i, level
        character(len=256) :: filename
        character(len=8) :: level_str

        do level = 0, 3
            write(level_str, '(I0)') level
            filename = trim(data_dir)//"out-N_vs_W"//trim(level_str)//".dat"
            open(newunit=unit_num, file=trim(filename), status='replace', iostat=ierr)

            write(unit_num, '(2X, A, I3, 2X, A, I3)') 'n =', level + 1, 'Nconverg. =', N_conv(level + 1)
            write(unit_num, '(2X, A, 8X, A, I0)') 'N', 'W', level

            do i = 2, N_max, 2
                if (i - 1 <= size(E_arr, 1) .and. level + 1 <= size(E_arr, 2)) then
                    write(unit_num, '(I3, F15.5)') i, E_arr(i - 1, level + 1) * EUACM
                end if
            end do

            close(unit_num)
        end do
    end subroutine write_N_vs_W_files

end program qutu
