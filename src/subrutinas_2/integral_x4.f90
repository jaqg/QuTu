! -----------------------------------------------------------------------------
! Calculo de la integral de la componente cuartica del potencial
! -----------------------------------------------------------------------------
function cuar(i,j,xe,Vb,alpha) result(cuartica)
    COMMON hbar,m
    real*8 :: hbar,m
    integer, intent(in) :: i, j
    real*8, intent(in) :: xe, Vb, alpha
    real*8 :: cuartica

    ! Funcion para el calculo de la integral <n|x⁴|m>

    if (j == i) then
        cuartica = (3.d0*((2.d0*dble(i)**2 + 2.d0*dble(i) + 1.d0))/&
                   (4.d0*alpha**2))
    elseif (j == i + 2) then
        cuartica = (((2.d0*dble(i) + 3.d0)*((dble(i) + 1.d0) * &
                   (dble(i)+2.d0))**(1.d0/2.d0))/(2.d0*alpha**2))
   elseif (i == j + 2) then
        cuartica = (((2.d0*dble(j) + 3.d0)*((dble(j) + 1.d0) * &
                   (dble(j)+2.d0))**(1.d0/2.d0))/(2.d0*alpha**2))
    elseif (j == i + 4) then
        cuartica = ((((dble(i) + 1.d0)*(dble(i) + 2.d0)*(dble(i) + 3.d0)* &
                   (dble(i) + 4.d0))**(1.d0/2.d0))/(4.d0 * alpha**2))
    elseif (i == j + 4) then
        cuartica = ((((dble(j) + 1.d0)*(dble(j) + 2.d0)*(dble(j) + 3.d0) * &
                   (dble(j) + 4.d0))**(1.d0/2.d0))/(4.d0 * alpha**2))
    else    ! Para una diferencia igual o mayor a 6 niveles, la integral sobre
            ! x4 es (practicamente) nula
        cuartica = 0.0d0
    endif

    return
end function cuar
