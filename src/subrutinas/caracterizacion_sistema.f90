! |------------------------------------|
! | Autor: Jose Antonio Quinonero Gris |
! |____________________________________|
module caracterizacion_sistema
    !
    ! Modulo para la caracterizacion del sistema:
    ! Calculo del potencial
    ! Calculo de los puntos de corte
    ! Calculo de la masa reducida de la molecula
    ! Calculo del parametro alfa optimizado
    !
    implicit none
    contains
        function V(xe,Vb,x) result(potencial)
            !
            ! Funcion para el computo de la funcion de energia potencial
            !
            COMMON hbar,m
            real*8 :: hbar,m
            real*8, intent(in) :: xe,Vb,x
            real*8 :: potencial

            potencial = (Vb/xe**4)*x**4 - (2.d0*Vb/xe**2)*x**2 + Vb

            return
        end function V
        !
        subroutine puntos_corte(E, Vb, xe, x1, x2, x3, x4)
            !
            ! Subrutina para el calculo de los puntos de corte con el
            ! potencial, es decir, valores de x para los que V(x) = E
            !
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
        !
        subroutine masa_reducida(mH, mN, m)
            !
            ! Subrutina para el calculo de la masa reducida del NH3
            !
            real*8, intent(in) :: mH, mN
            real*8, intent(out) :: m

            m = (3.d0*mH*mN)/(3.d0*mH + mN)

            return
        end subroutine masa_reducida
        !
        subroutine alpha_opt(xe, Vb, alpha)
            !
            ! Subrutina para el calculo del parametro alpha optimizado
            ! considerando solo la componente cuartica del potencial
            !
            COMMON hbar,m
            real*8 :: hbar, m
            real*8, intent(in) :: xe, Vb
            real*8, intent(out) :: alpha

            alpha = (6.d0*m*Vb/(hbar**2*xe**4))**(1.d0/3.d0)

            return
        end subroutine alpha_opt
end module
