# Multi-Agent Orchestration Status

**Project**: Quantum Tunneling Simulation Restructuring & Generalization
**Orchestrator**: Agent Organizer
**Date**: 2026-01-20

---

## OVERVIEW

This document tracks the multi-phase restructuring and generalization project.

### Objectives
1. Restructure project for clean installation (no data/, no results/)
2. Plan generalization from NH3-specific to arbitrary 1D potentials
3. Create basic self-contained NH3 example

---

## PHASE 1: PROJECT RESTRUCTURING

**Status**: IN PROGRESS
**Agent**: Refactoring Specialist
**Priority**: HIGH

### Target Structure
```
quantum-tunnelling/
├── src/
│   ├── main/              # Main program files
│   ├── modules/           # Fortran modules (existing)
│   └── visualization/     # Python plotting scripts
├── tests/
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── validation/       # Physics validation tests
├── build/                # Compilation artifacts (.gitignored)
├── docs/
│   ├── user_guide/       # User documentation
│   ├── developer_guide/  # Developer documentation
│   ├── theory/           # Theory and LaTeX sources
│   └── references/       # Bibliography, papers
├── examples/
│   └── 01_basic_NH3/     # Self-contained NH3 tutorial
├── scripts/              # Utility scripts
├── config/               # Configuration templates
├── README.md
├── LICENSE
├── .gitignore
└── INPUT (example at root)
```

### Tasks
- [ ] Create directory structure
- [ ] Move main program to src/main/
- [ ] Move visualization scripts to src/visualization/
- [ ] Move documentation to docs/
- [ ] Create test directories
- [ ] Update all file paths in code
- [ ] Update Makefile and build scripts
- [ ] Create .gitignore for build/ and local data/
- [ ] Remove git-tracked deleted files
- [ ] Update root README.md

### File Moves
**Source Code**:
- `src/doble_pozo_NH3.f90` → `src/main/doble_pozo_NH3.f90`
- `src/modules/*.f90` → `src/modules/` (keep location)
- `src/Makefile` → `Makefile` (root) or update paths

**Visualization** (from git status, deleted):
- Create `src/visualization/` for future scripts
- Move any Python scripts if found

**Documentation**:
- `CLAUDE.md` → `docs/CLAUDE.md` (project instructions)
- `CLAUDE-FULL.md` → `docs/CLAUDE-FULL.md`
- `README.md` → keep at root, update
- `TODO.md` → `docs/developer_guide/TODO.md`
- `IMPLEMENTATION_REPORT.md` → `docs/developer_guide/IMPLEMENTATION_REPORT.md`
- `INPUT_GUIDE.md` → `docs/user_guide/INPUT_GUIDE.md`

**Data**:
- Remove `src/data/` from git tracking
- Add to .gitignore
- Document data management in README

### Code Updates
- Update `data_dir` in main program
- Update file paths in I/O modules
- Update Makefile paths

---

## PHASE 2: GENERALIZATION PLANNING

**Status**: PENDING (after Phase 1)
**Agent**: Plan Agent
**Priority**: HIGH
**Output File**: `docs/developer_guide/GENERALIZATION_PLAN.md`

### Planning Requirements
1. **Potential Definition Strategy**
   - Analyze Fortran procedure pointer approach
   - Consider predefined potential library
   - Design potential interface/abstract class
   - Plan parameter system redesign

2. **Architecture Design**
   - Module structure for generic potentials
   - Factory pattern for potential selection
   - Generic I/O naming scheme
   - Configuration file format

3. **Backward Compatibility**
   - NH3 as default case
   - Migration strategy
   - Deprecation plan

4. **Implementation Roadmap**
   - Phase breakdown
   - Testing strategy
   - Documentation updates
   - Timeline estimation

5. **Risk Assessment**
   - Technical challenges
   - Breaking changes
   - Performance considerations

### Deliverables
- [ ] Written plan document (GENERALIZATION_PLAN.md)
- [ ] Architecture diagrams
- [ ] Implementation timeline
- [ ] Testing strategy
- [ ] **USER APPROVAL REQUIRED before implementation**

---

## PHASE 3: BASIC EXAMPLE CREATION

**Status**: PENDING (after Phase 1)
**Agent**: Documentation Engineer
**Priority**: MEDIUM

### Example Structure
```
examples/01_basic_NH3/
├── README.md           # Complete tutorial
├── INPUT               # NH3 parameters
├── run.sh              # Execution script
└── data/               # Local data (gitignored)
```

### Tasks
- [ ] Create example directory
- [ ] Copy INPUT template
- [ ] Write comprehensive README
- [ ] Create run script with:
  - Build instructions
  - Execution commands
  - Output description
- [ ] Add visualization example
- [ ] Test end-to-end execution

### README Contents
- Introduction to NH3 tunneling
- Physical background
- How to run the example
- Expected outputs
- Visualization instructions
- References

---

## PROGRESS TRACKING

### Phase 1 Progress
- **Started**: [timestamp]
- **Completed**: [timestamp]
- **Files moved**: 0/XX
- **Tests passed**: 0/XX

### Phase 2 Progress
- **Started**: [timestamp]
- **Plan written**: NO
- **User approved**: NO

### Phase 3 Progress
- **Started**: [timestamp]
- **Example created**: NO
- **Tested**: NO

---

## COORDINATION NOTES

### Dependencies
- Phase 2 can start during Phase 1 (planning only)
- Phase 3 requires Phase 1 completion
- Phase 2 implementation requires user approval

### Risks
1. Path updates may break compilation
2. Data files need careful handling
3. Git history cleanup may be complex

### Communication
- Update this file after each major milestone
- Document all breaking changes
- Track user approvals

---

## FINAL DELIVERABLES

1. Restructured project with clean installation structure
2. Written generalization plan (docs/developer_guide/GENERALIZATION_PLAN.md)
3. Working basic NH3 example (examples/01_basic_NH3/)
4. Updated documentation reflecting new structure
5. All git-deleted files removed
6. Clean .gitignore for build artifacts and local data

---

**Last Updated**: 2026-01-20
**Status**: Phase 1 - In Progress
