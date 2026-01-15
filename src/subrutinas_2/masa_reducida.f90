! Subrutina para el cálculo de la masa reducida de la molecula de NH3
subroutine masa_reducida(mH, mN, m)
    ! COMMON hbar,m
    real*8, intent(in) :: mH, mN
    real*8, intent(out) :: m

    m = (3.d0*mH*mN)/(3.d0*mH + mN)

    return
end subroutine masa_reducida
