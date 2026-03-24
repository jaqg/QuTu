# TODO List - QuTu Quantum Tunneling Simulation

## Completed in `dev/generalization-potential`

- [x] Add support for general polynomial potential V(x) = Σ vₖ xᵏ
- [x] Auto-detect parity symmetry from polynomial coefficients
- [x] Implement master recursion for ⟨m|xᵏ|n⟩ in HO basis
- [x] Assemble polynomial Hamiltonian using recursion
- [x] Build full N×N Hamiltonian for asymmetric/general case
- [x] Three-tier mass input (direct / XYn formula / legacy NH3)
- [x] Conditional INPUT parsing and validation per mode
- [x] Conditional output (parity labels only for symmetric)
- [x] New examples: PH3 inversion (E1), asymmetric double-well (E2)
- [x] Updated INPUT_GUIDE.md with polynomial mode documentation
- [x] Unit tests: xk recursion, parity detection, input parser
- [x] Validation tests: NH3 regression, polynomial equivalence, harmonic limit, asymmetric
- [x] Integration tests: full pipeline symmetric and asymmetric

## Completed in `dev/PIB-implementation`

- [x] PIB-FBR basis functions φₙ(x) on box [-L/2, L/2] (cosine for odd n, sine for even n)
- [x] Exact diagonal kinetic matrix T_mn = n²π²/(2L²) δ_mn (no quadrature)
- [x] Closed-form potential matrix elements I^(k)_mn for k = 0,1,2,3,4 (parity selection rule)
- [x] `src/modules/pib.f90`: phi_pib, pib_kinetic_matrix, pib_xk_element, pib_potential_matrix, build_hamiltonian_pib
- [x] `basis = PIB` key in INPUT; `box_length` auto-derived from xmax−xmin if not given
- [x] Dispatch in `qutu.f90`: init, Hamiltonian build, wavefunction evaluation, section output
- [x] Unit tests (test_pib_matrix.f90): 13 tests — orthonormality, parity selection rule, k=0..4 vs quadrature, symmetry, normalization
- [x] Integration test (test_full_run_pib.sh): full PIB pipeline
- [x] Validation test (test_pib_vs_ho.sh): HO vs PIB agree to < 0.01 cm⁻¹ (N=80)
- [x] Example 03: INPUT_HO, INPUT_PIB, run.sh comparison script
- [x] Theory: docs/theory/latex/sections/05b_PIB_basis.tex (with corrected k=2,4 formulas)

## Future Enhancements

- [ ] Switch LAPACK solver to banded `DSBEV` (O(K·N²) vs O(N³))
- [ ] HO center x₀ at barrier top for asymmetric potentials (currently fixed at 0)
- [ ] Brent root-finding auto-locate potential minima for optimal-α computation
- [ ] Analytical alpha estimate for general polynomial degree > 4
- [ ] Section 9 (four-state wavepacket) for polynomial asymmetric mode
- [ ] Section 10 (expansion coefficients) for polynomial mode
- [ ] CI/CD: automate regression and validation test suite
- [ ] Asymmetric tunneling splitting output (Δ = sqrt((E1-E0)² - ε²))

## Input System - Future Enhancements

### Parameter Validation
- [ ] Validate N_max > 0 and even number
- [ ] Validate xe > 0 (equilibrium position must be positive)
- [ ] Validate Vb > 0 (barrier height must be positive)
- [ ] Validate xmin < xmax
- [ ] Validate dx > 0
- [ ] Validate mass_H > 0 and mass_N > 0
- [ ] Check for reasonable physical ranges (e.g., masses in amu range 1-300)
- [ ] Warn if grid parameters might cause numerical issues

### Additional Configurable Parameters
- [ ] Make output directory configurable (currently hard-coded)
- [ ] Make output filename prefix configurable
- [ ] Add option to control output verbosity level
- [ ] Add option to select which outputs to generate (energies, wavefunctions, densities, etc.)
- [ ] Make time evolution parameters configurable (if needed for wave packet dynamics)
- [ ] Consider making physical constants configurable vs hard-coded
- [ ] Add option for different potential types (beyond NH3 double-well)

## Code Quality

### Documentation
- [ ] Add inline documentation to new input_reader module
- [ ] Document INPUT file format in detail
- [ ] Create example INPUT files for different scenarios

### Testing
- [ ] Create test suite for input parser
- [ ] Validate that numerical results match previous implementation
- [ ] Test error handling for malformed INPUT files

---
*Created: 2026-01-20*
