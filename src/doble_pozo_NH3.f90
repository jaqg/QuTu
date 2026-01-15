! _____________________________________________________________________________
! *****************************************************************************
! Autor: Jose Antonio Quinonero Gris
! Fecha de creacion: 28 de mayo de 2022
! *****************************************************************************
! -----------------------------------------------------------------------------

! -----------------------------------------------------------------------------
! PROGRAMA PRINCIPAL
! -----------------------------------------------------------------------------
program doble_pozo_NH3

    ! Problema del doble pozo para la molecula de NH3:
    ! H = -hbar**2/(2*mu) <v|d2/dx2|v> + a <v|x4|v> - b <v|x2|v> + Vb
    ! donde a,b > 0
    ! Podemos escribir el potencial en funcion de las posiciones de los
    ! pozos (xe) y la altura de la barrera (Vb) segun
    ! V = (Vb/xe^4) <v|x4|v> - (2Vb/xe^2) <v|x2|v> + Vb
    !   = Vb/xe^4 (x^2 - xe^2)^2
    ! de manera que escribimos el hamiltoniano como
    ! H = -(hbar**2/(2*mu))<v|d2/dx2|v>+(Vb/xe^4)<v|x4|v>-(2Vb/xe^2)<v|x2|v>+Vb

    ! Programa para calcular las energias y parametros variacionales
    ! diagonalizando la matriz del hamiltoniano, de manera que
    ! Hc = Ec
    ! donde H es una matriz real simetrica de elementos Hij=<i|H|j>
    ! Obtendremos como autovalores las energias variacionales, E
    ! y como autovectores los coeficientes variacionales c

    ! IMPLICIT REAL*8(A-H,O-Z)
    ! IMPLICIT INTEGER(I-N)

    use caracterizacion_sistema
    use modulo_OA1D
    use integrales_Hamiltoniano
    use probabilidad_supervivencia_general
    use valores_esperados

    implicit none

    ! =======================
    ! Definicion de variables
    ! =======================

    integer :: i,j,l,jj, j_arr, fu
    logical :: True, False

    COMMON hbar,m
    ! Constantes fisicas (CGS) y factores de conversion tomadas del
    ! NIST (CODATA-2018)
    real*8, parameter :: RBOHR=0.529177210903D0    ! Radio de Bohr en angstrom
    real*8, parameter :: EUACM=2.1947463136320D5   ! Conversion hartrees -> cm-1
    real*8, parameter :: UMA=1.66053906660D-24     ! Unidad de masa atomica en gramos
    real*8, parameter :: PELEC=9.1093837015D-28    ! Masa del electron en gramos
    real*8, parameter :: EHAJ=4.3597447222071D-18  ! Conversion hartrees -> J
    real*8            :: PUAUMA                    ! Conversion masa ua -> uma, PUAUMA=UMA/PELEC
    real*8, parameter :: HP=6.62607015D-34         ! Constante de Planck en J s
    real*8            :: hbar=1.0D0                !
    real*8 :: pi
    ! Masa reducida (m), del H y del N
    real*8 :: m, mH, mN
    ! Numero de funciones base
    integer :: N, Nmax, Npar, Nimpar, N_conver
    ! Resultado de la funcion para el parametro alpha
    real*8 :: alpha
    ! Resultado de la funcion para la integral sobre d2/dx2
    real*8 :: derivada
    ! Resultado de la funcion para la integral sobre x2
    real*8 :: cuadratica
    ! Resultado de la funcion para la integral sobre x4
    real*8 :: cuartica
    ! Matriz del hamiltoniano
    real*8, dimension(:,:), allocatable :: H_par, H_impar, c_k
    real*8, dimension(:), allocatable :: min_coef, max_coef
    ! Array para los valores propios de la energia
    real*8, dimension(:), allocatable :: E, E_par, E_impar, E_Nmax, E_Nmax_cm
    ! Array de energias para cada N
    real*8, dimension(:,:), allocatable :: E_arr
    ! Variables para los valores de energia del bucle para hallar N_conver
    real*8 :: E_sup, E_inf, Delta_E, E_conver, E_conver_cm
    ! Array necesaria para la subrutina de diagonalizacion
    real*8, dimension(:), allocatable :: work
    ! Declaracion de parametros necesarios para la subrutina que calcula los
    ! eigenvalues
    integer :: nr, lwork, info
    ! Array auxiliar para tabla de energias
    real*8, dimension(21,4) :: E_tabla
    ! Posicion de los minimos y altura de la barrera de potencial
    real*8 :: xe, Vb, xe_A, Vb_cm
    ! Variables para la posicion, x
    real*8 :: x, xmin, xmax, dx, x_angstrom
    ! Matriz de la posicion en la base armonica
    real*8, dimension(:,:), allocatable :: mat_x_arm
    ! Array posicion
    real*8, dimension(:), allocatable :: x_vec, x_vec_angstrom
    ! Array potencial
    real*8, dimension(:), allocatable :: V_vec
    ! Numero de valores de x
    integer :: steps_x
    ! Vector funcion de prueba y densidad de probabilidad
    real*8 :: Phi0, Phi1, Phi2, Phi3, Phi4, Phi5
    real*8 :: Phi0_A, Phi1_A, Phi2_A, Phi3_A, Phi4_A, Phi5_A
    real*8, dimension(:), allocatable :: Phi0_vec, Phi1_vec, Phi2_vec, &
                                         Phi3_vec, Phi4_vec, Phi5_vec
    real*8, dimension(:), allocatable :: Phi0_vec_A, Phi1_vec_A, Phi2_vec_A,&
                                         Phi3_vec_A, Phi4_vec_A, Phi5_vec_A
    real*8 :: dPhi0, dPhi1, dPhi2, dPhi3, dPhi4, dPhi5
    real*8 :: dPhi0_A, dPhi1_A, dPhi2_A, dPhi3_A, dPhi4_A, dPhi5_A
    real*8, dimension(:), allocatable :: dPhi0_vec, dPhi1_vec, dPhi2_vec, &
                                         dPhi3_vec, dPhi4_vec, dPhi5_vec
    real*8, dimension(:), allocatable :: dPhi0_vec_A,dPhi1_vec_A,dPhi2_vec_A, &
                                         dPhi3_vec_A,dPhi4_vec_A,dPhi5_vec_A
    ! Puntos de corte de las energias con la curva de potencial
    real*8 :: x1, x2, x3, x4
    ! Funcion de onda
    ! Array con los coeficientes de las combinaciones de los paquetes
    real*8, dimension(:), allocatable :: c_psi1, c_psi2
    ! Numero de funciones que conforman el paquete
    integer :: n_func_comb
    ! Energias de los paquetes
    real*8 :: E_psi1, E_psi3, E_psi1_cm, E_psi3_cm
    real*8, dimension(:), allocatable :: E_wp
    ! Paquetes de onda
    real*8, dimension(:), allocatable :: psi1_vec,psi2_vec,psi3_vec,psi4_vec
    real*8, dimension(:), allocatable :: dpsi1_vec,dpsi2_vec,dpsi3_vec,&
                                         dpsi4_vec
    real*8, dimension(:), allocatable :: psi1_vec_A,psi2_vec_A,psi3_vec_A,&
                                         psi4_vec_A
    real*8, dimension(:), allocatable :: dpsi1_vec_A,dpsi2_vec_A,dpsi3_vec_A,&
                                         dpsi4_vec_A
    ! Subrutina para el calculo del tiempo de recurrencia
    real*8 :: E0, E1, tr
    ! Subrutina para el calculo la probabilidad de supervivencia
    real*8, dimension(:), allocatable :: t_vec
    real*8 :: t, t0, tf, dt, Ps
    integer :: steps_t
    ! Paquete de cuatro estados estacionarios
    real*8, dimension(4) :: c_psi_4EE
    real*8, dimension(:), allocatable :: psi_4EE_vec_A, dpsi_4EE_vec_A
    real*8 :: psi_4EE, dpsi_4EE, E_4EE, E_4EE_cm, alfa_4EE
    real*8, dimension(:), allocatable :: array_alfa_4EE
    ! Funcion para la integral sobre x
    real*8 :: val_esp_x

    ! ===================
    ! INICIO DEL PROGRAMA
    ! ===================

    ! Valor de pi
    PI=4.D0*DATAN(1.D0)

    ! Apertura y lectura del fichero con los datos iniciales
    open(unit=1, file="data/in-doble_pozo_NH3.dat")
    open(unit=2, file="data/in-potencial.dat")
    open(unit=3, file="data/in-masas_atomicas.dat")
    ! Omite la primera linea del archivo de datos de entrada
    read(1,*)
    read(2,*)
    read(3,*)
    ! Lee los datos de entrada
    read(1,*) Nmax, xe_A, Vb_cm
    ! Convierto xe y Vb a unidades atomicas
    xe = xe_A/RBOHR
    Vb = Vb_cm/EUACM
    write(*,*) 'xe =', xe, 'Vb =', Vb
    write(*,*) 'a =', Vb/xe**4, 'b=', 2.d0*Vb/xe**2
    write(*,*) 'b/a =', (2.d0*Vb/xe**2)/(Vb/xe**4)
    read(2,*) xmin, xmax, dx
    read(3,*) mH, mN
    ! Convierto mH y mN a unidades de masa ua
    PUAUMA=UMA/PELEC ! Factor de conversion uma -> ua
    mH = mH*PUAUMA
    mN = mN*PUAUMA
    ! Cierra los ficheros de entrada
    close(1)
    close(2)
    close(3)

    ! Apertura del fichero de resultados
    ! open(unit=2,   file="data/out-energias_variacionales.dat")
    ! open(unit=3,   file="data/out-Econver_n=0,5,10,15.dat")
    ! open(unit=4,   file="data/out-E_arr.dat")
    open(unit=7,   file="data/out-N_vs_W0.dat")
    open(unit=8,   file="data/out-N_vs_W1.dat")
    open(unit=9,   file="data/out-N_vs_W2.dat")
    open(unit=10,  file="data/out-N_vs_W3.dat")
    ! open(unit=11,  file="data/out-energias.dat")
    open(unit=12,  file="data/out-conver_energias_hartrees.dat")
    open(unit=13,  file="data/out-conver_energias_cm-1.dat")
    open(unit=14,  file="data/out-masa_red_alfa.dat")
    open(unit=20,  file="data/out-coeficientes_par.dat")
    open(unit=21,  file="data/out-coeficientes_impar.dat")
    open(unit=30,  file="data/out-potencial_hartrees.dat")
    open(unit=31,  file="data/out-potencial_cm-1.dat")
    open(unit=40,  file="data/out-funciones_pares_hartrees.dat")
    open(unit=41,  file="data/out-densidad_prob_pares_hartrees.dat")
    open(unit=42,  file="data/out-funciones_impares_hartrees.dat")
    open(unit=43,  file="data/out-densidad_prob_impares_hartrees.dat")
    open(unit=44,  file="data/out-funciones_pares_A.dat")
    open(unit=45,  file="data/out-densidad_prob_pares_A.dat")
    open(unit=46,  file="data/out-funciones_impares_A.dat")
    open(unit=47,  file="data/out-densidad_prob_impares_A.dat")
    open(unit=50,  file="data/out-psi1.dat")
    open(unit=51,  file="data/out-psi2.dat")
    open(unit=52,  file="data/out-psi3.dat")
    open(unit=53,  file="data/out-psi4.dat")
    open(unit=54,  file="data/out-psi1_A.dat")
    open(unit=55,  file="data/out-psi2_A.dat")
    open(unit=56,  file="data/out-psi3_A.dat")
    open(unit=57,  file="data/out-psi4_A.dat")
    open(unit=70,  file="data/out-tiempo_recurrencia.dat")
    open(unit=80,  file="data/out-probabilidad_supervivencia_Psi0.dat")
    open(unit=81,  file="data/out-probabilidad_supervivencia_Psi1.dat")
    open(unit=82,  file="data/out-puntos_corte.dat")
    open(unit=90,  file="data/out-psi_4EE_alfa=0.dat")
    open(unit=91,  file="data/out-psi_4EE_alfa=10.dat")
    open(unit=92,  file="data/out-psi_4EE_alfa=15.dat")
    open(unit=93,  file="data/out-psi_4EE_alfa=20.dat")
    open(unit=94,  file="data/out-psi_4EE_alfa=30.dat")
    open(unit=95,  file="data/out-psi_4EE_alfa=40.dat")
    open(unit=96,  file="data/out-psi_4EE_alfa=45.dat")
    open(unit=97,  file="data/out-psi_4EE_alfa=50.dat")
    open(unit=98,  file="data/out-psi_4EE_alfa=60.dat")
    open(unit=99,  file="data/out-psi_4EE_alfa=70.dat")
    open(unit=100, file="data/out-psi_4EE_alfa=75.dat")
    open(unit=101, file="data/out-psi_4EE_alfa=80.dat")
    open(unit=102, file="data/out-psi_4EE_alfa=90.dat")
    open(unit=110, file="data/out-prob_sup_alfa=0.dat")
    open(unit=111, file="data/out-prob_sup_alfa=10.dat")
    open(unit=112, file="data/out-prob_sup_alfa=15.dat")
    open(unit=113, file="data/out-prob_sup_alfa=20.dat")
    open(unit=114, file="data/out-prob_sup_alfa=30.dat")
    open(unit=115, file="data/out-prob_sup_alfa=40.dat")
    open(unit=116, file="data/out-prob_sup_alfa=45.dat")
    open(unit=117, file="data/out-prob_sup_alfa=50.dat")
    open(unit=118, file="data/out-prob_sup_alfa=60.dat")
    open(unit=119, file="data/out-prob_sup_alfa=70.dat")
    open(unit=120, file="data/out-prob_sup_alfa=75.dat")
    open(unit=121, file="data/out-prob_sup_alfa=80.dat")
    open(unit=122, file="data/out-prob_sup_alfa=90.dat")
    open(unit=130, file="data/out-val_esp_x_alfa=0.dat")
    open(unit=131, file="data/out-val_esp_x_alfa=10.dat")
    open(unit=132, file="data/out-val_esp_x_alfa=15.dat")
    open(unit=133, file="data/out-val_esp_x_alfa=20.dat")
    open(unit=134, file="data/out-val_esp_x_alfa=30.dat")
    open(unit=135, file="data/out-val_esp_x_alfa=40.dat")
    open(unit=136, file="data/out-val_esp_x_alfa=45.dat")
    open(unit=137, file="data/out-val_esp_x_alfa=50.dat")
    open(unit=138, file="data/out-val_esp_x_alfa=60.dat")
    open(unit=139, file="data/out-val_esp_x_alfa=70.dat")
    open(unit=140, file="data/out-val_esp_x_alfa=75.dat")
    open(unit=141, file="data/out-val_esp_x_alfa=80.dat")
    open(unit=142, file="data/out-val_esp_x_alfa=90.dat")

    ! Formatos
    9999 format('====================================================&
                    =============================')
    9998 format('----------------------------------------------------&
                    -----------------------------')
    9997 format(2x, "N", 8x, "W0",  13x, "W1",  13x, "W2",  13x, "W3",  13x,&
                             "W4",  13x, "W5",  13x, "W6",  13x, "W7",  13x,&
                             "W8",  13x, "W9",  13x, "W10", 13x, "W11", 13x,&
                             "W12", 13x, "W13", 13x, "W14", 13x, "W15", 13x,&
                             "W16", 13x, "W17", 13x, "W18", 13x, "W19", 13x,&
                             "W20")
    9996 format(2x, "i", 6x,"c_i(Phi_0)", 5x,"c_i(Phi_2)", 5x,"c_i(Phi_4)",&
                         5x,"c_i(Phi_6)", 5x,"c_i(Phi_8)", 5x,"c_i(Phi_10)")
    9995 format(2x, "i", 6x,"c_i(Phi_1)", 5x,"c_i(Phi_3)", 5x,"c_i(Phi_5)",&
                         5x,"c_i(Phi_7)", 5x,"c_i(Phi_9)")
    9994 format(2x, "n", 3x, "N_conv", 2x, "W_n(conv.)", 5x, "W_n(max.)")

    ! Bucle principal:
    ! Para cada valor de d
    !   Para N funciones base
    !       Crea y escribe la matriz H
    !       Halla los valores y vectores propios
    !       Escribe los resultados
    allocate(E_arr(Nmax,Nmax))

    ! Calculo de la masa reducida
    call masa_reducida(mH, mN, m)
    ! write(*,*) 'mu =', m

    ! Calcula el valor de alpha optimizado para la perturbacion d
    call alpha_opt(xe, Vb, alpha)
    ! write(*,*) 'alfa =', alpha
    write(14,'(3x, "mu (a.m.)", 17x, "alpha (a0^{-2})", 11x, "alpha (A^{-2})")')
    write(14,*) m, alpha, alpha/RBOHR**2

    ! Escribe la primera fila de las tablas
    ! - Fichero 2 -
    write(2,9999)
    write(2,9998)
    write(2,'(2x, "N", 8x, "W0", 13x, "W1", 13x, "W2", 13x, "W3", 13x,&
                "W4", 13x, "W5", 13x, "W6", 13x, "W7")')
    ! - Fichero 3 -
    write(3,9999)
    write(3,9998)
    write(3,9994)
    write(3,9998)
    ! - Fichero 4 -
    write(4,9999)
    write(4,9998)
    ! - Ficheros 12 y 13 -
    write(12,9994)
    write(13,9994)
    ! - Fichero 30 -
    write(30,9998)
    write(30,'(6x, "x (a0)", 12x, "V(x) (Ha)")')
    write(31,9998)
    write(31,'(6x, "x (A)", 12x, "V(x) (cm-1)")')
    ! - Fichero 40 -
    write(40,9998)
    write(40,'(6x, "x (a0)", 11x, "Phi0(x)", 8x, "Phi2(x)", 8x, "Phi4(x)")')
    write(44,9998)
    write(44,'(6x, "x (A)", 11x, "Phi0(x)", 8x, "Phi2(x)", 8x, "Phi4(x)")')
    ! - Fichero 41 -
    write(41,9998)
    write(41,'(6x, "x (a0)", 11x, "|Phi0|^2", 7x, "|Phi2|^2", 7x, "|Phi4|^2")')
    write(45,9998)
    write(45,'(6x, "x (A)", 11x, "|Phi0|^2", 7x, "|Phi2|^2", 7x, "|Phi4|^2")')
    ! - Fichero 42 -
    write(42,9998)
    write(42,'(6x, "x (a0)", 11x, "Phi1(x)", 8x, "Phi3(x)", 8x, "Phi5(x)")')
    write(46,9998)
    write(46,'(6x, "x (A)", 11x, "Phi1(x)", 8x, "Phi3(x)", 8x, "Phi5(x)")')
    ! - Fichero 43 -
    write(43,9998)
    write(43,'(6x, "x (a0)", 11x, "|Phi1|^2", 7x, "|Phi3|^2", 7x, "|Phi5|^2")')
    write(47,9998)
    write(47,'(6x, "x (A)", 11x, "|Phi1|^2", 7x, "|Phi3|^2", 7x, "|Phi5|^2")')
    ! - Fichero 50, 51, 52, 53 -
    do i=50, 53, 1
        write(i,9999)
    end do
    write(50,'(5x, "psi = 1/dsqrt(2) Phi_0 + 1/dsqrt(2) Phi_1")')
    write(51,'(5x, "psi = 1/dsqrt(2) Phi_0 - 1/dsqrt(2) Phi_1")')
    write(52,'(5x, "psi = 1/dsqrt(2) Phi_2 + 1/dsqrt(2) Phi_3")')
    write(53,'(5x, "psi = 1/dsqrt(2) Phi_2 - 1/dsqrt(2) Phi_3")')
    write(54,'(5x, "psi = 1/dsqrt(2) Phi_0 + 1/dsqrt(2) Phi_1")')
    write(55,'(5x, "psi = 1/dsqrt(2) Phi_0 - 1/dsqrt(2) Phi_1")')
    write(56,'(5x, "psi = 1/dsqrt(2) Phi_2 + 1/dsqrt(2) Phi_3")')
    write(57,'(5x, "psi = 1/dsqrt(2) Phi_2 - 1/dsqrt(2) Phi_3")')
    !
    do i=50, 53, 1
        write(i,9998)
        write(i,'(8x,"E (Ha)",8x,"x (a0)",11x,"psi(x)",8x,"|psi(x)|^2")')
    end do
    do i=54, 57, 1
        write(i,9998)
        write(i,'(5x, "E (cm-1)",6x,"x (A)",9x,"psi(x)",8x,"|psi(x)|^2")')
    end do

    do i=90, 102, 1
        write(i,9999)
        write(i,'("Psi = cos(alfa)/dsqrt(2)*(Phi0 + Phi1) + &
                  sen(alfa)/dsqrt(2)*(Phi2 + Phi3)")')
        write(i,9998)
        write(i,'("alfa",6x,"E (cm-1)",6x,"x (A)",9x,"psi(x)",&
                  8x,"|psi(x)|^2")')
    end do

    ! Bucle para crear array x y potencial
    steps_x = int((xmax - xmin)/dx)

    allocate(x_vec(steps_x), x_vec_angstrom(steps_x), V_vec(steps_x))
    allocate(Phi0_vec(steps_x), Phi1_vec(steps_x), Phi2_vec(steps_x), &
             Phi3_vec(steps_x), Phi4_vec(steps_x), Phi5_vec(steps_x))
    allocate(dPhi0_vec(steps_x), dPhi1_vec(steps_x), dPhi2_vec(steps_x), &
             dPhi3_vec(steps_x), dPhi4_vec(steps_x), dPhi5_vec(steps_x))
    allocate(Phi0_vec_A(steps_x), Phi1_vec_A(steps_x), Phi2_vec_A(steps_x), &
             Phi3_vec_A(steps_x), Phi4_vec_A(steps_x), Phi5_vec_A(steps_x))
    allocate(dPhi0_vec_A(steps_x), dPhi1_vec_A(steps_x), dPhi2_vec_A(steps_x),&
             dPhi3_vec_A(steps_x), dPhi4_vec_A(steps_x), dPhi5_vec_A(steps_x))
    allocate(psi1_vec(steps_x), psi2_vec(steps_x), psi3_vec(steps_x), &
             psi4_vec(steps_x))
    allocate(dpsi1_vec(steps_x), dpsi2_vec(steps_x), dpsi3_vec(steps_x), &
             dpsi4_vec(steps_x))
    allocate(psi1_vec_A(steps_x), psi2_vec_A(steps_x), psi3_vec_A(steps_x), &
             psi4_vec_A(steps_x))
    allocate(dpsi1_vec_A(steps_x), dpsi2_vec_A(steps_x), dpsi3_vec_A(steps_x),&
             dpsi4_vec_A(steps_x))
    allocate(psi_4EE_vec_A(steps_x), dpsi_4EE_vec_A(steps_x))

    do i=1, steps_x+1, 1
        x = xmin + (dx * float(i-1))
        x_vec(i) = x
        x_vec_angstrom(i) = x*RBOHR
        V_vec(i) = V(xe,Vb,x)
        ! Escribe los resultados en angstrom y cm-1
        write(30,'(f10.3, 10000f15.5)') x_vec(i), V_vec(i)
        write(31,'(f10.3, 10000f15.5)') x_vec_angstrom(i), V_vec(i)*EUACM
    end do

    ! Halla los resultados para cada valor de N
    j_arr = 0 ! Variable auxiliar
    do_N: do N=2, Nmax, 1
        ! Da dimensiones al array de energias variacionales
        allocate(E(N))
        ! y del array 'work' para la subrutina de diagonalizacion
        allocate(work(3*N))

        ! Numero de funciones base pares e impares
        Nimpar = N/2
        Npar = N - Nimpar

        ! ------------
        ! MATRIZ PAR
        ! ------------

        ! Da dimensiones a la matriz par del hamiltoniano
        allocate(H_par(Npar,Npar))
        ! y de valores propios
        allocate(E_par(Npar))

        ! Crear la matriz del hamiltoniano par
        H_par(:,:) = 0.0
        do_filas_par: do i=1, Npar, 1
            do_columnas_par: do j=1, Npar, 1
                ! Calcula los elementos de la matriz y almacenalos
                H_par(i,j) = H(2*(i-1),2*(j-1),xe,Vb,alpha)
            end do do_columnas_par
        end do do_filas_par
        ! Rutina para calcular los valores propios
        lwork = 3*N
        call dsyev ( 'V', 'U', Npar, H_par, Npar, E_par,&
                     work, lwork, info )
        ! Los valores propios de la energia son guardados en E
        ! Los vectores propios, los coeficientes de la combinacion lineal,
        ! son guardados en la matriz H_mat a la salida
        ! Cada columna de la matriz H_mat, a la salida, da un eigenvector
        ! H_mat(j,i)
        !   j = indice de la funcion base
        !   i = indice del valor propio

        ! Si la diagonalizacion ha funcionado, info = 0
        if (info/= 0) then
            write(*,*) 'La diagonalizacion de la matriz H_par ha fallado'
            write(*,*) 'INFO =', info
            stop
        end if

        ! Escribe el array E
        do i=1, Npar, 1
            ! Ordena los valores pares en las posiciones impares
            E(2*i - 1) = E_par(i) + Vb
        end do

        ! Escribe los coeficientes variacionales de las funciones pares
        if (N==Nmax) then
            write(20,9996)
            do j=1, Npar, 1
            write(20,'(i3.1,100f15.5)') 2*(j-1),(H_par(j,i),i=1,3)
            end do
         end if

        if (N==Nmax) then
            do i=1, steps_x+1, 1
                x = x_vec(i)
                x_angstrom = x_vec_angstrom(i)
                Phi0 = 0.0
                Phi2 = 0.0
                Phi4 = 0.0
                Phi0_A = 0.0
                Phi2_A = 0.0
                Phi4_A = 0.0
                do j=1, Npar, 1
                    ! Para agilizar el calculo, impongo la condicion de que
                    ! los coeficientes de la combinacion c<0.001 no
                    ! contribuyan a la combinacion
                    if (abs(H_par(j,1))>0.001) Phi0=Phi0+(-H_par(j,1))*&
                                                    phi(2*(j-1),alpha,x)
                    if (abs(H_par(j,2))>0.001) Phi2=Phi2+(H_par(j,2))*&
                                                    phi(2*(j-1),alpha,x)
                    if (abs(H_par(j,3))>0.001) Phi4=Phi4+(H_par(j,3))*&
                                                    phi(2*(j-1),alpha,x)
                    !
                    if (abs(H_par(j,1))>0.001) Phi0_A=Phi0_A+(-H_par(j,1))*&
                                         phi(2*(j-1),alpha/RBOHR**2,x_angstrom)
                    if (abs(H_par(j,2))>0.001) Phi2_A=Phi2_A+(H_par(j,2))*&
                                         phi(2*(j-1),alpha/RBOHR**2,x_angstrom)
                    if (abs(H_par(j,3))>0.001) Phi4_A=Phi4_A+(H_par(j,3))*&
                                         phi(2*(j-1),alpha/RBOHR**2,x_angstrom)
                end do
                Phi0_vec(i) = Phi0
                Phi2_vec(i) = Phi2
                Phi4_vec(i) = Phi4
                dPhi0_vec(i) = Phi0**2
                dPhi2_vec(i) = Phi2**2
                dPhi4_vec(i) = Phi4**2
                !
                Phi0_vec_A(i) = Phi0_A
                Phi2_vec_A(i) = Phi2_A
                Phi4_vec_A(i) = Phi4_A
                dPhi0_vec_A(i) = (Phi0_A**2)
                dPhi2_vec_A(i) = (Phi2_A**2)
                dPhi4_vec_A(i) = (Phi4_A**2)
                write(40,'(f10.3, 10000f15.5)') x, Phi0_vec(i), &
                                                   Phi2_vec(i), &
                                                   Phi4_vec(i)
                write(41,'(f10.3, 10000f15.5)') x, dPhi0_vec(i), &
                                                   dPhi2_vec(i), &
                                                   dPhi4_vec(i)
                write(44,'(f10.3, 10000f15.5)') x_angstrom,&
                                                Phi0_vec_A(i), &
                                                Phi2_vec_A(i), &
                                                Phi4_vec_A(i)
                write(45,'(f10.3, 10000f15.5)') x_angstrom,&
                                                dPhi0_vec_A(i), &
                                                dPhi2_vec_A(i), &
                                                dPhi4_vec_A(i)
            end do
        end if

        ! Borra la matriz
        deallocate(E_par)

        ! ------------
        ! MATRIZ IMPAR
        ! ------------

        ! Da dimensiones a la matriz impar del hamiltoniano
        allocate(H_impar(Nimpar,Nimpar))
        ! y de valores propios
        allocate(E_impar(Nimpar))

        ! Crear la matriz del hamiltoniano impar
        H_impar(:,:) = 0.0
        do_filas_impar: do i=1, Nimpar, 1
            do_columnas_impar: do j=1, Nimpar, 1
                ! Calcula los elementos de la matriz y almacenalos
                H_impar(i,j) = H(2*i-1,2*j-1,xe,Vb,alpha)
            end do do_columnas_impar
        end do do_filas_impar
        ! Rutina para calcular los valores propios
        lwork = 3*N
        call dsyev ( 'V', 'U', Nimpar, H_impar, Nimpar, E_impar,&
                     work, lwork, info )

        ! Los valores propios de la energia son guardados en E
        ! Los vectores propios, los coeficientes de la combinacion lineal,
        ! son guardados en la matriz H_mat a la salida
        ! Cada columna de la matriz H_mat, a la salida, da un eigenvector
        ! H_mat(j,i)
        !   j = indice de la funcion base
        !   i = indice del valor propio

        ! Si la diagonalizacion ha funcionado, info = 0
        if (info/= 0) then
            write(*,*) 'La diagonalizacion de la matriz H_impar ha fallado'
            write(*,*) 'INFO =', info
            stop
        end if

        ! Escribe el array E
        do i=1, Nimpar, 1
            ! Ordena los valores impares en las posiciones impares
            E(2*i) = E_impar(i) + Vb
        end do

        ! Escribe los coeficientes variacionales de las funciones impares
        if (N==Nmax) then
            write(21,9995)
            do j=1, Nimpar, 1
                write(21,'(i3.1,100f15.5)') 2*j-1, (H_impar(j,i),i=1,3)
            end do
        end if
        !
        ! --- Creacion array de E_n para N=Nmax ---
        !
        if (N==Nmax) then
            allocate(E_Nmax(Nmax), E_Nmax_cm(Nmax))
            do i = 1, Nmax
                E_Nmax(i) = E(i)                ! En unidades atomicas
                E_Nmax_cm(i) = E(i) * EUACM     ! En cm-1
            end do
        end if
        !
        ! --- Creacion de la matriz de coeficientes de las combinaciones ---
        !
        if (N==Nmax) then
            allocate(c_k(N,N))
            ! Inicializacion de la matriz
            do i = 1, N
                do j = 1, i
                    c_k(i,j) = 0.d0
                end do
            end do
            ! Escritura de la matriz
            do j = 1, Npar
                ! Cambia el signo de los coeficientes de Phi_0
                if (j==1) then
                    do i = 1, Npar
                        c_k(2*i-1,2*j-1) = -H_par(i,j)
                    end do
                else
                    do i = 1, Npar
                        c_k(2*i-1,2*j-1) = H_par(i,j)
                    end do
                end if
            end do
            do j = 1, Nimpar
                ! Cambia el signo de los coeficientes de Phi_1 y Phi_3
                if (j==1.or.j==2) then
                    do i = 1, Nimpar
                        c_k(2*i,2*j) = -H_impar(i,j)
                    end do
                else
                    do i = 1, Nimpar
                        c_k(2*i,2*j) = H_impar(i,j)
                    end do
                end if
            end do
        end if
        !
        if (N==Nmax) then
            do i=1, steps_x+1, 1
                x = x_vec(i)
                x_angstrom = x_vec_angstrom(i)
                Phi1 = 0.0
                Phi3 = 0.0
                Phi5 = 0.0
                Phi1_A = 0.0
                Phi3_A = 0.0
                Phi5_A = 0.0
                do j=1, Nimpar, 1
                    ! Para agilizar el calculo, impongo la condicion de que
                    ! los coeficientes de la combinacion c<0.001 no
                    ! contribuyan a la combinacion
                    if (abs(H_impar(j,1))>0.001) Phi1=Phi1+(-H_impar(j,1))*&
                                                      phi(2*j-1,alpha,x)
                    if (abs(H_impar(j,2))>0.001) Phi3=Phi3+(-H_impar(j,2))*&
                                                      phi(2*j-1,alpha,x)
                    if (abs(H_impar(j,3))>0.001) Phi5=Phi5+(H_impar(j,3))*&
                                                      phi(2*j-1,alpha,x)
                    if (abs(H_impar(j,1))>0.001) Phi1_A=Phi1_A+&
                                                        (-H_impar(j,1))*&
                                           phi(2*j-1,alpha/RBOHR**2,x_angstrom)
                    if (abs(H_impar(j,2))>0.001) Phi3_A=Phi3_A+&
                                                        (-H_impar(j,2))*&
                                           phi(2*j-1,alpha/RBOHR**2,x_angstrom)
                    if (abs(H_impar(j,3))>0.001) Phi5_A=Phi5_A+&
                                                        (H_impar(j,3))*&
                                           phi(2*j-1,alpha/RBOHR**2,x_angstrom)
                end do
                Phi1_vec(i) = Phi1
                Phi3_vec(i) = Phi3
                Phi5_vec(i) = Phi5
                dPhi1_vec(i) = Phi1**2
                dPhi3_vec(i) = Phi3**2
                dPhi5_vec(i) = Phi5**2
                Phi1_vec_A(i) = Phi1_A
                Phi3_vec_A(i) = Phi3_A
                Phi5_vec_A(i) = Phi5_A
                dPhi1_vec_A(i) = Phi1_A**2
                dPhi3_vec_A(i) = Phi3_A**2
                dPhi5_vec_A(i) = Phi5_A**2
                write(42,'(f10.3, 10000f15.5)') x, Phi1_vec(i), &
                                                   Phi3_vec(i), &
                                                   Phi5_vec(i)
                write(43,'(f10.3, 10000f15.5)') x, dPhi1_vec(i), &
                                                   dPhi3_vec(i), &
                                                   dPhi5_vec(i)
                write(46,'(f10.3, 10000f15.5)') x_angstrom,&
                                                Phi1_vec_A(i), &
                                                Phi3_vec_A(i), &
                                                Phi5_vec_A(i)
                write(47,'(f10.3, 10000f15.5)') x_angstrom,&
                                                dPhi1_vec_A(i), &
                                                dPhi3_vec_A(i), &
                                                dPhi5_vec_A(i)
            end do
        end if
        !
        if (N==Nmax) then
            n_func_comb = 2
            allocate(c_psi1(n_func_comb), c_psi2(n_func_comb))
            c_psi1(1) = 1.d0/dsqrt(2.d0)
            c_psi1(2) = 1.d0/dsqrt(2.d0)
            c_psi2(1) = 1.d0/dsqrt(2.d0)
            c_psi2(2) = 1.d0/dsqrt(2.d0)
            E_psi1 = abs(c_psi1(1))**2*E(1) + abs(c_psi1(2))**2*E(2)
            E_psi3 = abs(c_psi2(1))**2*E(3) + abs(c_psi2(2))**2*E(4)
            E_psi1_cm = E_psi1 * EUACM
            E_psi3_cm = E_psi3 * EUACM
            do i=1, steps_x+1, 1
                x = x_vec(i)
                x_angstrom = x_vec_angstrom(i)
                !
                psi1_vec(i) = c_psi1(1)*Phi0_vec(i) + c_psi1(2)*Phi1_vec(i)
                psi2_vec(i) = c_psi1(1)*Phi0_vec(i) - c_psi1(2)*Phi1_vec(i)
                psi3_vec(i) = c_psi2(1)*Phi2_vec(i) + c_psi2(2)*Phi3_vec(i)
                psi4_vec(i) = c_psi2(1)*Phi2_vec(i) - c_psi2(2)*Phi3_vec(i)
                !
                dpsi1_vec(i) = psi1_vec(i)**2
                dpsi2_vec(i) = psi2_vec(i)**2
                dpsi3_vec(i) = psi3_vec(i)**2
                dpsi4_vec(i) = psi4_vec(i)**2
                !
                psi1_vec_A(i) = c_psi1(1)*Phi0_vec_A(i) +&
                                c_psi1(2)*Phi1_vec_A(i)
                psi2_vec_A(i) = c_psi1(1)*Phi0_vec_A(i) -&
                                c_psi1(2)*Phi1_vec_A(i)
                psi3_vec_A(i) = c_psi2(1)*Phi2_vec_A(i) +&
                                c_psi2(2)*Phi3_vec_A(i)
                psi4_vec_A(i) = c_psi2(1)*Phi2_vec_A(i) -&
                                c_psi2(2)*Phi3_vec_A(i)
                !
                dpsi1_vec_A(i) = psi1_vec_A(i)**2
                dpsi2_vec_A(i) = psi2_vec_A(i)**2
                dpsi3_vec_A(i) = psi3_vec_A(i)**2
                dpsi4_vec_A(i) = psi4_vec_A(i)**2
                !
                write(50,'(f15.5, f10.3, 10000f15.5)') E_psi1, x,&
                                                   psi1_vec(i), &
                                                  dpsi1_vec(i)
                write(51,'(f15.5, f10.3, 10000f15.5)') E_psi1, x,&
                                                    psi2_vec(i), &
                                                   dpsi2_vec(i)
                write(52,'(f15.5, f10.3, 10000f15.5)') E_psi3, x,&
                                                    psi3_vec(i), &
                                                   dpsi3_vec(i)
                write(53,'(f15.5, f10.3, 10000f15.5)') E_psi3, x,&
                                                    psi4_vec(i), &
                                                   dpsi4_vec(i)
                write(54,'(f15.5, f10.3, 10000f15.5)') E_psi1_cm, x_angstrom,&
                                                   psi1_vec_A(i), &
                                                  dpsi1_vec_A(i)
                write(55,'(f15.5, f10.3, 10000f15.5)') E_psi1_cm, x_angstrom,&
                                                    psi2_vec_A(i), &
                                                   dpsi2_vec_A(i)
                write(56,'(f15.5, f10.3, 10000f15.5)') E_psi3_cm, x_angstrom,&
                                                    psi3_vec_A(i), &
                                                   dpsi3_vec_A(i)
                write(57,'(f15.5, f10.3, 10000f15.5)') E_psi3_cm, x_angstrom,&
                                                    psi4_vec_A(i), &
                                                   dpsi4_vec_A(i)
            end do
        end if

        if (N==Nmax) then
            ! --- Calculo del tiempo de recurrencia ---
            write(70,'("Psi", 26x, "tr (ps)")')
            ! Primera combinacion lineal:
            ! Psi = (Phi0 +- Phi1)/dsqrt(2)
            E0 = E(1)*EHAJ   ! Energia del nivel v=0 en J
            E1 = E(2)*EHAJ   ! Energia del nivel v=1 en J
            call tiempo_recurrencia(E0, E1, HP, tr)
            write(70,'("(Phi0+-Phi1)/dsqrt(2)", 2x, f15.5)') tr*1.D12 !tr en ps
            !
            ! Segunda combinacion lineal:
            ! Psi = (Phi2 +- Phi3)/dsqrt(2)
            E0 = E(3)*EHAJ   ! Energia del nivel v=0 en J
            E1 = E(4)*EHAJ   ! Energia del nivel v=1 en J
            call tiempo_recurrencia(E0, E1, HP, tr)
            write(70,'("(Phi2+-Phi3)/dsqrt(2)", 2x, f15.5)') tr*1.D12 !tr en ps
            !
            ! --- Calculo la probabilidad de supervivencia ---
            !
            ! --- Primer paquete de ondas ---
            ! Psi = (Phi0 +- Phi1)/dsqrt(2)
            allocate(E_wp(n_func_comb))
            E_wp(1) = E(1)   ! Energia del nivel v=0 en Ha
            E_wp(2) = E(2)   ! Energia del nivel v=1 en Ha
            t0 = 0.d0
            dt = 0.1d0
            tf = 100.d0
            steps_t = int((tf - t0)/dt)
            allocate(t_vec(steps_t))
            write(80,'("t (ps)", 5x, "Ps(t)")')
            do i=1, steps_t+1, 1
                t = t0 + (dt * dble(i-1))
                t_vec(i) = t
                ! El tiempo es convertido a picosegundos por la subrutina
                call probabilidad_supervivencia(c_psi1,E_wp,t,EHAJ,HP,pi,Ps)
                write(80,'(f6.2, f15.5)') t, Ps
            end do
            deallocate(t_vec, E_wp)

            ! --- Segundo paquete de ondas ---
            ! Psi = (Phi2 +- Phi3)/dsqrt(2)
            allocate(E_wp(n_func_comb))
            E_wp(1) = E(3)   ! Energia del nivel v=0 en Ha
            E_wp(2) = E(4)   ! Energia del nivel v=1 en Ha
            t0 = 0.d0
            dt = 0.01d0
            tf = 1.d0
            steps_t = int((tf - t0)/dt)
            allocate(t_vec(steps_t))
            write(81,'("t (ps)", 5x, "Ps(t)")')
            do i=1, steps_t+1, 1
                t = t0 + (dt * dble(i-1))
                t_vec(i) = t
                ! El tiempo es convertido a picosegundos por la subrutina
                call probabilidad_supervivencia(c_psi2,E_wp,t,EHAJ,HP,pi,Ps)
                write(81,'(f6.2, f15.5)') t, Ps
            end do
            deallocate(t_vec, E_wp)
            deallocate(c_psi1, c_psi2)
        end if

        ! ==========================================
        ! --- Paquete de 4 estados estacionarios ---
        ! ==========================================
        ! Psi = a0*Phi0 + a1*Phi1 + a2*Phi2 + a3*Phi3
        ! a0 = a1 = 1/dsqrt(2) * cos(alfa)
        ! a2 = a3 = 1/dsqrt(2) * sen(alfa)
        ! Casos limites:
        ! si alfa = 0  -> Psi = Psi1 = a0*Phi0 + a1*Phi1
        ! si alfa = 90 -> Psi = Psi2 = a2*Phi2 + a3*Phi3
        if (N==Nmax) then
            ! Calcula la matriz posicion en la base armonica
            call matriz_posicion(N, alpha/RBOHR**2, mat_x_arm)
            ! Numero de funciones de estados estacionarios a usar en el paquete
            n_func_comb = 4
            allocate(E_wp(n_func_comb))
            E_wp(1) = E(1)   ! Energia del nivel v=0 en Ha
            E_wp(2) = E(2)   ! Energia del nivel v=1 en Ha
            E_wp(3) = E(3)   ! Energia del nivel v=2 en Ha
            E_wp(4) = E(4)   ! Energia del nivel v=3 en Ha
            ! Valores de alfa = 0,10,15,20,30,40,45,50,60,70,75,80 y 90
            allocate(array_alfa_4EE(13))
            array_alfa_4EE(1)  = 0.d0
            array_alfa_4EE(2)  = 10.d0
            array_alfa_4EE(3)  = 15.d0
            array_alfa_4EE(4)  = 20.d0
            array_alfa_4EE(5)  = 30.d0
            array_alfa_4EE(6)  = 40.d0
            array_alfa_4EE(7)  = 45.d0
            array_alfa_4EE(8)  = 50.d0
            array_alfa_4EE(9)  = 60.d0
            array_alfa_4EE(10) = 70.d0
            array_alfa_4EE(11) = 75.d0
            array_alfa_4EE(12) = 80.d0
            array_alfa_4EE(13) = 90.d0
            ! Calculo de los paquetes para cada alfa
            write(82,9999)
            write(82,'(2x, "alfa", 6x, "E (cm-1)", 8x, "Puntos de corte (A)")')
            write(82,9998)
            do j=1, size(array_alfa_4EE)
                alfa_4EE = array_alfa_4EE(j)
                ! Coeficientes de la combinacion
                c_psi_4EE(1) = 1.d0/dsqrt(2.d0) * cos(alfa_4EE*PI/180.d0)
                c_psi_4EE(2) = 1.d0/dsqrt(2.d0) * cos(alfa_4EE*PI/180.d0)
                c_psi_4EE(3) = 1.d0/dsqrt(2.d0) * sin(alfa_4EE*PI/180.d0)
                c_psi_4EE(4) = 1.d0/dsqrt(2.d0) * sin(alfa_4EE*PI/180.d0)
                ! Energia del paquete
                E_4EE = abs(c_psi_4EE(1))**2 * E(1) +&
                        abs(c_psi_4EE(2))**2 * E(2) +&
                        abs(c_psi_4EE(3))**2 * E(3) +&
                        abs(c_psi_4EE(4))**2 * E(4)
                ! Conversion de energia de UA -> cm-1
                E_4EE_cm = E_4EE * EUACM
                ! Calculo de los puntos de corte
                call puntos_corte(E_4EE_cm, Vb_cm, xe_A, x1, x2, x3, x4)
                write(82,'(f6.1, 100f15.5)') alfa_4EE, E_4EE_cm, x1, x2, x3, x4
                ! Calculo de los paquetes
                do i=1, steps_x+1, 1
                    x_angstrom = x_vec_angstrom(i)

                    psi_4EE_vec_A(i) = c_psi_4EE(1)*Phi0_vec_A(i) +&
                                       c_psi_4EE(2)*Phi1_vec_A(i) +&
                                       c_psi_4EE(3)*Phi2_vec_A(i) +&
                                       c_psi_4EE(4)*Phi3_vec_A(i)
                    dpsi_4EE_vec_A(i) = psi_4EE_vec_A(i)**2

                    ! Escribe los resultados
                    write(89+j,'(f4.1, f15.5, f10.3, 2f15.5)') &
                          alfa_4EE, E_4EE_cm, x_angstrom,&
                          psi_4EE_vec_A(i), dpsi_4EE_vec_A(i)
                end do
                !
                ! --- Calculo de la probabilidad de supervivencia y
                !     valor esperado de la posicion ---
                !
                t0 = 0.d0
                tf = 50.d0
                dt = 5.d-3
                steps_t = int((tf - t0)/dt)
                allocate(t_vec(steps_t))
                write(109+j,9999)
                write(109+j,'("---"," alfa =", f5.1, " ---")') alfa_4EE
                write(109+j,9998)
                write(109+j,'("t (ps)", 5x, "Ps(t)")')
                write(129+j,9999)
                write(129+j,'("---"," alfa =", f5.1, " ---")') alfa_4EE
                write(129+j,9998)
                write(129+j,'(2x, "t (ps)", 7x, "<x>t (A)")')
                do i=1, steps_t+1, 1
                    t = t0 + (dt * dble(i-1))
                    t_vec(i) = t
                    ! El tiempo es convertido a picosegundos por la subrutina
                    call probabilidad_supervivencia(c_psi_4EE, E_wp, t, &
                                                    EHAJ, HP, pi, Ps)
                    write(109+j,'(f8.4, f15.5)') t, Ps
                    ! Calculo del valor esperado de x
                    call valor_esperado_x(N, c_psi_4EE, E_wp, t, c_k, &
                                         mat_x_arm, EHAJ, HP, pi,&
                                         val_esp_x)
                    write(129+j,'(f8.4, f15.5)') t, val_esp_x
                end do
                deallocate(t_vec)
            end do
            deallocate(E_wp)
        end if

        ! borra las matrices
        deallocate(H_par)
        deallocate(H_impar)
        deallocate(E_impar)
        deallocate(work)

        ! Escribe las 7 primeras energias variacionales cuando N>=8
        jj = N  ! Variable auxiliar
        if (jj<=8) then
            write(2,' (i3.1, 100f15.5)') N, ( E(i), i=1,N ), &
                                         ( j*0., j=1,8-jj )
        else
            write(2,' (i3.1, 100f15.5)') N, ( E(i), i=1,8 )
        end if

        ! Array auxiliar (E_arr) que almacena cada valor de Wn(N) para un
        ! numero de funciones base N dado, de manera que
        !           W0(N1)  W1(N1)  ..
        ! E_arr =   W0(N2)  W1(N2)  ..
        !            :       :
        ! Uso este array para controlar el numero de funciones base para
        ! la convergencia de cada nivel
        j_arr = j_arr + 1
        do i=1, N, 1
            E_arr(j_arr, i) = E(i)
        end do

        ! Borra la ultima matriz
        deallocate(E)
    end do do_N

    ! Escribe el array E_arr
    do i=1, Nmax-1, 1
        write(4,'(1000f15.5)') ( E_arr(i,j), j=1, Nmax )
    end do

    ! Bucle para encontrar el numero de funciones base de convergencia
    do j=1, 6
        do i=1, Nmax, 1
            ! E_sup = E_arr(i+5,1) ! Cambiar limite del DO de Nmax a Nmax-5
            E_sup = E_arr(Nmax-1,j)
            E_inf = E_arr(i,j)
            Delta_E = E_inf - E_sup
            if (abs(Delta_E)<=0.000001) then
                N_conver = i + 1
                E_conver = E_inf
                exit
            end if
        end do
        if (N_conver<Nmax) then
            write(3,'(i3.1, f15.5, i5.2)') j-1, E_conver, N_conver
        else
            write(3,'(i3.1, f15.5, "Aumentar Nmax")') j-1, E_conver
        end if
        ! Escribo los ficheros 7, 8, 9, 10
        if (j==1) then
            write(7,'(2x,"n =",i3.1,2x,"Nconverg. =",i3.1)') j, N_conver
            write(7, '(2x, "N", 8x, "W0")')
        elseif (j==2) then
            write(8,'(2x,"n =",i3.1,2x,"Nconverg. =",i3.1)') j, N_conver
            write(8, '(2x, "N", 8x, "W1")')
        elseif (j==3) then
            write(9,'(2x,"n =",i3.1,2x,"Nconverg. =",i3.1)') j, N_conver
            write(9, '(2x, "N", 8x, "W2")')
        elseif (j==4) then
            write(10,'(2x,"n =",i3.1,2x,"Nconverg. =",i3.1)') j, N_conver
            write(10, '(2x, "N", 8x, "W3")')
        end if
    end do

    ! Escribe n, W_n y Ncon. para los n=21 primeros niveles
    do j=1, 21, 1
        do i=1, Nmax, 1
            ! E_sup = E_arr(i+5,1) ! Cambiar limite del DO de Nmax a Nmax-5
            E_sup = E_arr(Nmax-1,j)
            E_inf = E_arr(i,j)
            Delta_E = E_inf - E_sup
            if (abs(Delta_E)<0.00001) then
                N_conver = i + 1
                E_conver = E_inf
                E_conver_cm = E_conver*EUACM
                exit
            end if
        end do
        if (N_conver<Nmax) then
            write(12,'(i3.1, i5.2, 2f15.5)') j-1, N_conver, E_conver, E_Nmax(j)
            write(13,'(i3.1, i5.2, 2f15.5)') j-1, N_conver, E_conver_cm,&
                                                                   E_Nmax_cm(j)
        else
            write(12,'(i3.1, "Aumentar Nmax", 2f15.5 )') j-1, E_conver
            write(13,'(i3.1, "Aumentar Nmax", 2f15.5 )') j-1, E_conver_cm
        end if
    end do

    ! Escribe los valores de W0, W1, W2 y W3 en sus ficheros para N pares.
    ! Para N impares, cambiar el bucle DO.
    do N=2, Nmax, 2
        write(7,'  (i3.1, 100f15.5)') N, E_arr(N-1,1)*EUACM
        write(8,'  (i3.1, 100f15.5)') N, E_arr(N-1,2)*EUACM
        if (N>=3) then
            write(9,'  (i3.1, 100f15.5)') N, E_arr(N-1,3)*EUACM
        end if
        if (N>=4) then
            write(10,' (i3.1, 100f15.5)') N, E_arr(N-1,4)*EUACM
        end if
    end do

    ! Ficheros de E vs N
    write(11,9997)
    do i=1, Nmax-1, 2
        write(11,'(i3.1, 1000f15.5)') i+1, ( E_arr(i,j), j=1, 21 )
    end do

    deallocate(E_arr)

    ! Cierra todos los ficheros
    close(2)
    close(3)
    close(4)
    do i=7, 142, 1
        close(i)
    end do

    write(*,*) 'El programa ha finalizado'

    stop
endprogram doble_pozo_NH3
