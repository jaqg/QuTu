! =============================================================================
! Module: types
! Description: Derived types for system parameters and calculation results
!              in the NH3 double-well quantum tunneling problem.
! Author: Jose Antonio Quinonero Gris
! =============================================================================
module types
    use constants, only: dp
    implicit none
    private

    ! -------------------------------------------------------------------------
    ! System parameters type
    ! -------------------------------------------------------------------------
    type, public :: system_params_t
        ! Equilibrium position (well minima at +/- xe)
        real(dp) :: xe = 0.0_dp         ! in atomic units (a0)
        real(dp) :: xe_angstrom = 0.0_dp ! in Angstrom

        ! Barrier height at x=0
        real(dp) :: Vb = 0.0_dp         ! in atomic units (Hartree)
        real(dp) :: Vb_cm = 0.0_dp      ! in cm^-1

        ! Optimized alpha parameter for harmonic oscillator basis
        real(dp) :: alpha = 0.0_dp      ! in a0^-2
        real(dp) :: alpha_angstrom = 0.0_dp ! in A^-2

        ! Reduced mass of the system
        real(dp) :: mass = 0.0_dp       ! in atomic units

        ! Individual atomic masses (in atomic units)
        real(dp) :: mass_H = 0.0_dp
        real(dp) :: mass_N = 0.0_dp

        ! Number of basis functions
        integer :: N = 0

        ! Number of even and odd basis functions
        integer :: N_even = 0
        integer :: N_odd = 0

        ! --- Polynomial potential mode ---
        ! V(x) = sum_{k=0}^{poly_degree} v_poly(k+1) * x^k
        real(dp), allocatable :: v_poly(:)
        integer :: poly_degree = 0

        ! .true. iff all odd-k coefficients are zero (auto-detected at init)
        logical :: is_symmetric = .true.

        ! .false. = legacy xe/Vb mode (default); .true. = polynomial mode
        logical :: use_polynomial = .false.
    end type system_params_t

    ! -------------------------------------------------------------------------
    ! Grid parameters type
    ! -------------------------------------------------------------------------
    type, public :: grid_params_t
        real(dp) :: xmin = 0.0_dp       ! Minimum x value (a.u.)
        real(dp) :: xmax = 0.0_dp       ! Maximum x value (a.u.)
        real(dp) :: dx = 0.0_dp         ! Grid spacing (a.u.)
        integer :: n_points = 0         ! Number of grid points
    end type grid_params_t

    ! -------------------------------------------------------------------------
    ! Time parameters type (for wavepacket dynamics)
    ! -------------------------------------------------------------------------
    type, public :: time_params_t
        real(dp) :: t0 = 0.0_dp         ! Initial time (ps)
        real(dp) :: tf = 0.0_dp         ! Final time (ps)
        real(dp) :: dt = 0.0_dp         ! Time step (ps)
        integer :: n_steps = 0          ! Number of time steps
    end type time_params_t

    ! -------------------------------------------------------------------------
    ! Energy results type
    ! -------------------------------------------------------------------------
    type, public :: energy_results_t
        real(dp), allocatable :: E(:)           ! Energies (Hartree)
        real(dp), allocatable :: E_cm(:)        ! Energies (cm^-1)
        real(dp), allocatable :: E_even(:)      ! Even state energies
        real(dp), allocatable :: E_odd(:)       ! Odd state energies
        integer :: n_levels = 0                 ! Number of energy levels
        integer, allocatable :: N_converged(:)  ! Convergence N for each level
    end type energy_results_t

    ! -------------------------------------------------------------------------
    ! Wavefunction coefficients type
    ! -------------------------------------------------------------------------
    type, public :: wavefunction_coeffs_t
        real(dp), allocatable :: c_even(:,:)    ! Even state coefficients
        real(dp), allocatable :: c_odd(:,:)     ! Odd state coefficients
        real(dp), allocatable :: c_full(:,:)    ! Full coefficient matrix
        integer :: n_even = 0
        integer :: n_odd = 0
    end type wavefunction_coeffs_t

    ! -------------------------------------------------------------------------
    ! Wavepacket type (for dynamics calculations)
    ! -------------------------------------------------------------------------
    type, public :: wavepacket_t
        real(dp), allocatable :: coeffs(:)      ! Expansion coefficients
        real(dp), allocatable :: energies(:)    ! Energies of component states
        real(dp) :: total_energy = 0.0_dp       ! Total energy of wavepacket
        integer :: n_states = 0                 ! Number of states in wavepacket
        character(len=64) :: description = ""   ! Description of the wavepacket
    end type wavepacket_t

    ! -------------------------------------------------------------------------
    ! Public interface for type initialization
    ! -------------------------------------------------------------------------
    public :: init_system_params
    public :: init_system_params_poly
    public :: init_grid_params
    public :: init_time_params
    public :: init_wavepacket

contains

    ! -------------------------------------------------------------------------
    ! Initialize system parameters
    ! -------------------------------------------------------------------------
    pure subroutine init_system_params(params, N, xe_A, Vb_cm, mH_uma, mN_uma)
        use constants, only: RBOHR, EUACM, UMA_TO_AU
        type(system_params_t), intent(out) :: params
        integer, intent(in) :: N
        real(dp), intent(in) :: xe_A, Vb_cm, mH_uma, mN_uma

        params%N = N
        params%xe_angstrom = xe_A
        params%xe = xe_A / RBOHR
        params%Vb_cm = Vb_cm
        params%Vb = Vb_cm / EUACM
        params%mass_H = mH_uma * UMA_TO_AU
        params%mass_N = mN_uma * UMA_TO_AU

        ! Calculate reduced mass: mu = 3*mH*mN / (3*mH + mN)
        params%mass = (3.0_dp * params%mass_H * params%mass_N) / &
                      (3.0_dp * params%mass_H + params%mass_N)

        ! Calculate even and odd basis function counts
        params%N_odd = N / 2
        params%N_even = N - params%N_odd
    end subroutine init_system_params

    ! -------------------------------------------------------------------------
    ! Initialize grid parameters
    ! -------------------------------------------------------------------------
    pure subroutine init_grid_params(grid, xmin, xmax, dx)
        type(grid_params_t), intent(out) :: grid
        real(dp), intent(in) :: xmin, xmax, dx

        grid%xmin = xmin
        grid%xmax = xmax
        grid%dx = dx
        grid%n_points = int((xmax - xmin) / dx) + 1
    end subroutine init_grid_params

    ! -------------------------------------------------------------------------
    ! Initialize time parameters
    ! -------------------------------------------------------------------------
    pure subroutine init_time_params(time, t0, tf, dt)
        type(time_params_t), intent(out) :: time
        real(dp), intent(in) :: t0, tf, dt

        time%t0 = t0
        time%tf = tf
        time%dt = dt
        time%n_steps = int((tf - t0) / dt) + 1
    end subroutine init_time_params

    ! -------------------------------------------------------------------------
    ! Initialize wavepacket with given coefficients and energies
    ! -------------------------------------------------------------------------
    subroutine init_wavepacket(wp, n_states, coeffs, energies, description)
        type(wavepacket_t), intent(out) :: wp
        integer, intent(in) :: n_states
        real(dp), intent(in) :: coeffs(:)
        real(dp), intent(in) :: energies(:)
        character(len=*), intent(in), optional :: description
        integer :: i

        wp%n_states = n_states

        if (allocated(wp%coeffs)) deallocate(wp%coeffs)
        if (allocated(wp%energies)) deallocate(wp%energies)

        allocate(wp%coeffs(n_states))
        allocate(wp%energies(n_states))

        wp%coeffs = coeffs(1:n_states)
        wp%energies = energies(1:n_states)

        ! Calculate total energy
        wp%total_energy = 0.0_dp
        do i = 1, n_states
            wp%total_energy = wp%total_energy + abs(wp%coeffs(i))**2 * wp%energies(i)
        end do

        if (present(description)) then
            wp%description = description
        else
            wp%description = "Wavepacket"
        end if
    end subroutine init_wavepacket

    ! -------------------------------------------------------------------------
    ! Initialize system parameters for polynomial potential mode
    ! V(x) = sum_{k=0}^{poly_degree} v_coeffs(k+1) * x^k
    !
    ! mass_au : reduced mass already in atomic units
    ! v_coeffs: polynomial coefficients [v0, v1, ..., v_deg]
    ! alpha   : HO basis width parameter (a0^-2)
    ! -------------------------------------------------------------------------
    subroutine init_system_params_poly(params, N, mass_au, v_coeffs, alpha)
        use constants, only: SYMMETRY_THRESHOLD
        type(system_params_t), intent(out) :: params
        integer,  intent(in) :: N
        real(dp), intent(in) :: mass_au
        real(dp), intent(in) :: v_coeffs(:)
        real(dp), intent(in) :: alpha

        integer :: deg, k

        deg = size(v_coeffs) - 1   ! poly_degree = number of coefficients - 1

        params%N            = N
        params%mass         = mass_au
        params%alpha        = alpha
        params%poly_degree  = deg
        params%use_polynomial = .true.

        if (allocated(params%v_poly)) deallocate(params%v_poly)
        allocate(params%v_poly(0:deg))
        params%v_poly(0:deg) = v_coeffs(1:deg+1)

        ! Auto-detect parity symmetry: all odd-k coefficients must be zero
        params%is_symmetric = .true.
        do k = 1, deg, 2
            if (abs(params%v_poly(k)) > SYMMETRY_THRESHOLD) then
                params%is_symmetric = .false.
                exit
            end if
        end do

        ! Even/odd basis split (used only when is_symmetric = .true.)
        params%N_odd  = N / 2
        params%N_even = N - params%N_odd
    end subroutine init_system_params_poly

end module types
