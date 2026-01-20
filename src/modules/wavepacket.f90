! =============================================================================
! Module: wavepacket
! Description: Wave packet dynamics calculations including survival probability,
!              recurrence time, and expectation values.
! Author: Jose Antonio Quinonero Gris
! =============================================================================
module wavepacket
    use constants, only: dp, PI, EHAJ, HP, RBOHR
    use types, only: wavepacket_t, system_params_t
    implicit none
    private

    ! Public procedures
    public :: recurrence_time
    public :: survival_probability
    public :: expectation_value_x
    public :: position_integral
    public :: build_position_matrix
    public :: trial_function_x_integral

contains

    ! -------------------------------------------------------------------------
    ! Recurrence time for a two-level wavepacket
    ! t_r = h / |E1 - E0|
    ! -------------------------------------------------------------------------
    pure function recurrence_time(E0, E1) result(tr)
        real(dp), intent(in) :: E0, E1  ! Energies in Hartree
        real(dp) :: tr                   ! Recurrence time in seconds
        real(dp) :: E0_J, E1_J

        E0_J = E0 * EHAJ
        E1_J = E1 * EHAJ
        tr = HP / abs(E1_J - E0_J)
    end function recurrence_time

    ! -------------------------------------------------------------------------
    ! Survival probability P(t) = |<Psi(0)|Psi(t)>|^2
    ! For a wavepacket: Psi = sum_i c_i |i>
    ! P(t) = sum_i |c_i|^4 + 2 * sum_i sum_{j>i} |c_i|^2 |c_j|^2 cos((E_j-E_i)*t/hbar)
    ! -------------------------------------------------------------------------
    pure function survival_probability(coeffs, energies, t_ps) result(Ps)
        real(dp), intent(in) :: coeffs(:)    ! Expansion coefficients
        real(dp), intent(in) :: energies(:)  ! Energies in Hartree
        real(dp), intent(in) :: t_ps         ! Time in picoseconds
        real(dp) :: Ps
        real(dp) :: t_s, hbar_SI, E_i, E_j, c_i, c_j
        integer :: i, j, n

        hbar_SI = HP / (2.0_dp * PI)
        t_s = t_ps * 1.0e-12_dp  ! Convert picoseconds to seconds
        n = size(coeffs)

        Ps = 0.0_dp

        ! Cross terms
        do i = 1, n
            do j = i + 1, n
                E_i = energies(i) * EHAJ  ! Convert from Hartree to Joules
                E_j = energies(j) * EHAJ
                c_i = coeffs(i)
                c_j = coeffs(j)
                ! Calculate survival probability for cross terms
                Ps = Ps + abs(c_i)**2 * abs(c_j)**2 * cos((E_j - E_i) * t_s / hbar_SI)
            end do
        end do

        Ps = 2.0_dp * Ps

        ! Diagonal terms
        do i = 1, n
            c_i = coeffs(i)
            Ps = Ps + abs(c_i)**4
        end do
    end function survival_probability

    ! -------------------------------------------------------------------------
    ! Position integral <n|x|m> for harmonic oscillator basis functions
    ! Non-zero only for |n-m| = 1
    ! -------------------------------------------------------------------------
    pure function position_integral(n, m, alpha) result(x_nm)
        integer, intent(in) :: n, m
        real(dp), intent(in) :: alpha
        real(dp) :: x_nm

        if (n == m + 1) then
            x_nm = sqrt(real(m + 1, dp) / (2.0_dp * alpha))
        else if (m == n + 1) then
            x_nm = sqrt(real(n + 1, dp) / (2.0_dp * alpha))
        else
            x_nm = 0.0_dp
        end if
    end function position_integral

    ! -------------------------------------------------------------------------
    ! Build position matrix <i|x|j> in harmonic oscillator basis
    ! Note: Matrix indices are (start at) 1-based, but quantum numbers are 0-based
    ! So matrix element (i,j) corresponds to <i-1|x|j-1>
    ! -------------------------------------------------------------------------
    subroutine build_position_matrix(N, alpha, x_matrix)
        integer, intent(in) :: N
        real(dp), intent(in) :: alpha
        real(dp), allocatable, intent(out) :: x_matrix(:,:)
        integer :: i, j

        allocate(x_matrix(N, N))
        x_matrix = 0.0_dp

        do i = 1, N
            do j = 1, N
                x_matrix(i, j) = position_integral(i - 1, j - 1, alpha)
            end do
        end do
    end subroutine build_position_matrix

    ! -------------------------------------------------------------------------
    ! Integral <Phi_n|x|Phi_m> for trial (variational) wavefunctions
    ! Phi_n = sum_k c_k^(n) |k>
    ! <Phi_n|x|Phi_m> = sum_k sum_l c_k^(n) c_l^(m) <k|x|l>
    ! -------------------------------------------------------------------------
    pure function trial_function_x_integral(state_n, state_m, n_basis, c_matrix, x_matrix) result(x_nm)
        integer, intent(in) :: state_n, state_m   ! State indices (1-based)
        integer, intent(in) :: n_basis            ! Basis size
        real(dp), intent(in) :: c_matrix(:,:)     ! Coefficient matrix c_matrix(k,state)
        real(dp), intent(in) :: x_matrix(:,:)     ! Position matrix in HO basis
        real(dp) :: x_nm
        real(dp) :: c_n_k, c_m_l
        real(dp), parameter :: THRESHOLD = 0.001_dp
        integer :: k, l

        x_nm = 0.0_dp

        do k = 1, n_basis
            c_n_k = c_matrix(k, state_n)
            if (abs(c_n_k) > THRESHOLD) then
                do l = 1, n_basis
                    c_m_l = c_matrix(l, state_m)
                    if (abs(c_m_l) > THRESHOLD) then
                        x_nm = x_nm + c_n_k * c_m_l * x_matrix(k, l)
                    end if
                end do
            end if
        end do
    end function trial_function_x_integral

    ! -------------------------------------------------------------------------
    ! Expectation value of position <x>(t) for a wavepacket
    ! <x>(t) = sum_i |c_i|^2 <Phi_i|x|Phi_i>
    !        + 2 * sum_i sum_{j>i} c_i c_j <Phi_i|x|Phi_j> cos((E_j-E_i)*t/hbar)
    ! -------------------------------------------------------------------------
    pure function expectation_value_x(n_basis, coeffs, energies, t_ps, &
                                       c_matrix, x_matrix) result(x_exp)
        integer, intent(in) :: n_basis           ! Basis size
        real(dp), intent(in) :: coeffs(:)        ! Wavepacket coefficients
        real(dp), intent(in) :: energies(:)      ! State energies (Hartree)
        real(dp), intent(in) :: t_ps             ! Time (picoseconds)
        real(dp), intent(in) :: c_matrix(:,:)    ! Variational coefficients
        real(dp), intent(in) :: x_matrix(:,:)    ! Position matrix (HO basis)
        real(dp) :: x_exp
        real(dp) :: t_s, hbar_SI, E_i, E_j, c_i, c_j, x_ij
        integer :: i, j, n_states

        hbar_SI = HP / (2.0_dp * PI)
        t_s = t_ps * 1.0e-12_dp
        n_states = size(coeffs)

        x_exp = 0.0_dp

        ! Cross terms
        do i = 1, n_states
            do j = i + 1, n_states
                E_i = energies(i) * EHAJ
                E_j = energies(j) * EHAJ
                c_i = coeffs(i)
                c_j = coeffs(j)
                x_ij = trial_function_x_integral(i, j, n_basis, c_matrix, x_matrix)
                x_exp = x_exp + c_i * c_j * x_ij * cos((E_j - E_i) * t_s / hbar_SI)
            end do
        end do
        x_exp = 2.0_dp * x_exp

        ! Diagonal terms
        do i = 1, n_states
            c_i = coeffs(i)
            x_exp = x_exp + abs(c_i)**2 * &
                    trial_function_x_integral(i, i, n_basis, c_matrix, x_matrix)
        end do
    end function expectation_value_x

end module wavepacket
