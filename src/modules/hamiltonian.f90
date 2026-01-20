! =============================================================================
! Module: hamiltonian
! Description: Hamiltonian matrix elements and construction for the NH3
!              double-well potential using harmonic oscillator basis.
! Author: Jose Antonio Quinonero Gris
! =============================================================================
module hamiltonian
    use constants, only: dp, HBAR_AU
    use types, only: system_params_t
    implicit none
    private

    ! Public procedures
    public :: potential
    public :: kinetic_integral
    public :: quadratic_integral
    public :: quartic_integral
    public :: hamiltonian_element
    public :: build_hamiltonian_matrices
    public :: compute_optimal_alpha
    public :: turning_points

contains

    ! -------------------------------------------------------------------------
    ! Double-well potential: V(x) = (Vb/xe^4)*x^4 - (2*Vb/xe^2)*x^2 + Vb
    ! This can be rewritten as: V(x) = (Vb/xe^4)*(x^2 - xe^2)^2
    ! -------------------------------------------------------------------------
    pure function potential(x, xe, Vb) result(V)
        real(dp), intent(in) :: x
        real(dp), intent(in) :: xe, Vb
        real(dp) :: V

        V = (Vb / xe**4) * x**4 - (2.0_dp * Vb / xe**2) * x**2 + Vb
    end function potential

    ! -------------------------------------------------------------------------
    ! Optimal alpha parameter based on quartic approximation
    ! alpha = (6*m*Vb / (hbar^2 * xe^4))^{1/3}
    ! -------------------------------------------------------------------------
    pure function compute_optimal_alpha(mass, xe, Vb) result(alpha)
        real(dp), intent(in) :: mass, xe, Vb
        real(dp) :: alpha

        alpha = (6.0_dp * mass * Vb / (HBAR_AU**2 * xe**4))**(1.0_dp / 3.0_dp)
    end function compute_optimal_alpha

    ! -------------------------------------------------------------------------
    ! Kinetic energy integral: <n|d^2/dx^2|m> in harmonic oscillator basis
    ! -------------------------------------------------------------------------
    pure function kinetic_integral(n, m, alpha) result(T_nm)
        integer, intent(in) :: n, m
        real(dp), intent(in) :: alpha
        real(dp) :: T_nm

        if (n == m) then
            ! Diagonal element
            T_nm = -alpha * (real(n, dp) + 0.5_dp)
        else if (abs(n - m) == 2) then
            ! Off-diagonal element (n = m +/- 2)
            if (n < m) then
                T_nm = (alpha * sqrt(real(n + 1, dp) * real(n + 2, dp))) / 2.0_dp
            else
                T_nm = (alpha * sqrt(real(m + 1, dp) * real(m + 2, dp))) / 2.0_dp
            end if
        else
            T_nm = 0.0_dp
        end if
    end function kinetic_integral

    ! -------------------------------------------------------------------------
    ! Quadratic integral: <n|x^2|m> in harmonic oscillator basis
    ! -------------------------------------------------------------------------
    pure function quadratic_integral(n, m, alpha) result(x2_nm)
        integer, intent(in) :: n, m
        real(dp), intent(in) :: alpha
        real(dp) :: x2_nm

        if (n == m) then
            ! Diagonal element
            x2_nm = (real(n, dp) + 0.5_dp) / alpha
        else if (abs(n - m) == 2) then
            ! Off-diagonal element (n = m +/- 2)
            if (n < m) then
                x2_nm = sqrt(real(n + 1, dp) * real(n + 2, dp)) / (2.0_dp * alpha)
            else
                x2_nm = sqrt(real(m + 1, dp) * real(m + 2, dp)) / (2.0_dp * alpha)
            end if
        else
            x2_nm = 0.0_dp
        end if
    end function quadratic_integral

    ! -------------------------------------------------------------------------
    ! Quartic integral: <n|x^4|m> in harmonic oscillator basis
    ! -------------------------------------------------------------------------
    pure function quartic_integral(n, m, alpha) result(x4_nm)
        integer, intent(in) :: n, m
        real(dp), intent(in) :: alpha
        real(dp) :: x4_nm
        real(dp) :: rn, rm

        rn = real(n, dp)
        rm = real(m, dp)

        if (m == n) then
            ! Diagonal element
            x4_nm = 3.0_dp * (2.0_dp * rn**2 + 2.0_dp * rn + 1.0_dp) / (4.0_dp * alpha**2)
        else if (m == n + 2) then
            ! m = n + 2
            x4_nm = ((2.0_dp * rn + 3.0_dp) * sqrt((rn + 1.0_dp) * (rn + 2.0_dp))) / &
                    (2.0_dp * alpha**2)
        else if (n == m + 2) then
            ! n = m + 2
            x4_nm = ((2.0_dp * rm + 3.0_dp) * sqrt((rm + 1.0_dp) * (rm + 2.0_dp))) / &
                    (2.0_dp * alpha**2)
        else if (m == n + 4) then
            ! m = n + 4
            x4_nm = sqrt((rn + 1.0_dp) * (rn + 2.0_dp) * (rn + 3.0_dp) * (rn + 4.0_dp)) / &
                    (4.0_dp * alpha**2)
        else if (n == m + 4) then
            ! n = m + 4
            x4_nm = sqrt((rm + 1.0_dp) * (rm + 2.0_dp) * (rm + 3.0_dp) * (rm + 4.0_dp)) / &
                    (4.0_dp * alpha**2)
        else
            ! For |n - m| >= 6, the integral is zero
            x4_nm = 0.0_dp
        end if
    end function quartic_integral

    ! -------------------------------------------------------------------------
    ! Complete Hamiltonian matrix element H_nm
    ! H = -(hbar^2 / 2m) d^2/dx^2 + (Vb/xe^4) x^4 - (2Vb/xe^2) x^2 + Vb
    ! Note: Vb constant term is NOT included here; added separately as shift
    ! -------------------------------------------------------------------------
    pure function hamiltonian_element(n, m, mass, xe, Vb, alpha) result(H_nm)
        integer, intent(in) :: n, m
        real(dp), intent(in) :: mass, xe, Vb, alpha
        real(dp) :: H_nm
        real(dp) :: T_nm, x2_nm, x4_nm

        T_nm = kinetic_integral(n, m, alpha)
        x2_nm = quadratic_integral(n, m, alpha)
        x4_nm = quartic_integral(n, m, alpha)

        H_nm = (-HBAR_AU**2 / (2.0_dp * mass)) * T_nm + &
               (Vb / xe**4) * x4_nm - &
               (2.0_dp * Vb / xe**2) * x2_nm
    end function hamiltonian_element

    ! -------------------------------------------------------------------------
    ! Build even and odd Hamiltonian matrices exploiting parity symmetry
    ! -------------------------------------------------------------------------
    subroutine build_hamiltonian_matrices(params, H_even, H_odd)
        type(system_params_t), intent(in) :: params
        real(dp), allocatable, intent(out) :: H_even(:,:)
        real(dp), allocatable, intent(out) :: H_odd(:,:)
        integer :: i, j, n_i, n_j

        ! Allocate matrices
        allocate(H_even(params%N_even, params%N_even))
        allocate(H_odd(params%N_odd, params%N_odd))

        ! Initialize
        H_even = 0.0_dp
        H_odd = 0.0_dp

        ! Build even matrix (basis functions with even parity, n = 0, 2, 4, ...)
        do i = 1, params%N_even
            n_i = 2 * (i - 1)  ! Map to quantum number
            do j = 1, params%N_even
                n_j = 2 * (j - 1)
                H_even(i, j) = hamiltonian_element(n_i, n_j, params%mass, &
                                                   params%xe, params%Vb, params%alpha)
            end do
        end do

        ! Build odd matrix (basis functions with odd parity, n = 1, 3, 5, ...)
        do i = 1, params%N_odd
            n_i = 2 * i - 1  ! Map to quantum number
            do j = 1, params%N_odd
                n_j = 2 * j - 1
                H_odd(i, j) = hamiltonian_element(n_i, n_j, params%mass, &
                                                  params%xe, params%Vb, params%alpha)
            end do
        end do
    end subroutine build_hamiltonian_matrices

    ! -------------------------------------------------------------------------
    ! Calculate turning points (classical intersection of V(x) = E)
    ! Returns x1 < x2 < 0 < x3 < x4
    ! -------------------------------------------------------------------------
    pure subroutine turning_points(E, Vb, xe, x1, x2, x3, x4)
        real(dp), intent(in) :: E, Vb, xe
        real(dp), intent(out) :: x1, x2, x3, x4

        ! For V(x) = E, solve (Vb/xe^4)*(x^2 - xe^2)^2 = E - Vb + Vb = E
        ! x^2 = xe^2 +/- xe^2 * sqrt(E/Vb)
        x1 = -sqrt(sqrt(E * Vb) / Vb + 1.0_dp) * xe
        x2 = -sqrt(1.0_dp - sqrt(E * Vb) / Vb) * xe
        x3 = -x2
        x4 = -x1
    end subroutine turning_points

end module hamiltonian
