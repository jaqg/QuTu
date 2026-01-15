! -----------------------------------------------------------------------------
! Calculo de la integral con la segunda derivada respeccto a x
! -----------------------------------------------------------------------------
function der(i,j,xe,Vb,alpha) result(derivada)
    COMMON hbar,m
    real*8 :: hbar,m
    integer, intent(in) :: i, j
    real*8, intent(in) :: xe, Vb, alpha
    real*8 :: derivada

    if (i==j) then
        derivada = (-alpha*(float(i)+1.d0/2.d0))
    elseif (i==j+2 .or. j==i+2) then
        if (i<j) then
            derivada = ((alpha*((float(i)+1)*(float(i)+2))**(1.d0/2.d0))/2.d0)
        else
            derivada = ((alpha*((float(j)+1)*(float(j)+2))**(1.d0/2.d0))/2.d0)
        end if
    else
        derivada = 0.d0
    end if
    return
end function der
