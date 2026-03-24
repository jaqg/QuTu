"""Validation test: parse a real OUTPUT file from examples/.

Skipped automatically when the file is not present.
"""

import sys
from pathlib import Path

import numpy as np
import pytest

SCRIPTS = Path(__file__).parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import parse_output as _po

EXAMPLE_OUTPUT = (
    Path(__file__).parents[2] / "examples" / "01_basic_NH3" / "OUTPUT"
)


@pytest.fixture(scope="module")
def data():
    if not EXAMPLE_OUTPUT.exists():
        pytest.skip(f"Example OUTPUT not found: {EXAMPLE_OUTPUT}")
    return _po.parse_output(str(EXAMPLE_OUTPUT))


class TestAllSectionsPresent:
    def test_potential_present(self, data):
        assert data["POTENTIAL"] is not None

    def test_energies_present(self, data):
        assert data["ENERGIES"] is not None

    def test_wavefunctions_present(self, data):
        assert data["WAVEFUNCTIONS"] is not None

    def test_densities_present(self, data):
        assert data["DENSITIES"] is not None


class TestEnergiesConsistency:
    def test_energies_ascending(self, data):
        en = data["ENERGIES"]
        E  = en["E_cm"]
        assert np.all(E[1:] >= E[:-1]), "Energies must be non-decreasing"

    def test_energies_non_negative(self, data):
        en = data["ENERGIES"]
        assert np.all(en["E_cm"] >= 0.0), "All energies must be >= 0 (ground-state ref)"

    def test_at_least_four_levels(self, data):
        assert len(data["ENERGIES"]) >= 4


class TestWavefunctionConsistency:
    def test_x_grid_matches_potential(self, data):
        """WAVEFUNCTIONS and POTENTIAL must share the same x-grid (Å)."""
        wf   = data["WAVEFUNCTIONS"]
        pot  = data["POTENTIAL"]
        if pot is None:
            pytest.skip("POTENTIAL not present")
        np.testing.assert_allclose(
            wf[:, 1], pot[:, 1], atol=1e-4,
            err_msg="WAVEFUNCTIONS x(A) grid differs from POTENTIAL x(A) grid",
        )

    def test_density_equals_wf_squared(self, data):
        """DENSITIES[:, 2+n] should equal WAVEFUNCTIONS[:, 2+n]² (within tolerance).

        Both sections use Fortran F14.6 format (6 decimal places), so values
        below ~5e-7 are rounded to 0.000000.  We use atol=2e-6 to account for
        this format-level truncation in either column.
        """
        wf   = data["WAVEFUNCTIONS"]
        dens = data["DENSITIES"]
        if dens is None:
            pytest.skip("DENSITIES not present")
        for n in range(min(6, wf.shape[1] - 2)):
            np.testing.assert_allclose(
                dens[:, 2 + n],
                wf[:, 2 + n] ** 2,
                atol=2e-6,
                err_msg=f"DENSITIES col {n} does not equal WAVEFUNCTIONS col {n}²",
            )

    def test_wavefunctions_shape(self, data):
        wf = data["WAVEFUNCTIONS"]
        assert wf.ndim == 2
        assert wf.shape[1] == 8   # x_a0, x_A, Phi0..Phi5


class TestAlphaIndexedSections:
    def test_survival_4state_values_in_0_1(self, data):
        s4 = data["SURVIVAL_4STATE"]
        if s4 is None:
            pytest.skip("SURVIVAL_4STATE not present")
        for alpha, arr in s4.items():
            Ps = arr[:, 2]
            assert np.all(Ps >= -1e-6), "Survival probability must be >= 0"
            assert np.all(Ps <= 1.0 + 1e-6), "Survival probability must be <= 1"

    def test_expectation_x_is_finite(self, data):
        ex = data["EXPECTATION_X"]
        if ex is None:
            pytest.skip("EXPECTATION_X not present")
        for alpha, arr in ex.items():
            assert np.all(np.isfinite(arr[:, 2])), "<x>(t) must be finite"
