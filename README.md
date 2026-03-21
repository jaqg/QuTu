# QuTu - Quantum Tunneling Simulation in 1D Potentials

**Quantum mechanical simulation of tunneling in one-dimensional double-well potentials using the variational method with harmonic oscillator basis functions.**

[![Fortran](https://img.shields.io/badge/Fortran-2008-blue.svg)](https://fortran-lang.org/)
[![License: GPL v3](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)

## Features

- **Variational Method**: Uses harmonic oscillator basis functions for accurate eigenstate calculations
- **LAPACK Integration**: Efficient Hamiltonian diagonalization using industry-standard linear algebra
- **Wave Packet Dynamics**: Time-dependent simulation with survival probability analysis
- **General Polynomial Potential**: Solve V(x) = Σ vₖ xᵏ for any polynomial degree — symmetric or asymmetric
- **NH3 Support**: Pre-configured for ammonia (NH3) umbrella inversion mode (backward compatible)
- **Unit Flexibility**: Atomic units internally with conversion to Angstroms and cm⁻¹
- **Modular Architecture**: Clean, modern Fortran 2008 codebase

### Polynomial Potential Mode

Any polynomial potential can be specified directly in the INPUT file:

```
poly_degree = 4
v_coeffs    = 0.0, 0.002, -0.027, 0.0, 0.010   # Ha/a0^k
mass        = 1.007276                           # amu
```

Parity symmetry is auto-detected: if all odd-power coefficients are zero, the fast block-diagonal solver is used automatically. See `docs/user_guide/INPUT_GUIDE.md` for full documentation and `examples/02_ph3_inversion/` (symmetric) and `examples/03_asymmetric_double_well/` (asymmetric) for worked examples.

## Quick Start

### Prerequisites

- **gfortran** compiler (GCC Fortran)
- **LAPACK** and **BLAS** libraries
- Python 3.x (optional, for visualization)

### Build

```bash
cd quantum-tunnelling
make
```

This creates the executable `QuTu` in the `build/release/` directory.

### Run

```bash
./build/release/QuTu
```

Results are written to the `data/` directory (created automatically).

## Installation

### System Requirements

- Linux, macOS, or Windows (with WSL/MinGW)
- gfortran 7.0 or higher
- LAPACK/BLAS (via OS package manager)

### Detailed Build Instructions

#### Ubuntu/Debian
```bash
sudo apt-get install gfortran liblapack-dev libblas-dev
cd quantum-tunnelling
make clean
make
```

#### macOS (with Homebrew)
```bash
brew install gcc lapack openblas
cd quantum-tunnelling
make clean
make
```

#### Build Options
```bash
make              # Standard build
make debug        # Debug build with extra checks
make release      # Optimized build for production
make clean        # Remove build artifacts
make help         # Show all available targets
```

## Project Structure

```
quantum-tunnelling/
├── src/
│   ├── main/              # Main program
│   │   └── qutu.f90
│   ├── modules/           # Fortran modules
│   │   ├── constants.f90
│   │   ├── types.f90
│   │   ├── input_reader.f90
│   │   ├── harmonic_oscillator.f90
│   │   ├── hamiltonian.f90
│   │   ├── wavepacket.f90
│   │   └── io.f90
│   └── visualization/     # Python visualization scripts
│       ├── core/
│       ├── static/
│       └── animation/
├── tests/                 # Test suite
│   ├── unit/
│   ├── integration/
│   └── validation/
├── build/                 # Build artifacts (gitignored)
│   ├── debug/
│   └── release/
├── docs/                  # Documentation
│   ├── user_guide/        # User documentation
│   ├── developer_guide/   # Developer documentation
│   ├── theory/            # Mathematical formulation
│   └── references/        # Bibliography and papers
├── examples/              # Tutorial examples
│   └── 01_basic_NH3/      # Basic NH3 inversion example
├── scripts/               # Utility scripts
├── config/                # Configuration templates
│   └── INPUT.template
├── INPUT                  # Example input file
├── Makefile               # Build system
├── README.md              # This file
└── CITATION.cff           # Citation metadata
```

## Usage

### Basic Workflow

1. **Configure**: Edit the `INPUT` file with your parameters
2. **Build**: Run `make` to compile the code
3. **Execute**: Run `./build/release/QuTu`
4. **Analyze**: Results are in `data/` directory

### INPUT File

The simulation is configured via the `INPUT` file. See `docs/user_guide/INPUT_GUIDE.md` for detailed documentation.

**Basic structure**:
```
# Basis set
N_max = 200          # Number of basis functions

# Potential parameters
xe = 0.3816          # Equilibrium position (Angstroms)
Vb = 2028.6          # Barrier height (cm^-1)

# Atomic masses
mass_H = 1.00782503207
mass_N = 14.0030740048

# Grid parameters
xmin = -5.0          # Grid minimum (a0)
xmax = 5.0           # Grid maximum (a0)
dx = 0.02            # Grid spacing (a0)
```

### Output Files

All outputs are written to `data/` (created automatically):

| File | Description |
|------|-------------|
| `out-energias*.dat` | Energy eigenvalues |
| `out-funciones_*.dat` | Wavefunctions on grid |
| `out-densidad_prob_*.dat` | Probability densities |
| `out-probabilidad_supervivencia_*.dat` | Wave packet survival probability |

## Examples

### NH3 Umbrella Inversion

A complete tutorial example is provided in `examples/01_basic_NH3/`:

```bash
cd examples/01_basic_NH3
./run.sh
```

This demonstrates:
- NH3 double-well potential setup
- Energy level calculations
- Tunneling splitting analysis
- Wave function visualization
- Comparison with literature values

See `examples/01_basic_NH3/README.md` for detailed tutorial.

## Documentation

### User Documentation
- **Quick Start**: This README
- **Input Guide**: `docs/user_guide/INPUT_GUIDE.md`
- **Examples**: `examples/*/README.md`

### Developer Documentation
- **Architecture**: `docs/developer_guide/ARCHITECTURE.md`
- **Code Structure**: `docs/developer_guide/IMPLEMENTATION_REPORT.md`
- **TODO List**: `docs/developer_guide/TODO.md`
- **Generalization Plan**: `docs/developer_guide/GENERALIZATION_PLAN.md`

### Theory
- **Mathematical Formulation**: `docs/theory/` (LaTeX documents)
- **Physics Background**: See references below

## Physics Background

The program solves the time-independent Schrödinger equation for a 1D double-well potential:

$$\hat{H}\psi = E\psi$$

using the variational method with harmonic oscillator basis functions:

$$\psi(x) = \sum_{n=0}^{N_{max}} c_n \phi_n(x)$$

where $\phi_n(x)$ are harmonic oscillator eigenfunctions.

### NH3 Double-Well Potential

The NH3 inversion potential is modeled as:

$$V(x) = \frac{V_b}{x_e^4}x^4 - \frac{2V_b}{x_e^2}x^2 + V_b$$

with parameters from NIST:
- $x_e = 0.3816$ Å (equilibrium position)
- $V_b = 2028.6$ cm⁻¹ (barrier height)

## Testing

```bash
make test            # Run all tests (to be implemented)
make test-unit       # Unit tests
make test-integration # Integration tests
make test-validation  # Physics validation tests
```

## Contributing

This is a research code. Contributions are welcome:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

See `docs/developer_guide/` for development guidelines.

## Roadmap

### Current Version (1.0)
- ✅ NH3 double-well potential
- ✅ Variational method with harmonic oscillator basis
- ✅ Time-dependent wave packet dynamics
- ✅ Modern Fortran modular structure

### Future Enhancements
- 🔄 Generalization to arbitrary 1D potentials (planned)
- 🔄 Potential library (harmonic, Morse, Pöschl-Teller, etc.)
- 🔄 User-definable potential functions
- 🔄 Comprehensive test suite
- 🔄 Python visualization package
- 🔄 Multi-dimensional potentials (2D, 3D)

See `docs/developer_guide/GENERALIZATION_PLAN.md` for detailed roadmap.

## Performance

Typical performance on modern hardware:
- **N_max = 200**: ~5-10 seconds
- **Wave packet dynamics**: ~30-60 seconds
- **Memory**: < 100 MB

Scales approximately as O(N³) due to matrix diagonalization.

## References

### NH3 Inversion
- Swalen, J. D., & Ibers, J. A. (1962). Potential function for the inversion of ammonia. *J. Chem. Phys.*, 36(7), 1914-1918.
- Townes, C. H., & Schawlow, A. L. (1955). *Microwave Spectroscopy*. McGraw-Hill.

### Computational Methods
- Szabo, A., & Ostlund, N. S. (1996). *Modern Quantum Chemistry*. Dover Publications.
- Levine, I. N. (2014). *Quantum Chemistry* (7th ed.). Pearson.

### Atomic Data
- NIST Atomic Spectra Database: https://www.nist.gov/pml/atomic-spectra-database
- CODATA Fundamental Physical Constants (2018)

## Related Repositories

- **[NH3-double-well-v1](https://github.com/jaqg/NH3-double-well-v1)** —
  Intermediate refactored version, used as a starting point for student TFG projects.
- **[NH3-double-well-v0-TFG](https://github.com/jaqg/NH3-double-well-v0-TFG)** —
  Original Bachelor's Thesis code (archived). Historical reference only.

## License

This program is free software: you can redistribute it and/or modify it under the terms
of the **GNU General Public License v3** as published by the Free Software Foundation.
See the [LICENSE](LICENSE) file for details.

## Citation

If you use this code in your research, please cite:

```bibtex
@software{qutu2026,
  author       = {Quinonero Gris, Jose Antonio},
  title        = {QuTu: Quantum Tunneling Simulation in 1D Double-Well Potentials},
  year         = {2026},
  url          = {https://github.com/jaqg/QuTu},
  license      = {GPL-3.0},
  version      = {2.0.0}
}
```

A `CITATION.cff` file is also provided for GitHub's "Cite this repository" button.

## Contact

**Author**: Jose Antonio Quinonero Gris
**Institution**: Universidad de Murcia
**Repository**: https://github.com/jaqg/QuTu

## Acknowledgments

- NIST for atomic data and physical constants
- LAPACK developers for numerical linear algebra routines
- The Fortran community for modern language development

---

**Version**: 2.0.0
**Last Updated**: 2026-02-28
**Status**: Production Ready
