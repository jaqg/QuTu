! Polinomios de Hermite
recursive function hp(n, x) result(res_hp)
    integer, intent(in) :: n
    real*8, intent(in) :: x
    real*8 :: hp1, hp2, res_hp

    ! Hago uso de la relacion de recurrencia:
    ! H_n(x) = 2xH_n-1(x) - 2(n-1)H_n-2(x)
    ! Teniendo en cuenta que
    ! H_0(x) = 1
    ! H_1(x) = 2x
    if (n==0) then
        res_hp = 1.d0
    elseif (n==1) then
        res_hp = 2.d0*x
    else
        hp1 = 2.d0*x*hp(n-1,x)
        hp2 = 2.d0*float(n-1)*hp(n-2,x)
        res_hp = hp1 - hp2
    end if

    return
end function hp
