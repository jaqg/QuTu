"""Unit tests for scripts/parse_output.py."""

import sys
import textwrap
from pathlib import Path

import numpy as np
import pytest

# Make scripts/ importable
SCRIPTS = Path(__file__).parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import parse_output as _po


# ---------------------------------------------------------------------------
# Fixtures / mock data builders
# ---------------------------------------------------------------------------

def _make_file(tmp_path, content: str) -> str:
    p = tmp_path / "OUTPUT"
    p.write_text(textwrap.dedent(content))
    return str(p)


MOCK_POTENTIAL = """
$BEGIN POTENTIAL
# columns: x(a0)   x(A)   V(Ha)   V(cm-1)
#
  -2.0000  -1.0584   0.12345678   2709.8200
  -1.0000  -0.5292   0.05000000   1097.3700
   0.0000   0.0000   0.00000000      0.0000
   1.0000   0.5292   0.05000000   1097.3700
   2.0000   1.0584   0.12345678   2709.8200
$END POTENTIAL
"""

MOCK_ENERGIES_SYMMETRIC = """
$BEGIN ENERGIES
# columns: n   parity   E(Ha)   E(cm-1)
#
   0   even   0.0012345678    271.1200
   1   odd    0.0013456789    295.5000
   2   even   0.0045678900   1002.8700
   3   odd    0.0047890100   1051.4200
$END ENERGIES
"""

MOCK_ENERGIES_ASYMMETRIC = """
$BEGIN ENERGIES
# columns: n   E(Ha)   E(cm-1)
#
   0   0.0012345678    271.1200
   1   0.0013456789    295.5000
   2   0.0045678900   1002.8700
$END ENERGIES
"""

MOCK_CONVERGENCE = """
$BEGIN CONVERGENCE
# columns: n   N_conv   E_conv(Ha)   E_conv(cm-1)   E_max(Ha)   E_max(cm-1)
#
  0     10   0.0012345678    271.1200   0.0012345678    271.1200
  1     12   0.0013456789    295.5000   0.0013456789    295.5000
$END CONVERGENCE
"""

MOCK_WAVEFUNCTIONS = """
$BEGIN WAVEFUNCTIONS
# Phi0,Phi2,Phi4 are even-parity; Phi1,Phi3,Phi5 are odd-parity
# columns: x(a0)   x(A)   Phi0..Phi5
#
  -1.0000  -0.5292   0.123456   0.234567   0.000100   0.000200   0.000010   0.000020
   0.0000   0.0000   0.987654   0.876543   0.001000   0.002000   0.000100   0.000200
   1.0000   0.5292   0.123456   0.234567   0.000100   0.000200   0.000010   0.000020
$END WAVEFUNCTIONS
"""

MOCK_DENSITIES = """
$BEGIN DENSITIES
# columns: x(a0)   x(A)   |Phi0|^2...|Phi5|^2
#
  -1.0000  -0.5292   0.015241   0.055022   0.000000   0.000000   0.000000   0.000000
   0.0000   0.0000   0.975459   0.768327   0.000001   0.000004   0.000000   0.000000
   1.0000   0.5292   0.015241   0.055022   0.000000   0.000000   0.000000   0.000000
$END DENSITIES
"""

MOCK_SURVIVAL_2STATE = """
$BEGIN SURVIVAL_2STATE
# Psi_A = (Phi0+Phi1)/sqrt(2)   Psi_C = (Phi2+Phi3)/sqrt(2)
# columns: t(ps)   Ps_A(t)   Ps_C(t)
#
  0.0000   1.000000   0.000000
  0.1000   0.998000   0.002000
  0.2000   0.992000   0.008000
$END SURVIVAL_2STATE
"""

MOCK_SURVIVAL_4STATE = """
$BEGIN SURVIVAL_4STATE
# columns: alpha(deg)   t(ps)   Ps(t)
#
   0.00   0.00000   1.000000
   0.00   0.10000   0.998000
  45.00   0.00000   1.000000
  45.00   0.10000   0.950000
$END SURVIVAL_4STATE
"""

MOCK_WAVEPACKETS_4STATE = """
$BEGIN WAVEPACKETS_4STATE
# columns: alpha(deg)   x(A)   Psi   |Psi|^2   E(cm-1)
#
    0.00  -0.5292   0.123456   0.015241    271.1200
    0.00   0.0000   0.987654   0.975459    271.1200
    0.00   0.5292   0.123456   0.015241    271.1200
   45.00  -0.5292   0.234567   0.055022    500.0000
   45.00   0.0000   0.876543   0.768327    500.0000
   45.00   0.5292   0.234567   0.055022    500.0000
$END WAVEPACKETS_4STATE
"""

MOCK_COEFFICIENTS = """
$BEGIN COEFFICIENTS
# Even states (Phi0, Phi2, Phi4): basis index = 0, 2, 4, ...
# Odd  states (Phi1, Phi3, Phi5): basis index = 1, 3, 5, ...
# columns: i   parity   c_i(Phi0)   c_i(Phi2)   c_i(Phi4)   c_i(Phi1)   c_i(Phi3)   c_i(Phi5)
#
   0 even   0.707107   0.000001   0.000000    1 odd    0.707107   0.000001   0.000000
   2 even   0.000001   0.707107   0.000000    3 odd    0.000001   0.707107   0.000000
$END COEFFICIENTS
"""


# ---------------------------------------------------------------------------
# Tests: parse_output / list_sections
# ---------------------------------------------------------------------------

class TestListSections:
    def test_returns_present_sections(self, tmp_path):
        content = MOCK_POTENTIAL + MOCK_ENERGIES_SYMMETRIC
        path = _make_file(tmp_path, content)
        secs = _po.list_sections(path)
        assert "POTENTIAL" in secs
        assert "ENERGIES" in secs

    def test_order_preserved(self, tmp_path):
        content = MOCK_ENERGIES_SYMMETRIC + MOCK_POTENTIAL
        path = _make_file(tmp_path, content)
        secs = _po.list_sections(path)
        assert secs.index("ENERGIES") < secs.index("POTENTIAL")

    def test_empty_file(self, tmp_path):
        path = _make_file(tmp_path, "")
        assert _po.list_sections(path) == []


class TestPotential:
    def test_shape(self, tmp_path):
        path = _make_file(tmp_path, MOCK_POTENTIAL)
        d = _po.parse_output(path)
        arr = d["POTENTIAL"]
        assert arr.shape == (5, 4)

    def test_dtype_float(self, tmp_path):
        path = _make_file(tmp_path, MOCK_POTENTIAL)
        arr = _po.parse_output(path)["POTENTIAL"]
        assert arr.dtype.kind == "f"

    def test_values(self, tmp_path):
        path = _make_file(tmp_path, MOCK_POTENTIAL)
        arr = _po.parse_output(path)["POTENTIAL"]
        # First row
        np.testing.assert_allclose(arr[0, 2], 0.12345678, rtol=1e-6)
        np.testing.assert_allclose(arr[0, 3], 2709.82,    rtol=1e-4)

    def test_symmetry(self, tmp_path):
        """x-grid should be symmetric around 0."""
        path = _make_file(tmp_path, MOCK_POTENTIAL)
        arr = _po.parse_output(path)["POTENTIAL"]
        np.testing.assert_allclose(arr[:, 1], -arr[::-1, 1], atol=1e-4)


class TestEnergiesSymmetric:
    def test_shape(self, tmp_path):
        path = _make_file(tmp_path, MOCK_ENERGIES_SYMMETRIC)
        en = _po.parse_output(path)["ENERGIES"]
        assert len(en) == 4

    def test_has_parity(self, tmp_path):
        path = _make_file(tmp_path, MOCK_ENERGIES_SYMMETRIC)
        en = _po.parse_output(path)["ENERGIES"]
        assert "parity" in en.dtype.names
        parities = [p.strip() for p in en["parity"]]
        assert parities == ["even", "odd", "even", "odd"]

    def test_ascending_E_cm(self, tmp_path):
        path = _make_file(tmp_path, MOCK_ENERGIES_SYMMETRIC)
        en = _po.parse_output(path)["ENERGIES"]
        E = en["E_cm"]
        assert np.all(E[1:] >= E[:-1])

    def test_indices(self, tmp_path):
        path = _make_file(tmp_path, MOCK_ENERGIES_SYMMETRIC)
        en = _po.parse_output(path)["ENERGIES"]
        assert list(en["n"]) == [0, 1, 2, 3]


class TestEnergiesAsymmetric:
    def test_no_parity(self, tmp_path):
        path = _make_file(tmp_path, MOCK_ENERGIES_ASYMMETRIC)
        en = _po.parse_output(path)["ENERGIES"]
        assert en["parity"][0].strip() == ""

    def test_shape(self, tmp_path):
        path = _make_file(tmp_path, MOCK_ENERGIES_ASYMMETRIC)
        en = _po.parse_output(path)["ENERGIES"]
        assert len(en) == 3


class TestAlphaIndexedSections:
    def test_survival_4state_keys(self, tmp_path):
        path = _make_file(tmp_path, MOCK_SURVIVAL_4STATE)
        d = _po.parse_output(path)["SURVIVAL_4STATE"]
        assert isinstance(d, dict)
        assert set(d.keys()) == {0.0, 45.0}

    def test_survival_4state_shape(self, tmp_path):
        path = _make_file(tmp_path, MOCK_SURVIVAL_4STATE)
        d = _po.parse_output(path)["SURVIVAL_4STATE"]
        assert d[0.0].shape == (2, 3)

    def test_wavepackets_4state_keys(self, tmp_path):
        path = _make_file(tmp_path, MOCK_WAVEPACKETS_4STATE)
        d = _po.parse_output(path)["WAVEPACKETS_4STATE"]
        assert set(d.keys()) == {0.0, 45.0}

    def test_wavepackets_4state_n_x(self, tmp_path):
        path = _make_file(tmp_path, MOCK_WAVEPACKETS_4STATE)
        d = _po.parse_output(path)["WAVEPACKETS_4STATE"]
        assert d[0.0].shape == (3, 5)   # 3 x-points, 5 columns


class TestCoefficients:
    def test_returns_dict(self, tmp_path):
        path = _make_file(tmp_path, MOCK_COEFFICIENTS)
        coef = _po.parse_output(path)["COEFFICIENTS"]
        assert isinstance(coef, dict)
        assert "even" in coef and "odd" in coef

    def test_even_fields(self, tmp_path):
        path = _make_file(tmp_path, MOCK_COEFFICIENTS)
        coef = _po.parse_output(path)["COEFFICIENTS"]
        assert "c_Phi0" in coef["even"].dtype.names

    def test_even_shape(self, tmp_path):
        path = _make_file(tmp_path, MOCK_COEFFICIENTS)
        coef = _po.parse_output(path)["COEFFICIENTS"]
        assert len(coef["even"]) == 2
        assert len(coef["odd"])  == 2

    def test_even_values(self, tmp_path):
        path = _make_file(tmp_path, MOCK_COEFFICIENTS)
        coef = _po.parse_output(path)["COEFFICIENTS"]
        np.testing.assert_allclose(coef["even"]["c_Phi0"][0], 0.707107, rtol=1e-5)


class TestMissingSection:
    def test_missing_returns_none(self, tmp_path):
        path = _make_file(tmp_path, MOCK_POTENTIAL)
        d = _po.parse_output(path)
        # Sections not in file should be None
        assert d["ENERGIES"] is None
        assert d["WAVEFUNCTIONS"] is None
        assert d["SURVIVAL_4STATE"] is None

    def test_all_known_sections_present_as_keys(self, tmp_path):
        path = _make_file(tmp_path, MOCK_POTENTIAL)
        d = _po.parse_output(path)
        for s in _po.KNOWN_SECTIONS:
            assert s in d


class TestGetSection:
    def test_valid_section(self, tmp_path):
        path = _make_file(tmp_path, MOCK_POTENTIAL)
        d = _po.parse_output(path)
        arr = _po.get_section(d, "POTENTIAL")
        assert arr is not None

    def test_unknown_section_raises(self, tmp_path):
        path = _make_file(tmp_path, MOCK_POTENTIAL)
        d = _po.parse_output(path)
        with pytest.raises(KeyError):
            _po.get_section(d, "NONEXISTENT")

    def test_absent_section_returns_none(self, tmp_path):
        path = _make_file(tmp_path, MOCK_POTENTIAL)
        d = _po.parse_output(path)
        assert _po.get_section(d, "ENERGIES") is None


class TestConvergence:
    def test_shape(self, tmp_path):
        path = _make_file(tmp_path, MOCK_CONVERGENCE)
        arr = _po.parse_output(path)["CONVERGENCE"]
        assert arr.shape == (2, 6)


class TestWavefunctions:
    def test_shape(self, tmp_path):
        path = _make_file(tmp_path, MOCK_WAVEFUNCTIONS)
        arr = _po.parse_output(path)["WAVEFUNCTIONS"]
        assert arr.shape == (3, 8)

    def test_x_grid_symmetric(self, tmp_path):
        path = _make_file(tmp_path, MOCK_WAVEFUNCTIONS)
        arr = _po.parse_output(path)["WAVEFUNCTIONS"]
        np.testing.assert_allclose(arr[0, 1], -arr[-1, 1], atol=1e-4)


class TestSurvival2State:
    def test_shape(self, tmp_path):
        path = _make_file(tmp_path, MOCK_SURVIVAL_2STATE)
        arr = _po.parse_output(path)["SURVIVAL_2STATE"]
        assert arr.shape == (3, 3)

    def test_t_starts_at_zero(self, tmp_path):
        path = _make_file(tmp_path, MOCK_SURVIVAL_2STATE)
        arr = _po.parse_output(path)["SURVIVAL_2STATE"]
        assert arr[0, 0] == pytest.approx(0.0)
