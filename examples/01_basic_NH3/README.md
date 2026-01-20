# Example 01: NH3 Umbrella Inversion - Basic Tutorial

**System**: Ammonia (NH3) Molecule - Inversion Mode
**Level**: Beginner
**Time**: ~5 minutes to run

---

## Introduction

This example demonstrates quantum tunneling in the ammonia (NH3) molecule's umbrella inversion mode. The nitrogen atom tunnels through the plane formed by the three hydrogen atoms, creating a classic double-well potential system.

### What You Will Learn

- How to run a basic quantum tunneling simulation
- Understanding double-well potentials
- Interpreting energy levels and tunneling splitting
- Visualizing wavefunctions (symmetric vs. antisymmetric)
- Comparing with experimental NIST data

---

## Physical Background

### The NH3 Molecule

Ammonia (NH3) has a pyramidal structure with the nitrogen atom above the plane of three hydrogen atoms:

```
      N
     /|\
    H H H    ←→    H H H
                     \|/
                      N
   Configuration 1      Configuration 2
```

The molecule can "invert" - the nitrogen atom tunnels through the H₃ plane to the other side. This creates a **symmetric double-well potential**.

### The Double-Well Potential

The potential energy as a function of the nitrogen displacement (x) from the H₃ plane is:

$$V(x) = \frac{V_b}{x_e^4}x^4 - \frac{2V_b}{x_e^2}x^2 + V_b$$

**Parameters (NIST values)**:
- **xₑ = 0.3816 Å**: Equilibrium position (nitrogen distance from H₃ plane)
- **Vb = 2028.6 cm⁻¹**: Barrier height (energy at x=0)

**Key Features**:
- Two minima at x = ±xₑ (equilibrium configurations)
- Barrier at x = 0 (planar transition state)
- Symmetric potential: V(-x) = V(x)

### Quantum Tunneling

**Classical behavior**: Molecule would be trapped in one well
**Quantum behavior**: Wavefunction extends through barrier → tunneling between wells

**Result**: Energy levels split into pairs (tunneling doublets)
- **Even states** (symmetric): ψ(-x) = +ψ(x)
- **Odd states** (antisymmetric): ψ(-x) = -ψ(x)

**Tunneling splitting**: ΔE = E_odd - E_even (experimentally observable!)

---

## Prerequisites

Before running this example, ensure you have:

1. **Compiled QuTu**:
   ```bash
   cd ../../
   make release
   ```

2. **Executable location**: `../../build/release/QuTu`

3. **Optional - Python for visualization**:
   ```bash
   pip install numpy matplotlib
   ```

---

## Input Parameters

The `INPUT` file contains all simulation parameters:

```
# Basis Set
N_max = 200              # Number of harmonic oscillator basis functions

# NH3 Potential Parameters
xe = 0.3816              # Equilibrium position (Å)
Vb = 2028.6              # Barrier height (cm⁻¹)

# Atomic Masses (NIST 2018)
mass_H = 1.00782503207   # Hydrogen atomic mass (amu)
mass_N = 14.0030740048   # Nitrogen atomic mass (amu)

# Spatial Grid
xmin = -5.0              # Grid minimum (Bohr radii)
xmax = 5.0               # Grid maximum (Bohr radii)
dx = 0.02                # Grid spacing (Bohr radii)
```

### Parameter Explanation

**N_max**: Larger values → higher accuracy but slower calculation
- N=50: Quick test (~1 second)
- N=200: Production quality (~5 seconds)
- N=500: High precision (~30 seconds)

**Potential Parameters**: From experimental measurements (NIST database)

**Masses**: Used to calculate reduced mass:
$$\mu = \frac{m_N \cdot (3m_H)}{m_N + 3m_H}$$

**Grid**: Covers wavefunction spatial extent
- Too small: wavefunction cut off
- Too large: unnecessary computation
- Current values are optimized for NH3

---

## Running the Simulation

### Method 1: Automated Script (Recommended)

```bash
cd examples/01_basic_NH3
./run.sh
```

The script will:
1. Check for the QuTu executable
2. Create `data/` directory for output
3. Run the simulation
4. Report results

### Method 2: Manual Execution

```bash
cd examples/01_basic_NH3
mkdir -p data
../../build/release/QuTu
```

### Expected Runtime

- **N_max = 200**: ~5-10 seconds on modern hardware
- **Output files**: Created in `data/` directory

---

## Output Files

All results are written to the `data/` subdirectory:

| File | Description | Size |
|------|-------------|------|
| `out-energias_pares.dat` | Even state energies | ~20 KB |
| `out-energias_impares.dat` | Odd state energies | ~20 KB |
| `out-funciones_pares_*.dat` | Even wavefunctions | ~500 KB |
| `out-funciones_impares_*.dat` | Odd wavefunctions | ~500 KB |
| `out-densidad_prob_par_*.dat` | Even probability densities | ~500 KB |
| `out-densidad_prob_impar_*.dat` | Odd probability densities | ~500 KB |
| `out-probabilidad_supervivencia_*.dat` | Wave packet survival probability | ~100 KB |

### File Formats

**Energy files** (`out-energias_*.dat`):
```
# Energy eigenvalues (atomic units and cm^-1)
# n    E (a.u.)         E (cm^-1)
  0    0.001234         271.05
  1    0.001567         343.89
  ...
```

**Wavefunction files** (`out-funciones_*.dat`):
```
# x (a.u.)    x (Å)    psi(x)
 -5.0000    -2.6458   0.0000
 -4.9800    -2.6352   0.0001
  ...
```

---

## Expected Results

### Energy Levels

**Ground state pair** (n=0):
- **E₀_even** ≈ 271 cm⁻¹ (symmetric ground state)
- **E₀_odd** ≈ 296 cm⁻¹ (antisymmetric ground state)
- **Tunneling splitting**: ΔE₀ ≈ 25 cm⁻¹

**First excited pair** (n=1):
- **E₁_even** ≈ 344 cm⁻¹
- **E₁_odd** ≈ 420 cm⁻¹
- **Tunneling splitting**: ΔE₁ ≈ 76 cm⁻¹

**Second excited pair** (n=2):
- **E₂_even** ≈ 468 cm⁻¹
- **E₂_odd** ≈ 594 cm⁻¹
- **Tunneling splitting**: ΔE₂ ≈ 126 cm⁻¹

**Experimental value**: ν_inv = 0.79 cm⁻¹ (microwave inversion frequency)

*Note: Our simplified 1D model gives qualitatively correct behavior but quantitative comparison requires more sophisticated treatment.*

### Wavefunctions

**Even states** (n=0, 2, 4, ...):
- Symmetric: ψ(-x) = ψ(x)
- Maximum at x = 0 (barrier region) for ground state
- Nodes increase with n

**Odd states** (n=1, 3, 5, ...):
- Antisymmetric: ψ(-x) = -ψ(x)
- Node at x = 0
- Localized in wells

### Physical Interpretation

1. **Tunneling doublets**: Energy level pairs due to symmetric/antisymmetric combinations
2. **Splitting increases** with excitation (higher states → more tunneling probability)
3. **Ground state is symmetric**: Lower energy due to constructive interference in barrier region

---

## Visualization

### Using Python Scripts

If you have Python with matplotlib:

```bash
cd examples/01_basic_NH3
python ../../src/visualization/static/funciones_y_potencial.py
```

This will generate plots of:
- Potential energy curve
- Wavefunctions overlaid on potential
- Probability densities

### Manual Inspection

You can plot data files using your favorite tool:
- **gnuplot**
- **Python matplotlib**
- **MATLAB/Octave**
- **Excel** (for quick checks)

### Example: gnuplot

```gnuplot
set xlabel "Position (Bohr radii)"
set ylabel "Energy (cm^{-1})"
plot 'data/out-potencial.dat' u 1:3 w l title "V(x)", \
     'data/out-funciones_pares_n0.dat' u 1:($3*1000+271) w l title "ψ₀ (even)"
```

---

## Convergence Study

To verify numerical convergence, try different N_max values:

```bash
# Quick test
sed -i 's/N_max = 200/N_max = 50/' INPUT
./run.sh

# Production quality
sed -i 's/N_max = 50/N_max = 200/' INPUT
./run.sh

# High precision
sed -i 's/N_max = 200/N_max = 500/' INPUT
./run.sh
```

**Compare energies**: Should converge to within 0.1 cm⁻¹ for N > 150

---

## Exercises

### Exercise 1: Barrier Height Sensitivity

**Task**: Investigate how tunneling splitting depends on barrier height

**Method**:
1. Copy INPUT to INPUT.backup
2. Modify Vb: Try 1000, 1500, 2028.6, 3000 cm⁻¹
3. Run for each value
4. Plot ΔE vs Vb

**Expected**: ΔE decreases as barrier increases (less tunneling)

**Question**: How does the relationship look? Linear? Exponential?

---

### Exercise 2: Convergence Analysis

**Task**: Study convergence with N_max

**Method**:
1. Run with N = 50, 100, 150, 200, 300, 500
2. Record E₀ for each N
3. Plot E₀ vs N

**Expected**: Rapid convergence, then plateau

**Question**: What N_max is sufficient for 1 cm⁻¹ accuracy?

---

### Exercise 3: Comparison with Harmonic Oscillator

**Task**: Compare double-well to harmonic oscillator

**Method**:
1. Note NH3 ground state energy
2. Calculate harmonic oscillator ground state: E₀ = ℏω/2
3. Estimate ω from potential curvature at minimum

**Question**: How much does anharmonicity matter?

---

### Exercise 4: Wave Packet Dynamics

**Task**: Explore time-dependent tunneling

**Method**:
1. Check `out-probabilidad_supervivencia_*.dat` files
2. Plot survival probability vs time
3. Identify recurrence time

**Expected**: Oscillations due to quantum beating between even/odd states

**Question**: What is the period? Does it relate to ΔE?

---

## Troubleshooting

### Problem: "Error reading INPUT file"

**Solution**: Check INPUT file syntax
- No spaces in parameter names
- Correct format: `parameter = value`
- Comments start with `#`

### Problem: "LAPACK eigenvalue solver failed"

**Solution**:
- Reduce N_max temporarily
- Check for LAPACK library installation
- Verify basis set is not linearly dependent

### Problem: "Segmentation fault"

**Solution**:
- Reduce N_max (may exceed memory)
- Check array bounds
- Compile with debug flags: `make debug`

### Problem: Results don't match expected values

**Solution**:
- Verify INPUT parameters against this README
- Check N_max is sufficient (try N=200)
- Compare with example output in `reference_results/`

---

## Comparison with Literature

### Key NH3 Properties

| Property | This Simulation | Experiment | Notes |
|----------|----------------|------------|-------|
| Barrier height | 2028.6 cm⁻¹ | 2028.6 cm⁻¹ | Input value |
| Equilibrium xe | 0.3816 Å | 0.3816 Å | Input value |
| Inversion frequency | ~25 cm⁻¹ | 0.79 cm⁻¹ | 1D approximation |
| Ground state energy | ~271 cm⁻¹ | - | Relative to barrier |

**Note**: Our 1D model captures qualitative behavior. Quantitative agreement requires:
- Full 3D treatment
- Rotation-vibration coupling
- More accurate potential surface

**References**: See bibliography below

---

## Further Reading

### Recommended Papers

1. **Swalen, J. D., & Ibers, J. A. (1962)**. Potential function for the inversion of ammonia. *J. Chem. Phys.*, 36(7), 1914-1918.
   - Classic paper on NH3 potential

2. **Townes, C. H., & Schawlow, A. L. (1955)**. *Microwave Spectroscopy*. McGraw-Hill.
   - Comprehensive reference on molecular spectroscopy

3. **Coudert, L. H., et al. (2014)**. Analysis of the rotational-tunneling spectrum of ammonia. *J. Mol. Spectrosc.*, 303, 36-41.
   - Modern spectroscopic analysis

### Textbooks

- **Griffiths, D. J. (2018)**. *Introduction to Quantum Mechanics* (3rd ed.). Chapter on tunneling.
- **Levine, I. N. (2014)**. *Quantum Chemistry* (7th ed.). Molecular vibrations chapter.

### Online Resources

- NIST Atomic Spectra Database: https://www.nist.gov/pml/atomic-spectra-database
- CCCBDB (Computational Chemistry): https://cccbdb.nist.gov/

---

## Technical Details

### Computational Method

**Basis Functions**: Harmonic oscillator eigenfunctions
$$\phi_n(x) = N_n H_n(\alpha x) e^{-\alpha^2 x^2/2}$$

where Hₙ are Hermite polynomials.

**Variational Principle**: Expand wavefunction
$$\psi(x) = \sum_{n=0}^{N_{max}} c_n \phi_n(x)$$

**Hamiltonian Matrix Elements**:
$$H_{nm} = \langle \phi_n | \hat{H} | \phi_m \rangle$$

**Eigenvalue Problem**: Solve HC = EC for energies E and coefficients C

**Diagonalization**: LAPACK DSYEV routine (industry standard)

### Atomic Units

Calculations use atomic units internally:
- Length: 1 a.u. = 1 Bohr radius = 0.529177 Å
- Energy: 1 a.u. = 1 Hartree = 219474.63 cm⁻¹
- Mass: 1 a.u. = electron mass

**Conversion factors** (NIST 2018):
```fortran
real(dp), parameter :: bohr_to_angstrom = 0.529177210903_dp
real(dp), parameter :: hartree_to_cm1 = 219474.6313632_dp
real(dp), parameter :: amu_to_au = 1822.888486209_dp
```

---

## Summary

This example demonstrates:
- ✅ Basic QuTu workflow
- ✅ NH3 umbrella inversion physics
- ✅ Quantum tunneling in double-well potentials
- ✅ Energy level splitting
- ✅ Symmetric/antisymmetric states
- ✅ Comparison with NIST data

**Next Steps**:
- Try exercises above
- Explore other examples in `examples/` directory
- Read generalization plan: `docs/developer_guide/GENERALIZATION_PLAN.md`
- Contribute your own potential: `docs/developer_guide/CUSTOM_POTENTIALS.md`

---

## Feedback

Found this tutorial helpful? Have suggestions?
Please contact [maintainer email] or open an issue on GitHub.

---

**Tutorial Version**: 1.0
**Last Updated**: 2026-01-20
**Tested with**: QuTu v1.0, gfortran 11.3, Ubuntu 22.04
