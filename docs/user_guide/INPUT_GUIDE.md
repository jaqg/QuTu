# INPUT File Quick Reference Guide

## Overview

The NH3 quantum tunneling simulation now uses a single unified `INPUT` file instead of three separate input files. This guide explains how to use it.

## File Location

The `INPUT` file must be placed in the project root directory:
```
/home/jose/Documents/Universidad/aac-INVESTIGACION/zuñiga/quantum-tunnelling/INPUT
```

## Format

The INPUT file uses a simple `key = value` format:
```
# This is a comment
parameter_name = value

# Inline comments are also supported
N_max = 200  # Maximum basis functions
```

## Required Parameters

All 8 parameters are required. The program will report an error if any are missing.

| Parameter | Type | Units | Description | Default |
|-----------|------|-------|-------------|---------|
| `N_max` | integer | - | Maximum harmonic oscillator basis functions | 200 |
| `xe` | real | Å | Equilibrium position (well location) | 0.3816 |
| `Vb` | real | cm⁻¹ | Barrier height (inversion barrier) | 2028.6 |
| `mass_H` | real | amu | Hydrogen atomic mass (NIST 2018) | 1.00782503207 |
| `mass_N` | real | amu | Nitrogen atomic mass (NIST 2018) | 14.0030740048 |
| `xmin` | real | a₀ | Grid minimum (in Bohr radii) | -5.0 |
| `xmax` | real | a₀ | Grid maximum (in Bohr radii) | 5.0 |
| `dx` | real | a₀ | Grid spacing (in Bohr radii) | 0.02 |

## Example INPUT File

```
# NH3 Double-Well Quantum Tunneling Simulation
# Input parameters

# Basis set size
N_max = 200

# Potential parameters (NH3 molecule)
xe = 0.3816      # Equilibrium position (Angstroms)
Vb = 2028.6      # Barrier height (cm^-1)

# Atomic masses (NIST 2018)
mass_H = 1.00782503207   # Hydrogen mass (amu)
mass_N = 14.0030740048   # Nitrogen mass (amu)

# Spatial grid (atomic units)
xmin = -5.0      # Grid minimum (Bohr)
xmax = 5.0       # Grid maximum (Bohr)
dx = 0.02        # Grid spacing (Bohr)
```

## Running the Simulation

1. **Edit INPUT file** (if needed):
   ```bash
   nano INPUT
   ```

2. **Navigate to source directory**:
   ```bash
   cd /home/jose/Documents/Universidad/aac-INVESTIGACION/zuñiga/quantum-tunnelling/src
   ```

3. **Compile** (if not already compiled):
   ```bash
   make clean
   make
   ```

4. **Run**:
   ```bash
   ./doble_pozo_NH3
   ```

5. **Check results** in the `data/` directory:
   ```bash
   ls -lh data/out-*.dat
   ```

## Common Modifications

### Higher Accuracy Calculation
Increase the basis set size:
```
N_max = 300  # More accurate but slower
```

### Finer Grid
Decrease the grid spacing:
```
dx = 0.01  # Finer grid, more memory
```

### Larger Grid Range
Increase the grid extent:
```
xmin = -10.0
xmax = 10.0
```

### Different Isotope
For deuterated ammonia (ND3), change hydrogen mass:
```
mass_H = 2.01410177812  # Deuterium mass
```

## Error Messages

### "Cannot open INPUT file"
- **Cause:** INPUT file not found
- **Solution:** Create INPUT file in project root directory

### "Missing required parameter: [parameter_name]"
- **Cause:** A required parameter is not in the INPUT file
- **Solution:** Add the missing parameter with format `parameter_name = value`

### "Unknown parameter in INPUT file: [parameter_name]"
- **Cause:** Typo or unsupported parameter
- **Solution:** Check spelling (parameters are case-sensitive)
- **Note:** This is just a warning, simulation will continue

## Output Files

All output files are written to the `data/` directory:

| File Pattern | Description |
|--------------|-------------|
| `out-energias*.dat` | Energy eigenvalues |
| `out-funciones_*.dat` | Wavefunctions |
| `out-densidad_prob_*.dat` | Probability densities |
| `out-potencial*.dat` | Potential energy curves |
| `out-psi*.dat` | Wavepackets |
| `out-probabilidad_supervivencia_*.dat` | Survival probabilities |
| `out-conver_energias*.dat` | Convergence analysis |

## Advanced Usage

### Parameter Scanning
You can create multiple INPUT files for parameter studies:
```bash
cp INPUT INPUT.N100
cp INPUT INPUT.N200
# Edit each file with different N_max values
```

### Reproducibility
Always save your INPUT file with your results:
```bash
cp INPUT data/INPUT.backup
```

## Troubleshooting

### Simulation crashes
1. Check INPUT file for syntax errors
2. Verify all parameters are present
3. Check parameter values are reasonable:
   - N_max: 50-300 (higher needs more memory)
   - xe > 0
   - Vb > 0
   - dx > 0
   - xmax > xmin

### Wrong results
1. Verify INPUT parameters match your intention
2. Check units (xe in Å, Vb in cm⁻¹, grid in a₀)
3. Increase N_max for better convergence

### Compilation errors
1. Ensure all modules are present in `src/modules/`
2. Run `make clean` before `make`
3. Check gfortran version (need >= 4.6)

## Migration from Old Input Files

**Note:** The new INPUT system does NOT read old input files.

If you have old simulations with separate input files:
- `data/in-doble_pozo_NH3.dat`
- `data/in-potencial.dat`
- `data/in-masas_atomicas.dat`

Copy their values into the new INPUT file format.

## Reference

- **Unit conversions:**
  - 1 Bohr radius (a₀) = 0.529177 Å
  - 1 Hartree = 219474.63 cm⁻¹
  - 1 amu = 1822.89 electron masses

- **Physical constants:** NIST CODATA-2018

- **Full documentation:** See `CLAUDE.md` and `CLAUDE-FULL.md`

---
*Last updated: 2026-01-20*
