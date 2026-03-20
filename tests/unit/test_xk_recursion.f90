! =============================================================================
! Unit test: compute_xk_matrix
! Tests the master X^(k) recursion in the hamiltonian module against
! analytic formulas for k=0,2,4 and selection-rule / symmetry checks for
! k=1,3.
! =============================================================================
program test_xk_recursion
    use constants, only: dp
    use hamiltonian, only: compute_xk_matrix, quadratic_integral, quartic_integral
    implicit none

    ! ---------------------------------------------------------------------------
    ! Parameters
    ! ---------------------------------------------------------------------------
    integer,  parameter :: N    = 10
    real(dp), parameter :: ALPHA = 1.0_dp
    real(dp), parameter :: TOL   = 1.0e-12_dp

    ! ---------------------------------------------------------------------------
    ! Local variables
    ! ---------------------------------------------------------------------------
    real(dp), allocatable :: Xk(:,:)
    real(dp)              :: ref, diff, maxdiff
    integer               :: m, n_q, n_fail
    logical               :: ok

    n_fail = 0

    ! ==========================================================================
    ! Test 1: k=0 — identity matrix
    ! ==========================================================================
    call compute_xk_matrix(0, N, ALPHA, Xk)

    ok = .true.
    do m = 0, N-1
        do n_q = 0, N-1
            if (m == n_q) then
                if (abs(Xk(m, n_q) - 1.0_dp) > TOL) ok = .false.
            else
                if (abs(Xk(m, n_q)) > TOL) ok = .false.
            end if
        end do
    end do

    if (ok) then
        write(*,'(A)') 'PASS: k=0 yields identity matrix'
    else
        write(*,'(A)') 'FAIL: k=0 does not yield identity matrix'
        n_fail = n_fail + 1
    end if
    deallocate(Xk)

    ! ==========================================================================
    ! Test 2: k=2 — matches quadratic_integral element-by-element
    ! ==========================================================================
    call compute_xk_matrix(2, N, ALPHA, Xk)

    ok      = .true.
    maxdiff = 0.0_dp
    do m = 0, N-1
        do n_q = 0, N-1
            ref  = quadratic_integral(m, n_q, ALPHA)
            diff = abs(Xk(m, n_q) - ref)
            if (diff > maxdiff) maxdiff = diff
            if (diff > TOL) ok = .false.
        end do
    end do

    if (ok) then
        write(*,'(A,ES10.3,A)') 'PASS: k=2 matches quadratic_integral (max diff = ', &
                                  maxdiff, ')'
    else
        write(*,'(A,ES10.3,A)') 'FAIL: k=2 deviates from quadratic_integral (max diff = ', &
                                  maxdiff, ')'
        n_fail = n_fail + 1
    end if
    deallocate(Xk)

    ! ==========================================================================
    ! Test 3: k=4 — matches quartic_integral element-by-element
    ! ==========================================================================
    call compute_xk_matrix(4, N, ALPHA, Xk)

    ok      = .true.
    maxdiff = 0.0_dp
    do m = 0, N-1
        do n_q = 0, N-1
            ref  = quartic_integral(m, n_q, ALPHA)
            diff = abs(Xk(m, n_q) - ref)
            if (diff > maxdiff) maxdiff = diff
            if (diff > TOL) ok = .false.
        end do
    end do

    if (ok) then
        write(*,'(A,ES10.3,A)') 'PASS: k=4 matches quartic_integral (max diff = ', &
                                  maxdiff, ')'
    else
        write(*,'(A,ES10.3,A)') 'FAIL: k=4 deviates from quartic_integral (max diff = ', &
                                  maxdiff, ')'
        n_fail = n_fail + 1
    end if
    deallocate(Xk)

    ! ==========================================================================
    ! Test 4: selection rule k=1
    !   * Elements with |m-n| > 1 must be zero.
    !   * Elements with (m-n) not odd must be zero (parity selection rule).
    !   * Elements with |m-n| = 1 must be nonzero.
    ! ==========================================================================
    call compute_xk_matrix(1, N, ALPHA, Xk)

    ok = .true.
    do m = 0, N-1
        do n_q = 0, N-1
            if (abs(m - n_q) > 1 .or. mod(abs(m - n_q), 2) /= 1) then
                ! Must be zero
                if (abs(Xk(m, n_q)) > TOL) then
                    ok = .false.
                end if
            else
                ! |m-n| == 1: must be nonzero
                if (abs(Xk(m, n_q)) <= TOL) then
                    ok = .false.
                end if
            end if
        end do
    end do

    if (ok) then
        write(*,'(A)') 'PASS: k=1 selection rule (|m-n|=1 nonzero, rest zero)'
    else
        write(*,'(A)') 'FAIL: k=1 selection rule violated'
        n_fail = n_fail + 1
    end if
    deallocate(Xk)

    ! ==========================================================================
    ! Test 5: selection rule k=3
    !   * Elements with |m-n| > 3 must be zero.
    ! ==========================================================================
    call compute_xk_matrix(3, N, ALPHA, Xk)

    ok = .true.
    do m = 0, N-1
        do n_q = 0, N-1
            if (abs(m - n_q) > 3) then
                if (abs(Xk(m, n_q)) > TOL) ok = .false.
            end if
        end do
    end do

    if (ok) then
        write(*,'(A)') 'PASS: k=3 selection rule (|m-n|>3 all zero)'
    else
        write(*,'(A)') 'FAIL: k=3 selection rule violated (nonzero element with |m-n|>3)'
        n_fail = n_fail + 1
    end if
    deallocate(Xk)

    ! ==========================================================================
    ! Test 6: symmetry X^(k)_{mn} = X^(k)_{nm} for k = 1,2,3,4
    ! ==========================================================================
    block
        integer :: kk
        do kk = 1, 4
            call compute_xk_matrix(kk, N, ALPHA, Xk)
            ok      = .true.
            maxdiff = 0.0_dp
            do m = 0, N-1
                do n_q = 0, N-1
                    diff = abs(Xk(m, n_q) - Xk(n_q, m))
                    if (diff > maxdiff) maxdiff = diff
                    if (diff > TOL) ok = .false.
                end do
            end do
            if (ok) then
                write(*,'(A,I1,A,ES10.3,A)') 'PASS: k=', kk, &
                    ' matrix is symmetric (max |Xk(m,n)-Xk(n,m)| = ', maxdiff, ')'
            else
                write(*,'(A,I1,A,ES10.3,A)') 'FAIL: k=', kk, &
                    ' matrix is NOT symmetric (max |Xk(m,n)-Xk(n,m)| = ', maxdiff, ')'
                n_fail = n_fail + 1
            end if
            deallocate(Xk)
        end do
    end block

    ! ==========================================================================
    ! Final result
    ! ==========================================================================
    if (n_fail > 0) then
        write(*,'(A)') 'RESULT: SOME TESTS FAILED'
        stop 1
    else
        write(*,'(A)') 'RESULT: ALL TESTS PASSED'
    end if

end program test_xk_recursion
