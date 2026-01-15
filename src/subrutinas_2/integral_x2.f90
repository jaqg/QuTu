! -----------------------------------------------------------------------------
! Calculo de la integral con x^2
! -----------------------------------------------------------------------------
function cuad(i,j,xe,Vb,alpha) result(cuadratica)
    COMMON hbar,m
    real*8 :: hbar,m
    integer, intent(in) :: i, j
    real*8, intent(in) :: xe, Vb, alpha
    real*8 :: cuadratica

    if (i==j) then
        ! n = float(i) = float(j)
        cuadratica = ((float(i)+1.d0/2.d0)/alpha)
    elseif (i==j+2 .or. j==i+2) then
        if (i<j) then
            cuadratica = ((((float(i)+1)*(float(i)+2))**(1.d0/2.d0))/&
                         (2.d0*alpha))
        else
            cuadratica = ((((float(j)+1)*(float(j)+2))**(1.d0/2.d0))/&
                         (2.d0*alpha))
        end if
        ! n = float(i)
    else
        cuadratica = 0.d0
    end if
    return
end function cuad
