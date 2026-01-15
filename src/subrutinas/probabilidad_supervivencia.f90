! |------------------------------------|
! | Autor: Jose Antonio Quinonero Gris |
! |____________________________________|
module probabilidad_supervivencia_general
    !
    ! Modulo para el calculo del tiempo de recurrencia y de la probabilidad de
    ! supervivencia general
    !
    implicit none
    contains
        subroutine tiempo_recurrencia(E0,E1,HP, tr)
            !
            ! Subrutina para el calculo del tiempo de recurrencia para una
            ! combinacion de dos funciones estacionarias
            !
            real*8, intent(in) :: E0,E1,HP
            real*8, intent(out) :: tr

            tr = HP/(E1 - E0)

            return
        end subroutine tiempo_recurrencia
        !
        subroutine probabilidad_supervivencia(c_i, E_wp, t, EHAJ, HP, pi, Ps)
            !
            ! Subrutina para el calculo de la probabilidad de supervivencia
            !
            implicit none
            COMMON hbar,m
            real*8, dimension(:), intent(in) :: c_i
            real*8, dimension(:), intent(in) :: E_wp
            real*8, intent(in) :: t, EHAJ, HP, pi
            real*8, intent(out) :: Ps
            integer :: i, j, numero_func
            real*8 :: hbar, m, t_s, E0, E1, a_i, a_j

            hbar = HP/(2.d0*pi)     ! J s
            t_s = t*1.d-12          ! Tiempo en segundos <- picosegundos
            numero_func = size(c_i)

            Ps = 0.d0
            do i=1, numero_func, 1
                do j=i+1, numero_func, 1
                    E0 = E_wp(i) * EHAJ          ! Energia del nivel v=0 en J
                    E1 = E_wp(j) * EHAJ          ! Energia del nivel v=1 en J
                    a_i = c_i(i)
                    a_j = c_i(j)
                    Ps = Ps + abs(a_i)**2 * abs(a_j)**2 * cos((E1-E0)*t_s/hbar)
                end do
            end do
            Ps = 2.d0 * Ps
            do i=1, numero_func, 1
                a_i = c_i(i)
                Ps = Ps + abs(a_i)**4
            end do

            return
        end subroutine probabilidad_supervivencia
end module
