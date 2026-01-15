# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a computational quantum mechanics project that studies quantum tunneling in a 1D double-well potential model, specifically applied to the ammonia (NH3) molecule inversion problem. The system uses the variational method with harmonic oscillator basis functions to solve the Schrödinger equation.

## Build and Run Commands

```bash
# Compile and run the main Fortran program (from src/ directory)
cd src
./exec.sh

# Or manually:
gfortran doble_pozo_NH3.f90 subrutinas/*.f90 -o doble_pozo_NH3 -L/usr/local/lib/ -llapack -lblas
./doble_pozo_NH3
```

**Dependencies:** gfortran, LAPACK, BLAS

## Code Architecture

### Core Fortran Code (src/)

- **doble_pozo_NH3.f90** - Main program that:
  - Constructs and diagonalizes the Hamiltonian matrix in the harmonic oscillator basis
  - Exploits parity symmetry by separating even/odd basis functions
  - Computes variational energies, wavefunctions, and probability densities
  - Calculates wave packet dynamics (survival probability, recurrence time, expectation values)
  - Uses LAPACK's `dsyev` for eigenvalue problems

- **subrutinas/** - Fortran modules:
  - `caracterizacion_sistema.f90` - System characterization: potential V(x), turning points, reduced mass, optimal alpha parameter
  - `modulo_integrales_hamiltoniano.f90` - Hamiltonian matrix elements: kinetic (d²/dx²), quadratic (x²), quartic (x⁴) integrals in harmonic basis
  - `modulo_OA1D.f90` - 1D harmonic oscillator eigenfunctions: Hermite polynomials (recursive), phi_n(x) basis functions
  - `probabilidad_supervivencia.f90` - Survival probability calculations for wave packets
  - `valores_esperados.f90` - Expectation value calculations (position, etc.)

### Visualization (Python)

- **src/grafica/** - Static plots: wavefunctions, probability densities, potential curves, convergence plots
- **src/animacion/** - Wave packet animations using matplotlib

### Input/Output (src/data/)

**Input files:**
- `in-doble_pozo_NH3.dat` - N (basis size), xe (equilibrium position in Å), Vb (barrier height in cm⁻¹)
- `in-potencial.dat` - xmin, xmax, dx (grid parameters)
- `in-masas_atomicas.dat` - Hydrogen and nitrogen masses (in amu)

**Output files:** Results in both atomic units (Hartree, a₀) and conventional units (cm⁻¹, Å)
- `out-energias*.dat` - Variational energies
- `out-funciones_*.dat` - Wavefunctions
- `out-densidad_prob_*.dat` - Probability densities
- `out-probabilidad_supervivencia_*.dat` - Wave packet survival probabilities
- `out-val_esp_x_*.dat` - Position expectation values vs time

## Physical Model

The double-well potential: V(x) = (Vb/xe⁴)x⁴ - (2Vb/xe²)x² + Vb

where:
- xe = equilibrium position (well minima at ±xe)
- Vb = barrier height at x=0

NH3 parameters (default): xe = 0.3816 Å, Vb = 2028.6 cm⁻¹

## Unit Conversions

The code works internally in atomic units and converts to/from:
- Length: Bohr radius (a₀) ↔ Angstrom (Å)
- Energy: Hartree (Ha) ↔ cm⁻¹
- Mass: electron mass ↔ amu

Key constants are defined in the main program header (NIST CODATA-2018 values).

## Git Workflow

This project uses a simplified Git Flow workflow:

### Branch Structure

- **main**: Stable, production-ready code. Direct commits discouraged.
- **develop**: Active development branch. Features are merged here first.
- **feature/\***: Feature branches created from `develop` (e.g., `feature/new-potential`)
- **hotfix/\***: Emergency fixes created from `main`

### Workflow Guidelines

```bash
# Start new feature
git checkout develop
git pull origin develop
git checkout -b feature/your-feature-name

# Work on feature, commit regularly
git add -A
git commit -m "Description of changes"

# When feature is complete, merge to develop
git checkout develop
git merge --no-ff feature/your-feature-name
git branch -d feature/your-feature-name

# For releases: merge develop to main
git checkout main
git merge --no-ff develop
git tag -a v1.0.0 -m "Release version 1.0.0"
```

### Commit Message Convention

Use clear, descriptive messages:
- `Add`: New feature or file
- `Update`: Enhancement to existing feature
- `Fix`: Bug fix
- `Refactor`: Code restructuring without behavior change
- `Docs`: Documentation only

### Files Tracked vs Ignored

**Tracked (in git):**
- All `.f90` source files
- All `.py` visualization scripts
- Input data files (`in-*.dat`)
- Documentation and scripts

**Ignored (not tracked):**
- Compiled files (`*.o`, `*.mod`, executables)
- Output data (`out-*.dat`)
- Generated graphics (`*.pdf`, `*.svg`, `*.mp4`)
- Backup files (`*.bak`)
