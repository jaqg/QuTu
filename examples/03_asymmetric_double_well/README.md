# Example 03: Asymmetric Double-Well — Proton Transfer in O-H...O

**System**: Model asymmetric double-well — proton in a hydrogen bond
**Level**: Intermediate
**Time**: ~5 minutes to run

---

## Introduction

This example demonstrates the **asymmetric** polynomial mode of QuTu. An asymmetric
double-well arises whenever the two potential minima have different depths — a situation
common in proton transfer reactions within hydrogen bonds where the donor and acceptor
are in inequivalent environments.

The asymmetry is controlled by the linear term v1*x in the polynomial expansion. When
v1 = 0 the potential is symmetric and QuTu uses the block-diagonal solver. When v1 != 0
QuTu falls back to the full-matrix solver and parity labels disappear from the output.

---

## Physical Motivation: Proton Tunneling in O-H...O

In an asymmetric O-H...O hydrogen bond the proton potential along the O...O axis looks like:

```
Energy
  |
  |    *           <- barrier top
  |  *   *
  | *     *
  |*       *
  |   deep  *    * <- shallow minimum
  |         * *
  |__________*________> x (proton coordinate)
             x=0
```

The left well (donor) is deeper. The right well (acceptor) is shallower by an energy
difference called the **ZPE asymmetry** (epsilon). This tilted landscape is described by:

```
V(x) = v1*x + v2*x^2 + v4*x^4
```

where v1*x provides the tilt (v1 > 0 raises the right well relative to the left).

---

## Symmetric vs Asymmetric: What Changes

### v1 = 0 (symmetric)

- V(-x) = V(x): both wells identical
- QuTu detects `is_symmetric = T`
- Energies labeled "even" and "odd" (parity eigenstates)
- Tunneling doublet: E1 - E0 = Delta (pure tunnel coupling)
- Wavefunctions delocalized equally over both wells

### v1 != 0 (asymmetric, this example)

- V(-x) != V(x): wells at different depths
- QuTu detects `is_symmetric = F`
- No parity labels: OUTPUT shows plain index n = 0, 1, 2, ...
- Ground state localized in the deeper well
- First excited state localized in the shallower well

### Tunneling Splitting Formula

In the symmetric case the observable gap is simply Delta = E1 - E0.

For the asymmetric case, the two-state model gives:

```
E1 - E0 = sqrt(epsilon^2 + Delta^2)
```

where:
- epsilon = ZPE asymmetry = ½*h*omega_- + V(x_-) - ½*h*omega_+ - V(x_+)
- Delta = intrinsic tunnel coupling (the quantity that decays exponentially with barrier)

QuTu outputs both E1 - E0 (directly observable from the spectrum) and Delta separately.

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
make && cd examples/03_asymmetric_double_well && ./run.sh
```

### Method 2: Manual Execution

```bash
cd examples/03_asymmetric_double_well
../../build/QuTu
```

---

## Key Output Differences from the Symmetric Case

Open the OUTPUT file and look for:

1. **is_symmetric = F** in the SYSTEM PARAMETERS section — confirms asymmetry was detected.

2. **No "even"/"odd" labels** in the ENERGIES block:
   ```
   $BEGIN ENERGIES
   # columns: n   E(Ha)   E(cm-1)
      0   ...   ~<E0>
      1   ...   ~<E1>
   ```
   Compare to the symmetric examples (01, 02) where the second column reads "even"/"odd".

3. **Delta output**: look for a line reporting the intrinsic tunnel coupling Delta
   separately from E1 - E0. This is non-trivial only when epsilon > 0.

---

## Isotope Effect Exercise

Proton vs deuteron tunneling is one of the clearest signatures of quantum tunneling.
Change the `mass` parameter in INPUT:

| Particle | mass (amu)  | Qualitative effect                     |
|----------|-------------|----------------------------------------|
| proton   | 1.007276    | lighter, tunnels more, larger Delta    |
| deuteron | 2.01355     | heavier, tunnels less, smaller Delta   |
| muon     | 0.113429    | much lighter, much more tunneling      |

Steps:
1. Run with `mass = 1.007276` (proton). Record E1 - E0.
2. Edit INPUT: set `mass = 2.01355` (deuteron). Run again. Record E1 - E0.
3. Compute the kinetic isotope effect (KIE): KIE = Delta_H / Delta_D.

The WKB prediction is:
```
Delta ~ exp(-sqrt(2 * mu * Vb) * L)
```
where L is the tunneling path length. Since m_D / m_H = 2, the exponent increases
by sqrt(2), giving KIE ~ exp(sqrt(2) - 1) * (original exponent) — exponentially large.

---

## Exercise: Scan v1 and Observe Asymmetry Growth

Starting from the symmetric case (v1 = 0) and increasing v1 shows how the doublet
structure breaks:

1. Edit INPUT, set `v1 = 0.0` in v_coeffs (make the first non-v0 coefficient zero):
   `v_coeffs = 0.0, 0.0, -0.02722, 0.0, 0.01`
2. Run and record E1 - E0.
3. Increase v1 in steps: 0.001, 0.002, 0.005, 0.010.
4. Plot E1 - E0 as a function of v1.

The two-state model predicts:
```
E1 - E0 = sqrt(epsilon(v1)^2 + Delta_0^2)
```
so for small v1: E1 - E0 grows quadratically from Delta_0; for large v1 it grows
linearly with v1 (Delta contribution becomes negligible).

---

## Input Parameters Explained

| Key        | Value           | Units   | Description                              |
|------------|-----------------|---------|------------------------------------------|
| poly_degree| 4               | -       | Degree of polynomial V(x)               |
| v_coeffs   | 0.0, 0.002, ... | Ha/a0^k | v0=0, v1=0.002 (tilt), v2, v3=0, v4    |
| mass       | 1.007276        | amu     | Proton mass (direct single-mass input)  |
| alpha      | 4.7             | a0^-1   | HO basis width (verified by quantiko)   |
| N_max      | 80              | -       | Number of basis functions               |
| xmin/xmax  | -3.0/3.0        | a0      | Grid range (narrower: minima at ±1.2)  |
| dx         | 0.01            | a0      | Grid spacing                            |

The `mass` key (single value) sets the particle mass directly in amu. This is the
simplest mass input method for a non-molecule test particle.

---

## References

- Benderskii, V. A., Makarov, D. E., & Wight, C. A. (1994).
  *Chemical Dynamics at Low Temperatures*. Wiley-Interscience, Chapters 4-5.
  *Authoritative treatment of tunneling in asymmetric potentials.*

- Garg, A. (2000). Am. J. Phys., **68**(5), 430-437.
  *Tunnel splittings for one-dimensional potential wells revisited.*
  *Pedagogical derivation of the asymmetric double-well two-state model.*

- Razavy, M. (2014). *Quantum Theory of Tunneling* (2nd ed.). World Scientific.
  *Comprehensive reference for the theory underlying this calculation.*

- Smedarchina, Z., Siebrand, W., & Fernandez-Ramos, A. (2012).
  J. Chem. Phys., **137**, 224105.
  *Tunneling splittings in asymmetric systems: benchmark calculations.*

---

**Next Steps**:
- PH3 symmetric polynomial example: `examples/02_ph3_inversion/`
- NH3 basics: `examples/01_basic_NH3/`

**Tutorial Version**: 1.0
**Last Updated**: 2026-03-20
**Tested with**: QuTu v1.0-dev, gfortran 11.3
