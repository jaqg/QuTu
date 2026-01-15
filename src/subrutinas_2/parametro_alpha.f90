! -----------------------------------------------------------------------------
! Parametro alpha optimizado
! -----------------------------------------------------------------------------
subroutine alpha_opt(xe, Vb, alpha)
    COMMON hbar,m
    real*8 :: hbar, m
    real*8, intent(in) :: xe, Vb
    real*8, intent(out) :: alpha
    ! real*8 :: k

    ! Expresion para alfa del oscilador armonico
    ! k = 1.
    ! alpha = (k*m)**0.5/hbar

    ! Expresion para alfa_opt. oscilador perturbado cuarticamente
    ! alpha = ((3**((-3.0d+0)/2.0d+0)*m*sqrt(243*d**2*hbar**2-k**3*m))/&
    !             hbar**3+((6*m*d)/hbar**2)/2.0d+0)**(1.0d+0/3.0d+0)+&
    !             (((m*k)*((3**((-3.0d+0)/2.0d+0)*m*sqrt(243*d**2*hbar**2-&
    !             k**3*m))/hbar**3+((6*m*d)/hbar**2)/2.0d+0)**((-1.0d+0)/&
    !             3.0d+0))/hbar**2)/3.0d+0

    ! Expresion para alfa_opt. del oscilador cuartico
    ! alpha = (6.*m*d/hbar**2)**(1./3.)

    ! Expresion para alfa_opt. del oscilador doble pozo, en el que solo
    ! considero el parametro cuartico para la optimizacion
    alpha = (6.d0*m*Vb/(hbar**2*xe**4))**(1.d0/3.d0)

    return
end subroutine alpha_opt
