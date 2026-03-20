# Generalization Plan: Arbitrary 1D Quantum Potentials

> **SUPERSEDED**: This document describes an earlier generalization plan (OOP factory
> pattern) that was not implemented. The adopted approach — a general polynomial
> potential V(x) = Σ vₖ xᵏ with master recursion for matrix elements — is
> documented in `generalization-potential.md` at the project root and implemented
> in branch `dev/generalization-potential`. This file is retained for historical
> reference only.

**Project**: QuTu - Quantum Tunneling Simulation
**Version**: 2.0 (Planned)
**Date**: 2026-01-20
**Status**: SUPERSEDED — see generalization-potential.md

---

## Executive Summary

This document presents a comprehensive plan to generalize the QuTu quantum tunneling simulation from NH3-specific calculations to supporting arbitrary one-dimensional quantum potentials. The generalization will transform QuTu from a specialized NH3 tool into a flexible quantum mechanics toolkit capable of solving the Schrödinger equation for various 1D systems while maintaining backward compatibility with existing NH3 workflows.

**Key Objectives**:
1. Support user-definable 1D potential energy functions
2. Provide a library of common quantum potentials
3. Maintain NH3 as a well-documented example case
4. Preserve computational performance
5. Ensure backward compatibility with existing INPUT files

**Recommended Approach**: Hybrid potential system combining a predefined potential library with extensibility for custom implementations.

**Implementation Timeline**: 4-6 weeks across 4 phases

---

## Table of Contents

1. [Current State Analysis](#1-current-state-analysis)
2. [Requirements](#2-requirements)
3. [Proposed Solution](#3-proposed-solution)
4. [Backward Compatibility](#4-backward-compatibility)
5. [Testing Strategy](#5-testing-strategy)
6. [Implementation Roadmap](#6-implementation-roadmap)
7. [Example Potentials](#7-example-potentials)
8. [Risk Assessment](#8-risk-assessment)
9. [Future Extensions](#9-future-extensions)
10. [Recommendations](#10-recommendations)

---

## 1. Current State Analysis

### 1.1 NH3-Specific Implementation

The current codebase is tightly coupled to the NH3 double-well potential:

**Potential Function** (in `hamiltonian.f90`):
```fortran
V(x) = (Vb/xe⁴)x⁴ - (2Vb/xe²)x² + Vb
```

**Parameters**:
- `xe` = 0.3816 Å (equilibrium position)
- `Vb` = 2028.6 cm⁻¹ (barrier height)
- `mass_H`, `mass_N` (atomic masses)

### 1.2 Limitations

**Hardcoded Elements**:
1. Potential function in `hamiltonian.f90`
2. Parameter names in `types.f90` and INPUT reader
3. NH3-specific naming in output files
4. Physical constants specific to NH3 system
5. Documentation references NH3 exclusively

**Flexibility Constraints**:
- Cannot easily switch to different potential forms
- Adding new potentials requires code modification
- No framework for user-defined potentials
- Testing limited to NH3 parameter space

### 1.3 Strengths to Preserve

- **Clean modular structure**: Well-separated concerns
- **Efficient numerics**: LAPACK integration
- **Comprehensive I/O**: Good file handling
- **Working NH3 example**: Validated against literature
- **Modern Fortran**: F2008 standard compliance

---

## 2. Requirements

### 2.1 Functional Requirements

**FR1**: Support multiple predefined potential types
- Harmonic oscillator
- Double-well (symmetric and asymmetric)
- Morse potential
- Pöschl-Teller potential
- Infinite square well
- User-extensible

**FR2**: Generic parameter system
- Variable number of potential-specific parameters
- Clear parameter naming and units
- Validation and bounds checking

**FR3**: Backward compatibility
- Existing NH3 INPUT files must work (with warnings if needed)
- NH3 results must remain unchanged
- Migration path for old configurations

**FR4**: Performance requirements
- No significant overhead for potential evaluation
- Maintain O(N³) scaling for matrix operations
- Memory usage comparable to current version

### 2.2 Non-Functional Requirements

**NFR1**: Maintainability
- Clean separation of potential definitions
- Well-documented interface
- Easy to add new potentials

**NFR2**: Usability
- Simple INPUT syntax for common cases
- Clear error messages
- Good documentation

**NFR3**: Testing
- Unit tests for each potential
- Validation against analytical solutions
- Regression tests for NH3

---

## 3. Proposed Solution

### 3.1 Potential Definition Strategy

**Recommendation**: **Hybrid Approach** combining predefined library with extensibility

#### 3.1.1 Architecture Overview

```
┌─────────────────────────────────────────────┐
│          Main Program (qutu.f90)            │
└─────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────┐
│      Potential Factory (potential.f90)      │
│  - Selects potential based on INPUT         │
│  - Initializes parameters                   │
│  - Provides unified interface               │
└─────────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
┌──────────────────┐    ┌──────────────────┐
│  Potential       │    │  Custom          │
│  Library         │    │  Potentials      │
│  (predefined)    │    │  (user-defined)  │
└──────────────────┘    └──────────────────┘
```

#### 3.1.2 Core Components

**1. Abstract Potential Interface** (`potential_base_type`)

```fortran
module potential_interface
    use constants
    implicit none

    type, abstract :: potential_base_type
        character(len=64) :: name
        integer :: num_params
        real(dp), allocatable :: params(:)
    contains
        procedure(evaluate_potential_i), deferred :: V
        procedure(evaluate_force_i), deferred :: dV_dx
        procedure(evaluate_curvature_i), deferred :: d2V_dx2
        procedure(initialize_i), deferred :: initialize
        procedure :: print_info
    end type potential_base_type

    abstract interface
        function evaluate_potential_i(this, x) result(V)
            import :: potential_base_type, dp
            class(potential_base_type), intent(in) :: this
            real(dp), intent(in) :: x
            real(dp) :: V
        end function evaluate_potential_i

        function evaluate_force_i(this, x) result(dV)
            import :: potential_base_type, dp
            class(potential_base_type), intent(in) :: this
            real(dp), intent(in) :: x
            real(dp) :: dV
        end function evaluate_force_i

        function evaluate_curvature_i(this, x) result(d2V)
            import :: potential_base_type, dp
            class(potential_base_type), intent(in) :: this
            real(dp), intent(in) :: x
            real(dp) :: d2V
        end function evaluate_curvature_i

        subroutine initialize_i(this, params)
            import :: potential_base_type, dp
            class(potential_base_type), intent(inout) :: this
            real(dp), intent(in) :: params(:)
        end subroutine initialize_i
    end interface

end module potential_interface
```

**2. Concrete Potential Implementations**

Each potential inherits from `potential_base_type`:

```fortran
module double_well_potential
    use potential_interface
    implicit none

    type, extends(potential_base_type) :: double_well_quartic_type
        real(dp) :: xe    ! Equilibrium position
        real(dp) :: Vb    ! Barrier height
    contains
        procedure :: V => double_well_V
        procedure :: dV_dx => double_well_dV
        procedure :: d2V_dx2 => double_well_d2V
        procedure :: initialize => double_well_init
    end type double_well_quartic_type

contains

    function double_well_V(this, x) result(V)
        class(double_well_quartic_type), intent(in) :: this
        real(dp), intent(in) :: x
        real(dp) :: V

        V = (this%Vb / this%xe**4) * x**4 &
          - (2.0_dp * this%Vb / this%xe**2) * x**2 &
          + this%Vb
    end function double_well_V

    ! ... dV_dx, d2V_dx2, initialize ...

end module double_well_potential
```

**3. Potential Factory**

```fortran
module potential_factory
    use potential_interface
    use double_well_potential
    use harmonic_potential
    use morse_potential
    ! ... other potentials ...

    implicit none

contains

    function create_potential(potential_type, params) result(pot)
        character(len=*), intent(in) :: potential_type
        real(dp), intent(in) :: params(:)
        class(potential_base_type), allocatable :: pot

        select case (trim(adjustl(potential_type)))
        case ('double_well_quartic', 'NH3')
            allocate(double_well_quartic_type :: pot)
        case ('harmonic')
            allocate(harmonic_type :: pot)
        case ('morse')
            allocate(morse_type :: pot)
        case ('poschl_teller')
            allocate(poschl_teller_type :: pot)
        case default
            error stop "Unknown potential type: " // trim(potential_type)
        end select

        call pot%initialize(params)

    end function create_potential

end module potential_factory
```

### 3.2 Parameter System Redesign

#### 3.2.1 New INPUT Format

**Proposed structure** (backward compatible):

```
# =============================================================================
# INPUT file for QuTu - Quantum Tunneling Simulation
# =============================================================================

# -----------------------------------------------------------------------------
# Basis Set Parameters
# -----------------------------------------------------------------------------
N_max = 200

# -----------------------------------------------------------------------------
# Potential Type Selection
# -----------------------------------------------------------------------------
# Options:
#   - double_well_quartic (symmetric quartic double-well)
#   - harmonic (harmonic oscillator)
#   - morse (Morse potential)
#   - poschl_teller (Pöschl-Teller potential)
#   - NH3 (alias for double_well_quartic with NH3 defaults)
potential_type = double_well_quartic

# -----------------------------------------------------------------------------
# Potential Parameters (depends on potential_type)
# -----------------------------------------------------------------------------
# For double_well_quartic:
#   xe = equilibrium position (Angstroms)
#   Vb = barrier height (cm^-1)
#
# For harmonic:
#   omega = angular frequency (cm^-1) OR k = force constant
#
# For morse:
#   De = well depth (cm^-1)
#   alpha = width parameter (1/Angstrom)
#   re = equilibrium distance (Angstroms)

[potential_params]
xe = 0.3816
Vb = 2028.6

# -----------------------------------------------------------------------------
# System Parameters
# -----------------------------------------------------------------------------
# For molecular systems: specify atomic masses
# For generic potentials: specify reduced mass directly

[masses]
mass_H = 1.00782503207  # amu
mass_N = 14.0030740048  # amu

# Alternative: specify reduced mass directly
# mass_reduced = 1.045  # amu

# -----------------------------------------------------------------------------
# Grid Parameters
# -----------------------------------------------------------------------------
xmin = -5.0
xmax = 5.0
dx = 0.02
```

#### 3.2.2 Backward Compatibility Mode

**Legacy NH3 format** (still supported):

```
N_max = 200
xe = 0.3816
Vb = 2028.6
mass_H = 1.00782503207
mass_N = 14.0030740048
xmin = -5.0
xmax = 5.0
dx = 0.02
```

**Detection logic**:
1. Check for `potential_type` parameter
2. If absent, check for NH3-specific parameters (`xe`, `Vb`)
3. If found, assume NH3 legacy mode
4. Issue deprecation warning but proceed

### 3.3 Code Changes Required

#### 3.3.1 New Modules

| Module | Purpose | Priority |
|--------|---------|----------|
| `potential_interface.f90` | Abstract base type | High |
| `potential_factory.f90` | Potential selection | High |
| `potential_double_well.f90` | Double-well implementation | High |
| `potential_harmonic.f90` | Harmonic oscillator | Medium |
| `potential_morse.f90` | Morse potential | Medium |
| `potential_poschl_teller.f90` | Pöschl-Teller | Low |

#### 3.3.2 Modified Modules

**`types.f90`**:
- Add `potential_params_t` type
- Generalize `system_params_t`
- Add potential type enumeration

**`input_reader.f90`**:
- Parse `potential_type` parameter
- Handle `[potential_params]` section
- Implement backward compatibility logic
- Validate potential-specific parameters

**`hamiltonian.f90`**:
- Replace hardcoded potential with polymorphic call
- Use `pot%V(x)` instead of direct formula
- Update matrix element calculations

**`io.f90`**:
- Generic output file naming
- Include potential type in output headers
- Write potential parameters to output

**`src/main/qutu.f90`**:
- Initialize potential via factory
- Pass potential object to relevant functions
- Update documentation strings

#### 3.3.3 Compilation Dependencies

**New dependency graph**:
```
constants.f90
    ↓
potential_interface.f90
    ↓
potential_*.f90 (concrete implementations)
    ↓
potential_factory.f90
    ↓
types.f90 (uses potential_interface)
    ↓
... rest of modules ...
```

---

## 4. Backward Compatibility

### 4.1 Compatibility Strategy

**Three-tier approach**:

1. **Full Compatibility** (Phase 1): Legacy INPUT files work unchanged
2. **Deprecation Warnings** (Phase 2): Warn users to update format
3. **Migration** (Phase 3): Provide conversion tool

### 4.2 Legacy Detection Algorithm

```fortran
subroutine detect_input_format(filename, format_type, ierr)
    character(len=*), intent(in) :: filename
    character(len=64), intent(out) :: format_type
    integer, intent(out) :: ierr

    logical :: has_potential_type
    logical :: has_NH3_params

    ! Check for new format markers
    call check_parameter_exists(filename, 'potential_type', has_potential_type)

    ! Check for legacy NH3 parameters
    call check_parameter_exists(filename, 'xe', has_NH3_params)

    if (has_potential_type) then
        format_type = 'new'
    else if (has_NH3_params) then
        format_type = 'legacy_NH3'
        write(*,'(A)') 'WARNING: Using legacy NH3 INPUT format'
        write(*,'(A)') '         Consider updating to new format'
        write(*,'(A)') '         See docs/user_guide/INPUT_GUIDE.md'
    else
        ierr = 1
        return
    end if

    ierr = 0
end subroutine detect_input_format
```

### 4.3 Migration Tool

**Script**: `scripts/migrate_input.py`

```python
#!/usr/bin/env python3
"""
Migrate legacy INPUT files to new format
"""

def migrate_NH3_input(old_file, new_file):
    """Convert NH3 legacy format to new format"""

    # Read old format
    params = parse_old_input(old_file)

    # Generate new format
    with open(new_file, 'w') as f:
        f.write("# Migrated from legacy NH3 format\n\n")
        f.write(f"N_max = {params['N_max']}\n\n")
        f.write("potential_type = double_well_quartic\n\n")
        f.write("[potential_params]\n")
        f.write(f"xe = {params['xe']}\n")
        f.write(f"Vb = {params['Vb']}\n\n")
        f.write("[masses]\n")
        f.write(f"mass_H = {params['mass_H']}\n")
        f.write(f"mass_N = {params['mass_N']}\n\n")
        # ... grid params ...

    print(f"✓ Migrated {old_file} → {new_file}")
```

### 4.4 Validation

**Regression test**: Ensure NH3 results are identical

```fortran
! In tests/validation/test_NH3_compatibility.f90
program test_NH3_compatibility
    ! Run NH3 with legacy INPUT
    ! Run NH3 with new INPUT
    ! Compare energies, wavefunctions
    ! Assert: max difference < 1e-10
end program test_NH3_compatibility
```

---

## 5. Testing Strategy

### 5.1 Unit Tests

**Module**: `tests/unit/test_potentials.f90`

**Tests for each potential**:
1. Initialization with valid parameters
2. Initialization with invalid parameters (should fail gracefully)
3. V(x) evaluation at specific points
4. dV/dx evaluation and numerical derivative comparison
5. d2V/dx2 evaluation
6. Symmetry properties (where applicable)
7. Asymptotic behavior

**Example**:
```fortran
subroutine test_double_well_potential()
    type(double_well_quartic_type) :: pot
    real(dp) :: params(2), V_at_zero, V_at_min

    ! Initialize
    params = [0.3816_dp, 2028.6_dp]  ! xe, Vb
    call pot%initialize(params)

    ! Test: V(0) = Vb
    V_at_zero = pot%V(0.0_dp)
    call assert_close(V_at_zero, 2028.6_dp, 1e-10_dp, "V(0) = Vb")

    ! Test: V(±xe) = 0 (minimum)
    V_at_min = pot%V(0.3816_dp)
    call assert_close(V_at_min, 0.0_dp, 1e-10_dp, "V(xe) = 0")

    ! Test: derivative at minimum is zero
    ! ... etc ...
end subroutine test_double_well_potential
```

### 5.2 Integration Tests

**Module**: `tests/integration/test_hamiltonian_construction.f90`

**Tests**:
1. Full Hamiltonian matrix construction with different potentials
2. Eigenvalue solving
3. Wavefunction normalization
4. Orthogonality of eigenstates

### 5.3 Validation Tests

**Module**: `tests/validation/test_analytical_solutions.f90`

**Compare with known solutions**:

| System | Test | Analytical Solution |
|--------|------|---------------------|
| Harmonic Oscillator | Energies | $E_n = \hbar\omega(n + 1/2)$ |
| Harmonic Oscillator | Wavefunctions | Hermite polynomials |
| Infinite Square Well | Energies | $E_n = \frac{n^2\pi^2\hbar^2}{2mL^2}$ |
| Morse Potential | Ground state | Known formula |

**Convergence tests**:
- Vary N_max and verify convergence
- Compare with literature values for NH3

**Example**:
```fortran
subroutine test_harmonic_oscillator()
    ! Set up harmonic potential
    ! Calculate eigenvalues
    ! Compare with analytical: E_n = ℏω(n + 1/2)
    ! Assert: relative error < 1e-6
end subroutine test_harmonic_oscillator
```

### 5.4 Performance Tests

**Benchmark**:
- Measure potential evaluation overhead
- Compare timing: old hardcoded vs. new polymorphic
- Target: < 5% slowdown

**Memory profiling**:
- Check for memory leaks
- Verify cleanup of allocated potential objects

---

## 6. Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

**Objective**: Establish infrastructure for generic potentials

**Tasks**:
1. Create `potential_interface.f90` with abstract base type
2. Implement `potential_double_well.f90` (NH3 equivalent)
3. Implement `potential_harmonic.f90` (for testing)
4. Create `potential_factory.f90`
5. Write unit tests for new modules
6. Update Makefile dependencies

**Deliverables**:
- [ ] `src/modules/potential_interface.f90`
- [ ] `src/modules/potential_double_well.f90`
- [ ] `src/modules/potential_harmonic.f90`
- [ ] `src/modules/potential_factory.f90`
- [ ] `tests/unit/test_potentials.f90`
- [ ] Updated Makefile

**Validation**: Unit tests pass

---

### Phase 2: Integration (Week 2-3)

**Objective**: Integrate potential system into main code

**Tasks**:
1. Modify `types.f90` to include potential object
2. Update `input_reader.f90` for new INPUT format
3. Implement backward compatibility detection
4. Modify `hamiltonian.f90` to use polymorphic potential
5. Update `io.f90` for generic output naming
6. Update main program (`qutu.f90`)
7. Write integration tests

**Deliverables**:
- [ ] Modified `types.f90`
- [ ] Modified `input_reader.f90`
- [ ] Modified `hamiltonian.f90`
- [ ] Modified `io.f90`
- [ ] Modified `qutu.f90`
- [ ] `tests/integration/test_hamiltonian.f90`
- [ ] Updated INPUT.template

**Validation**:
- Compilation successful
- Integration tests pass
- NH3 calculations still work

---

### Phase 3: Testing & Validation (Week 3-4)

**Objective**: Comprehensive testing and validation

**Tasks**:
1. Write validation tests (harmonic oscillator, square well)
2. Regression testing for NH3
3. Convergence studies
4. Performance benchmarking
5. Memory profiling
6. Bug fixes

**Deliverables**:
- [ ] `tests/validation/test_analytical_solutions.f90`
- [ ] `tests/validation/test_NH3_compatibility.f90`
- [ ] Performance report
- [ ] Bug fix commits

**Validation**:
- All tests pass
- NH3 results match original (< 1e-10 error)
- Performance within 5% of original

---

### Phase 4: Documentation & Examples (Week 4-6)

**Objective**: Complete documentation and examples

**Tasks**:
1. Update all documentation
2. Create examples for new potentials
   - `examples/02_harmonic_oscillator/`
   - `examples/03_morse_potential/`
3. Write INPUT_GUIDE.md section on potentials
4. Create TUTORIAL.md for adding custom potentials
5. Update README.md
6. Write migration guide
7. Create `scripts/migrate_input.py`

**Deliverables**:
- [ ] Updated `docs/user_guide/INPUT_GUIDE.md`
- [ ] New `docs/developer_guide/CUSTOM_POTENTIALS.md`
- [ ] `examples/02_harmonic_oscillator/`
- [ ] `examples/03_morse_potential/`
- [ ] Updated README.md
- [ ] `scripts/migrate_input.py`

**Validation**:
- Documentation complete and accurate
- Examples run successfully
- Migration script tested

---

## 7. Example Potentials

### 7.1 Initial Potential Library

**Priority 1** (Must have):

1. **Double-Well Quartic** (NH3-type)
   ```
   V(x) = (Vb/xe⁴)x⁴ - (2Vb/xe²)x² + Vb
   Parameters: xe, Vb
   ```

2. **Harmonic Oscillator**
   ```
   V(x) = ½kx² = ½mω²x²
   Parameters: k OR omega (with mass)
   ```

3. **Infinite Square Well**
   ```
   V(x) = 0 for |x| < a, ∞ otherwise
   Parameters: a (well width)
   ```

**Priority 2** (Should have):

4. **Morse Potential**
   ```
   V(x) = De(1 - e^(-α(x-re)))²
   Parameters: De, α, re
   Applications: Diatomic molecules
   ```

5. **Pöschl-Teller Potential**
   ```
   V(x) = -V0/cosh²(αx)
   Parameters: V0, α
   Applications: Solitons, quantum wells
   ```

6. **Generic Quartic Double-Well**
   ```
   V(x) = ax⁴ + bx² + c
   Parameters: a, b, c
   More flexible than NH3-specific form
   ```

**Priority 3** (Nice to have):

7. **Asymmetric Double-Well**
   ```
   V(x) = ax⁴ + bx³ + cx² + dx + e
   Parameters: a, b, c, d, e
   ```

8. **Finite Square Well**
   ```
   V(x) = 0 for |x| < a, V0 otherwise
   Parameters: a, V0
   ```

9. **Lennard-Jones Potential**
   ```
   V(x) = 4ε[(σ/x)¹² - (σ/x)⁶]
   Parameters: ε, σ
   ```

### 7.2 Implementation Template

**Template for adding new potential** (`potential_template.f90`):

```fortran
module potential_TEMPLATE
    use potential_interface
    implicit none

    type, extends(potential_base_type) :: TEMPLATE_type
        ! Potential-specific parameters
        real(dp) :: param1
        real(dp) :: param2
        ! ... additional params ...
    contains
        procedure :: V => TEMPLATE_V
        procedure :: dV_dx => TEMPLATE_dV
        procedure :: d2V_dx2 => TEMPLATE_d2V
        procedure :: initialize => TEMPLATE_init
    end type TEMPLATE_type

contains

    function TEMPLATE_V(this, x) result(V)
        class(TEMPLATE_type), intent(in) :: this
        real(dp), intent(in) :: x
        real(dp) :: V

        ! Implement V(x) here
        V = ...
    end function TEMPLATE_V

    function TEMPLATE_dV(this, x) result(dV)
        class(TEMPLATE_type), intent(in) :: this
        real(dp), intent(in) :: x
        real(dp) :: dV

        ! Implement dV/dx here
        ! Can use numerical derivative if analytical not available
        dV = ...
    end function TEMPLATE_dV

    function TEMPLATE_d2V(this, x) result(d2V)
        class(TEMPLATE_type), intent(in) :: this
        real(dp), intent(in) :: x
        real(dp) :: d2V

        ! Implement d²V/dx² here
        d2V = ...
    end function TEMPLATE_d2V

    subroutine TEMPLATE_init(this, params)
        class(TEMPLATE_type), intent(inout) :: this
        real(dp), intent(in) :: params(:)

        ! Validate number of parameters
        if (size(params) /= 2) then
            error stop "TEMPLATE potential requires 2 parameters"
        end if

        ! Assign parameters
        this%param1 = params(1)
        this%param2 = params(2)

        ! Validate parameter ranges
        if (this%param1 <= 0.0_dp) then
            error stop "param1 must be positive"
        end if

        this%name = 'TEMPLATE'
        this%num_params = 2
        allocate(this%params(2))
        this%params = params
    end subroutine TEMPLATE_init

end module potential_TEMPLATE
```

---

## 8. Risk Assessment

### 8.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Performance degradation from polymorphic calls | Medium | Low | Benchmark early; use inlining if needed |
| Fortran OOP complexity | Medium | Medium | Extensive testing; clear documentation |
| Backward compatibility breaks | High | Low | Comprehensive regression tests |
| Memory leaks in potential objects | Medium | Low | Memory profiling; careful cleanup |
| Numerical instability with new potentials | Medium | Medium | Validation tests against analytical solutions |

### 8.2 Project Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Scope creep (too many potentials) | Medium | High | Prioritize core potentials; Phase 2 for others |
| Insufficient testing | High | Medium | Require tests before merging new potentials |
| Documentation lag | Medium | High | Write docs alongside code |
| User confusion with new INPUT format | Medium | Medium | Clear migration guide; deprecation warnings |
| Development timeline overrun | Low | Medium | Phased approach; MVPfirst |

### 8.3 Mitigation Strategies

**Performance**:
- Benchmark potential evaluation overhead in Phase 1
- If > 5% slowdown, investigate compiler optimizations (`-flto`, inlining)
- Consider caching for expensive potentials

**Complexity**:
- Provide clear template for adding potentials
- Document OOP patterns used
- Code reviews for new potential implementations

**Testing**:
- Make tests mandatory for each new potential
- Automated testing in CI/CD (future)
- Validation against literature values

**User Adoption**:
- Maintain backward compatibility for 2-3 versions
- Provide migration script
- Clear warnings and helpful error messages

---

## 9. Future Extensions

### 9.1 Short-term (Version 2.x)

1. **Additional Potentials**: Expand library based on user requests
2. **Visualization**: Auto-plot potentials from INPUT parameters
3. **Potential Fitting**: Fit analytical form to numerical data
4. **Parameter Sweeps**: Automated exploration of parameter space

### 9.2 Medium-term (Version 3.x)

1. **2D Potentials**: Extend to two dimensions
2. **Time-dependent Potentials**: V(x,t)
3. **Multi-well Systems**: Generalize to N-well potentials
4. **Coupled Potentials**: Multiple degrees of freedom

### 9.3 Long-term (Version 4.x+)

1. **3D Potentials**: Full three-dimensional systems
2. **Spin-orbit Coupling**: Multi-component wavefunctions
3. **Many-body Systems**: Hartree-Fock, DFT integration
4. **GPU Acceleration**: For large-scale calculations

---

## 10. Recommendations

### 10.1 Implementation Priority

**Recommended Phased Approach**:

**Phase 1 (MVP)**:
- Double-well quartic (NH3)
- Harmonic oscillator
- Infrastructure (factory, interface)
- Backward compatibility

**Phase 2**:
- Morse potential
- Infinite square well
- Extended testing

**Phase 3**:
- Pöschl-Teller
- Generic quartic
- Additional examples

**Phase 4**:
- User requests
- Performance optimization
- Documentation completion

### 10.2 Best Practices

1. **Test-Driven Development**: Write tests before implementation
2. **Incremental Changes**: Small, reviewable commits
3. **Documentation-First**: Update docs with code
4. **Backward Compatibility**: Maintain for minimum 2 versions
5. **Code Review**: All potential implementations reviewed
6. **Benchmarking**: Performance tests for each addition

### 10.3 Decision Points

**Before proceeding, user should approve**:
- [ ] Proposed architecture (abstract interface + factory)
- [ ] New INPUT format
- [ ] Backward compatibility strategy
- [ ] Priority 1 potential list
- [ ] Implementation timeline

**After Phase 1, reassess**:
- Performance impact
- Developer experience adding potentials
- User feedback on new INPUT format

---

## Appendices

### Appendix A: Code Snippets

**A.1 Hamiltonian Module Integration**

```fortran
! Old (NH3-specific):
function potential_element_old(n, m, params) result(V_nm)
    integer, intent(in) :: n, m
    type(system_params_t), intent(in) :: params
    real(dp) :: V_nm

    ! Hardcoded NH3 potential
    V_nm = compute_x4_matrix(n, m, params) * (params%Vb / params%xe**4) &
         - compute_x2_matrix(n, m, params) * (2.0_dp * params%Vb / params%xe**2) &
         + params%Vb * delta(n, m)
end function potential_element_old

! New (generic):
function potential_element_new(n, m, pot, params) result(V_nm)
    integer, intent(in) :: n, m
    class(potential_base_type), intent(in) :: pot
    type(system_params_t), intent(in) :: params
    real(dp) :: V_nm

    ! Generic: integrate ⟨n|V(x)|m⟩
    V_nm = integrate_potential_element(n, m, pot, params)
end function potential_element_new

function integrate_potential_element(n, m, pot, params) result(V_nm)
    ! Numerical integration over grid
    ! Or analytical if basis functions allow
    integer, intent(in) :: n, m
    class(potential_base_type), intent(in) :: pot
    type(system_params_t), intent(in) :: params
    real(dp) :: V_nm

    real(dp) :: x, integrand, dx
    integer :: i

    V_nm = 0.0_dp
    dx = 0.01_dp  ! Integration step

    do i = 1, 1000
        x = -10.0_dp + i * dx
        integrand = phi_n(n, x, params) * pot%V(x) * phi_m(m, x, params)
        V_nm = V_nm + integrand * dx
    end do
end function integrate_potential_element
```

### Appendix B: INPUT File Examples

**B.1 NH3 (New Format)**
```
N_max = 200
potential_type = double_well_quartic

[potential_params]
xe = 0.3816      # Angstroms
Vb = 2028.6      # cm^-1

[masses]
mass_H = 1.00782503207
mass_N = 14.0030740048

xmin = -5.0
xmax = 5.0
dx = 0.02
```

**B.2 Harmonic Oscillator**
```
N_max = 100
potential_type = harmonic

[potential_params]
omega = 1000.0   # cm^-1

[masses]
mass_reduced = 1.0  # amu

xmin = -10.0
xmax = 10.0
dx = 0.05
```

**B.3 Morse Potential (HCl)**
```
N_max = 150
potential_type = morse

[potential_params]
De = 37244.0      # cm^-1 (well depth)
alpha = 1.8677    # Angstrom^-1
re = 1.2746       # Angstrom

[masses]
mass_H = 1.00782503207
mass_Cl = 34.96885268

xmin = -2.0
xmax = 8.0
dx = 0.02
```

### Appendix C: References

**Quantum Mechanics Textbooks**:
- Griffiths, D. J. (2018). *Introduction to Quantum Mechanics* (3rd ed.). Cambridge University Press.
- Sakurai, J. J., & Napolitano, J. (2017). *Modern Quantum Mechanics* (2nd ed.). Cambridge University Press.
- Cohen-Tannoudji, C., Diu, B., & Laloë, F. (1977). *Quantum Mechanics*. Wiley.

**Computational Methods**:
- Press, W. H., et al. (2007). *Numerical Recipes: The Art of Scientific Computing* (3rd ed.). Cambridge University Press.
- Tannor, D. J. (2007). *Introduction to Quantum Mechanics: A Time-Dependent Perspective*. University Science Books.

**Fortran OOP**:
- Chivers, I., & Sleightholme, J. (2015). *Introduction to Programming with Fortran* (3rd ed.). Springer.
- Metcalf, M., Reid, J., & Cohen, M. (2011). *Modern Fortran Explained*. Oxford University Press.

**Specific Potentials**:
- Morse, P. M. (1929). Diatomic molecules according to the wave mechanics. *Phys. Rev.*, 34(1), 57.
- Pöschl, G., & Teller, E. (1933). Bemerkungen zur Quantenmechanik des anharmonischen Oszillators. *Z. Phys.*, 83(3-4), 143-151.
- Swalen, J. D., & Ibers, J. A. (1962). Potential function for the inversion of ammonia. *J. Chem. Phys.*, 36(7), 1914-1918.

---

**Document Status**: Draft for User Review
**Next Step**: User approval required before Phase 1 implementation
**Contact**: For questions or feedback, contact the development team

---

*End of Generalization Plan*
