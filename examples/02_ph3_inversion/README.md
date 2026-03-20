# Example 02: PH3 Umbrella Inversion — Polynomial Mode

**System**: Phosphine (PH3) Molecule - Inversion Mode
**Level**: Intermediate
**Time**: ~10 minutes to run

---

## Introduction

This example demonstrates the polynomial potential mode of QuTu using phosphine (PH3)
umbrella inversion. PH3, like NH3, has C3v symmetry and a symmetric double-well inversion
potential. The key difference is a much higher barrier (~11,500 cm-1 vs ~1,770 cm-1 for
NH3), which makes tunneling splitting negligible at room temperature.

This example shows how to express a double-well potential as a polynomial directly in
atomic units, bypassing the legacy xe/Vb input mode.

---

## Physical Background

### PH3 vs NH3: Same Symmetry, Very Different Barrier

Both molecules have a pyramidal equilibrium geometry and a planar (D3h) transition state:

```
      P (or N)
     /|\
    H H H    <-->    H H H
                      \|/
                    P (or N)
  Configuration 1      Configuration 2
```

The C3v point group guarantees that the inversion potential is symmetric: V(-x) = V(x).
Only even powers of x appear in the polynomial expansion.

| Property         | NH3           | PH3            |
|------------------|---------------|----------------|
| Barrier Vb       | ~1,770 cm-1   | ~11,500 cm-1   |
| Equilibrium xe   | ~0.38 A       | ~0.76 A        |
| Tunneling split  | ~1 cm-1       | negligible     |
| Reduced mass     | ~2.49 amu     | ~2.75 amu      |

The much higher PH3 barrier suppresses tunneling exponentially. The ground-state
tunneling splitting is below experimental detection with this 1D model.

### Why the Polynomial Input Mode?

The legacy mode requires `xe` and `Vb` directly. The polynomial mode is more general:
it accepts any polynomial V(x) = sum_k v_k * x^k expressed directly in atomic units
(Hartree for energy, Bohr radii for length).

The conversion from (Vb, xe) to polynomial coefficients is:

```
V(x) = Vb/xe^4 * x^4 - 2*Vb/xe^2 * x^2 + Vb
     = v4*x^4 + v2*x^2 + v0

where:
  v0 = Vb            (barrier height, sets energy origin)
  v2 = -2*Vb/xe^2   (negative: creates the double well)
  v4 = Vb/xe^4      (positive: ensures V -> +inf as |x| -> inf)
```

For PH3 (Spirko 1983, Sousa-Silva et al. 2013):
- Vb = 11500 cm-1 = 0.05239 Ha
- xe = 0.76 A = 1.43681 a0

This gives:
- v0 = 0.05239 Ha
- v2 = -2 * 0.05239 / 1.43681^2 = -0.05080 Ha/a0^2
- v4 = 0.05239 / 1.43681^4 = 0.01236 Ha/a0^4

---

## Why Parity Labels Appear

Because all odd polynomial coefficients (v1, v3) are zero, QuTu auto-detects the
potential as symmetric (`is_symmetric = .true.`). The Hamiltonian is block-diagonalized
into even and odd sectors, and energies are labeled "even" and "odd" in the OUTPUT —
exactly as in the legacy NH3 mode.

This is a useful cross-check: **a symmetric polynomial input must produce even/odd labels**.
If they are absent, an odd coefficient is non-zero by mistake.

---

## Running the Simulation

### Prerequisites

Build the executable first:

```bash
cd ../../
make
```

### Method 1: Automated Script (Recommended)

```bash
make && cd examples/02_ph3_inversion && ./run.sh
```

### Method 2: Manual Execution

```bash
cd examples/02_ph3_inversion
../../build/QuTu
```

### Expected Runtime

- N_max = 200, grid 800 points: ~10-20 seconds on modern hardware

---

## Expected Output

The OUTPUT file will contain:

```
Mode        = polynomial
is_symmetric = T
...
$BEGIN ENERGIES
# columns: n   parity   E(Ha)   E(cm-1)
   0   even   ...   ~1400-1800
   1   odd    ...   ~1400-1800  (nearly identical to n=0: negligible splitting)
   2   even   ...   ~4000+
   ...
$END ENERGIES
```

Key features:
- Ground-state doublet (n=0 even, n=1 odd) nearly degenerate (splitting < 0.1 cm-1)
- First excited pair (n=2, n=3) also nearly degenerate
- Energies measured from the bottom of the barrier (V=v0)

---

## Exercises

### Exercise 1: Convergence Study

Verify that the energies converge with N_max:

1. Edit INPUT: change N_max from 200 to 50, 100, 150, 200
2. Run for each value and record E(0)
3. How many basis functions are needed for 1 cm-1 accuracy?

PH3 requires more basis functions than NH3 because its barrier is higher and the
wavefunctions are more localized near the potential minima.

### Exercise 2: Compare NH3 vs PH3 Tunneling Splittings

1. Run example 01 (NH3, legacy mode): record E(1) - E(0)
2. Run this example (PH3, polynomial mode): record E(1) - E(0)
3. Compare the ratio. How does the much higher PH3 barrier suppress tunneling?

The WKB approximation predicts an exponential dependence:
```
Delta ~ exp(-sqrt(2*mu*Vb) * xe)
```
Does your numerical result follow this trend?

---

## Input Parameters Explained

| Key          | Value        | Units    | Description                          |
|--------------|--------------|----------|--------------------------------------|
| poly_degree  | 4            | -        | Degree of polynomial V(x)            |
| v_coeffs     | v0,...,v4    | Ha/a0^k  | Polynomial coefficients              |
| mass_central | 30.97376     | amu      | Phosphorus-31 mass                   |
| mass_ligand  | 1.00782503   | amu      | Hydrogen-1 mass                      |
| n_ligands    | 3            | -        | Number of H atoms                    |
| alpha        | 8.0          | a0^-1    | HO basis width parameter             |
| N_max        | 200          | -        | Number of basis functions            |
| xmin/xmax    | -8.0/8.0     | a0       | Grid range (wider than NH3)          |
| dx           | 0.02         | a0       | Grid spacing                         |

The reduced mass is computed internally:
```
mu = mass_central * (n_ligands * mass_ligand) / (mass_central + n_ligands * mass_ligand)
   = 30.974 * (3 * 1.008) / (30.974 + 3 * 1.008)
   ~ 2.754 amu
```

---

## References

- Spirko, V. (1983). J. Mol. Spectrosc., 101(1), 30-47.
  *Vibrational anharmonicity and the inversion motion of phosphine.*
- Sousa-Silva, C., et al. (2013). J. Mol. Spectrosc., 288, 28-37.
  *A definitive assignment of the vibrational fundamentals of phosphine.*
- Swalen, J. D., & Ibers, J. A. (1962). J. Chem. Phys., 36(7), 1914-1918.
  *Classic double-well inversion potential (NH3 — same formalism applies).*

---

**Next Steps**:
- Try the asymmetric double-well: `examples/03_asymmetric_double_well/`
- Return to NH3 basics: `examples/01_basic_NH3/`

**Tutorial Version**: 1.0
**Last Updated**: 2026-03-20
**Tested with**: QuTu v1.0-dev, gfortran 11.3
