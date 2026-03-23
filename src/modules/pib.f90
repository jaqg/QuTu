! =============================================================================
! Module: pib
! Description: Particle-in-a-Box (PIB) Finite Basis Representation (FBR).
!              Provides basis functions, diagonal kinetic matrix, and
!              closed-form potential matrix elements for any polynomial
!              potential V(x) = sum_{k=0}^{deg} v_k * x^k on [-L/2, L/2].
!
!              Basis functions (1-indexed, n = 1, 2, 3, ...):
!                phi_n(x) = sqrt(2/L)*cos(n*pi*x/L),  n = 1,3,5,... (even parity)
!                phi_n(x) = sqrt(2/L)*sin(n*pi*x/L),  n = 2,4,6,... (odd  parity)
!
!              Kinetic matrix: T_mn = (n^2*pi^2)/(2*L^2) * delta_mn  (exact diagonal)
!
!              Parity selection rule: I^(k)_mn = 0 if m+n+k is odd.
!
! Reference: docs/theory/latex/sections/05b_PIB_basis.tex
! Author: Jose Antonio Quinonero Gris
! =============================================================================
module pib
    use constants, only: dp, PI, HBAR_AU
    use types,     only: system_params_t
    implicit none
    private

    ! Public procedures
    public :: phi_pib
    public :: pib_kinetic_matrix
    public :: pib_xk_element
    public :: pib_potential_matrix
    public :: build_hamiltonian_pib

contains

    ! -------------------------------------------------------------------------
    ! PIB basis function phi_n(x; L)
    !   odd n  -> even parity -> cos(n*pi*x/L)
    !   even n -> odd  parity -> sin(n*pi*x/L)
    ! Returns 0 outside the box [-L/2, L/2].
    ! -------------------------------------------------------------------------
    pure function phi_pib(n, L, x) result(phi_n)
        integer,  intent(in) :: n      ! quantum number, 1-based
        real(dp), intent(in) :: L      ! box length (a.u.)
        real(dp), intent(in) :: x      ! position (a.u.)
        real(dp) :: phi_n
        real(dp) :: norm

        ! Outside the box: wavefunction is zero
        if (abs(x) > L / 2.0_dp) then
            phi_n = 0.0_dp
            return
        end if

        norm = sqrt(2.0_dp / L)
        if (mod(n, 2) == 1) then   ! odd n -> even parity -> cosine
            phi_n = norm * cos(real(n, dp) * PI * x / L)
        else                        ! even n -> odd parity -> sine
            phi_n = norm * sin(real(n, dp) * PI * x / L)
        end if
    end function phi_pib

    ! -------------------------------------------------------------------------
    ! Diagonal kinetic energy matrix T_mn = n^2*pi^2/(2*L^2) * delta_mn.
    ! Stores the geometric factor only (mass factor applied in build_hamiltonian_pib).
    ! T_mat is (1:N, 1:N), 1-based.
    ! -------------------------------------------------------------------------
    subroutine pib_kinetic_matrix(N, L, T_mat)
        integer,  intent(in)  :: N
        real(dp), intent(in)  :: L
        real(dp), allocatable, intent(out) :: T_mat(:,:)
        integer :: in_   ! loop index (avoid clash with dummy arg N, case-insensitive)

        allocate(T_mat(N, N))
        T_mat = 0.0_dp
        do in_ = 1, N
            T_mat(in_, in_) = real(in_, dp)**2 * PI**2 / (2.0_dp * L**2)
        end do
    end subroutine pib_kinetic_matrix

    ! -------------------------------------------------------------------------
    ! Closed-form matrix element I^(k)_mn = <phi_m | x^k | phi_n>
    ! for k = 0, 1, 2, 3, 4.
    !
    ! Parity selection rule: I^(k)_mn = 0 if m+n+k is odd.
    !
    ! Formulas derived in docs/theory/latex/sections/05b_PIB_basis.tex
    ! and verified by SymPy symbolic integration.
    ! -------------------------------------------------------------------------
    pure function pib_xk_element(m, n, k, L) result(Imn)
        integer,  intent(in) :: m, n, k   ! 1-based quantum numbers; k = power
        real(dp), intent(in) :: L
        real(dp) :: Imn

        integer :: exp_s, exp_diff, exp_sum, s_int
        real(dp) :: rm, rn, rmn_diff, rmn_sum, rmn_sq_diff

        Imn = 0.0_dp

        ! --- Parity selection rule ---
        if (mod(m + n + k, 2) /= 0) return

        rm = real(m, dp)
        rn = real(n, dp)

        select case (k)

        ! -----------------------------------------------------------------
        case (0)
        ! -----------------------------------------------------------------
        ! I^(0)_mn = delta_mn  (orthonormality)
            if (m == n) Imn = 1.0_dp

        ! -----------------------------------------------------------------
        case (1)
        ! -----------------------------------------------------------------
        ! I^(1)_mn = -8*m*n*L / (pi^2*(m^2-n^2)^2) * (-1)^((m+n-1)/2)
        ! Non-zero only when m+n is odd (sel. rule), diagonal is zero.
            if (m == n) return   ! diagonal is zero; also blocked by sel. rule
            ! (m+n-1) is even when m+n is odd, so (m+n-1)/2 is an integer
            exp_s = mod((m + n - 1) / 2, 2)
            rmn_sq_diff = real((m**2 - n**2)**2, dp)
            Imn = -8.0_dp * rm * rn * L &
                  / (PI**2 * rmn_sq_diff) &
                  * real((-1)**exp_s, dp)

        ! -----------------------------------------------------------------
        case (2)
        ! -----------------------------------------------------------------
        ! Non-zero only when m+n is even (sel. rule).
        ! Diagonal:    I^(2)_nn = L^2 * (1/12 - 1/(2*n^2*pi^2))
        ! Off-diagonal (m+n even, m != n):
        !   phi_m*phi_n = (2/L)*trig*trig = (1/L)*[cos(m-n) +/- cos(m+n)]
        !   Each cos-integral gives J_p^(2) = 2*(-1)^(p/2)*L^3/(p^2*pi^2)
        !   so I^(2)_mn = (1/L)*[J_{m-n} +/- J_{m+n}]
        !              = 2*L^2/pi^2 * [(-1)^((m-n)/2)/(m-n)^2
        !                              + s*(-1)^((m+n)/2)/(m+n)^2]
        !   where s = (-1)^(m+1)  [+1 if both odd, -1 if both even]
            if (m == n) then
                Imn = L**2 * (1.0_dp/12.0_dp &
                              - 1.0_dp/(2.0_dp * rn**2 * PI**2))
            else
                ! (m-n) is even when m+n is even; use abs for exponent sign
                exp_diff = mod(abs(m - n) / 2, 2)
                exp_sum  = mod((m + n) / 2, 2)
                s_int    = (-1)**(m + 1)   ! +1 if m odd, -1 if m even
                rmn_diff = real((m - n)**2, dp)
                rmn_sum  = real((m + n)**2, dp)
                Imn = 2.0_dp * L**2 / PI**2 * ( &
                      real((-1)**exp_diff, dp) / rmn_diff &
                      + real(s_int * (-1)**exp_sum, dp) / rmn_sum )
            end if

        ! -----------------------------------------------------------------
        case (3)
        ! -----------------------------------------------------------------
        ! I^(3)_mn = (-1)^((m+n-1)/2) * 6*m*n*L^3/(pi^2*(m^2-n^2)^2)
        !            * [16*(m^2+n^2)/(pi^2*(m^2-n^2)^2) - 1]
        ! Non-zero only when m+n is odd, diagonal is zero.
            if (m == n) return
            exp_s = mod((m + n - 1) / 2, 2)
            rmn_sq_diff = real((m**2 - n**2)**2, dp)
            Imn = real((-1)**exp_s, dp) &
                  * 6.0_dp * rm * rn * L**3 &
                  / (PI**2 * rmn_sq_diff) &
                  * (16.0_dp * (rm**2 + rn**2) / (PI**2 * rmn_sq_diff) - 1.0_dp)

        ! -----------------------------------------------------------------
        case (4)
        ! -----------------------------------------------------------------
        ! Non-zero only when m+n is even (sel. rule).
        ! Diagonal: J_{2n}^(4) = (-1)^n * L^5*(n^2*pi^2-6)/(4*n^4*pi^4)
        !   I^(4)_nn = L^4/80 + (-1)^n * L^4*(n^2*pi^2-6)/(4*n^4*pi^4)
        !   For both parities this simplifies to:
        !   I^(4)_nn = L^4*(1/80 - 1/(4*n^2*pi^2) + 3/(2*n^4*pi^4))
        ! Off-diagonal: J_p^(4) = (-1)^(p/2) * L^5*(p^2*pi^2-24)/(p^4*pi^4)
        !   I^(4)_mn = (1/L)*[J_{m-n}^(4) + s*J_{m+n}^(4)]
        !   = L^4/pi^4 * [(-1)^((m-n)/2)*((m-n)^2*pi^2-24)/(m-n)^4
        !                + s*(-1)^((m+n)/2)*((m+n)^2*pi^2-24)/(m+n)^4]
        !   where s = (-1)^(m+1)
            if (m == n) then
                Imn = L**4 * ( 1.0_dp/80.0_dp &
                               - 1.0_dp/(4.0_dp * rn**2 * PI**2) &
                               + 3.0_dp/(2.0_dp * rn**4 * PI**4) )
            else
                exp_diff = mod(abs(m - n) / 2, 2)
                exp_sum  = mod((m + n) / 2, 2)
                s_int    = (-1)**(m + 1)
                rmn_diff = real((m - n)**2, dp)   ! (m-n)^2
                rmn_sum  = real((m + n)**2, dp)   ! (m+n)^2
                Imn = L**4 / PI**4 * ( &
                      real((-1)**exp_diff, dp) * (rmn_diff * PI**2 - 24.0_dp) &
                      / rmn_diff**2 &
                      + real(s_int * (-1)**exp_sum, dp) * (rmn_sum * PI**2 - 24.0_dp) &
                      / rmn_sum**2 )
            end if

        ! -----------------------------------------------------------------
        case default
        ! -----------------------------------------------------------------
        ! k > 4 not implemented; return 0
            Imn = 0.0_dp

        end select

    end function pib_xk_element

    ! -------------------------------------------------------------------------
    ! Assemble the full potential matrix V_mn = sum_{k=0}^{deg} v_k * I^(k)_mn
    ! v_poly is indexed 0:deg.  V_mat is (1:N, 1:N), 1-based.
    ! -------------------------------------------------------------------------
    subroutine pib_potential_matrix(v_poly, N, L, V_mat)
        real(dp), intent(in)  :: v_poly(0:)    ! coefficients v0..vdeg
        integer,  intent(in)  :: N
        real(dp), intent(in)  :: L
        real(dp), allocatable, intent(out) :: V_mat(:,:)

        integer :: im, jn, k, deg   ! loop indices (im/jn avoid clash with N)

        deg = ubound(v_poly, 1)

        allocate(V_mat(N, N))
        V_mat = 0.0_dp

        do k = 0, deg
            if (v_poly(k) == 0.0_dp) cycle
            do im = 1, N
                do jn = 1, N
                    V_mat(im, jn) = V_mat(im, jn) &
                                    + v_poly(k) * pib_xk_element(im, jn, k, L)
                end do
            end do
        end do
    end subroutine pib_potential_matrix

    ! -------------------------------------------------------------------------
    ! Build the full N×N Hamiltonian matrix for the PIB basis:
    !   H_mn = (hbar^2/mass) * T_mn + V_mn
    !        = (1/mass) * n^2*pi^2/(2*L^2) * delta_mn  +  sum_k v_k * I^(k)_mn
    !
    ! In atomic units hbar = 1, so the kinetic prefactor is 1/mass.
    ! H_full is (1:N, 1:N), 1-based, ready for dsyev.
    ! -------------------------------------------------------------------------
    subroutine build_hamiltonian_pib(params, H_full)
        type(system_params_t), intent(in) :: params
        real(dp), allocatable, intent(out) :: H_full(:,:)

        real(dp), allocatable :: V_mat(:,:)
        integer :: N, i

        N = params%N

        call pib_potential_matrix(params%v_poly, N, params%box_length, V_mat)

        allocate(H_full(N, N))
        H_full = V_mat

        ! Add diagonal kinetic term: T_ii = (hbar^2/mass) * i^2*pi^2/(2*L^2)
        ! HBAR_AU = 1 in atomic units, so coefficient is 1/mass
        do i = 1, N
            H_full(i, i) = H_full(i, i) &
                           + (HBAR_AU**2 / params%mass) &
                             * real(i, dp)**2 * PI**2 / (2.0_dp * params%box_length**2)
        end do

        deallocate(V_mat)
    end subroutine build_hamiltonian_pib

end module pib
