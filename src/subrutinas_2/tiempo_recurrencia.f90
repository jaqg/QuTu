! Subrutina para el cálculo del tiempo de recurrencia para una combinacion de
! dos funciones estacionarias
subroutine tiempo_recurrencia(E0,E1,HP, tr)
    real*8, intent(in) :: E0,E1,HP
    real*8, intent(out) :: tr

    tr = HP/(E1 - E0)

    return
end subroutine tiempo_recurrencia
