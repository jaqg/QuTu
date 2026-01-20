# Basic NH3 Example Creation Specification

**Date**: 2026-01-20
**Agent**: Agent Organizer
**For**: Documentation Engineer
**Output**: examples/01_basic_NH3/ (complete example)

---

## OBJECTIVE

Create a self-contained, tutorial-quality example demonstrating NH3 umbrella inversion quantum tunneling simulation. This example should be runnable by any user after building the main program.

---

## LOCATION

```
examples/01_basic_NH3/
├── README.md              # Complete tutorial
├── INPUT                  # NH3 configuration
├── run.sh                 # Execution script
├── visualize.py           # Visualization script (optional)
└── data/                  # Local output (created at runtime, gitignored)
```

---

## FILE SPECIFICATIONS

### 1. README.md

**Purpose**: Complete, self-contained tutorial for running NH3 simulation

**Required Sections**:

#### Introduction
- Brief description of NH3 umbrella inversion
- What this example demonstrates
- Expected learning outcomes

#### Physical Background
- NH3 molecular structure (brief)
- Double-well potential description
- Quantum tunneling concept
- Key parameters (xe, Vb, barrier height)

#### Prerequisites
- Compiled main program (`doble_pozo_NH3` executable)
- Path to executable (../../doble_pozo_NH3)
- Optional: Python for visualization

#### Input Parameters
- Explanation of INPUT file parameters
- Why these specific values for NH3
- Parameter ranges and sensitivity

#### Running the Simulation
```bash
# Step-by-step instructions
cd examples/01_basic_NH3
./run.sh
```

#### Output Files
- List and explain each output file
- What physical information they contain
- Units and formats

#### Visualization
- How to visualize results
- Example plots to generate
- Interpretation of results

#### Expected Results
- Energy levels (ground state, first excited, etc.)
- Tunneling splitting
- Wave functions (symmetric/antisymmetric)
- Comparison with literature values

#### Exercises (Optional)
- Vary N_max (convergence study)
- Change barrier height
- Modify equilibrium position
- Compare with harmonic oscillator

#### References
- Key papers on NH3 inversion
- Textbook references
- NIST data sources

**Content Guidelines**:
- Clear, tutorial style
- Assume user knows basic quantum mechanics
- Include equations where helpful (Markdown math)
- Use visual aids (ASCII diagrams acceptable)
- Provide concrete examples

**Template Structure**:
```markdown
# Example 01: Basic NH3 Umbrella Inversion

## Introduction
[What this example does]

## Physical Background
[NH3 structure, tunneling, etc.]

### The NH3 Molecule
[Brief description]

### Double-Well Potential
[Potential formula and explanation]

### Quantum Tunneling
[Tunneling concept]

## Running the Example

### Prerequisites
- Compiled main program
- Basic understanding of quantum mechanics

### Quick Start
```bash
cd examples/01_basic_NH3
./run.sh
```

### Input Parameters
[Detailed explanation of INPUT file]

### Step-by-Step
1. [First step]
2. [Second step]
...

## Understanding the Output

### Energy Levels
[Explanation]

### Wave Functions
[Explanation]

### Survival Probability
[Explanation]

## Visualization

[How to create plots]

## Expected Results

### Energy Spectrum
[Values and interpretation]

### Tunneling Splitting
[Calculation and significance]

### Wave Function Characteristics
[What to look for]

## Exercises

1. [Exercise 1]
2. [Exercise 2]

## References

[Citations]
```

---

### 2. INPUT File

**Purpose**: NH3-specific configuration ready to run

**Content**: Copy current INPUT from root with NH3 defaults:

```
# =============================================================================
# INPUT file for Example 01: NH3 Umbrella Inversion
# =============================================================================
#
# This example demonstrates quantum tunneling in the NH3 double-well potential
# using the standard NIST parameters for ammonia.
#
# =============================================================================

# -----------------------------------------------------------------------------
# Basis Set Parameters
# -----------------------------------------------------------------------------

# N_max: Number of harmonic oscillator basis functions
# For NH3, N=200 gives well-converged results
N_max = 200

# -----------------------------------------------------------------------------
# Double-Well Potential Parameters (NH3)
# -----------------------------------------------------------------------------

# xe: Equilibrium position (distance of N from H3 plane)
# NIST value for NH3: 0.3816 Angstroms
xe = 0.3816

# Vb: Inversion barrier height
# NIST value for NH3: 2028.6 cm^-1
Vb = 2028.6

# -----------------------------------------------------------------------------
# Atomic Masses (NIST 2018 values)
# -----------------------------------------------------------------------------

# Hydrogen atomic mass
mass_H = 1.00782503207

# Nitrogen atomic mass
mass_N = 14.0030740048

# -----------------------------------------------------------------------------
# Spatial Grid Parameters
# -----------------------------------------------------------------------------

# Grid range in atomic units (Bohr radii)
xmin = -5.0
xmax = 5.0

# Grid spacing
dx = 0.02

# =============================================================================
# Expected Results:
# - Ground state energy: ~-0.0757 Hartree
# - First excited state: ~-0.0748 Hartree
# - Tunneling splitting: ~20 cm^-1
# =============================================================================
```

---

### 3. run.sh Script

**Purpose**: Automated execution with error checking

**Features**:
- Check for executable
- Create data directory
- Run simulation
- Report success/failure
- Show output location

**Script Content**:
```bash
#!/bin/bash

# =============================================================================
# Run script for Example 01: NH3 Umbrella Inversion
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
EXECUTABLE="../../doble_pozo_NH3"
INPUT_FILE="INPUT"
DATA_DIR="data"

echo "======================================================"
echo "  NH3 Umbrella Inversion Quantum Tunneling Example"
echo "======================================================"
echo ""

# Check for executable
echo "Checking for executable..."
if [ ! -f "$EXECUTABLE" ]; then
    echo -e "${RED}ERROR:${NC} Executable not found at $EXECUTABLE"
    echo "Please compile the program first:"
    echo "  cd ../.."
    echo "  make"
    exit 1
fi
echo -e "${GREEN}OK:${NC} Found executable"
echo ""

# Check for INPUT file
echo "Checking for INPUT file..."
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}ERROR:${NC} INPUT file not found"
    exit 1
fi
echo -e "${GREEN}OK:${NC} Found INPUT file"
echo ""

# Create data directory
echo "Creating data directory..."
mkdir -p "$DATA_DIR"
echo -e "${GREEN}OK:${NC} Data directory ready: $DATA_DIR/"
echo ""

# Copy INPUT to current directory (or create symlink)
echo "Preparing INPUT file..."
if [ ! -f "INPUT" ] || [ ! -L "INPUT" ]; then
    cp "$INPUT_FILE" INPUT
fi
echo ""

# Run simulation
echo "======================================================"
echo "  Running simulation..."
echo "======================================================"
echo ""

# Run with time measurement
START_TIME=$(date +%s)

if $EXECUTABLE; then
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))

    echo ""
    echo "======================================================"
    echo -e "  ${GREEN}Simulation completed successfully!${NC}"
    echo "======================================================"
    echo ""
    echo "Execution time: ${ELAPSED} seconds"
    echo ""
    echo "Output files written to: $DATA_DIR/"
    echo ""
    echo "Key output files:"
    echo "  - Energy levels: $DATA_DIR/out-conver_energias_*.dat"
    echo "  - Wave functions: $DATA_DIR/out-funciones_*.dat"
    echo "  - Survival probability: $DATA_DIR/out-probabilidad_supervivencia_*.dat"
    echo ""
    echo "To visualize results:"
    echo "  python visualize.py  (if available)"
    echo ""
else
    echo ""
    echo -e "${RED}ERROR:${NC} Simulation failed"
    exit 1
fi
```

**Permissions**: Make executable with `chmod +x run.sh`

---

### 4. visualize.py (Optional)

**Purpose**: Basic visualization of results

**Features**:
- Plot potential energy surface
- Plot first few eigenstates
- Plot survival probability
- Simple, clear plots

**Script Content** (basic version):
```python
#!/usr/bin/env python3
"""
Visualization script for NH3 tunneling example
"""

import numpy as np
import matplotlib.pyplot as plt
import os

DATA_DIR = "data"

def main():
    """Create basic plots from simulation output"""

    print("Visualizing NH3 tunneling simulation results...")
    print()

    # Check if data directory exists
    if not os.path.exists(DATA_DIR):
        print(f"ERROR: Data directory '{DATA_DIR}' not found")
        print("Please run the simulation first: ./run.sh")
        return

    # Plot 1: Potential and lowest energy levels
    plot_potential_and_states()

    # Plot 2: Wave functions
    plot_wavefunctions()

    # Plot 3: Survival probability (if available)
    plot_survival_probability()

    print()
    print("Visualization complete!")
    print("Plots saved to current directory")

def plot_potential_and_states():
    """Plot potential energy curve with energy levels"""
    # Implementation details
    pass

def plot_wavefunctions():
    """Plot wave functions for lowest states"""
    # Implementation details
    pass

def plot_survival_probability():
    """Plot survival probability vs time"""
    # Implementation details
    pass

if __name__ == "__main__":
    main()
```

**Note**: Full implementation to be added based on output file formats

---

## DATA DIRECTORY

**Creation**: By run.sh script at runtime

**Content**: All output files from simulation

**Git Status**:
- Add to .gitignore
- Not tracked in repository
- Each user generates their own

**Pattern**: `examples/*/data/` should all be gitignored

---

## QUALITY CHECKLIST

### README.md
- [ ] Clear introduction
- [ ] Physical background explained
- [ ] Prerequisites listed
- [ ] Step-by-step instructions
- [ ] Output files explained
- [ ] Expected results documented
- [ ] References included
- [ ] Well-formatted (headings, lists, code blocks)

### INPUT File
- [ ] NH3 parameters correct (NIST values)
- [ ] Well-commented
- [ ] Ready to run as-is
- [ ] Includes expected results comment

### run.sh Script
- [ ] Executable permissions
- [ ] Error checking
- [ ] User-friendly output
- [ ] Creates data directory
- [ ] Reports success/failure
- [ ] Shows output locations

### Overall Example
- [ ] Self-contained
- [ ] Works out of the box (after building main program)
- [ ] Educational value
- [ ] Professional quality
- [ ] Tested end-to-end

---

## TESTING REQUIREMENTS

Before considering complete, test:

1. **Fresh clone test**:
   - Start from clean repository
   - Build main program
   - Run example
   - Should work without issues

2. **Documentation test**:
   - Follow README step-by-step
   - All instructions should be accurate
   - All referenced files should exist

3. **Output test**:
   - Verify expected outputs are generated
   - Check data/ directory created
   - Verify file formats match documentation

4. **Error handling test**:
   - Run without building main program (should error gracefully)
   - Run with corrupted INPUT (should error clearly)

---

## INTEGRATION WITH PROJECT DOCUMENTATION

### Update examples/README.md

Add entry for this example:
```markdown
## Available Examples

### 1. Basic NH3 Umbrella Inversion (`01_basic_NH3`)

**Description**: Introduction to quantum tunneling simulation using NH3 umbrella mode

**Topics Covered**:
- Setting up input files
- Running simulations
- Interpreting energy levels
- Visualizing wave functions
- Tunneling splitting

**Difficulty**: Beginner

**Prerequisites**: Basic quantum mechanics

**Time**: ~30 minutes
```

### Update main README.md

Add pointer to examples:
```markdown
## Examples

Complete tutorial examples are available in the `examples/` directory:

- **NH3 Umbrella Inversion**: `examples/01_basic_NH3/`
  - Basic introduction to the code
  - Standard NH3 parameters and expected results
  - Visualization examples
```

---

## SUCCESS CRITERIA

The example will be considered complete when:

1. **Runnable**: User can execute successfully after building main program
2. **Educational**: README provides clear tutorial
3. **Self-contained**: All necessary files included
4. **Documented**: Clear explanations of inputs and outputs
5. **Tested**: Verified to work end-to-end
6. **Professional**: High-quality documentation and scripts

---

## FUTURE ENHANCEMENTS (Not Required Now)

- Additional visualization scripts
- Jupyter notebook version
- Comparison with analytical approximations
- Parameter sensitivity analysis
- Interactive widgets for parameter exploration

---

**Status**: READY FOR IMPLEMENTATION
**Depends On**: Project restructuring (Phase 1)
**Output**: Complete example in examples/01_basic_NH3/
