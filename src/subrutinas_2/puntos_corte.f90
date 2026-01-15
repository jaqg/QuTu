! Subrutina para el calculo de los puntos de corte de los niveles de energia
! con la curva de potencial
subroutine puntos_corte(E, Vb, xe, x1, x2, x3, x4)
    implicit none
    real*8, intent(in) :: E, Vb, xe
    real*8, intent(out) :: x1, x2, x3, x4

    ! Los puntos x_i tienen unidades de xe

    x1 = -dsqrt(dsqrt(E*Vb)/Vb+1.d0)*xe
    x2 = -dsqrt(1.d0-dsqrt(E*Vb)/Vb)*xe
    x3 = -x2
    x4 = -x1

    return
end subroutine puntos_corte
