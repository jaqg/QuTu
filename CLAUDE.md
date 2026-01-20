# CLAUDE.md - Compact Version

Quantum tunneling simulation in 1D double-well potential (NH3 inversion). Variational method with harmonic oscillator basis.

## Quick Build
```bash
cd src && ./exec.sh
# Manual: gfortran doble_pozo_NH3.f90 subrutinas/*.f90 -o doble_pozo_NH3 -L/usr/local/lib/ -llapack -lblas
```
Dependencies: gfortran, LAPACK, BLAS

## Code Structure
**Main:** `doble_pozo_NH3.f90` - Hamiltonian construction, diagonalization (LAPACK dsyev), wave packet dynamics

**Modules (subrutinas/):**
- `caracterizacion_sistema.f90` - V(x), turning points, reduced mass, alpha
- `modulo_integrales_hamiltoniano.f90` - Matrix elements: d²/dx², x², x⁴
- `modulo_OA1D.f90` - Harmonic basis: Hermite polynomials, phi_n(x)
- `probabilidad_supervivencia.f90` - Wave packet survival
- `valores_esperados.f90` - Expectation values

**Visualization:** `grafica/` (static), `animacion/` (dynamics)

## Key Files
**Input (data/):** `in-doble_pozo_NH3.dat` (N, xe, Vb), `in-potencial.dat` (grid), `in-masas_atomicas.dat` (masses)

**Output:** `out-energias*.dat`, `out-funciones_*.dat`, `out-densidad_prob_*.dat`, `out-probabilidad_supervivencia_*.dat`

## Physics
V(x) = (Vb/xe⁴)x⁴ - (2Vb/xe²)x² + Vb | NH3: xe=0.3816 Å, Vb=2028.6 cm⁻¹

Units: Atomic units ↔ (Å, cm⁻¹, amu). Constants in main program (NIST-2018).

---
Full documentation: CLAUDE-FULL.md
