! Funcion para calcular el potencial de doble pozo
function V(xe,Vb,x) result(potencial)
    COMMON hbar,m
    real*8 :: hbar,m
    real*8, intent(in) :: xe,Vb,x
    real*8 :: potencial

    potencial = (Vb/xe**4)*x**4 - (2.d0*Vb/xe**2)*x**2 + Vb

    return
end function V
