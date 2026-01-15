! -----------------------------------------------------------------------------
! Integrales del Hamiltoniano
! -----------------------------------------------------------------------------
function H(i, j, xe, Vb, alpha) result(intham)
    COMMON hbar,m
    real*8 :: hbar,m
    integer, intent(in) :: i, j
    real*8, intent(in) :: xe, Vb, alpha
    real*8 :: intham

    real*8 :: derivada, cuadratica, cuartica

    ! Hago uso de las funciones para el calculo de los valores
    ! propios de la energia y la integral de la componente cuartica
    interface
        function der(i,j,xe,Vb,alpha) result(derivada)
        integer, intent(in) :: i, j
        real*8, intent(in) :: xe, Vb, alpha
        real*8 :: derivada
        end function der
        function cuad(i,j,xe,Vb,alpha) result(cuadratica)
        integer, intent(in) :: i, j
        real*8, intent(in) :: xe, Vb, alpha
        real*8 :: cuadratica
        end function cuad
        function cuar(i,j,xe,Vb,alpha) result(cuartica)
        integer, intent(in) :: i, j
        real*8, intent(in) :: xe, Vb, alpha
        real*8 :: cuartica
        end function cuar
    end interface

    intham = (-hbar**2/(2.d0*m)) * der(i,j,xe,Vb,alpha) + &
             Vb/xe**4 * cuar(i,j,xe,Vb,alpha) -         &
             2.d0*Vb/xe**2 * cuad(i,j,xe,Vb,alpha)
    return
end function H
