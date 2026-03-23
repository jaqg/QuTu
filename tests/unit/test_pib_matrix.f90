! =============================================================================
! Unit test: pib module
! Tests the PIB-FBR closed-form matrix elements against exact formulas and
! numerical quadrature (trapezoidal), and verifies basis function properties.
!
! Tests:
!   1.  Kinetic diagonal: T_nn = n^2*pi^2/(2*L^2)
!   2.  Kinetic off-diagonal: all zero
!   3.  k=0 orthonormality: I^(0)_mn = delta_mn
!   4.  Parity selection rule for k=1..4
!   5.  k=2 diagonal vs numerical quadrature
!   6.  k=4 diagonal vs numerical quadrature
!   7.  k=1 off-diagonal vs numerical quadrature
!   8.  k=2 off-diagonal vs numerical quadrature
!   9.  k=4 off-diagonal vs numerical quadrature
!  10.  Symmetry: I^(k)_mn = I^(k)_nm
!  11.  phi_pib normalization
!  12.  phi_pib parity: phi_n(-x) = (-1)^(n+1) * phi_n(x)
!  13.  build_hamiltonian_pib produces a symmetric H matrix
! =============================================================================
program test_pib_matrix
    use constants,  only: dp, PI
    use types,      only: system_params_t, init_system_params_pib
    use pib,        only: phi_pib, pib_kinetic_matrix, pib_xk_element, &
                          pib_potential_matrix, build_hamiltonian_pib
    implicit none

    ! -------------------------------------------------------------------------
    ! Parameters
    ! -------------------------------------------------------------------------
    integer,  parameter :: NBAS   = 12          ! basis size for matrix tests
    real(dp), parameter :: L      = 6.0_dp      ! box length
    real(dp), parameter :: TOL    = 1.0e-12_dp  ! tolerance for exact tests
    real(dp), parameter :: TOL_Q  = 1.0e-5_dp   ! tolerance for quadrature tests

    ! Quadrature grid
    real(dp), parameter :: DX     = 1.0e-5_dp   ! grid spacing for integration
    integer             :: NPTS                  ! number of grid points (computed)

    ! -------------------------------------------------------------------------
    ! Local variables
    ! -------------------------------------------------------------------------
    real(dp), allocatable :: T_mat(:,:), H_full(:,:)
    real(dp) :: ref, diff, maxdiff, ana, num
    real(dp) :: x, fval
    integer  :: im, jn, k, n_fail
    logical  :: ok

    type(system_params_t) :: params
    real(dp), allocatable :: v_test(:)

    n_fail = 0
    NPTS   = nint(L / DX) + 1

    ! ==========================================================================
    ! Test 1: Kinetic diagonal T_nn = n^2*pi^2/(2*L^2)
    ! ==========================================================================
    call pib_kinetic_matrix(NBAS, L, T_mat)

    ok = .true.
    do im = 1, NBAS
        ref  = real(im, dp)**2 * PI**2 / (2.0_dp * L**2)
        diff = abs(T_mat(im, im) - ref)
        if (diff > TOL) then
            ok = .false.
            write(*,'(A,I3,A,ES12.4)') 'FAIL detail T1 n=', im, ' diff=', diff
        end if
    end do
    if (ok) then
        write(*,'(A)') 'PASS: kinetic diagonal T_nn = n^2*pi^2/(2*L^2)'
    else
        write(*,'(A)') 'FAIL: kinetic diagonal formula'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 2: Kinetic off-diagonal all zero
    ! ==========================================================================
    ok = .true.
    do im = 1, NBAS
        do jn = 1, NBAS
            if (im /= jn) then
                if (abs(T_mat(im, jn)) > TOL) then
                    ok = .false.
                    write(*,'(A,2I3,A,ES12.4)') 'FAIL detail T2 (', im, jn, ') T=', T_mat(im,jn)
                end if
            end if
        end do
    end do
    if (ok) then
        write(*,'(A)') 'PASS: kinetic off-diagonal all zero'
    else
        write(*,'(A)') 'FAIL: kinetic off-diagonal not zero'
        n_fail = n_fail + 1
    end if

    deallocate(T_mat)

    ! ==========================================================================
    ! Test 3: k=0 orthonormality: I^(0)_mn = delta_mn
    ! ==========================================================================
    ok = .true.
    do im = 1, NBAS
        do jn = 1, NBAS
            ana = pib_xk_element(im, jn, 0, L)
            if (im == jn) then
                ref = 1.0_dp
            else
                ref = 0.0_dp
            end if
            if (abs(ana - ref) > TOL) then
                ok = .false.
                write(*,'(A,2I3,A,ES12.4)') 'FAIL detail T3 (', im, jn, ') I0=', ana
            end if
        end do
    end do
    if (ok) then
        write(*,'(A)') 'PASS: k=0 orthonormality I^(0)_mn = delta_mn'
    else
        write(*,'(A)') 'FAIL: k=0 orthonormality'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 4: Parity selection rule: I^(k)_mn = 0 when m+n+k is odd
    ! ==========================================================================
    ok = .true.
    do k = 1, 4
        do im = 1, NBAS
            do jn = 1, NBAS
                if (mod(im + jn + k, 2) /= 0) then
                    ana = pib_xk_element(im, jn, k, L)
                    if (abs(ana) > TOL) then
                        ok = .false.
                        write(*,'(A,3I3,A,ES12.4)') &
                            'FAIL detail T4 k=', k, ' (', im, jn, ') I=', ana
                    end if
                end if
            end do
        end do
    end do
    if (ok) then
        write(*,'(A)') 'PASS: parity selection rule I^(k)_mn=0 when m+n+k odd'
    else
        write(*,'(A)') 'FAIL: parity selection rule violated'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 5: k=2 diagonal vs numerical quadrature
    ! I^(2)_nn = L^2*(1/12 - 1/(2*n^2*pi^2))
    ! ==========================================================================
    ok = .true.
    maxdiff = 0.0_dp
    do im = 1, 6
        ana = pib_xk_element(im, im, 2, L)
        ! Numerical integration: integral_{-L/2}^{L/2} phi_n(x)^2 * x^2 dx
        num = 0.0_dp
        do jn = 0, NPTS - 1
            x = -L/2.0_dp + real(jn, dp) * DX
            fval = phi_pib(im, L, x)**2 * x**2
            if (jn == 0 .or. jn == NPTS-1) then
                num = num + 0.5_dp * fval * DX
            else
                num = num + fval * DX
            end if
        end do
        diff = abs(ana - num)
        if (diff > maxdiff) maxdiff = diff
        if (diff > TOL_Q) then
            ok = .false.
            write(*,'(A,I3,A,ES12.4,A,ES12.4,A,ES12.4)') &
                'FAIL detail T5 n=', im, ' ana=', ana, ' num=', num, ' diff=', diff
        end if
    end do
    if (ok) then
        write(*,'(A,ES10.3,A)') 'PASS: k=2 diagonal vs quadrature (max diff=', maxdiff, ')'
    else
        write(*,'(A)') 'FAIL: k=2 diagonal formula'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 6: k=4 diagonal vs numerical quadrature
    ! I^(4)_nn = L^4*(1/80 - 1/(4*n^2*pi^2) + 3/(n^4*pi^4))
    ! ==========================================================================
    ok = .true.
    maxdiff = 0.0_dp
    do im = 1, 6
        ana = pib_xk_element(im, im, 4, L)
        num = 0.0_dp
        do jn = 0, NPTS - 1
            x = -L/2.0_dp + real(jn, dp) * DX
            fval = phi_pib(im, L, x)**2 * x**4
            if (jn == 0 .or. jn == NPTS-1) then
                num = num + 0.5_dp * fval * DX
            else
                num = num + fval * DX
            end if
        end do
        diff = abs(ana - num)
        if (diff > maxdiff) maxdiff = diff
        if (diff > TOL_Q) then
            ok = .false.
            write(*,'(A,I3,A,ES12.4,A,ES12.4,A,ES12.4)') &
                'FAIL detail T6 n=', im, ' ana=', ana, ' num=', num, ' diff=', diff
        end if
    end do
    if (ok) then
        write(*,'(A,ES10.3,A)') 'PASS: k=4 diagonal vs quadrature (max diff=', maxdiff, ')'
    else
        write(*,'(A)') 'FAIL: k=4 diagonal formula'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 7: k=1 off-diagonal vs numerical quadrature
    ! Test pairs (m+n odd): (1,2), (3,2), (5,4)
    ! ==========================================================================
    ok = .true.
    maxdiff = 0.0_dp
    call check_offdiag_quad(1, 2, 1, ok, maxdiff)
    call check_offdiag_quad(3, 2, 1, ok, maxdiff)
    call check_offdiag_quad(5, 4, 1, ok, maxdiff)
    if (ok) then
        write(*,'(A,ES10.3,A)') 'PASS: k=1 off-diagonal vs quadrature (max diff=', maxdiff, ')'
    else
        write(*,'(A)') 'FAIL: k=1 off-diagonal formula'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 8: k=2 off-diagonal vs numerical quadrature
    ! Test pairs (m+n even, m!=n): (1,3), (2,4), (1,5)
    ! ==========================================================================
    ok = .true.
    maxdiff = 0.0_dp
    call check_offdiag_quad(1, 3, 2, ok, maxdiff)
    call check_offdiag_quad(2, 4, 2, ok, maxdiff)
    call check_offdiag_quad(1, 5, 2, ok, maxdiff)
    if (ok) then
        write(*,'(A,ES10.3,A)') 'PASS: k=2 off-diagonal vs quadrature (max diff=', maxdiff, ')'
    else
        write(*,'(A)') 'FAIL: k=2 off-diagonal formula'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 9: k=4 off-diagonal vs numerical quadrature
    ! Test pairs (m+n even, m!=n): (1,3), (2,4)
    ! ==========================================================================
    ok = .true.
    maxdiff = 0.0_dp
    call check_offdiag_quad(1, 3, 4, ok, maxdiff)
    call check_offdiag_quad(2, 4, 4, ok, maxdiff)
    if (ok) then
        write(*,'(A,ES10.3,A)') 'PASS: k=4 off-diagonal vs quadrature (max diff=', maxdiff, ')'
    else
        write(*,'(A)') 'FAIL: k=4 off-diagonal formula'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 10: Symmetry I^(k)_mn = I^(k)_nm
    ! ==========================================================================
    ok = .true.
    maxdiff = 0.0_dp
    do k = 1, 4
        do im = 1, 8
            do jn = 1, 8
                diff = abs(pib_xk_element(im, jn, k, L) &
                           - pib_xk_element(jn, im, k, L))
                if (diff > maxdiff) maxdiff = diff
                if (diff > TOL) then
                    ok = .false.
                    write(*,'(A,3I3,A,ES12.4)') &
                        'FAIL detail T10 k=', k, ' (', im, jn, ') asym=', diff
                end if
            end do
        end do
    end do
    if (ok) then
        write(*,'(A,ES10.3,A)') 'PASS: symmetry I^(k)_mn = I^(k)_nm (max asym=', maxdiff, ')'
    else
        write(*,'(A)') 'FAIL: matrix is not symmetric'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 11: phi_pib normalization integral_{-L/2}^{L/2} phi_n^2 dx = 1
    ! ==========================================================================
    ok = .true.
    maxdiff = 0.0_dp
    do im = 1, 6
        num = 0.0_dp
        do jn = 0, NPTS - 1
            x = -L/2.0_dp + real(jn, dp) * DX
            fval = phi_pib(im, L, x)**2
            if (jn == 0 .or. jn == NPTS-1) then
                num = num + 0.5_dp * fval * DX
            else
                num = num + fval * DX
            end if
        end do
        diff = abs(num - 1.0_dp)
        if (diff > maxdiff) maxdiff = diff
        if (diff > TOL_Q) then
            ok = .false.
            write(*,'(A,I3,A,ES12.4)') 'FAIL detail T11 n=', im, ' norm=', num
        end if
    end do
    if (ok) then
        write(*,'(A,ES10.3,A)') 'PASS: phi_pib normalization (max |norm-1|=', maxdiff, ')'
    else
        write(*,'(A)') 'FAIL: phi_pib normalization'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 12: phi_pib parity: phi_n(-x) = (-1)^(n+1) * phi_n(x)
    ! ==========================================================================
    ok = .true.
    do im = 1, 6
        do jn = 1, 10
            x = L / 4.0_dp * real(jn, dp) / 10.0_dp   ! x in (0, L/4)
            ref  = real((-1)**(im+1), dp) * phi_pib(im, L, x)
            diff = abs(phi_pib(im, L, -x) - ref)
            if (diff > TOL) then
                ok = .false.
                write(*,'(A,I3,A,ES12.4,A,ES12.4)') &
                    'FAIL detail T12 n=', im, ' x=', x, ' diff=', diff
            end if
        end do
    end do
    if (ok) then
        write(*,'(A)') 'PASS: phi_pib parity phi_n(-x) = (-1)^(n+1)*phi_n(x)'
    else
        write(*,'(A)') 'FAIL: phi_pib parity'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 13: build_hamiltonian_pib produces a symmetric matrix
    ! Use a simple test potential: V(x) = 0.01*x + 0.5*x^2 + 0.01*x^4
    ! ==========================================================================
    allocate(v_test(0:4))
    v_test = [0.0_dp, 0.01_dp, 0.5_dp, 0.0_dp, 0.01_dp]
    call init_system_params_pib(params, 6, 1.0_dp, v_test(0:4)+0.0_dp, L)

    ! init_system_params_pib expects v_coeffs(:) — pass as 1:5 array
    deallocate(v_test)
    allocate(v_test(5))
    v_test = [0.0_dp, 0.01_dp, 0.5_dp, 0.0_dp, 0.01_dp]
    call init_system_params_pib(params, 6, 1.0_dp, v_test, L)
    deallocate(v_test)

    call build_hamiltonian_pib(params, H_full)

    ok = .true.
    maxdiff = 0.0_dp
    do im = 1, params%N
        do jn = 1, params%N
            diff = abs(H_full(im, jn) - H_full(jn, im))
            if (diff > maxdiff) maxdiff = diff
            if (diff > TOL) then
                ok = .false.
                write(*,'(A,2I3,A,ES12.4)') 'FAIL detail T13 (', im, jn, ') asym=', diff
            end if
        end do
    end do
    deallocate(H_full)

    if (ok) then
        write(*,'(A,ES10.3,A)') 'PASS: H from build_hamiltonian_pib is symmetric (max asym=', maxdiff, ')'
    else
        write(*,'(A)') 'FAIL: H is not symmetric'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Summary
    ! ==========================================================================
    write(*,*)
    if (n_fail == 0) then
        write(*,'(A)') 'All PIB unit tests PASSED'
        stop 0
    else
        write(*,'(I0,A)') n_fail, ' PIB unit test(s) FAILED'
        stop 1
    end if

contains

    ! -------------------------------------------------------------------------
    ! Helper: compare pib_xk_element(m,n,k,L) vs numerical quadrature
    ! Updates ok (sets to .false. on failure) and maxdiff.
    ! -------------------------------------------------------------------------
    subroutine check_offdiag_quad(m_in, n_in, k_in, ok_flag, mxdiff)
        integer,  intent(in)    :: m_in, n_in, k_in
        logical,  intent(inout) :: ok_flag
        real(dp), intent(inout) :: mxdiff

        real(dp) :: ana_val, num_val, df, x_loc, fv
        integer  :: jj

        ana_val = pib_xk_element(m_in, n_in, k_in, L)

        ! Numerical: integral_{-L/2}^{L/2} phi_m(x) * x^k * phi_n(x) dx
        num_val = 0.0_dp
        do jj = 0, NPTS - 1
            x_loc = -L/2.0_dp + real(jj, dp) * DX
            fv    = phi_pib(m_in, L, x_loc) * (x_loc**k_in) * phi_pib(n_in, L, x_loc)
            if (jj == 0 .or. jj == NPTS-1) then
                num_val = num_val + 0.5_dp * fv * DX
            else
                num_val = num_val + fv * DX
            end if
        end do

        df = abs(ana_val - num_val)
        if (df > mxdiff) mxdiff = df
        if (df > TOL_Q) then
            ok_flag = .false.
            write(*,'(A,I2,A,2I3,A,ES12.4,A,ES12.4,A,ES12.4)') &
                'FAIL detail k=', k_in, ' (', m_in, n_in, &
                ') ana=', ana_val, ' num=', num_val, ' diff=', df
        end if
    end subroutine check_offdiag_quad

end program test_pib_matrix
