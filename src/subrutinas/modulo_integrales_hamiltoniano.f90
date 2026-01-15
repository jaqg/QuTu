! |------------------------------------|
! | Autor: Jose Antonio Quinonero Gris |
! |____________________________________|
module integrales_Hamiltoniano
    !
    ! Modulo para el calculo de las integrales del Hamiltoniano
    !
    implicit none
    contains
        function der(i,j,xe,Vb,alpha) result(derivada)
            !
            ! Funcion para el calculo de la integral sobre la segunda derivada
            ! respecto a x en la base armonica
            !
            COMMON hbar,m
            real*8 :: hbar,m
            integer, intent(in) :: i, j
            real*8, intent(in) :: xe, Vb, alpha
            real*8 :: derivada

            if (i==j) then
                derivada = (-alpha*(float(i)+1.d0/2.d0))
            elseif (i==j+2 .or. j==i+2) then
                if (i<j) then
                    derivada = ((alpha*((float(i)+1)* &
                               (float(i)+2))**(1.d0/2.d0))/2.d0)
                else
                    derivada = ((alpha*((float(j)+1)* &
                               (float(j)+2))**(1.d0/2.d0))/2.d0)
                end if
            else
                derivada = 0.d0
            end if
            return
        end function der
        !
        function cuad(i,j,xe,Vb,alpha) result(cuadratica)
            !
            ! Funcion para el calculo de la integral sobre x^2 en la base
            ! armonica
            !
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
        !
        function cuar(i,j,xe,Vb,alpha) result(cuartica)
            !
            ! Funcion para el calculo de las integrales sobre x^4 en la base
            ! armonica
            !
            COMMON hbar,m
            real*8 :: hbar,m
            integer, intent(in) :: i, j
            real*8, intent(in) :: xe, Vb, alpha
            real*8 :: cuartica

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
                cuartica = ((((dble(i) + 1.d0)*(dble(i) + 2.d0)*(dble(i) +&
                           3.d0)*(dble(i) + 4.d0))**(1.d0/2.d0))/(4.d0 * &
                           alpha**2))
            elseif (i == j + 4) then
                cuartica = ((((dble(j) + 1.d0)*(dble(j) + 2.d0)*(dble(j) +&
                           3.d0) * (dble(j) + 4.d0))**(1.d0/2.d0))/(4.d0 *&
                           alpha**2))
            else    ! Para una diferencia igual o mayor a 6 niveles, la integral sobre
                    ! x4 es (practicamente) nula
                cuartica = 0.0d0
            endif

            return
        end function cuar
        !
        function H(i, j, xe, Vb, alpha) result(intham)
            !
            ! Funcion para el calculo de las integrales del Hamiltoniano a
            ! partir del resto de funciones
            !
            COMMON hbar,m
            real*8 :: hbar,m
            integer, intent(in) :: i, j
            real*8, intent(in) :: xe, Vb, alpha
            real*8 :: intham

            real*8 :: derivada, cuadratica, cuartica

            intham = (-hbar**2/(2.d0*m)) * der(i,j,xe,Vb,alpha) + &
                     Vb/xe**4 * cuar(i,j,xe,Vb,alpha) -         &
                     2.d0*Vb/xe**2 * cuad(i,j,xe,Vb,alpha)
            return
        end function H
end module
