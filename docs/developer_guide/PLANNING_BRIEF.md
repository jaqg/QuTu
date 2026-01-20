# Generalization Planning Brief

**Date**: 2026-01-20
**Agent**: Agent Organizer
**For**: Plan Agent
**Output**: docs/developer_guide/GENERALIZATION_PLAN.md

---

## OBJECTIVE

Design a comprehensive plan to generalize the quantum tunneling simulation from NH3-specific to supporting arbitrary 1D potential functions, while maintaining NH3 as one example among others.

---

## CURRENT LIMITATIONS

### 1. Hard-coded NH3 Potential

The potential is currently defined specifically for NH3 double-well:

**Formula**: V(x) = (Vb/xe⁴)x⁴ - (2Vb/xe²)x² + Vb

**Parameters**:
- xe = 0.3816 Å (equilibrium position)
- Vb = 2028.6 cm⁻¹ (barrier height)
- mass_H, mass_N (specific to NH3)

**Code location**: Various modules reference these parameters

### 2. NH3-Specific Naming

- Files: `doble_pozo_NH3.f90`
- Output files: `out-*_NH3*.dat` (some)
- Comments and documentation reference NH3 specifically

### 3. Parameter System

INPUT file is structured around NH3-specific parameters (xe, Vb, masses).

---

## GENERALIZATION REQUIREMENTS

### 1. Support Arbitrary 1D Potentials

Users should be able to:
- Define custom potential functions V(x)
- Use predefined potentials (double-well, harmonic, square well, etc.)
- Specify potential parameters generically
- For now, the program should be generalizable to any double-well (simmetric or antisimmetric) potential

### 2. Flexible Parameter System

- Generic parameter names
- Support for different numbers of parameters
- Backward compatibility with NH3 setup

### 3. Generic Naming

- Program name: Either generic or modular
- Output files: Reference system/potential type, not NH3
- Documentation: General quantum tunneling, with NH3 as example

### 4. Maintain NH3 Example

- NH3 should work as before (backward compatible)
- NH3 as one example in `examples/01_basic_NH3/`
- Easy to set up NH3 calculations

---

## PLANNING REQUIREMENTS

Your plan must address the following topics in detail:

### 1. Potential Definition Strategy

**Options to evaluate**:

a) **Fortran Procedure Pointers**
   - Define abstract interface for V(x), dV/dx, etc.
   - Implement concrete potentials as procedures
   - Select at runtime via configuration
   - Pros/cons analysis

b) **Predefined Potential Library**
   - Create module with common potentials
   - Select by name/ID in INPUT
   - Each potential has its own parameters
   - Extensibility considerations

c) **Formula Parsing** (complex)
   - Parse mathematical expressions from input
   - Evaluate at runtime
   - Challenges in Fortran

d) **Hybrid Approach** (recommended?)
   - Library of common potentials
   - Optional custom implementation
   - Best of both worlds?

**Deliverable**: Recommendation with justification

### 2. Architecture Design

**Module Structure**:
- How to organize potential-related code
- Interface design (abstract potential class)
- Factory pattern for potential selection
- Parameter management

**Key Questions**:
- Where does potential selection happen?
- How are parameters passed around?
- How to handle variable number of parameters?
- Integration with existing modules

**Deliverable**: Architecture diagram and module specifications

### 3. Parameter System Redesign

**Current**: Fixed parameters in INPUT (N_max, xe, Vb, masses, grid)

**New Design**:
- Potential type selection
- Generic parameter sections
- Backward compatibility with NH3 format
- Validation and error handling

**Example New INPUT Structure**:
```
# Potential selection
potential_type = double_well_quartic

# Potential parameters (depends on type)
[potential_params]
xe = 0.3816
Vb = 2028.6
# ... etc

# Or for harmonic oscillator:
potential_type = harmonic
[potential_params]
omega = 1.0
```

**Deliverable**: INPUT file format specification

### 4. Code Changes Required

**Modules to modify**:
- `hamiltonian.f90`: Generic potential evaluation
- `io.f90`: Generic output naming
- `input_reader.f90`: Parse potential type and parameters
- `types.f90`: Potential type definitions
- Main program: Potential initialization

**New modules**:
- `potentials.f90`: Potential library and interface
- `potential_factory.f90`: Potential selection/creation

**Deliverable**: List of required changes per file

### 5. Backward Compatibility

**Requirements**:
- Existing NH3 INPUT files should work (or easy migration)
- Provide conversion tool/script if needed
- Default to NH3 if not specified?
- Deprecation warnings vs. breaking changes

**Deliverable**: Compatibility strategy and migration guide

### 6. Testing Strategy

**Unit Tests**:
- Each potential function (V(x), derivatives)
- Parameter parsing
- Potential factory/selection

**Integration Tests**:
- Full calculations with different potentials
- I/O with generic naming

**Validation Tests**:
- NH3 results unchanged
- Harmonic oscillator (analytical solution)
- Infinite square well
- Other known systems

**Deliverable**: Test plan with specific test cases

### 7. Implementation Phases

Break down implementation into manageable phases:

**Phase 1**: Foundation
- Define potential interface
- Create potential module structure
- Implement 2-3 basic potentials

**Phase 2**: Integration
- Update existing modules
- Modify INPUT reading
- Generic output naming

**Phase 3**: Testing
- Unit tests
- Integration tests
- Validation

**Phase 4**: Documentation
- Update all documentation
- Create examples for different potentials
- Migration guide

**Deliverable**: Phased timeline with dependencies

### 8. Example Potentials to Support

Recommend initial set of potentials:

**Essential**:
- NH3 double-well: V(x) = (Vb/xe⁴)x⁴ - (2Vb/xe²)x² + Vb
- Harmonic oscillator: V(x) = ½kx² or ½mω²x²
- Infinite square well: V(x) = 0 for |x| < a, ∞ otherwise

**Useful**:
- Generic quartic double-well: V(x) = ax⁴ + bx² + c
- Morse potential: V(x) = D(1 - e^(-αx))²
- Pöschl-Teller potential
- User-defined (if feasible)

**Deliverable**: Prioritized list with implementation notes

### 9. Output File Naming

**Current**: Mix of generic and NH3-specific names

**New Strategy**:
- Include potential type in filename?
- User-specified run ID?
- Date/timestamp?
- Configuration hash?

**Example**:
```
out-energies_double_well.dat
out-wavefunction_harmonic_n0.dat
```

**Deliverable**: Naming convention specification

### 10. Risk Assessment

**Technical Risks**:
- Fortran procedure pointer complexity
- Performance overhead
- Backward compatibility issues
- Testing coverage

**Project Risks**:
- Scope creep
- Breaking existing workflows
- Documentation burden
- User adoption

**Deliverable**: Risk matrix with mitigation strategies

---

## OUTPUT SPECIFICATION

Create a comprehensive document at:
**`docs/developer_guide/GENERALIZATION_PLAN.md`**

### Document Structure

```markdown
# Generalization Plan: Arbitrary 1D Potentials

## Executive Summary
[2-3 paragraphs summarizing the approach]

## 1. Current State Analysis
[What we have now, limitations]

## 2. Requirements
[Detailed requirements for generalization]

## 3. Proposed Solution
### 3.1 Potential Definition Strategy
[Chosen approach with justification]

### 3.2 Architecture Design
[Module structure, interfaces, diagrams]

### 3.3 Parameter System
[New INPUT format, parameter handling]

### 3.4 Implementation Details
[Specific code changes needed]

## 4. Backward Compatibility
[How to maintain NH3 functionality]

## 5. Testing Strategy
[Comprehensive test plan]

## 6. Implementation Roadmap
### Phase 1: Foundation
[Tasks, timeline, deliverables]

### Phase 2: Integration
[Tasks, timeline, deliverables]

### Phase 3: Testing & Validation
[Tasks, timeline, deliverables]

### Phase 4: Documentation
[Tasks, timeline, deliverables]

## 7. Example Potentials
[Initial set of supported potentials]

## 8. Risk Assessment
[Risks and mitigation strategies]

## 9. Future Extensions
[Potential future enhancements]

## 10. Recommendations
[Final recommendations and next steps]

## Appendices
### A. Code Snippets
[Example implementations]

### B. INPUT File Examples
[Example configurations for different potentials]

### C. References
[Relevant papers, books, documentation]
```

### Document Quality Requirements

- **Comprehensive**: Cover all aspects listed above
- **Technical**: Include code examples, interfaces, diagrams
- **Actionable**: Provide clear next steps for implementation
- **Realistic**: Consider Fortran constraints and project scope
- **Well-structured**: Use clear headings, lists, examples

---

## CONSTRAINTS AND CONSIDERATIONS

### Fortran Constraints
- No object-oriented features in older Fortran
- Procedure pointers available in Fortran 2003+
- Module dependencies and compilation order
- LAPACK integration unchanged

### Performance Considerations
- Potential evaluation called many times
- Avoid overhead in critical loops
- Maintain computational efficiency

### User Experience
- Simple for common cases (NH3, harmonic)
- Flexible for advanced users
- Clear error messages
- Good documentation

### Project Scope
- Focus on 1D potentials
- Time-independent and time-dependent
- Integration with existing variational method
- Visualization updates needed?

---

## SUCCESS CRITERIA

The plan will be considered successful if it:

1. **Provides clear technical approach** for implementing arbitrary potentials
2. **Maintains backward compatibility** with NH3 calculations
3. **Includes comprehensive testing strategy** with specific test cases
4. **Proposes realistic implementation timeline** with clear phases
5. **Addresses all risks** with mitigation strategies
6. **Is actionable** - a developer can implement from this plan
7. **Written to file** at docs/developer_guide/GENERALIZATION_PLAN.md

---

## NEXT STEPS AFTER PLANNING

1. **User review and approval** of the plan
2. **Refinement** based on user feedback
3. **Implementation** following the approved plan
4. **Testing** according to test strategy
5. **Documentation** updates
6. **Release** of generalized version

---

## REFERENCES FOR PLANNING

- Current codebase in `src/`
- INPUT file format in root
- Module documentation in code comments
- Physics background in CLAUDE-FULL.md
- Implementation notes in docs/developer_guide/

---

**Status**: READY FOR PLAN AGENT
**Priority**: HIGH (but after restructuring)
**Output Required**: docs/developer_guide/GENERALIZATION_PLAN.md
