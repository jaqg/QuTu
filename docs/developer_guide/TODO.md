# TODO List - NH3 Quantum Tunneling Simulation

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
