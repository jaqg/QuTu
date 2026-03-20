! =============================================================================
! Unit test: polynomial input parsing in read_input_file
! Writes temporary INPUT files, calls read_input_file, and checks the
! resulting input_params_t state and error code.
! =============================================================================
program test_input_parser
    use constants,    only: dp
    use input_reader, only: read_input_file, input_params_t
    implicit none

    ! ---------------------------------------------------------------------------
    ! Local variables
    ! ---------------------------------------------------------------------------
    type(input_params_t) :: params
    integer              :: ierr, u, n_fail

    n_fail = 0

    ! ==========================================================================
    ! Test 1: Polynomial mode — happy path
    !   poly_degree=4, v_coeffs with 5 entries, direct mass, grid params.
    !   Expected: use_polynomial=.true., poly_degree=4, size(v_poly)=5, ierr=0
    ! ==========================================================================
    open(newunit=u, file='test_input_tmp.dat', status='replace', action='write')
    write(u,'(A)') 'poly_degree=4'
    write(u,'(A)') 'v_coeffs=0.0,0.0,-0.03,0.0,0.01'
    write(u,'(A)') 'mass=1837.15'
    write(u,'(A)') 'N_max=50'
    write(u,'(A)') 'xmin=-5.0'
    write(u,'(A)') 'xmax=5.0'
    write(u,'(A)') 'dx=0.01'
    close(u)

    call read_input_file('test_input_tmp.dat', params, ierr)

    if (ierr == 0 .and. params%use_polynomial .and. &
        params%poly_degree == 4 .and. size(params%v_poly) == 5) then
        write(*,'(A)') 'PASS: Test 1 — polynomial mode detected correctly'
    else
        write(*,'(A)') 'FAIL: Test 1 — polynomial mode not detected correctly'
        write(*,'(A,L1,A,I0,A,I0,A,I0)') &
            '      use_polynomial=', params%use_polynomial, &
            '  poly_degree=', params%poly_degree, &
            '  size(v_poly)=', size(params%v_poly), &
            '  ierr=', ierr
        n_fail = n_fail + 1
    end if

    ! Clean up
    open(newunit=u, file='test_input_tmp.dat', status='old')
    close(u, status='delete')

    ! ==========================================================================
    ! Test 2: Missing v_coeffs — poly_degree present but v_coeffs absent.
    !   Expected: ierr /= 0
    ! ==========================================================================
    open(newunit=u, file='test_input_tmp.dat', status='replace', action='write')
    write(u,'(A)') 'poly_degree=4'
    write(u,'(A)') 'mass=1.0'
    write(u,'(A)') 'N_max=50'
    write(u,'(A)') 'xmin=-5.0'
    write(u,'(A)') 'xmax=5.0'
    write(u,'(A)') 'dx=0.01'
    close(u)

    call read_input_file('test_input_tmp.dat', params, ierr)

    if (ierr /= 0) then
        write(*,'(A)') 'PASS: Test 2 — missing v_coeffs correctly produces ierr /= 0'
    else
        write(*,'(A)') 'FAIL: Test 2 — missing v_coeffs should have produced ierr /= 0'
        n_fail = n_fail + 1
    end if

    ! Clean up
    open(newunit=u, file='test_input_tmp.dat', status='old')
    close(u, status='delete')

    ! ==========================================================================
    ! Test 3: Legacy mode — xe, Vb, mass_H, mass_N, grid params.
    !   Expected: use_polynomial=.false., ierr=0
    ! ==========================================================================
    open(newunit=u, file='test_input_tmp.dat', status='replace', action='write')
    write(u,'(A)') 'xe=0.718'
    write(u,'(A)') 'Vb=1770.0'
    write(u,'(A)') 'mass_H=1.008'
    write(u,'(A)') 'mass_N=14.003'
    write(u,'(A)') 'N_max=50'
    write(u,'(A)') 'xmin=-5.0'
    write(u,'(A)') 'xmax=5.0'
    write(u,'(A)') 'dx=0.01'
    close(u)

    call read_input_file('test_input_tmp.dat', params, ierr)

    if (ierr == 0 .and. .not. params%use_polynomial) then
        write(*,'(A)') 'PASS: Test 3 — legacy mode detected (use_polynomial=.false.)'
    else
        write(*,'(A)') 'FAIL: Test 3 — legacy mode not detected correctly'
        write(*,'(A,L1,A,I0)') &
            '      use_polynomial=', params%use_polynomial, '  ierr=', ierr
        n_fail = n_fail + 1
    end if

    ! Clean up
    open(newunit=u, file='test_input_tmp.dat', status='old')
    close(u, status='delete')

    ! ==========================================================================
    ! Test 4: XYn mass specification
    !   mass_central + mass_ligand + n_ligands present alongside poly mode.
    !   Expected: found_xyn_mass=.true., ierr=0
    ! ==========================================================================
    open(newunit=u, file='test_input_tmp.dat', status='replace', action='write')
    write(u,'(A)') 'poly_degree=4'
    write(u,'(A)') 'v_coeffs=0.0,0.0,-0.03,0.0,0.01'
    write(u,'(A)') 'mass_central=30.974'
    write(u,'(A)') 'mass_ligand=1.008'
    write(u,'(A)') 'n_ligands=3'
    write(u,'(A)') 'N_max=50'
    write(u,'(A)') 'xmin=-5.0'
    write(u,'(A)') 'xmax=5.0'
    write(u,'(A)') 'dx=0.01'
    close(u)

    call read_input_file('test_input_tmp.dat', params, ierr)

    if (ierr == 0 .and. params%found_xyn_mass) then
        write(*,'(A)') 'PASS: Test 4 — XYn mass fields accepted (found_xyn_mass=.true.)'
    else
        write(*,'(A)') 'FAIL: Test 4 — XYn mass fields not accepted correctly'
        write(*,'(A,L1,A,I0)') &
            '      found_xyn_mass=', params%found_xyn_mass, '  ierr=', ierr
        n_fail = n_fail + 1
    end if

    ! Clean up
    open(newunit=u, file='test_input_tmp.dat', status='old')
    close(u, status='delete')

    ! ==========================================================================
    ! Final result
    ! ==========================================================================
    if (n_fail > 0) then
        write(*,'(A)') 'RESULT: SOME TESTS FAILED'
        stop 1
    else
        write(*,'(A)') 'RESULT: ALL TESTS PASSED'
    end if

end program test_input_parser
