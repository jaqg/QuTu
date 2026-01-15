! |------------------------------------|
! | Autor: Jose Antonio Quinonero Gris |
! |____________________________________|
module valores_esperados
    !
    ! Modulo para el calculo de valores esperados
    ! La expresion general para el valor esperado de un observable A, <A>(t),
    ! es
    ! <A>(t) = <Psi(x,t)|A|Psi(x,t)>
    !        = sum_i |a_i|^2 <i|A|i> +
    !          + 2 sum_i sum_j>i a_i a_j <i|A|j> cos (E_j - E_i)t/hbarra
    !
    implicit none
    contains
        !
        ! Funcion para el calculo de las integrales <n|x|m> de las funciones
        ! base (funciones propias del oscilador armonico)
        !
        function integral_x(n,m,alfa) result(int_x)
            implicit none
            integer, intent(in) :: n,m
            real*8, intent(in) :: alfa
            real*8 :: int_x

            ! Antiguo
            ! if (n==m+1.or.m==n+1) then
            !     int_x = 1.d0/(sqrt(2.d0*alfa))
            ! else
            !     int_x = 0.d0
            ! end if

            ! Nuevo
            ! (ecs.(1.133) y (1.134)) libro espectroscopia
            if (n==m+1) then
                int_x = dsqrt(1.d0*(m+1)/(2.d0*alfa))
            elseif (m==n+1) then
                int_x = dsqrt(1.d0*(n+1)/(2.d0*alfa))
            elseif (n==m-1) then
                int_x = dsqrt(1.d0*m/(2.d0*alfa))
            elseif (m==n-1) then
                int_x = dsqrt(1.d0*n/(2.d0*alfa))
            else
                int_x = 0.d0
            end if

            return
        end function integral_x
        !
        ! Calculo de la matriz posicion en la base armonica
        !
        subroutine matriz_posicion(N, alfa, x)
            ! N: numero de funciones base
            implicit none
            integer, intent(in) :: N
            real*8, intent(in) :: alfa
            real*8, dimension(:,:), allocatable, intent(out) :: x
            integer :: i, j

            allocate(x(N,N))
            ! Inicializacion de la matriz
            do i = 1, N
                do j = 1, N
                    x(i,j) = 0.d0
                end do
            end do

            ! Creacion de la matriz con ayuda de la funcion integral_x
            ! do i = 1, N
            !     do j = 1, i
            !         x(j,i) = integral_x(j,i,alfa)
            !         x(i,j) = x(j, i)
            !     end do
            ! end do
            do i = 1, N
                do j = 1, N
                    x(i,j) = integral_x(i-1,j-1,alfa)
                end do
            end do

            return
        end subroutine matriz_posicion
        !
        ! Calculo de la integral <Phi_i|x|Phi_j> para las funciones de prueba
        !
        function integral_x_fprueba(n,m,Nf,c_k,mat_x) result(int_x_fprueba)
            !
            ! Para dos funciones de prueba Phi_n y Phi_m, calcula la integral
            ! <n|x|m>, desarrollando las combinaciones lineales de estas
            ! funciones, de manera que
            ! <n|x|m> = < sum_i c_i^(n) |i> | x | sum_j c_j^(m) |j> >
            ! haciendo uso de la funcion para el calculo de las integrales
            ! sobre x, para las funciones propias del oscilador armonico
            !
            implicit none
            integer, intent(in) :: n, m, Nf
            real*8, dimension(:,:), intent(in) :: c_k, mat_x
            real*8 :: int_x_fprueba
            integer :: i, j
            real*8, dimension(:), allocatable :: c_n, c_m

            allocate(c_n(Nf), c_m(Nf))
            do i = 1, Nf
                c_n(i) = c_k(i,n)
                c_m(i) = c_k(i,m)
            end do
            !
            ! Bucle principal
            !
            ! Una vez creados los arrays con los coeficientes variacionales
            ! c_n y c_m de las funciones Phi_n y Phi_m, calcula las
            ! integrales para dichas combinaciones
            int_x_fprueba = 0.d0
            do i=1, Nf, 1
                if (abs(c_n(i))>0.001) then
                    do j=1, Nf, 1
                        if (abs(c_m(j))>0.001) then
                            int_x_fprueba = int_x_fprueba + c_n(i) * &
                                            c_m(j) * mat_x(i,j)
                        end if
                    end do
                end if
            end do

            return
        end function integral_x_fprueba
        !
        ! Subrutina para el calculo del valor esperado de la posicion con t
        !
        subroutine valor_esperado_x(Nf, c_i, E_wp, t, c_k, &
                                    mat_x, EHAJ, HP, pi, val_esp_x)
            implicit none
            integer, intent(in) :: Nf
            real*8, dimension(:), intent(in) :: c_i
            real*8, dimension(:), intent(in) :: E_wp
            real*8, dimension(:,:), intent(in) :: c_k
            real*8, dimension(:,:), intent(in) :: mat_x
            real*8, intent(in) :: t, EHAJ, HP, pi
            real*8, intent(out) :: val_esp_x
            integer :: i,j,numero_func
            real*8 :: hbar, m, t_s, alfa_A, E0, E1, a_i, a_j

            hbar = HP/(2.d0*pi)     ! J s
            t_s = t*1.d-12          ! Tiempo en segundos <- picosegundos
            numero_func = size(c_i)

            val_esp_x = 0.d0
            do i=1, numero_func, 1
                do j=i+1, numero_func, 1
                    ! if (j==i+1) then
                        E0 = E_wp(i) * EHAJ          ! Energia del nivel v=i en Ha
                        E1 = E_wp(j) * EHAJ          ! Energia del nivel v=j en Ha
                        a_i = c_i(i)
                        a_j = c_i(j)
                        val_esp_x = val_esp_x +&
                                    a_i * a_j * &
                                    integral_x_fprueba(i,j,Nf,c_k,mat_x) *&
                                    cos((E1-E0)*t_s/hbar)
                    ! end if
                ! write(*,*) 'i =',i, 'j =', j, 'int =', integral_x_fprueba(i,j,Nf,c_k,mat_x)
                end do
            end do
            val_esp_x = 2.d0 * val_esp_x
            do i=1, numero_func, 1
                a_i = c_i(i)
                val_esp_x = val_esp_x + abs(a_i)**2 *&
                            integral_x_fprueba(i,i,Nf,c_k,mat_x)
                ! write(*,*) 'i =',i,'int =',integral_x_fprueba(i,i,Nf,c_k,mat_x)
            end do

            return
        end subroutine valor_esperado_x
end module
