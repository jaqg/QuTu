#!/usr/bin/env bash
# =============================================================================
# Run script for Example 01: NH3 Umbrella Inversion
# =============================================================================
#
# This script runs the NH3 quantum tunneling simulation with standard
# parameters and organizes output in the local data/ directory.
#
# Usage: ./run.sh
#
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo " Example 01: NH3 Umbrella Inversion"
echo "=========================================="
echo ""

# =============================================================================
# Step 1: Check for executable
# =============================================================================

EXEC_PATH="../../build/release/QuTu"
EXEC_PATH_DEBUG="../../build/debug/QuTu"
EXEC_PATH_OLD="../../build/QuTu"
EXEC_PATH_SRC="../../src/doble_pozo_NH3"

# Try to find executable
if [ -f "$EXEC_PATH" ]; then
    EXEC="$EXEC_PATH"
    echo -e "${GREEN}✓${NC} Found executable: $EXEC_PATH"
elif [ -f "$EXEC_PATH_DEBUG" ]; then
    EXEC="$EXEC_PATH_DEBUG"
    echo -e "${YELLOW}⚠${NC}  Using debug executable: $EXEC_PATH_DEBUG"
elif [ -f "$EXEC_PATH_OLD" ]; then
    EXEC="$EXEC_PATH_OLD"
    echo -e "${YELLOW}⚠${NC}  Using executable: $EXEC_PATH_OLD"
elif [ -f "$EXEC_PATH_SRC" ]; then
    EXEC="$EXEC_PATH_SRC"
    echo -e "${YELLOW}⚠${NC}  Using old executable: $EXEC_PATH_SRC"
else
    echo -e "${RED}✗${NC} Executable not found!"
    echo ""
    echo "Please build the program first:"
    echo "  cd ../.."
    echo "  make"
    echo ""
    echo "Or build release version:"
    echo "  cd ../.."
    echo "  make release"
    exit 1
fi

# =============================================================================
# Step 2: Check for INPUT file
# =============================================================================

if [ ! -f "INPUT" ]; then
    echo -e "${RED}✗${NC} INPUT file not found!"
    echo "Expected: $(pwd)/INPUT"
    exit 1
fi

echo -e "${GREEN}✓${NC} Found INPUT file"

# =============================================================================
# Step 3: Create data directory
# =============================================================================

if [ -d "data" ]; then
    echo -e "${YELLOW}⚠${NC}  data/ directory exists"
    read -p "Remove old results? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf data/*
        echo -e "${GREEN}✓${NC} Cleaned data/ directory"
    fi
else
    mkdir -p data
    echo -e "${GREEN}✓${NC} Created data/ directory"
fi

# =============================================================================
# Step 4: Run simulation
# =============================================================================

echo ""
echo "Running NH3 simulation..."
echo "Parameters:"
echo "  - N_max: $(grep 'N_max' INPUT | grep -v '#' | awk '{print $3}')"
echo "  - xe:    $(grep '^xe' INPUT | grep -v '#' | awk '{print $3}') Å"
echo "  - Vb:    $(grep '^Vb' INPUT | grep -v '#' | awk '{print $3}') cm⁻¹"
echo ""
echo "Output directory: $(pwd)/data/"
echo ""

# Record start time
START_TIME=$(date +%s)

# Run the program
if $EXEC; then
    echo ""
    echo -e "${GREEN}✓${NC} Simulation completed successfully!"
else
    echo ""
    echo -e "${RED}✗${NC} Simulation failed!"
    exit 1
fi

# Record end time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo "Execution time: ${ELAPSED} seconds"

# =============================================================================
# Step 5: Verify output
# =============================================================================

echo ""
echo "Checking output files..."

OUTPUT_FILES=(
    "data/out-energias_pares.dat"
    "data/out-energias_impares.dat"
)

MISSING_FILES=0
for file in "${OUTPUT_FILES[@]}"; do
    if [ -f "$file" ]; then
        SIZE=$(du -h "$file" | cut -f1)
        echo -e "${GREEN}✓${NC} $file ($SIZE)"
    else
        echo -e "${RED}✗${NC} $file (missing)"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo ""
    echo -e "${RED}Warning:${NC} Some output files are missing"
fi

# =============================================================================
# Step 6: Display results summary
# =============================================================================

echo ""
echo "=========================================="
echo " Results Summary"
echo "=========================================="
echo ""

# Display first few energy levels
if [ -f "data/out-energias_pares.dat" ]; then
    echo "Energy Levels (Even States):"
    echo "----------------------------"
    head -n 6 data/out-energias_pares.dat | grep -v '#'
    echo ""
fi

if [ -f "data/out-energias_impares.dat" ]; then
    echo "Energy Levels (Odd States):"
    echo "----------------------------"
    head -n 6 data/out-energias_impares.dat | grep -v '#'
    echo ""
fi

# Calculate tunneling splitting for ground state
if [ -f "data/out-energias_pares.dat" ] && [ -f "data/out-energias_impares.dat" ]; then
    # Extract ground state energies (skip header, get first line)
    E0_EVEN=$(grep -v '#' data/out-energias_pares.dat | head -n 1 | awk '{print $3}')
    E0_ODD=$(grep -v '#' data/out-energias_impares.dat | head -n 1 | awk '{print $3}')

    # Calculate splitting using awk for floating point
    SPLITTING=$(awk -v e1="$E0_ODD" -v e0="$E0_EVEN" 'BEGIN {printf "%.2f", e1 - e0}')

    echo "Ground State Tunneling Splitting:"
    echo "  E₀(even)  = $E0_EVEN cm⁻¹"
    echo "  E₀(odd)   = $E0_ODD cm⁻¹"
    echo "  ΔE₀       = $SPLITTING cm⁻¹"
    echo ""
fi

# =============================================================================
# Step 7: Next steps
# =============================================================================

echo "=========================================="
echo " Next Steps"
echo "=========================================="
echo ""
echo "1. Examine results in data/ directory"
echo "2. Read README.md for interpretation"
echo "3. Try exercises in README.md"
echo ""
echo "Visualization (if Python available):"
echo "  python ../../src/visualization/static/funciones_y_potencial.py"
echo ""
echo "Compare with literature values in README.md"
echo ""

exit 0
