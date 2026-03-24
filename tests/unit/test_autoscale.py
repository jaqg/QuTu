"""Unit tests for visualize.auto_scale()."""

import sys
from pathlib import Path

import numpy as np
import pytest

SCRIPTS = Path(__file__).parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
from visualize import PlotState, auto_scale


def _make_energies(E_cm_values):
    """Build a minimal structured ENERGIES array."""
    dt = np.dtype([("n", int), ("parity", "U4"), ("E_Ha", float), ("E_cm", float)])
    rows = [(i, "", 0.0, float(e)) for i, e in enumerate(E_cm_values)]
    return np.array(rows, dtype=dt)


def _make_wavefunctions(x_arr, phi_arrays):
    """Build WAVEFUNCTIONS ndarray from x_arr and list of Phi_n arrays."""
    n_x = len(x_arr)
    n_phi = len(phi_arrays)
    # Pad to 6 columns + 2 x-columns = 8 total
    data = np.zeros((n_x, 8))
    data[:, 0] = x_arr / 0.529177   # x_a0
    data[:, 1] = x_arr              # x_A
    for k, phi in enumerate(phi_arrays):
        if k < 6:
            data[:, 2 + k] = phi
    return data


def _make_densities(x_arr, phi_arrays):
    """Build DENSITIES ndarray (squared)."""
    n_x = len(x_arr)
    data = np.zeros((n_x, 8))
    data[:, 0] = x_arr / 0.529177
    data[:, 1] = x_arr
    for k, phi in enumerate(phi_arrays):
        if k < 6:
            data[:, 2 + k] = phi ** 2
    return data


class TestAutoScale:
    """Test that auto_scale maps max amplitude to 17 % of the visible range."""

    TARGET = 0.17

    def _run(self, E_cm, phi_list, wf_active=None, dens_active=None,
             y_min=None, y_max=None):
        x = np.linspace(-1.0, 1.0, 100)
        energies  = _make_energies(E_cm)
        wf_arr    = _make_wavefunctions(x, phi_list)
        dens_arr  = _make_densities(x, phi_list)

        if wf_active is None:
            wf_active = [True] + [False] * 5
        if dens_active is None:
            dens_active = [True] + [False] * 5

        state = PlotState(
            data={"ENERGIES": energies, "WAVEFUNCTIONS": wf_arr, "DENSITIES": dens_arr},
            wf_active=wf_active,
            dens_active=dens_active,
            y_min=y_min,
            y_max=y_max,
        )
        return auto_scale(state), x, phi_list

    def test_wf_scale_maps_to_target_fraction(self):
        E_cm     = [100.0, 400.0, 900.0]
        phi_list = [
            np.sin(np.linspace(0, np.pi, 100)),  # Phi0, max ≈ 1
            np.zeros(100),
            np.zeros(100),
        ]
        (scale_wf, scale_dens), x, phis = self._run(E_cm, phi_list)

        # visible range = E[-1] - E[0] = 800 cm-1
        visible = E_cm[-1] - E_cm[0]
        max_amp = float(np.max(np.abs(phis[0])))
        expected_scale_wf = self.TARGET * visible / max_amp
        assert scale_wf == pytest.approx(expected_scale_wf, rel=1e-6)

    def test_dens_scale_maps_to_target_fraction(self):
        E_cm     = [0.0, 500.0]
        phi_list = [
            2.0 * np.ones(100),  # Phi0, max = 2 → density max = 4
        ]
        (scale_wf, scale_dens), x, phis = self._run(E_cm, phi_list)

        visible = E_cm[-1] - E_cm[0]
        max_dens = float(np.max(phis[0] ** 2))
        expected_scale_dens = self.TARGET * visible / max_dens
        assert scale_dens == pytest.approx(expected_scale_dens, rel=1e-6)

    def test_uses_y_range_when_provided(self):
        E_cm     = [0.0, 100.0]
        phi_list = [np.ones(100)]
        y_min, y_max = 0.0, 2000.0
        (scale_wf, _), x, phis = self._run(
            E_cm, phi_list, y_min=y_min, y_max=y_max
        )
        visible = y_max - y_min
        max_amp = float(np.max(np.abs(phis[0])))
        expected = self.TARGET * visible / max_amp
        assert scale_wf == pytest.approx(expected, rel=1e-6)

    def test_no_active_wavefunctions_returns_current_scale(self):
        E_cm     = [100.0, 500.0]
        phi_list = [np.sin(np.linspace(0, np.pi, 100))]
        state = PlotState(
            data={
                "ENERGIES":     _make_energies(E_cm),
                "WAVEFUNCTIONS": _make_wavefunctions(
                    np.linspace(-1, 1, 100), phi_list),
                "DENSITIES":    _make_densities(
                    np.linspace(-1, 1, 100), phi_list),
            },
            wf_active=[False] * 6,
            dens_active=[False] * 6,
            scale_wf=123.0,
            scale_dens=456.0,
        )
        scale_wf, scale_dens = auto_scale(state)
        assert scale_wf   == pytest.approx(123.0)
        assert scale_dens == pytest.approx(456.0)

    def test_no_energies_returns_current_scale(self):
        state = PlotState(
            data={},
            scale_wf=77.0,
            scale_dens=88.0,
        )
        scale_wf, scale_dens = auto_scale(state)
        assert scale_wf   == pytest.approx(77.0)
        assert scale_dens == pytest.approx(88.0)
