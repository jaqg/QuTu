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

    ! Polynomial potential routines (Phase 2)
    public :: compute_xk_matrix
    public :: potential_matrix_poly
    public :: build_hamiltonian_full
    public :: potential_poly
    public :: turning_points_poly
    public :: compute_optimal_alpha_poly

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

    ! =========================================================================
    ! POLYNOMIAL POTENTIAL ROUTINES (Phase 2)
    ! V(x) = sum_{k=0}^{deg} v_poly(k) * x^k
    ! =========================================================================

    ! -------------------------------------------------------------------------
    ! Master recursion for <m|x^k|n> in the harmonic oscillator basis.
    !
    ! X^(0)_{mn} = delta_{mn}
    ! X^(k)_{mn} = ell * [ sqrt(n) * X^(k-1)_{m,n-1}
    !                     + sqrt(n+1) * X^(k-1)_{m,n+1} ]
    ! where ell = 1/sqrt(2*alpha).
    !
    ! Quantum numbers n, m run from 0 to N_basis-1.
    ! Xk is returned as Xk(0:N_basis-1, 0:N_basis-1), Xk(m,n) = <m|x^k|n>.
    ! -------------------------------------------------------------------------
    subroutine compute_xk_matrix(k, N_basis, alpha, Xk)
        integer,  intent(in)  :: k, N_basis
        real(dp), intent(in)  :: alpha
        real(dp), allocatable, intent(out) :: Xk(:,:)

        real(dp), allocatable :: Xprev(:,:), Xcurr(:,:)
        real(dp) :: ell
        integer  :: step, m, n

        ell = 1.0_dp / sqrt(2.0_dp * alpha)

        allocate(Xprev(0:N_basis-1, 0:N_basis-1))
        allocate(Xcurr(0:N_basis-1, 0:N_basis-1))
        allocate(Xk(0:N_basis-1, 0:N_basis-1))

        ! Base case: X^(0) = identity
        Xprev = 0.0_dp
        do n = 0, N_basis - 1
            Xprev(n, n) = 1.0_dp
        end do

        if (k == 0) then
            Xk = Xprev
            return
        end if

        ! Iterate from 1 to k
        do step = 1, k
            Xcurr = 0.0_dp
            do m = 0, N_basis - 1
                ! Selection rule: only |m-n| <= step with same parity as step
                do n = 0, N_basis - 1
                    if (mod(m - n + 1000*step, 2) /= mod(step, 2)) cycle
                    if (abs(m - n) > step) cycle

                    ! Left term: sqrt(n) * X^(step-1)_{m, n-1}
                    if (n > 0) then
                        Xcurr(m, n) = Xcurr(m, n) + ell * sqrt(real(n, dp)) * Xprev(m, n-1)
                    end if
                    ! Right term: sqrt(n+1) * X^(step-1)_{m, n+1}
                    if (n < N_basis - 1) then
                        Xcurr(m, n) = Xcurr(m, n) + ell * sqrt(real(n+1, dp)) * Xprev(m, n+1)
                    end if
                end do
            end do
            Xprev = Xcurr
        end do

        Xk = Xcurr
    end subroutine compute_xk_matrix

    ! -------------------------------------------------------------------------
    ! Assemble the full potential matrix in the HO basis:
    !   V_mat(m,n) = sum_{k=0}^{deg} v_poly(k) * X^(k)_{mn}
    !
    ! v_poly is indexed 0:deg.  V_mat is returned as (0:N_basis-1, 0:N_basis-1).
    ! -------------------------------------------------------------------------
    subroutine potential_matrix_poly(v_poly, N_basis, alpha, V_mat)
        real(dp), intent(in)  :: v_poly(0:)      ! coefficients v0..vdeg
        integer,  intent(in)  :: N_basis
        real(dp), intent(in)  :: alpha
        real(dp), allocatable, intent(out) :: V_mat(:,:)

        real(dp), allocatable :: Xk(:,:)
        integer :: k, deg

        deg = ubound(v_poly, 1)   ! v_poly(0:deg)

        allocate(V_mat(0:N_basis-1, 0:N_basis-1))
        V_mat = 0.0_dp

        do k = 0, deg
            if (v_poly(k) == 0.0_dp) cycle   ! skip exact-zero coefficients
            call compute_xk_matrix(k, N_basis, alpha, Xk)
            V_mat = V_mat + v_poly(k) * Xk
            deallocate(Xk)
        end do
    end subroutine potential_matrix_poly

    ! -------------------------------------------------------------------------
    ! Build the full N x N Hamiltonian for the polynomial potential.
    ! H_full is returned as H_full(1:N, 1:N) (1-based Fortran convention).
    ! -------------------------------------------------------------------------
    subroutine build_hamiltonian_full(params, H_full)
        type(system_params_t), intent(in) :: params
        real(dp), allocatable, intent(out) :: H_full(:,:)

        real(dp), allocatable :: V_mat(:,:)
        integer :: i, j, N

        N = params%N
        allocate(H_full(N, N))
        H_full = 0.0_dp

        ! Potential matrix (0-based internally)
        call potential_matrix_poly(params%v_poly, N, params%alpha, V_mat)

        ! Fill H = T + V (1-based storage, 0-based quantum numbers n=i-1, m=j-1)
        do i = 1, N
            do j = 1, N
                H_full(i, j) = (-HBAR_AU**2 / (2.0_dp * params%mass)) * &
                                kinetic_integral(i-1, j-1, params%alpha) + &
                                V_mat(i-1, j-1)
            end do
        end do

        deallocate(V_mat)
    end subroutine build_hamiltonian_full

    ! -------------------------------------------------------------------------
    ! Evaluate the polynomial V(x) = sum_{k=0}^{deg} v_poly(k)*x^k via Horner.
    ! v_poly is indexed 0:deg.
    ! -------------------------------------------------------------------------
    pure function potential_poly(x, v_poly) result(V)
        real(dp), intent(in) :: x
        real(dp), intent(in) :: v_poly(0:)
        real(dp) :: V

        integer :: k, deg

        deg = ubound(v_poly, 1)
        V = v_poly(deg)
        do k = deg - 1, 0, -1
            V = V * x + v_poly(k)
        end do
    end function potential_poly

    ! -------------------------------------------------------------------------
    ! Find a root of V_poly(x) - E = 0 on [x_L, x_R] via Brent's method.
    ! found = .true. if a root was bracketed and converged.
    ! -------------------------------------------------------------------------
    subroutine turning_points_poly(v_poly, E, x_L, x_R, x_turn, found)
        real(dp), intent(in)  :: v_poly(0:)
        real(dp), intent(in)  :: E, x_L, x_R
        real(dp), intent(out) :: x_turn
        logical,  intent(out) :: found

        real(dp), parameter :: TOL = 1.0e-10_dp
        integer,  parameter :: MAX_ITER = 100

        real(dp) :: a, b, c, d, ebrent, fa, fb, fc, s, tol1, xm
        integer  :: iter
        logical  :: mflag

        a  = x_L;  b  = x_R
        fa = potential_poly(a, v_poly) - E
        fb = potential_poly(b, v_poly) - E

        found   = .false.
        x_turn  = 0.0_dp

        ! Root must be bracketed
        if (fa * fb > 0.0_dp) return

        if (abs(fa) < abs(fb)) then
            call swap_dp(a, b); call swap_dp(fa, fb)
        end if

        c = a;  fc = fa
        mflag = .true.
        d = 0.0_dp;  ebrent = 0.0_dp

        do iter = 1, MAX_ITER
            if (abs(b - a) < TOL .or. abs(fb) < TOL) then
                found = .true.;  x_turn = b;  return
            end if

            if (fa /= fc .and. fb /= fc) then
                ! Inverse quadratic interpolation
                s = a*fb*fc/((fa-fb)*(fa-fc)) + b*fa*fc/((fb-fa)*(fb-fc)) + &
                    c*fa*fb/((fc-fa)*(fc-fb))
            else
                ! Secant
                s = b - fb*(b-a)/(fb-fa)
            end if

            tol1 = TOL * abs(b) + TOL
            xm   = 0.5_dp * (a + b)

            if (.not. ( (s > (3.0_dp*a+b)/4.0_dp .and. s < b) .or. &
                        (s < (3.0_dp*a+b)/4.0_dp .and. s > b) ) .or. &
                (mflag  .and. abs(s-b) >= 0.5_dp*abs(b-c)) .or. &
                (.not. mflag .and. abs(s-b) >= 0.5_dp*abs(c-ebrent)) .or. &
                (mflag  .and. abs(b-c) < tol1) .or. &
                (.not. mflag .and. abs(c-ebrent) < tol1)) then
                s = xm;  mflag = .true.
            else
                mflag = .false.
            end if

            ebrent = d
            d  = c
            c  = b;  fc = fb
            if (fa * (potential_poly(s, v_poly) - E) < 0.0_dp) then
                b = s;  fb = potential_poly(s, v_poly) - E
            else
                a = s;  fa = potential_poly(s, v_poly) - E
            end if

            if (abs(fa) < abs(fb)) then
                call swap_dp(a, b); call swap_dp(fa, fb)
            end if
        end do

        ! Did not converge; return best estimate
        x_turn = b;  found = .true.

    contains
        pure subroutine swap_dp(x, y)
            real(dp), intent(inout) :: x, y
            real(dp) :: tmp
            tmp = x;  x = y;  y = tmp
        end subroutine swap_dp
    end subroutine turning_points_poly

    ! -------------------------------------------------------------------------
    ! Compute optimal HO alpha from the local harmonic frequency at x_min:
    !   V''(x_min) = sum_{k>=2} k*(k-1)*v_poly(k)*x_min^{k-2}
    !   alpha = sqrt(mass * V''(x_min))
    !
    ! v_poly is indexed 0:deg.
    ! -------------------------------------------------------------------------
    pure function compute_optimal_alpha_poly(v_poly, mass, x_min) result(alpha)
        real(dp), intent(in) :: v_poly(0:)
        real(dp), intent(in) :: mass, x_min
        real(dp) :: alpha

        real(dp) :: d2V
        integer  :: k, deg

        deg = ubound(v_poly, 1)
        d2V = 0.0_dp
        do k = 2, deg
            d2V = d2V + real(k*(k-1), dp) * v_poly(k) * x_min**(k-2)
        end do

        if (d2V > 0.0_dp) then
            alpha = sqrt(mass * d2V)
        else
            alpha = 1.0_dp   ! fallback: user should override via INPUT
        end if
    end function compute_optimal_alpha_poly

end module hamiltonian
