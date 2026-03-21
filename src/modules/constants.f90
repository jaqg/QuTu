! =============================================================================
! Module: constants
! Description: Physical constants and precision definitions for quantum
!              tunneling calculations in the NH3 double-well potential model.
! Author: Jose Antonio Quinonero Gris
! =============================================================================
module constants
    implicit none
    private

    ! -------------------------------------------------------------------------
    ! Precision definition (portable double precision)
    ! -------------------------------------------------------------------------
    integer, parameter, public :: dp = selected_real_kind(15, 307)

    ! -------------------------------------------------------------------------
    ! Mathematical constants
    ! -------------------------------------------------------------------------
    real(dp), parameter, public :: PI = 4.0_dp * atan(1.0_dp)

    ! -------------------------------------------------------------------------
    ! Physical constants (NIST CODATA-2018)
    ! -------------------------------------------------------------------------

    ! Bohr radius in Angstrom
    real(dp), parameter, public :: RBOHR = 0.529177210903_dp

    ! Conversion factor: Hartree to cm^-1
    real(dp), parameter, public :: EUACM = 2.1947463136320e5_dp

    ! Atomic mass unit in grams
    real(dp), parameter, public :: UMA = 1.66053906660e-24_dp

    ! Electron mass in grams
    real(dp), parameter, public :: PELEC = 9.1093837015e-28_dp

    ! Conversion factor: Hartree to Joules
    real(dp), parameter, public :: EHAJ = 4.3597447222071e-18_dp

    ! Planck constant in J*s
    real(dp), parameter, public :: HP = 6.62607015e-34_dp

    ! Reduced Planck constant (hbar) in J*s
    real(dp), parameter, public :: HBAR_SI = HP / (2.0_dp * PI)

    ! Atomic unit value of hbar (dimensionless, = 1 in a.u.)
    real(dp), parameter, public :: HBAR_AU = 1.0_dp

    ! -------------------------------------------------------------------------
    ! Derived conversion factors
    ! -------------------------------------------------------------------------

    ! Conversion factor: atomic mass unit to atomic unit of mass
    real(dp), parameter, public :: UMA_TO_AU = UMA / PELEC

    ! Conversion factor: Angstrom to Bohr
    real(dp), parameter, public :: ANGSTROM_TO_BOHR = 1.0_dp / RBOHR

    ! Conversion factor: cm^-1 to Hartree
    real(dp), parameter, public :: CM_TO_HARTREE = 1.0_dp / EUACM

    ! -------------------------------------------------------------------------
    ! Numerical thresholds
    ! -------------------------------------------------------------------------

    ! Coefficient threshold for wavefunction calculations
    real(dp), parameter, public :: COEFF_THRESHOLD = 0.001_dp

    ! Energy convergence threshold
    real(dp), parameter, public :: ENERGY_CONV_THRESHOLD = 1.0e-5_dp

    ! Threshold for odd-coefficient parity symmetry detection
    real(dp), parameter, public :: SYMMETRY_THRESHOLD = 1.0e-12_dp

end module constants
