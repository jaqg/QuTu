! =============================================================================
! Unit test: parity auto-detection in init_system_params_poly
! Checks that is_symmetric is set correctly for various v_coeffs arrays,
! exercising the SYMMETRY_THRESHOLD comparison for odd-k coefficients.
! =============================================================================
program test_parity_detection
    use constants, only: dp
    use types,     only: system_params_t, init_system_params_poly
    implicit none

    ! ---------------------------------------------------------------------------
    ! Local variables
    ! ---------------------------------------------------------------------------
    type(system_params_t) :: params
    integer               :: n_fail

    n_fail = 0

    ! ==========================================================================
    ! Test 1: v_coeffs = [0.008, 0.0, -0.031, 0.0, 0.030]
    !         All odd-index coefficients (v1=0, v3=0) → is_symmetric = .true.
    ! ==========================================================================
    call init_system_params_poly(params, N=10, mass_au=2000.0_dp, &
                                 v_coeffs=[0.008_dp, 0.0_dp, -0.031_dp, 0.0_dp, 0.030_dp], &
                                 alpha=1.0_dp)
    if (params%is_symmetric) then
        write(*,'(A)') 'PASS: Test 1 — all odd coeffs zero → is_symmetric=.true.'
    else
        write(*,'(A)') 'FAIL: Test 1 — all odd coeffs zero but is_symmetric=.false.'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 2: v_coeffs = [0.008, 0.01, -0.031, 0.0, 0.030]
    !         v1 = 0.01 /= 0 → is_symmetric = .false.
    ! ==========================================================================
    call init_system_params_poly(params, N=10, mass_au=2000.0_dp, &
                                 v_coeffs=[0.008_dp, 0.01_dp, -0.031_dp, 0.0_dp, 0.030_dp], &
                                 alpha=1.0_dp)
    if (.not. params%is_symmetric) then
        write(*,'(A)') 'PASS: Test 2 — v1=0.01 (odd, nonzero) → is_symmetric=.false.'
    else
        write(*,'(A)') 'FAIL: Test 2 — v1=0.01 should give is_symmetric=.false.'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 3: v_coeffs = [0.0, 0.0, 0.0, 0.001, 1.0]
    !         v3 = 0.001 /= 0 → is_symmetric = .false.
    ! ==========================================================================
    call init_system_params_poly(params, N=10, mass_au=2000.0_dp, &
                                 v_coeffs=[0.0_dp, 0.0_dp, 0.0_dp, 0.001_dp, 1.0_dp], &
                                 alpha=1.0_dp)
    if (.not. params%is_symmetric) then
        write(*,'(A)') 'PASS: Test 3 — v3=0.001 (odd, nonzero) → is_symmetric=.false.'
    else
        write(*,'(A)') 'FAIL: Test 3 — v3=0.001 should give is_symmetric=.false.'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 4: v_coeffs = [0.0, 1.0e-14, 0.0, 0.0, 1.0]
    !         v1 = 1e-14 < SYMMETRY_THRESHOLD (1e-12) → is_symmetric = .true.
    ! ==========================================================================
    call init_system_params_poly(params, N=10, mass_au=2000.0_dp, &
                                 v_coeffs=[0.0_dp, 1.0e-14_dp, 0.0_dp, 0.0_dp, 1.0_dp], &
                                 alpha=1.0_dp)
    if (params%is_symmetric) then
        write(*,'(A)') 'PASS: Test 4 — v1=1e-14 (below threshold) → is_symmetric=.true.'
    else
        write(*,'(A)') 'FAIL: Test 4 — v1=1e-14 below SYMMETRY_THRESHOLD should give is_symmetric=.true.'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Test 5: v_coeffs = [0.0, 0.0, 1.0]   (purely quadratic, degree=2)
    !         No odd-index coefficients above threshold → is_symmetric = .true.
    ! ==========================================================================
    call init_system_params_poly(params, N=10, mass_au=2000.0_dp, &
                                 v_coeffs=[0.0_dp, 0.0_dp, 1.0_dp], &
                                 alpha=1.0_dp)
    if (params%is_symmetric) then
        write(*,'(A)') 'PASS: Test 5 — purely quadratic (degree=2) → is_symmetric=.true.'
    else
        write(*,'(A)') 'FAIL: Test 5 — purely quadratic should give is_symmetric=.true.'
        n_fail = n_fail + 1
    end if

    ! ==========================================================================
    ! Final result
    ! ==========================================================================
    if (n_fail > 0) then
        write(*,'(A)') 'RESULT: SOME TESTS FAILED'
        stop 1
    else
        write(*,'(A)') 'RESULT: ALL TESTS PASSED'
    end if

end program test_parity_detection
