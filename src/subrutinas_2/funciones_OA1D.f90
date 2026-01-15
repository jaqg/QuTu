! Funciones propias del oscilador armónico unidimensional
function phi(n,alpha,x) result(res_phi)
    COMMON hbar,m
    real*8 :: hbar,m
    real*8 :: Nv
    ! real*8 :: k = 1.0d0
    real*8 :: pi
    integer, intent(in) :: n
    real*8, intent(in) :: alpha, x
    real*8 :: res_phi

    interface
        recursive function hp(n, x) result(res_hp)
            integer, intent(in) :: n
            real*8, intent(in) :: x
            real*8 :: res_hp
        end function hp
    end interface

    ! Valor de pi
    PI=4.D0*DATAN(1.D0)

    ! Parametro alfa del oscilador
    ! alpha = (k*m)**0.5/hbar
    ! Constante de normalizacion
    ! Nota: factorial(n) = Gamma(n+1), donde n es real
    Nv = (alpha/pi)**0.25/sqrt(2.**float(n)*Gamma(float(n+1)))
    ! Funcion de onda
    res_phi = Nv*exp(-alpha*x**2./2.d0)*hp(n,sqrt(alpha)*x)
    ! write(*,*) 'alpha =', alpha

    return
end function phi
