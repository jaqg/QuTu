! =============================================================================
! Module: harmonic_oscillator
! Description: 1D harmonic oscillator eigenfunctions and Hermite polynomials
!              for the variational basis expansion.
! Author: Jose Antonio Quinonero Gris
! =============================================================================
module harmonic_oscillator
    use constants, only: dp, PI
    implicit none
    private

    ! Public procedures
    public :: hermite_polynomial
    public :: phi
    public :: phi_array

contains

    ! -------------------------------------------------------------------------
    ! Hermite polynomial H_n(x) using iterative recurrence relation
    ! H_n(x) = 2*x*H_{n-1}(x) - 2*(n-1)*H_{n-2}(x)
    ! with H_0(x) = 1, H_1(x) = 2*x
    ! -------------------------------------------------------------------------
    pure function hermite_polynomial(n, x) result(Hn)
        integer, intent(in) :: n
        real(dp), intent(in) :: x
        real(dp) :: Hn
        real(dp) :: H_nm2, H_nm1, H_current
        integer :: k

        select case (n)
        case (0)
            Hn = 1.0_dp
        case (1)
            Hn = 2.0_dp * x
        case default
            ! Iterative computation (more efficient than recursion)
            H_nm2 = 1.0_dp          ! H_0
            H_nm1 = 2.0_dp * x      ! H_1
            H_current = H_nm1       ! Initialize to avoid compiler warning

            do k = 2, n
                H_current = 2.0_dp * x * H_nm1 - 2.0_dp * real(k - 1, dp) * H_nm2
                H_nm2 = H_nm1
                H_nm1 = H_current
            end do

            Hn = H_current
        end select
    end function hermite_polynomial

    ! -------------------------------------------------------------------------
    ! Harmonic oscillator eigenfunction phi_n(x; alpha)
    ! phi_n(x) = N_n * exp(-alpha*x^2/2) * H_n(sqrt(alpha)*x)
    ! where N_n = (alpha/pi)^{1/4} / sqrt(2^n * n!)
    ! -------------------------------------------------------------------------
    pure function phi(n, alpha, x) result(phi_n)
        integer, intent(in) :: n
        real(dp), intent(in) :: alpha
        real(dp), intent(in) :: x
        real(dp) :: phi_n
        real(dp) :: Nv, scaled_x, Hn

        ! Normalization constant: N_n = (alpha/pi)^{1/4} / sqrt(2^n * n!)
        ! Taking into account that gamma(n+1) = n! (built-in gamma function)
        Nv = (alpha / PI)**0.25_dp / sqrt(2.0_dp**n * gamma(real(n + 1, dp)))

        ! Scaled coordinate
        scaled_x = sqrt(alpha) * x

        ! Hermite polynomial
        Hn = hermite_polynomial(n, scaled_x)

        ! Complete eigenfunction
        phi_n = Nv * exp(-alpha * x**2 / 2.0_dp) * Hn

    end function phi

    ! -------------------------------------------------------------------------
    ! Compute phi_n(x) for an array of x values
    ! -------------------------------------------------------------------------
    pure function phi_array(n, alpha, x_arr) result(phi_arr)
        integer, intent(in) :: n
        real(dp), intent(in) :: alpha
        real(dp), intent(in) :: x_arr(:)
        real(dp) :: phi_arr(size(x_arr))
        integer :: i

        do i = 1, size(x_arr)
            phi_arr(i) = phi(n, alpha, x_arr(i))
        end do
    end function phi_array

end module harmonic_oscillator
