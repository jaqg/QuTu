# QuTu Generalization: General Polynomial Potential

**Date:** 2026-03-19
**Branch:** `dev/generalization-potential`
**Contributors:** quantiko (theory, ×2), Plan agent (architecture)

---

## Strategic Decision: General Polynomial vs Asymmetric-Specific

**Decision: implement the general polynomial framework directly.**

The asymmetric double-well is a special case of `V(x) = Σ vₖ xᵏ` with `v₁ = c ≠ 0`.
The theory is already fully derived in Section 14 of `docs/theory/`. The refactor is no
harder than a special case and is future-proof for any polynomial potential.

---

## Key Theoretical Findings

### Parity and block-diagonalization

The current code exploits parity symmetry (`V(-x) = V(x)`) to block-diagonalize the
Hamiltonian into even and odd sectors, halving the matrix dimension. Adding **any odd-power
term** (`v₁x`, `v₃x³`, ...) breaks this completely — the parity operator no longer commutes
with H.

**Consequence:** for asymmetric/general potentials, diagonalize the full N×N Hamiltonian.
Keep the block-diagonal path as a special fast-path activated automatically when all odd
coefficients are zero.

### Master recursion for `<m|xᵏ|n>`

The matrix elements `X^(k)_{mn} = <m|xᵏ|n>` in the harmonic oscillator (HO) basis satisfy:

```
X^(k)_{mn} = ℓ [ sqrt(n)·X^(k-1)_{m,n-1} + sqrt(n+1)·X^(k-1)_{m,n+1} ]
```

with `ℓ = 1/sqrt(2α)` (atomic units, ħ=1) and initial condition `X^(0)_{mn} = δ_{mn}`.

**Selection rule:** `X^(k)_{mn} = 0` unless `|m-n| ≤ k` and `(m-n) ≡ k mod 2`.
**Bandwidth:** the Hamiltonian matrix is banded with half-bandwidth K (degree of polynomial).

**Stability:** numerically stable for k ≤ 8. Use the recursion rather than closed-form
expressions. Closed forms for k=1,2,3,4 serve as unit tests only.

### Optimal HO parameters for asymmetric potentials

- **Center x₀:** barrier top `x_b` (where `V'(x_b) = 0, V''(x_b) < 0`) — spans both wells
- **Width α:** arithmetic mean of local harmonic frequencies `α = (ω₋ + ω₊)/2`
- Both should be **user-overridable** via INPUT file for convergence studies
- Eigenvalues must be independent of `x₀` and `α` once the basis is large enough

### Tunneling splitting in the asymmetric case

For the symmetric DW: `ΔE = E₁ - E₀`.

For the asymmetric DW, in the two-state model with well bias ε and tunnel coupling Δ:

```
E₁ - E₀ = sqrt(ε² + Δ²)   →   Δ = sqrt((E₁-E₀)² - ε²)
```

where `ε ≈ ½ħω₋ + V(x₋) - ½ħω₊ - V(x₊)` is the zero-point energy difference.

**Output both:** the eigenvalue gap `E₁ - E₀` (always observable) and the intrinsic
tunnel coupling Δ. Also output the spectroscopic diagnostic `(E₁-E₀)/(E₂-E₁)` — the
two-state model is valid only when this ratio is small.

### LAPACK solver

Switch from dense `DSYEV` to banded `DSBEV`/`DSBEVD` (confirmed). For a matrix of size N
with bandwidth K, this reduces computation from O(N³) to O(K·N²) and storage from O(N²)
to O(K·N). For K=4 and N=200 this is a large saving. Applies to both symmetric (blocks)
and asymmetric (full banded matrix) cases.

The Hamiltonian must be stored in LAPACK's banded format (AB array, `ldab × N`) rather
than as a full square matrix. Both `build_hamiltonian_matrices` (symmetric blocks) and
`build_hamiltonian_full` (asymmetric) must fill this format. The bandwidth is `kd = K`
(polynomial degree) for the potential part, plus `kd = 2` from the kinetic term, so the
effective half-bandwidth is `max(K, 2) = K` for K ≥ 2.

---

## Implementation Plan

### Phase 0 — Git branch

```bash
git checkout -b dev/generalization-potential
```

All work on this branch. No changes to `main` until validation passes.

---

### Phase 1 — `src/modules/types.f90`

**Add to `system_params_t`:**

```fortran
! Polynomial potential: V(x) = sum_{k=0}^{poly_degree} v_poly(k+1) * x^k
real(dp), allocatable :: v_poly(:)
integer               :: poly_degree = 0

! Auto-detected at initialization: .true. iff all odd-k coefficients are zero
logical :: is_symmetric = .true.

! Mode flag: .false. = legacy xe/Vb mode (default, backward compatible)
logical :: use_polynomial = .false.
```

**Add new initializer** alongside the existing `init_system_params`:

```fortran
subroutine init_system_params_poly(params, N, mass_au, v_coeffs, alpha)
```

The `mass_au` argument receives the already-computed reduced mass in atomic units.
The mass computation (whichever of the three methods was used) happens in the main
program after reading the INPUT, before calling this initializer.

Sets `use_polynomial = .true.` and auto-detects `is_symmetric` by checking:

```fortran
is_symmetric = .true.
do k = 1, poly_degree, 2   ! odd powers: k=1,3,5,...
    if (abs(v_coeffs(k+1)) > SYMMETRY_THRESHOLD) then
        is_symmetric = .false.
        exit
    end if
end do
```

**All existing fields and subroutines remain untouched.**

---

### Phase 2 — `src/modules/hamiltonian.f90`

Five new public routines are added. All existing routines remain untouched and in use
for the legacy symmetric path.

#### 2.1 `compute_xk_matrix(k, N_basis, alpha, Xk)`

The master recursion engine.

```fortran
subroutine compute_xk_matrix(k, N_basis, alpha, Xk)
    integer,  intent(in)  :: k, N_basis
    real(dp), intent(in)  :: alpha
    real(dp), allocatable, intent(out) :: Xk(:,:)   ! N_basis × N_basis
```

- `ℓ = 1/sqrt(2·alpha)`
- Allocate two N×N working matrices (`Xprev`, `Xcurr`)
- Initialize `Xprev = I` (k=0)
- Iterate from 1 to k applying the recursion; exploit bandwidth (only compute
  entries with `|m-n| ≤ step` and `(m-n) ≡ step mod 2`)
- Return `Xcurr` as `Xk`

**Verification:** `compute_xk_matrix(2,N,α,X2)` must match `quadratic_integral`
element-by-element; `compute_xk_matrix(4,N,α,X4)` must match `quartic_integral`.

#### 2.2 `potential_matrix_poly(v_poly, N_basis, alpha, V_mat)`

Assembles the full potential matrix:

```
V_mat = Σ_{k=0}^{deg} v_poly(k+1) · X^(k)
```

The k=0 term contributes `v₀ · I`.

**Critical:** the constant `v₀` is now inside the matrix. The explicit `+ params%Vb`
energy shift in `qutu.f90` must be made conditional on legacy mode to avoid double-counting.

#### 2.3 `build_hamiltonian_full(params, H_full)`

Builds the full N×N Hamiltonian `H = T + V` for the asymmetric/general case.
Calls `potential_matrix_poly` and adds the kinetic matrix (`kinetic_integral` loop).

#### 2.4 `potential_poly(x, v_poly)` — Horner evaluation

```fortran
pure function potential_poly(x, v_poly) result(V)
    ! Horner: V = v_N; do k=N-1,0,-1; V = V*x + v_k; end do
```

Used for grid evaluation (plotting V on the grid).

#### 2.5 `turning_points_poly(v_poly, E, x_L, x_R, x_turn, found)`

Numerical root-finding (Brent's method) for `V_poly(x) = E` on a user-supplied
interval. Replaces the hardcoded analytic formula in `turning_points`.

#### 2.6 `compute_optimal_alpha_poly(v_poly, mass, x_min)`

Computes `α = sqrt(μ · V''(x_min))` where `V''(x) = Σ_{k≥2} k(k-1)vₖ x^{k-2}`.

---

### Phase 3 — `src/modules/input_reader.f90`

**New fields in `input_params_t`:**

```fortran
real(dp), allocatable :: v_poly(:)       ! polynomial coefficients
integer               :: poly_degree = -1
logical               :: use_polynomial = .false.

! Mass input — three mutually exclusive modes (priority: mass > XYn formula > mass_H/mass_N)
real(dp) :: mass = 0.0_dp               ! direct reduced mass in atomic units
logical  :: found_mass = .false.

real(dp) :: mass_central = 0.0_dp      ! mX in amu  (XYn umbrella formula)
real(dp) :: mass_ligand  = 0.0_dp      ! mY in amu
integer  :: n_ligands    = 0            ! n in XYn
logical  :: found_xyn_mass = .false.
```

**New INPUT keys (all optional, backward compatible):**

```
poly_degree  = 4
v_coeffs     = 0.0, 0.0, -2.0, 0.0, 1.0   # single comma-separated line: v₀, v₁, ..., vₙ
alpha        = 1.5                          # optional override

# Mass specification — choose ONE of three methods:

# Method 1: direct reduced mass (most general)
mass = 0.8875                               # amu

# Method 2: XYn umbrella inversion formula  μ = n·mY·mX/(n·mY + mX)
mass_central = 30.97376                     # amu  (central atom X)
mass_ligand  = 1.00782503                   # amu  (ligand atom Y)
n_ligands    = 3                            # n

# Method 3: legacy NH3-specific (backward compat, always available)
mass_H = 1.00782503207
mass_N = 14.0030740048
```

**Mass priority logic** (implemented in `read_input_file`):
1. `mass` key present → use directly (convert amu → a.u.)
2. `mass_central` + `mass_ligand` + `n_ligands` all present → compute
   `μ = n·mY·mX/(n·mY + mX)`, convert to a.u.
3. `mass_H` + `mass_N` present → use NH3 formula `μ = 3mH·mN/(3mH+mN)` (legacy)
4. None found → error in polynomial mode; error in legacy mode

If more than one method is provided, warn and follow the priority order above.

The general XY_n formula covers all umbrella-type molecules:

| Molecule | mass_central | mass_ligand | n_ligands | μ (u) |
|---|---|---|---|---|
| NH3 | N (14.003) | H (1.008) | 3 | 2.488 |
| PH3 | P (30.974) | H (1.008) | 3 | 2.754 |
| NF3 | N (14.003) | F (18.998) | 3 | 10.815 |
| AsH3 | As (74.922) | H (1.008) | 3 | 2.886 |
| ND3 | N (14.003) | D (2.014) | 3 | 4.342 |

**Detection logic:**
- If `v_coeffs` / `poly_degree` key found → `use_polynomial = .true.`
- Polynomial mode: `xe` and `Vb` not required; at least one mass method required
- Legacy mode: original validation unchanged (`xe`, `Vb`, `mass_H`, `mass_N` required)
- If both modes provided → warning, prefer polynomial

**Example INPUT for asymmetric DW:**

```
# Asymmetric quartic double-well
# V(x) = Vb + 0*x - (2*Vb/xe^2)*x^2 + 0*x^3 + (Vb/xe^4)*x^4 + c*x
poly_degree = 4
v_coeffs    = 2090.0, 150.0, -41800.0, 0.0, 209000.0   # in cm^-1 / a0^k units
mass        = 0.8875
N_max       = 100
xmin        = -5.0
xmax        =  5.0
dx          = 0.01
```

---

### Phase 4 — `src/main/qutu.f90`

**Dispatch in the convergence loop:**

```fortran
if (.not. params%use_polynomial .or. params%is_symmetric) then
    ! Existing block-diagonal path — store H_even/H_odd in banded format
    call build_hamiltonian_matrices(params, AB_even, AB_odd, kd)
    ! DSBEV on AB_even and AB_odd separately; interleave energies
else
    ! New full-matrix path — store H_full in banded format
    call build_hamiltonian_full(params, AB_full, kd)
    ! DSBEV on AB_full (N×N banded); eigenstates in mixed-parity order
end if
```

**Output adaptations:**
- `INPUT PARAMETERS` section: conditional block — print `v_k` in polynomial mode
- `SYSTEM PARAMETERS`: print polynomial coefficients, not just `a` and `b`
- `ENERGIES` section: `even`/`odd` parity labels only when `is_symmetric = .true.`;
  otherwise label by index `n=0, 1, 2, ...`
- Energy shift (`+ params%Vb`): conditional on legacy mode

**New wavefunction routine:**
`compute_wavefunctions_full(params, H_full, x_grid, psi_all)` — computes all N
eigenstates on the grid using all basis functions (even and odd quantum numbers together).
The existing `compute_wavefunctions` (even/odd) is kept for the symmetric path.

**Wavepacket sections (7, 8, 9):** structurally identical; pass eigenstates via unified
`psi_all(:,:)` index. The physical construction formulas do not depend on parity.

---

### Phase 5 — `src/modules/constants.f90`

Add:

```fortran
real(dp), parameter :: SYMMETRY_THRESHOLD = 1.0e-12_dp
```

Used by `init_system_params_poly` for parity auto-detection.

---

## Testing Strategy

### Phase T1 — Unit tests (`tests/unit/`)

**New file: `tests/unit/test_xk_recursion.f90`**

| Test | What it checks |
|---|---|
| `compute_xk_matrix(k=2,N=10,α=1)` vs `quadratic_integral` (all n,m) | Master recursion for k=2 |
| `compute_xk_matrix(k=4,N=10,α=1)` vs `quartic_integral` (all n,m) | Master recursion for k=4 |
| Selection rule k=1: only ±1 offsets nonzero | Bandwidth / parity property |
| Selection rule k=3: only ±1, ±3 offsets nonzero | Bandwidth / parity property |
| `compute_xk_matrix(k=0)` returns identity matrix | Base case |
| Matrix symmetry: `X^(k)_{mn} = X^(k)_{nm}` for all k | Hermitian property |

**New file: `tests/unit/test_parity_detection.f90`**

| Test | What it checks |
|---|---|
| `v_poly = [Vb, 0, -2Vb/xe², 0, Vb/xe⁴]` → `is_symmetric=.true.` | All odd terms zero |
| `v_poly = [Vb, 0.01, -2Vb/xe², 0, Vb/xe⁴]` → `is_symmetric=.false.` | Nonzero v₁ |
| `v_poly = [0, 0, 0, 0.001, 1]` → `is_symmetric=.false.` | Nonzero v₃ |
| Threshold: `v₁ = 1e-14` → `is_symmetric=.true.` (below threshold) | Numerical tolerance |

**New file: `tests/unit/test_input_parser.f90`** (extend existing unit test scope)

| Test | What it checks |
|---|---|
| `v_coeffs = 1.0, 0.0, -5.0, 0.0, 2.0` → correct `v_poly`, `poly_degree=4` | Parsing |
| `poly_degree = 4` with no `v_coeffs` → error message | Validation |
| `v_coeffs` present with `xe`/`Vb` also present → warning, polynomial preferred | Priority logic |
| `mass = 0.8875` without `mass_H`/`mass_N` → accepted in polynomial mode | Mode-conditional validation |
| Missing `mass` in polynomial mode → error | Required field check |

**Update `tests/unit/README.md`**: document the three test files and how to run them.

### Phase T2 — Validation tests (`tests/validation/`)

**New file: `tests/validation/test_NH3_regression.f90`**

Runs the full program in legacy mode with the NH3 INPUT and compares the first 10
energy levels (Hartree) to stored reference values. Max deviation must be < 1e-10 Eh.
This is the primary regression guard for the legacy code path.

**New file: `tests/validation/test_polynomial_equivalence.f90`**

Runs the program in polynomial mode with coefficients set to exactly the NH3 xe/Vb
values (`v₀=Vb, v₂=-2Vb/xe², v₄=Vb/xe⁴`, all odd terms = 0). Compares energies
against the NH3 regression reference. Tolerance: < 1e-8 Eh relative.

**New file: `tests/validation/test_harmonic_limit.f90`**

Sets `v_poly = [0, 0, ω²/2]` (pure harmonic) with known ω. Verifies that the
polynomial-mode energies satisfy `Eₙ = (n + ½)ω` to within 1e-6 relative error for
n = 0,...,9. Tests end-to-end from input parsing through diagonalization.

**New file: `tests/validation/test_asymmetric_convergence.f90`**

Adds a small linear bias `v₁ = 0.001 Eh/a₀` to the NH3 polynomial coefficients.
Verifies: (a) `is_symmetric = .false.`; (b) full N×N matrix path used; (c) energies
converge monotonically as N increases from 50 to 200; (d) removing the bias (`v₁→0`)
recovers the symmetric energies within 0.1% relative error.

**Update `tests/validation/README.md`**: describe all four test programs, expected
tolerances, and how to run (`make test-validation`).

### Phase T3 — Integration tests (`tests/integration/`)

**New file: `tests/integration/test_full_run_symmetric.f90`**

Runs the complete program pipeline (input → Hamiltonian → diagonalization → wavepacket →
observables → output) in polynomial mode with a symmetric polynomial. Checks that
output files are created, energies are ordered `E₀ ≤ E₁ ≤ ...`, wavefunctions are
normalized, and the two-state wavepacket survival probability oscillates with the
correct period `T = h/ΔE`.

**New file: `tests/integration/test_full_run_asymmetric.f90`**

Same pipeline for an asymmetric polynomial. Additional checks: the OUTPUT contains
no `even`/`odd` labels; turning points are found numerically and are consistent with
the eigenvalue; the asymmetric tunneling splitting output (`Δ`) satisfies
`Δ ≤ E₁ - E₀`.

**Update `tests/integration/README.md`**: document the two test programs and their
scope.

---

## Examples and Tutorials

### PH3 as an example — quantiko verdict

**PH3 is NOT asymmetric.** Like NH3, its potential satisfies V(x) = V(-x) by C₃ᵥ
symmetry — only even polynomial terms appear. What makes PH3 interesting is its much
higher barrier (~11,500 cm⁻¹ vs ~1,770 cm⁻¹ for NH3), making tunneling splitting
negligible. It is a good test of the polynomial mode on a symmetric system with very
different parameters, but not a demonstration of asymmetry.

**Genuine asymmetric double-well examples** (quantiko recommendations):
- Generic cubic-quartic model: `V(x) = v₂x² + v₃x³ + v₄x⁴` with `v₃ ≠ 0`
- Physical interpretation: symmetric DW tilted by an external field, or a proton
  transfer potential in a non-symmetric hydrogen bond

**Decision:** provide two new examples:
- `examples/02_ph3_inversion/` — PH3 symmetric DW via polynomial mode (tests the
  polynomial code path on a real molecule with known parameters)
- `examples/03_asymmetric_double_well/` — generic cubic-quartic model demonstrating
  the asymmetric code path

---

### Phase E1 — New example: `examples/02_ph3_inversion/`

PH3 umbrella inversion using the polynomial mode. Same formula as NH3 but entered
via `v_coeffs` instead of `xe`/`Vb`, demonstrating that the polynomial INPUT is
physically equivalent.

**Parameters (quantiko, Spirko 1983; Sousa-Silva et al. 2013):**
- Vb ≈ 11,500 cm⁻¹, xe ≈ 0.76 Å = 1.436 bohr → v₂ ≈ -11,154 cm⁻¹/bohr², v₄ ≈ 2,707 cm⁻¹/bohr⁴
- Reduced mass: μ = 3mH·mP/(3mH + mP) ≈ 2.754 u = 5,019 mₑ
- All odd coefficients = 0 → `is_symmetric = .true.` auto-detected

```
examples/02_ph3_inversion/
├── INPUT          # polynomial-mode INPUT, symmetric, PH3 parameters
├── README.md      # tutorial
├── run.sh
└── data/
```

**`INPUT`:**
```
# PH3 umbrella inversion — polynomial mode
# V(x) = v0 + v2*x^2 + v4*x^4  (symmetric: v1=v3=0)
# Parameters: Spirko (1983), Sousa-Silva et al. (2013)
poly_degree = 4
v_coeffs = <Vb_au>, 0.0, <v2_au>, 0.0, <v4_au>
mass_central = 30.97376    # P  (amu)
mass_ligand  = 1.00782503  # H  (amu)
n_ligands    = 3
N_max = 200
xmin = -8.0
xmax =  8.0
dx   = 0.02
```

**`README.md` tutorial content:**
- Physical background: PH3 vs NH3 (same symmetry, very different barrier)
- How to convert Vb/xe → polynomial coefficients
- Why parity labels still appear (symmetric polynomial → `is_symmetric=.true.`)
- Convergence: PH3 requires larger N_max due to deeper wells
- Comparison table: NH3 vs PH3 tunneling splittings (PH3 is negligible)
- Exercises: (1) verify the polynomial INPUT gives same energies as `xe`/`Vb` NH3
  would; (2) compare convergence rates for NH3 vs PH3

---

### Phase E2 — New example: `examples/03_asymmetric_double_well/`

**System: tilted quartic double well — model for proton transfer in an asymmetric
hydrogen bond** (quantiko recommendation, following Benderskii et al. 1994 and
Garg, Am. J. Phys. 68, 430, 2000).

**Physical picture:** a proton moves along the donor–acceptor axis of an O–H···O
hydrogen bond. When donor and acceptor are in inequivalent environments the
two minima have different depths — a genuinely asymmetric DW. The potential is:

```
V(x) = v₁·x + v₂·x² + v₄·x⁴      (v₀ = v₃ = 0)
```

The linear term `v₁·x` is the tilt that breaks parity. Setting `v₁ = 0` recovers a
symmetric DW and connects conceptually to Examples 01 and 02.

**Parameters (atomic units, validated by quantiko):**

| Coefficient | Value (a.u.) | Physical meaning |
|---|---|---|
| v₀ | 0.0 | energy reference |
| v₁ | +0.00200 Eh/a₀ | asymmetry tilt |
| v₂ | −0.02722 Eh/a₀² | double-well curvature |
| v₃ | 0.0 | — |
| v₄ | +0.01000 Eh/a₀⁴ | quartic confinement |
| mass | 1837.15 mₑ | proton mass |

**Derived quantities (symmetric part, v₁=0):**
- Minima at x± ≈ ±1.167 a₀ (≈ ±0.617 Å)
- Barrier height Vb ≈ 0.01852 Eh ≈ 4065 cm⁻¹ (realistic O–H in H-bond)
- Well energy asymmetry ΔV ≈ 2·v₁·|x±| ≈ 1025 cm⁻¹
- Local harmonic frequency ≈ 2500–3000 cm⁻¹

**Numerical verification (quantiko, 2026-03-19):**
- Discriminant Δ₃ > 0 confirmed → genuine double-well for these parameters
- Master recursion checked against analytic k=1,2,3,4 formulas: all match to
  machine precision
- Energies at N=40 converge to < 10⁻⁵ cm⁻¹ — fast convergence confirmed
- Script: `docs/theory/numerical_verification.py`

> **⚠ Alpha concern:** the verification script used the local harmonic frequency
> at the deeper minimum for α, giving α ≈ 14.7 a₀⁻². For a DW with minima at
> ±1.167 a₀, this basis is very tight around x=0 and may give incorrect absolute
> energies. **Relative quantities** (E₁−E₀, Δ, localization ratios) from the
> verification are reliable. Absolute energies should be re-checked with the
> global optimal α = (6·m·Vb/xe⁴)^(1/3) ≈ 4.7 a₀⁻² before quoting them. The
> production INPUT file should use this larger α or rely on N-convergence checks.

```
examples/03_asymmetric_double_well/
├── INPUT          # polynomial mode, v₁ ≠ 0, proton mass
├── README.md      # tutorial
├── run.sh
└── data/
```

**`INPUT`:**
```
# Asymmetric double-well: proton transfer in an O-H...O hydrogen bond
# V(x) = v1*x + v2*x^2 + v4*x^4   (v0=v3=0)
# Ref: Benderskii, Makarov, Wight (1994); Garg, Am. J. Phys. 68, 430 (2000)
poly_degree = 4
v_coeffs = 0.0, 0.002, -0.02722, 0.0, 0.01
mass = 1837.15    # proton mass (atomic units)
N_max = 80
xmin = -3.0
xmax =  3.0
dx   = 0.01
```

**`README.md` tutorial content:**
- Physical motivation: proton tunneling in H-bonds, why asymmetry arises
  (inequivalent donor/acceptor, crystal environment, etc.)
- How `v₁·x` tilts the symmetric DW: start with `v₁=0`, show symmetric doublets,
  then turn on asymmetry and watch the doublets break
- Asymmetric tunneling splitting: Δ vs E₁−E₀ (quantiko formulas from theory doc)
- Why parity labels disappear from the OUTPUT (`is_symmetric = .false.`)
- Isotope effect exercise: change `mass` from proton (1837 mₑ) to deuteron
  (3671 mₑ) — tunneling is dramatically quenched
- Exercises: (1) set `v₁=0`, verify symmetric results match a comparable symmetric
  DW; (2) scan `v₁` from 0 to 0.005 and plot Δ and E₁−E₀ vs `v₁`; (3) find the
  critical `v₁` where the second minimum disappears (discriminant Δ₃ = 0)

**Key literature:**
- Benderskii, Makarov, Wight, *Chemical Dynamics at Low Temperatures*, Wiley (1994) — Ch. 4–5
- Garg, Am. J. Phys. **68**, 430 (2000) — pedagogical asymmetric quartic DW
- Razavy, *Quantum Theory of Tunneling*, 2nd ed., World Scientific (2014)
- Smedarchina, Siebrand, Fernandez-Ramos, J. Chem. Phys. **137**, 224105 (2012)

---

### Phase E3 — Update `examples/01_basic_NH3/README.md`

Two small updates:

1. **Technical Details section**: change "LAPACK DSYEV routine" → "LAPACK DSBEV
   routine (banded symmetric eigensolver)" with a one-line note on why banded storage
   is used.

2. **"Next Steps" section**: replace the broken reference to
   `docs/developer_guide/CUSTOM_POTENTIALS.md` with references to
   `examples/02_ph3_inversion/` (polynomial mode, symmetric) and
   `examples/03_asymmetric_double_well/` (asymmetric) as natural progressions.

No other changes to the tutorial content or exercises.

---

## Documentation

### Phase D1 — `docs/user_guide/INPUT_GUIDE.md`

This is the most user-facing document and needs the most changes.

**Section: "Required Parameters"** — the current table lists 8 always-required keys.
Replace with two conditional tables:

*Legacy mode (existing behavior, unchanged):* `N_max`, `xe`, `Vb`, `mass_H`, `mass_N`,
`xmin`, `xmax`, `dx`.

*Polynomial mode (new):* `N_max`, `poly_degree`, `v_coeffs`, `mass`, `xmin`, `xmax`,
`dx`. The keys `xe`, `Vb`, `mass_H`, `mass_N` are not used in this mode.

**New section: "Polynomial Potential Mode"** — immediately after the Required Parameters
table. Include:
- When to use it (any potential expressible as Σ vₖ xᵏ)
- Syntax: `poly_degree = K` then `v_coeffs = v₀, v₁, ..., vₖ`
- Units convention: coefficients in atomic units (Eh/a₀ᵏ), mass in a.u.
- Symmetric vs asymmetric auto-detection explanation
- Full working example for an asymmetric double-well
- Note on convergence: N_max may need to be larger for asymmetric cases

**Section: "Output Files"** — add a note that in polynomial mode with odd-k
coefficients, the output will not contain even/odd parity labels and will instead use
a unified energy index.

**Section: "Error Messages"** — add entries for new error conditions:
- `"Missing required parameter: mass"` (polynomial mode without mass)
- `"poly_degree specified but v_coeffs missing"`
- `"v_coeffs has wrong number of entries for poly_degree N"`

**Section: "Common Modifications"** — add a new subsection "Switching to Polynomial
Mode" with the minimal INPUT change needed.

Update the "Last updated" date at the bottom.

### Phase D2 — `docs/developer_guide/TODO.md`

Mark the polynomial potential items as addressed and add new follow-up items:

```markdown
## Completed in dev/generalization-potential
- [x] Add support for general polynomial potential V(x) = Σ vₖ xᵏ
- [x] Switch LAPACK solver to banded DSBEV
- [x] Auto-detect parity symmetry from polynomial coefficients
- [x] Implement master recursion for <m|xᵏ|n>
- [x] Update INPUT guide for polynomial mode

## Future enhancements
- [ ] HO center x₀ at barrier top for asymmetric potentials (currently fixed at 0)
- [ ] Brent root-finding for turning points (currently bisection)
- [ ] Analytical alpha estimate for general polynomial degree > 4
- [ ] Example 03: harmonic oscillator limit demonstration
- [ ] CI/CD: automate the regression and validation test suite
```

### Phase D3 — `docs/developer_guide/GENERALIZATION_PLAN.md`

The existing file (created by a previous planning session) describes a different
architectural approach (abstract OOP potential factory) that was **not adopted**. Add
a header note at the top:

```markdown
> **SUPERSEDED**: This document describes an earlier generalization plan (OOP factory
> pattern) that was not implemented. The adopted approach is documented in
> `generalization-potential.md` at the project root. This file is retained for
> historical reference only.
```

No other edits — the file stays as historical record.

### Phase D4 — `docs/theory/latex/sections/14_general_case.tex`

The theory section is already complete and correct. One addition is needed at the end
of the "Implementation summary" table (Table 2): a new column or footnote noting that
Step 5 uses the **banded LAPACK routine `DSBEV`** (not `DSYEVD`) with half-bandwidth
`kd = K`. This aligns the theory document with the actual implementation.

Also add a brief paragraph at the end of Section 14 cross-referencing the asymmetric
observable outputs (the Δ vs E₁-E₀ distinction from the quantiko analysis) as a
practical note for users interpreting the code output.

After editing, recompile the PDF:
```bash
cd docs/theory/latex
pdflatex theory.tex && pdflatex theory.tex
cp theory.pdf ../theory.pdf
```

### Phase D5 — `README.md` (project root)

Add a short paragraph under the "Features" or "Usage" section noting the new
polynomial mode, with a one-line example INPUT and a pointer to
`docs/user_guide/INPUT_GUIDE.md`, `examples/02_ph3_inversion/` (symmetric
polynomial mode), and `examples/03_asymmetric_double_well/` (asymmetric).

Update the version/changelog section if one exists.

---

## Migration Summary

No existing code is deleted during the refactor. The legacy path remains fully active
when `use_polynomial = .false.`. Each phase is independently testable.

| Phase | Files changed | Backward compatible |
|---|---|---|
| 0 | — (git branch only) | Yes |
| 1 | `types.f90` — add fields + new init | Yes |
| 2 | `hamiltonian.f90` — add 5 new routines | Yes |
| 3 | `input_reader.f90` — add keys + conditional validation | Yes |
| 4 | `qutu.f90` — add dispatch branches + conditional output | Yes |
| 5 | `constants.f90` — add threshold constant | Yes |
| T1 | `tests/unit/` — 3 new test files + README update | Yes |
| T2 | `tests/validation/` — 4 new test files + README update | Yes |
| T3 | `tests/integration/` — 2 new test files + README update | Yes |
| E1 | `examples/02_ph3_inversion/` — PH3 symmetric polynomial example | Yes |
| E2 | `examples/03_asymmetric_double_well/` — generic cubic-quartic asymmetric example | Yes |
| E3 | `examples/01_basic_NH3/README.md` — 2 small updates | Yes |
| D1 | `docs/user_guide/INPUT_GUIDE.md` — polynomial mode + 3-method mass section | Yes |
| D2 | `docs/developer_guide/TODO.md` — mark done, add follow-ups | Yes |
| D3 | `docs/developer_guide/GENERALIZATION_PLAN.md` — superseded header | Yes |
| D4 | `docs/theory/latex/sections/14_general_case.tex` + recompile PDF | Yes |
| D5 | `README.md` — add polynomial mode mention | Yes |

---

## Confirmed Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Branch name | `dev/generalization-potential` |
| 2 | Input syntax | Single comma-separated line: `v_coeffs = v₀,v₁,...` |
| 3 | HO center x₀ | Default to 0 (barrier-top option deferred to future work) |
| 4 | LAPACK solver | Switch to banded `DSBEV` now in both symmetric and asymmetric paths |

---

## GitHub Workflow

### Initial setup

```bash
# Create branch from up-to-date main
git checkout main
git pull origin main
git checkout -b dev/generalization-potential
git push -u origin dev/generalization-potential
```

### Committing incrementally

Commit after **each completed phase** — never batch multiple phases in one commit.
This makes bisecting and reviewing straightforward.

```bash
# After each phase:
git add src/modules/types.f90            # Phase 1 example
git commit -m "feat: add polynomial potential fields to system_params_t (Phase 1)"

git add src/modules/hamiltonian.f90
git commit -m "feat: add compute_xk_matrix and polynomial Hamiltonian routines (Phase 2)"

git add src/modules/input_reader.f90
git commit -m "feat: parse polynomial INPUT keys and three-tier mass specification (Phase 3)"

git add src/main/qutu.f90
git commit -m "feat: dispatch symmetric/asymmetric path in main program (Phase 4)"

git add src/modules/constants.f90
git commit -m "chore: add SYMMETRY_THRESHOLD constant (Phase 5)"

# Testing phases
git add tests/unit/
git commit -m "test: unit tests for xk recursion and parity detection (T1)"

git add tests/validation/
git commit -m "test: validation — NH3 regression, polynomial equivalence, harmonic limit, asymmetric convergence (T2)"

git add tests/integration/
git commit -m "test: integration — full pipeline symmetric and asymmetric (T3)"

# Examples
git add examples/02_ph3_inversion/
git commit -m "docs: add PH3 umbrella inversion example (polynomial mode) (E1)"

git add examples/03_asymmetric_double_well/
git commit -m "docs: add asymmetric double-well proton-transfer example (E2)"

git add examples/01_basic_NH3/README.md
git commit -m "docs: update NH3 README — DSBEV solver, fix broken link (E3)"

# Documentation
git add docs/user_guide/INPUT_GUIDE.md
git commit -m "docs: document polynomial mode and mass specification methods (D1)"

git add docs/developer_guide/TODO.md docs/developer_guide/GENERALIZATION_PLAN.md
git commit -m "docs: update TODO, mark GENERALIZATION_PLAN superseded (D2/D3)"

git add docs/theory/latex/sections/14_general_case.tex docs/theory/theory.pdf
git commit -m "docs: add DSBEV note to Section 14, recompile PDF (D4)"

git add README.md
git commit -m "docs: mention polynomial potential mode in project README (D5)"
```

### Pull request

Open the PR **only after T2 validation passes** (not just T1 unit tests).

```bash
gh pr create \
  --base main \
  --head dev/generalization-potential \
  --title "feat: generalize to arbitrary polynomial potentials V(x) = Σ vₖxᵏ" \
  --body "$(cat <<'EOF'
## Summary
- Adds general polynomial potential mode `V(x) = Σ_{k=0}^{K} v_k x^k`
- Auto-detects parity symmetry (fast block-diagonal path preserved)
- Switches LAPACK solver to banded DSBEV for both paths
- Adds three-tier mass specification (direct / XYn formula / legacy NH3)
- Adds PH3 and asymmetric H-bond proton-transfer examples
- Full test coverage: unit (T1), validation (T2), integration (T3)

## Backward compatibility
All existing NH3 INPUT files continue to work unchanged (legacy mode active
whenever `poly_degree`/`v_coeffs` keys are absent).

## Test plan
- [ ] `make test-unit` — all T1 tests pass
- [ ] `make test-validation` — NH3 regression within 1e-10 Eh, polynomial
      equivalence within 1e-8 Eh, harmonic limit within 1e-6 relative
- [ ] `make test-integration` — full pipeline for symmetric and asymmetric cases
- [ ] Manual: run examples/02 and examples/03 and inspect OUTPUT

🤖 Generated with Claude Code
EOF
)"
```

---

## Session State / Progress Tracker

> **HOW TO USE THIS SECTION**
> Update the status column at the end of each session before closing.
> Statuses: `PLANNED` → `IN PROGRESS` → `DONE` → `BLOCKED`
> Add a note in the "Notes / blockers" column whenever you stop mid-phase.
> At the start of a new session, read this table first to know where to resume.
>
> **If you are running low on context** (Claude usage limit approaching), stop after
> completing the current phase, update this table, and commit + push the branch so
> work is not lost. Do NOT start a new phase if you cannot finish it.

### Source phases

| Phase | Description | Status | Notes / blockers |
|---|---|---|---|
| 0 | Create git branch | DONE | `dev/generalization-potential` on GitHub |
| 1 | `types.f90` — add polynomial fields | DONE | `init_system_params_poly`, parity auto-detect |
| 2 | `hamiltonian.f90` — add 6 new routines | DONE | N_work=N_basis+k buffer fix for boundary truncation |
| 3 | `input_reader.f90` — parse polynomial keys | DONE | three-tier mass priority |
| 4 | `qutu.f90` — dispatch symmetric/asymmetric | DONE | all polynomial cases use build_hamiltonian_full |
| 5 | `constants.f90` — add SYMMETRY_THRESHOLD | DONE | 1e-12 |

### Testing phases

| Phase | Description | Status | Notes / blockers |
|---|---|---|---|
| T1 | Unit tests (`tests/unit/`) | DONE | 9/9 pass |
| T2 | Validation tests (`tests/validation/`) | DONE | 4/4 pass |
| T3 | Integration tests (`tests/integration/`) | DONE | 2/2 pass |

### Examples phases

| Phase | Description | Status | Notes / blockers |
|---|---|---|---|
| E1 | `examples/02_ph3_inversion/` | DONE | Symmetric polynomial PH3 example |
| E2 | `examples/03_asymmetric_double_well/` | DONE | Proton transfer asymmetric DW |
| E3 | Update `examples/01_basic_NH3/README.md` | DONE | Fixed broken CUSTOM_POTENTIALS.md link |

### Documentation phases

| Phase | Description | Status | Notes / blockers |
|---|---|---|---|
| D1 | `docs/user_guide/INPUT_GUIDE.md` | DONE | Polynomial mode section added |
| D2 | `docs/developer_guide/TODO.md` | DONE | Completed section + future enhancements |
| D3 | `docs/developer_guide/GENERALIZATION_PLAN.md` | DONE | SUPERSEDED header added |
| D4 | `docs/theory/latex/sections/14_general_case.tex` | DONE | dsyev note (PDF recompile: manual, needs pdflatex) |
| D5 | `README.md` project root | DONE | Polynomial potential section + examples pointers |

### Overall status (last updated: 2026-03-20)

**Status: ALL PHASES COMPLETE.** Branch `dev/generalization-potential` is fully
implemented and pushed. Ready for review and merge to `main`.

**Not implemented (deferred to future work):**
- Banded LAPACK solver (DSBEV) — currently uses dense DSYEV; tracked in Future enhancements
- PDF recompile of theory document — requires local pdflatex installation
2. Compute exact PH3 v_coeffs in atomic units from Spirko (1983) Vb/xe values
   before writing `examples/02_ph3_inversion/INPUT`.
3. Confirm DSBEV calling convention in the installed LAPACK version on this machine
   before Phase 4 (`ldd src/qutu` or `pkg-config --libs lapack`).
