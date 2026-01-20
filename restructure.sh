#!/usr/bin/env bash
# =============================================================================
# Project Restructuring Script for QuTu
# =============================================================================
# This script reorganizes the project structure for clean installation
#
# Usage: ./restructure.sh
#
# IMPORTANT: Run this from the project root directory
# =============================================================================

set -e  # Exit on error

echo "=========================================="
echo "QuTu Project Restructuring Script"
echo "=========================================="
echo ""

# Check we're in the right directory
if [ ! -f "CLAUDE.md" ] || [ ! -d "src" ]; then
    echo "ERROR: Please run this script from the project root directory"
    exit 1
fi

# Backup check
echo "⚠️  This script will reorganize the project structure."
echo "   All changes will be tracked in git for easy rollback."
echo ""
read -p "Continue? (yes/no) " -r
echo
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Aborted."
    exit 0
fi

echo "Starting restructuring..."
echo ""

# =============================================================================
# Step 1: Create new directory structure
# =============================================================================
echo "[1/7] Creating new directory structure..."

mkdir -p src/main
mkdir -p src/visualization/core
mkdir -p src/visualization/static
mkdir -p src/visualization/animation
mkdir -p tests/unit
mkdir -p tests/integration
mkdir -p tests/validation
mkdir -p build/debug
mkdir -p build/release
mkdir -p docs/user_guide
mkdir -p docs/developer_guide
mkdir -p docs/theory
mkdir -p docs/references
mkdir -p examples
mkdir -p scripts
mkdir -p config

echo "✓ Directory structure created"

# =============================================================================
# Step 2: Move main program to src/main/
# =============================================================================
echo "[2/7] Moving main program..."

# Rename doble_pozo_NH3.f90 to qutu.f90
git mv src/doble_pozo_NH3.f90 src/main/qutu.f90

echo "✓ Main program moved and renamed to qutu.f90"

# =============================================================================
# Step 3: Move documentation files
# =============================================================================
echo "[3/7] Moving documentation files..."

# Move to docs/user_guide/
[ -f "INPUT_GUIDE.md" ] && git mv INPUT_GUIDE.md docs/user_guide/

# Move to docs/developer_guide/
[ -f "TODO.md" ] && git mv TODO.md docs/developer_guide/
[ -f "IMPLEMENTATION_REPORT.md" ] && git mv IMPLEMENTATION_REPORT.md docs/developer_guide/
[ -f "notas-claude.md" ] && git mv notas-claude.md docs/developer_guide/

# Move coordination documents to docs/developer_guide/
[ -f "ORCHESTRATION_STATUS.md" ] && git mv ORCHESTRATION_STATUS.md docs/developer_guide/
[ -f "COORDINATION_SUMMARY.md" ] && git mv COORDINATION_SUMMARY.md docs/developer_guide/
[ -f "PROJECT_COORDINATION_PLAN.md" ] && git mv PROJECT_COORDINATION_PLAN.md docs/developer_guide/
[ -f "RESTRUCTURING_PLAN.md" ] && git mv RESTRUCTURING_PLAN.md docs/developer_guide/
[ -f "PLANNING_BRIEF.md" ] && git mv PLANNING_BRIEF.md docs/developer_guide/
[ -f "EXAMPLE_CREATION_SPEC.md" ] && git mv EXAMPLE_CREATION_SPEC.md docs/developer_guide/

# CLAUDE-FULL.md stays at root or moves to docs/ (user choice - default: root)
# [ -f "CLAUDE-FULL.md" ] && git mv CLAUDE-FULL.md docs/

echo "✓ Documentation files moved"

# =============================================================================
# Step 4: Move Python visualization scripts
# =============================================================================
echo "[4/7] Moving visualization scripts..."

# Move existing grafica/ and animacion/ to src/visualization/
if [ -d "grafica" ]; then
    # Move Python scripts only
    find grafica -name "*.py" -type f -exec bash -c '
        for file; do
            git mv "$file" "src/visualization/static/" || true
        done
    ' bash {} +
fi

if [ -d "animacion" ]; then
    # Move Python scripts only
    find animacion -name "*.py" -type f -exec bash -c '
        for file; do
            git mv "$file" "src/visualization/animation/" || true
        done
    ' bash {} +
fi

echo "✓ Visualization scripts moved"

# =============================================================================
# Step 5: Create configuration template
# =============================================================================
echo "[5/7] Creating configuration template..."

cp INPUT config/INPUT.template

echo "✓ INPUT template created"

# =============================================================================
# Step 6: Clean up git-deleted files
# =============================================================================
echo "[6/7] Cleaning up git-tracked deleted files..."

# These files show as deleted in git status - complete the deletion
git rm --ignore-unmatch src/LEEME.txt 2>/dev/null || true
git rm --ignore-unmatch src/calculos_4f.wxmx 2>/dev/null || true
git rm --ignore-unmatch src/doble_pozo_NH3_COMPLETO.f90 2>/dev/null || true
git rm --ignore-unmatch src/exec.sh 2>/dev/null || true
git rm --ignore-unmatch src/factores_conversion_NIST-18.txt 2>/dev/null || true
git rm --ignore-unmatch src/valor_esperado_observable.f90 2>/dev/null || true

# Remove old subrutinas directories (already deleted in git)
git rm -r --ignore-unmatch src/subrutinas 2>/dev/null || true
git rm -r --ignore-unmatch src/subrutinas_2 2>/dev/null || true

# Remove old animation/grafica directories (already deleted in git)
git rm -r --ignore-unmatch src/animacion 2>/dev/null || true
git rm -r --ignore-unmatch src/grafica 2>/dev/null || true

echo "✓ Git cleanup completed"

# =============================================================================
# Step 7: Create placeholder README files
# =============================================================================
echo "[7/7] Creating placeholder documentation..."

# tests/unit/README.md
cat > tests/unit/README.md << 'EOF'
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
EOF

# tests/integration/README.md
cat > tests/integration/README.md << 'EOF'
# Integration Tests

This directory contains integration tests that verify multiple components work together correctly.

## Tests
- Hamiltonian construction
- Eigenvalue solving
- Wave packet propagation
- I/O operations

(To be implemented)
EOF

# tests/validation/README.md
cat > tests/validation/README.md << 'EOF'
# Validation Tests

This directory contains physics validation tests comparing results with:
- Known analytical solutions (harmonic oscillator, infinite well)
- Published NH3 data
- Convergence tests

(To be implemented)
EOF

# examples/README.md
cat > examples/README.md << 'EOF'
# Examples

This directory contains self-contained examples demonstrating how to use the quantum tunneling simulation code.

## Available Examples

1. **01_basic_NH3**: Basic NH3 umbrella inversion simulation (to be created in Phase 3)
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
EOF

# src/visualization/README.md
cat > src/visualization/README.md << 'EOF'
# Visualization Scripts

Python scripts for visualizing simulation results.

## Structure
- `core/`: Core visualization utilities
- `static/`: Static plot generation scripts
- `animation/`: Animation generation scripts

## Usage

See individual scripts for usage instructions.
EOF

# scripts/README.md
cat > scripts/README.md << 'EOF'
# Utility Scripts

This directory contains utility scripts for the project.

(To be populated)
EOF

# docs/theory/README.md
cat > docs/theory/README.md << 'EOF'
# Theory Documentation

This directory is reserved for theoretical documentation, including:
- Mathematical formulation (LaTeX)
- Derivations
- Physical background

(To be created)
EOF

# docs/references/README.md
cat > docs/references/README.md << 'EOF'
# References

This directory contains reference materials:
- Research papers (PDF)
- Bibliography
- External documentation

(To be populated)
EOF

echo "✓ Placeholder documentation created"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=========================================="
echo "Restructuring Complete!"
echo "=========================================="
echo ""
echo "Directory structure created:"
echo "  ✓ src/main/ - Main program (renamed to qutu.f90)"
echo "  ✓ src/modules/ - Fortran modules (unchanged)"
echo "  ✓ src/visualization/ - Python scripts"
echo "  ✓ tests/ - Test structure"
echo "  ✓ build/ - Build artifacts (gitignored)"
echo "  ✓ docs/ - Documentation"
echo "  ✓ examples/ - Tutorial examples"
echo "  ✓ scripts/ - Utility scripts"
echo "  ✓ config/ - Configuration templates"
echo ""
echo "Next steps:"
echo "  1. Update Makefile for new paths"
echo "  2. Update code path references"
echo "  3. Test compilation"
echo "  4. Commit changes: git add -A && git commit -m 'Restructure project'"
echo ""
echo "Files ready for Phase 2 (Planning) and Phase 3 (Example creation)"
echo ""
