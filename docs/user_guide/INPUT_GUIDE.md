# INPUT File Quick Reference Guide

## Overview

The NH3 quantum tunneling simulation now uses a single unified `INPUT` file instead of three separate input files. This guide explains how to use it.

## File Location

The `INPUT` file must be placed in the project root director

## Format

The INPUT file uses a simple `key = value` format:
```
# This is a comment
parameter_name = value

# Inline comments are also supported
N_max = 200  # Maximum basis functions
```

## Operating Modes

QuTu supports two modes, selected automatically from the INPUT file:

- **Legacy mode** (default): NH3-style `xe`/`Vb` potential. Required keys: `xe`, `Vb`, `mass_H`, `mass_N`.
- **Polynomial mode**: General `V(x) = Σ vₖ xᵏ`. Required keys: `poly_degree`, `v_coeffs`, plus one mass method.

If `poly_degree` or `v_coeffs` is present, polynomial mode is activated. All existing legacy INPUT files continue to work unchanged.

## Required Parameters

### Common (both modes)

| Parameter | Type | Units | Description |
|-----------|------|-------|-------------|
| `N_max` | integer | — | Maximum harmonic oscillator basis functions |
| `xmin` | real | a₀ | Grid minimum (Bohr radii) |
| `xmax` | real | a₀ | Grid maximum (Bohr radii) |
| `dx` | real | a₀ | Grid spacing (Bohr radii) |

### Legacy mode (existing behaviour, unchanged)

| Parameter | Type | Units | Description |
|-----------|------|-------|-------------|
| `xe` | real | Å | Equilibrium position (well minima at ±xe) |
| `Vb` | real | cm⁻¹ | Barrier height |
| `mass_H` | real | amu | Hydrogen atomic mass |
| `mass_N` | real | amu | Nitrogen atomic mass |

### Polynomial mode (new)

| Parameter | Type | Units | Description |
|-----------|------|-------|-------------|
| `poly_degree` | integer | — | Polynomial degree K |
| `v_coeffs` | real list | Ha/a₀ᵏ | Comma-separated coefficients v₀, v₁, …, vₖ |
| `alpha` | real | a₀⁻² | (Optional) HO basis width; auto-computed if absent |

Mass specification — choose **one** method (priority order):

| Method | Keys | Formula |
|--------|------|---------|
| 1 — direct | `mass` (amu) | μ = `mass` |
| 2 — XYn umbrella | `mass_central`, `mass_ligand`, `n_ligands` | μ = n·m_Y·m_X/(n·m_Y + m_X) |
| 3 — legacy NH3 | `mass_H`, `mass_N` | μ = 3m_H·m_N/(3m_H + m_N) |

## Polynomial Potential Mode

Use this mode for any potential expressible as a polynomial:

```
V(x) = v₀ + v₁x + v₂x² + v₃x³ + v₄x⁴ + …
```

**Parity auto-detection:** if all odd-power coefficients (v₁, v₃, v₅, …) are zero to within 10⁻¹², the potential is treated as symmetric and block-diagonal diagonalization is used automatically; parity labels (even/odd) appear in the output. Otherwise, a full N×N diagonalization is used and eigenvalues are indexed by n only.

**Units:** coefficients must be in atomic units (Hartree per Bohr^k). Mass via `mass` is in amu.

**Example — asymmetric double-well:**
```
poly_degree = 4
v_coeffs    = 0.0, 0.002, -0.027, 0.0, 0.010   # Ha/a0^k
mass        = 1.007276                           # proton (amu)
alpha       = 4.7                                # optional override
N_max       = 80
xmin        = -3.0
xmax        =  3.0
dx          = 0.01
```

**Convergence note:** asymmetric cases may require larger `N_max`. Check that the first few levels do not change by more than the desired tolerance as `N_max` increases.

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
   cd quantum-tunnelling/src
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

### "Missing required parameter: mass"
- **Cause:** Polynomial mode active but no mass method provided
- **Solution:** Add `mass = <value>`, or `mass_central`/`mass_ligand`/`n_ligands`, or `mass_H`/`mass_N`

### "poly_degree specified but v_coeffs missing"
- **Cause:** `poly_degree` present without the coefficient list
- **Solution:** Add `v_coeffs = v0, v1, ..., vK`

### "v_coeffs has N entries but poly_degree+1 = M"
- **Cause:** The number of coefficients does not match `poly_degree + 1`
- **Solution:** Ensure the comma-separated list has exactly `poly_degree + 1` values

### "Unknown parameter in INPUT file: [parameter_name]"
- **Cause:** Typo or unsupported parameter
- **Solution:** Check spelling (parameters are case-sensitive)
- **Note:** This is just a warning, simulation will continue

## Output Files — Polynomial Mode

In polynomial mode with odd-power coefficients present (`is_symmetric = F`):
- The `ENERGIES` section uses a simple index `n = 0, 1, 2, …` with **no parity labels** (even/odd are not good quantum numbers).
- The `SYSTEM PARAMETERS` section shows `is_symmetric = F`.
- Sections 9 (four-state wavepacket) and 10 (coefficients) are omitted.

In polynomial mode with all odd coefficients zero (`is_symmetric = T`): output is identical in structure to legacy mode, including parity labels.

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

## Common Modifications — Switching to Polynomial Mode

Minimum change to use polynomial mode with an existing symmetric double-well:

```
# Replace this (legacy):
xe   = 0.718    # A
Vb   = 1770.0   # cm-1

# With this (polynomial, equivalent):
# xe_au = 0.718 / 0.529177 = 1.3565 a0
# Vb_Ha = 1770.0 / 219474.63 = 0.008066 Ha
# v2 = -2*Vb/xe^2, v4 = Vb/xe^4
poly_degree = 4
v_coeffs = 0.008066, 0.0, -0.008761, 0.0, 0.002377   # Ha/a0^k
# Also add one mass method, e.g.:
mass_H = 1.00782503207
mass_N = 14.0030740048
```

See `examples/02_ph3_inversion/` for a complete symmetric polynomial example and `examples/03_asymmetric_double_well/` for an asymmetric case.

---
*Last updated: 2026-03-20*
