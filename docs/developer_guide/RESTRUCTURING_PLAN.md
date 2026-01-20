# Project Restructuring Plan - Detailed Specification

**Date**: 2026-01-20
**Agent**: Agent Organizer
**For**: Refactoring Specialist

---

## OBJECTIVE

Restructure the quantum tunneling simulation project for clean installation without cluttering data/ and results/ directories. The project should be ready for distribution to other users.
The final program should be called "QuTu" instead of "double_pozo_NH3.f90"
---

## TARGET STRUCTURE

```
quantum-tunnelling/
├── src/
│   ├── main/
│   │   └── doble_pozo_NH3.f90
│   ├── modules/
│   │   ├── constants.f90
│   │   ├── types.f90
│   │   ├── input_reader.f90
│   │   ├── harmonic_oscillator.f90
│   │   ├── hamiltonian.f90
│   │   ├── wavepacket.f90
│   │   └── io.f90
│   └── visualization/
│       └── (empty for now, ready for future scripts)
├── tests/
│   ├── unit/
│   │   └── README.md (placeholder)
│   ├── integration/
│   │   └── README.md (placeholder)
│   └── validation/
│       └── README.md (placeholder)
├── build/
│   └── .gitkeep (but directory in .gitignore)
├── docs/
│   ├── user_guide/
│   │   ├── INPUT_GUIDE.md
│   │   └── QUICKSTART.md (to be created)
│   ├── developer_guide/
│   │   ├── TODO.md
│   │   ├── IMPLEMENTATION_REPORT.md
│   │   └── ARCHITECTURE.md (to be created)
│   ├── theory/
│   │   └── README.md (placeholder for LaTeX docs)
│   └── references/
│       └── README.md (placeholder for bibliography)
├── examples/
│   └── README.md (overview of examples)
├── scripts/
│   └── README.md (placeholder for utility scripts)
├── config/
│   └── INPUT.template (template configuration)
├── README.md (main project README)
├── LICENSE (if exists)
├── .gitignore (updated)
├── INPUT (example at root level)
├── Makefile (updated with new paths)
├── CLAUDE.md (kept at root as project instructions)
└── CLAUDE-FULL.md (kept at root or moved to docs/)
```

---

## DETAILED FILE OPERATIONS

### 1. Create New Directories

Create the following directories:
```bash
mkdir -p src/main
mkdir -p src/visualization
mkdir -p tests/unit
mkdir -p tests/integration
mkdir -p tests/validation
mkdir -p build
mkdir -p docs/user_guide
mkdir -p docs/developer_guide
mkdir -p docs/theory
mkdir -p docs/references
mkdir -p examples
mkdir -p scripts
mkdir -p config
```

### 2. Move Source Files

**Main Program**:
```
src/doble_pozo_NH3.f90 → src/main/doble_pozo_NH3.f90
```

**Modules** (already in correct location):
```
src/modules/*.f90 (no move needed)
```

### 3. Move Documentation Files

```
INPUT_GUIDE.md → docs/user_guide/INPUT_GUIDE.md
TODO.md → docs/developer_guide/TODO.md
IMPLEMENTATION_REPORT.md → docs/developer_guide/IMPLEMENTATION_REPORT.md
notas-claude.md → docs/developer_guide/notas-claude.md
CLAUDE-FULL.md → docs/CLAUDE-FULL.md (or keep at root)
```

**Keep at root**:
- CLAUDE.md (project instructions for Claude)
- README.md (main project README)
- INPUT (example input file)

### 4. Handle Data Files

**Action**: Remove from git tracking, add to .gitignore

```
src/data/ → Remove from git, add to .gitignore
```

**Note**: The `data/` directory should be created by the program at runtime or by examples locally. It should not be in the repository.

### 5. Delete Git-Tracked Files

From git status, these files are marked for deletion (D):
```
src/LEEME.txt
src/animacion/*.py (all files)
src/grafica/*.py (all files)
src/calculos_4f.wxmx
src/doble_pozo_NH3_COMPLETO.f90
src/exec.sh
src/factores_conversion_NIST-18.txt
src/subrutinas/*.f90 (old modules)
src/subrutinas_2/*.f90 (old modules)
src/valor_esperado_observable.f90
```

**Action**: Use `git rm` to complete deletion.

### 6. Create Configuration Templates

**File**: `config/INPUT.template`
- Copy current INPUT file
- Add more detailed comments
- Serve as template for users

### 7. Update .gitignore

Create/update `.gitignore`:
```
# Build artifacts
build/
*.o
*.mod
*.exe
doble_pozo_NH3
*.out

# Data and results (user-generated)
data/
results/
*/data/
*/results/

# Visualization output
*.pdf
*.png
*.eps
*.svg

# Editor files
*~
*.swp
*.swo
.vscode/
.idea/

# OS files
.DS_Store
Thumbs.db

# LaTeX auxiliary files
*.aux
*.log
*.toc
*.bbl
*.blg
*.synctex.gz
```

---

## CODE UPDATES

### 1. Update Main Program (src/main/doble_pozo_NH3.f90)

**Line 88**: Update data directory path
```fortran
! OLD:
data_dir = "data/"

! NEW (make configurable or use environment):
data_dir = "data/"  ! Will be created in working directory
```

**Line 74**: Update INPUT file path
```fortran
! Consider making path configurable
call read_input_file("INPUT", input_params, ierr)
! Could be: call read_input_file("../../INPUT", input_params, ierr)
! Or: Use environment variable / command-line argument
```

**Action**:
- Check if paths are relative (should work)
- Add command-line argument parsing for INPUT file location
- Ensure data/ is created if it doesn't exist

### 2. Update I/O Module (src/modules/io.f90)

Check for any hardcoded paths and make them configurable.

### 3. Update Makefile

**Current location**: `src/Makefile`

**Options**:
1. Move to root: `Makefile`
2. Keep in src/ but update paths

**Recommended**: Move to root and update paths

**New Makefile structure**:
```makefile
# Directories
SRC_DIR = src
MAIN_DIR = $(SRC_DIR)/main
MODULE_DIR = $(SRC_DIR)/modules
BUILD_DIR = build

# Compiler settings
FC = gfortran
FFLAGS = -O2 -Wall
LDFLAGS = -llapack -lblas

# Source files
MODULES = $(wildcard $(MODULE_DIR)/*.f90)
MAIN = $(MAIN_DIR)/doble_pozo_NH3.f90
PROGRAM = doble_pozo_NH3

# Object files
MODULE_OBJS = $(patsubst $(MODULE_DIR)/%.f90,$(BUILD_DIR)/%.o,$(MODULES))
MAIN_OBJ = $(BUILD_DIR)/doble_pozo_NH3.o

# Build rules
all: $(PROGRAM)

$(PROGRAM): $(MODULE_OBJS) $(MAIN_OBJ)
	$(FC) $(FFLAGS) -o $@ $^ $(LDFLAGS)

$(BUILD_DIR)/%.o: $(MODULE_DIR)/%.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) -c $< -o $@ -J$(BUILD_DIR)

$(MAIN_OBJ): $(MAIN) $(MODULE_OBJS) | $(BUILD_DIR)
	$(FC) $(FFLAGS) -c $< -o $@ -J$(BUILD_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR) $(PROGRAM)

.PHONY: all clean
```

---

## PLACEHOLDER FILES

Create README.md files in empty directories to explain their purpose:

### tests/unit/README.md
```markdown
# Unit Tests

This directory contains unit tests for individual modules and functions.

## Structure
- One test file per module
- Tests should be independent and repeatable
- Use a Fortran testing framework (e.g., pFUnit) or simple test programs

## Running Tests
```bash
cd tests/unit
make test
```

(Testing framework to be implemented)
```

### tests/integration/README.md
```markdown
# Integration Tests

This directory contains integration tests that verify multiple components work together correctly.

## Tests
- Hamiltonian construction
- Eigenvalue solving
- Wave packet propagation
- I/O operations

(To be implemented)
```

### tests/validation/README.md
```markdown
# Validation Tests

This directory contains physics validation tests comparing results with:
- Known analytical solutions (harmonic oscillator, infinite well)
- Published NH3 data
- Convergence tests

(To be implemented)
```

### examples/README.md
```markdown
# Examples

This directory contains self-contained examples demonstrating how to use the quantum tunneling simulation code.

## Available Examples

1. **01_basic_NH3**: Basic NH3 umbrella inversion simulation
   - Introduction to the code
   - Standard NH3 parameters
   - Visualization examples

(More examples to be added)

## Running Examples

Each example is self-contained with its own README and run scripts:

```bash
cd examples/01_basic_NH3
./run.sh
```
```

### src/visualization/README.md
```markdown
# Visualization Scripts

Python scripts for visualizing simulation results.

(To be added - currently in git-deleted files)
```

---

## ROOT README.md UPDATE

Update the main README.md with new structure:

```markdown
# Quantum Tunneling Simulation in 1D Double-Well Potential

Quantum mechanical simulation of tunneling in one-dimensional double-well potentials using the variational method with harmonic oscillator basis functions.

## Features
- Variational method with harmonic oscillator basis
- Hamiltonian diagonalization (LAPACK)
- Wave packet dynamics and survival probability
- Support for NH3 umbrella inversion mode
- Atomic units with conversion to common units (Å, cm⁻¹)

## Installation

### Prerequisites
- gfortran compiler
- LAPACK and BLAS libraries
- Python 3.x (for visualization, optional)

### Build
```bash
make
```

This creates the executable `doble_pozo_NH3` in the root directory.

## Quick Start

1. Edit the `INPUT` file with your parameters
2. Run the simulation:
   ```bash
   ./doble_pozo_NH3
   ```
3. Results are written to `data/` directory

For detailed examples, see `examples/01_basic_NH3/`.

## Documentation

- **User Guide**: `docs/user_guide/`
  - Input file format: `INPUT_GUIDE.md`
  - Quick start tutorial

- **Developer Guide**: `docs/developer_guide/`
  - Code architecture
  - Module documentation
  - Contributing guidelines

- **Theory**: `docs/theory/`
  - Mathematical formulation
  - Physical background

## Project Structure

```
quantum-tunnelling/
├── src/              # Source code
│   ├── main/        # Main program
│   └── modules/     # Fortran modules
├── tests/           # Test suite
├── docs/            # Documentation
├── examples/        # Tutorial examples
├── scripts/         # Utility scripts
└── config/          # Configuration templates
```

## Examples

See `examples/` directory for complete, self-contained tutorials:
- `01_basic_NH3`: Basic NH3 umbrella inversion simulation

## Testing

```bash
make test
```

(Testing framework to be implemented)

## License

[Add license information]

## References

- [Add relevant papers and references]

## Contact

[Add contact information]
```

---

## VALIDATION STEPS

After restructuring, verify:

1. **Code compiles**:
   ```bash
   make clean
   make
   ```

2. **Program runs**:
   ```bash
   ./doble_pozo_NH3
   ```

3. **Generates expected output**:
   - Check `data/` directory is created
   - Check output files are generated

4. **Git status is clean**:
   ```bash
   git status
   ```
   - No deleted files should appear
   - data/ should not be tracked

5. **Documentation is accessible**:
   - All moved files are in correct locations
   - Links in README work

---

## IMPLEMENTATION CHECKLIST

- [ ] Create all new directories
- [ ] Move main program to src/main/
- [ ] Move documentation to docs/
- [ ] Create placeholder READMEs
- [ ] Update Makefile
- [ ] Update .gitignore
- [ ] Update main program paths
- [ ] Complete git deletions (git rm)
- [ ] Update root README.md
- [ ] Create config/INPUT.template
- [ ] Test compilation
- [ ] Test execution
- [ ] Verify git status

---

## NOTES

- Keep operations atomic where possible
- Test compilation after major changes
- Document any issues encountered
- Preserve git history for moved files (use git mv)

---

**Status**: READY FOR IMPLEMENTATION
**Next Step**: Assign to Refactoring Specialist agent
