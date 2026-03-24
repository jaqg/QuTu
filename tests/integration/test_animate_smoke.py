"""Smoke test for WavepacketEngine.compute_density() — no Tk required."""

import sys
from pathlib import Path

import numpy as np
import pytest

SCRIPTS = Path(__file__).parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
from animate import WavepacketEngine, _preset_2state, _preset_4state


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_data(n_x: int = 80, n_states: int = 4):
    """Build a minimal OUTPUT data dict."""
    x = np.linspace(-1.0, 1.0, n_x)

    wf = np.zeros((n_x, 8))
    wf[:, 0] = x / 0.529177
    wf[:, 1] = x
    for k in range(n_states):
        phi = np.sin((k + 1) * np.pi * (x + 1) / 2.0)
        phi /= np.sqrt(np.trapezoid(phi ** 2, x))
        wf[:, 2 + k] = phi

    dt = np.dtype([("n", int), ("parity", "U4"), ("E_Ha", float), ("E_cm", float)])
    energies = np.array(
        [(i, "", 0.001 * (i + 1), 200.0 + i * 100.0) for i in range(n_states)],
        dtype=dt,
    )
    return {"WAVEFUNCTIONS": wf, "ENERGIES": energies}, x


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestComputeDensityShape:
    def test_shape_matches_x_grid(self):
        data, _ = _make_data(n_x=80)
        eng = WavepacketEngine.from_data(data)
        dens = eng.compute_density(0.5)
        # x-grid has n_x points
        assert dens.shape == (80,)

    def test_shape_matches_wavefunctions(self):
        n_x = 120
        data, _ = _make_data(n_x=n_x)
        eng = WavepacketEngine.from_data(data)
        wf  = data["WAVEFUNCTIONS"]
        dens = eng.compute_density(1.0)
        assert dens.shape[0] == wf.shape[0]


class TestDensityValues:
    def test_non_negative(self):
        data, _ = _make_data()
        eng  = WavepacketEngine.from_data(data)
        dens = eng.compute_density(0.7)
        assert np.all(dens >= -1e-14)

    def test_real(self):
        data, _ = _make_data()
        eng  = WavepacketEngine.from_data(data)
        dens = eng.compute_density(2.0)
        assert np.isrealobj(dens)


class TestPresets:
    def test_preset_a_normalized(self):
        c = _preset_2state("A", 4)
        assert pytest.approx(float(np.sum(np.abs(c) ** 2)), rel=1e-10) == 1.0

    def test_preset_b_normalized(self):
        c = _preset_2state("B", 4)
        assert pytest.approx(float(np.sum(np.abs(c) ** 2)), rel=1e-10) == 1.0

    def test_preset_4state_at_0_matches_A(self):
        """4-state preset at α=0 should equal the A preset (only Φ0, Φ1)."""
        c4  = _preset_4state(0.0, 4)
        cA  = _preset_2state("A", 4)
        np.testing.assert_allclose(np.abs(c4), np.abs(cA), atol=1e-12)

    def test_preset_4state_at_90_matches_C(self):
        """4-state preset at α=90 should equal the C preset (only Φ2, Φ3)."""
        c4  = _preset_4state(90.0, 4)
        cC  = _preset_2state("C", 4)
        np.testing.assert_allclose(np.abs(c4), np.abs(cC), atol=1e-12)

    def test_preset_4state_normalized(self):
        for alpha in [0.0, 30.0, 45.0, 60.0, 90.0]:
            c = _preset_4state(alpha, 4)
            assert pytest.approx(float(np.sum(np.abs(c) ** 2)), rel=1e-10) == 1.0


class TestFromDataErrors:
    def test_missing_wavefunctions_raises(self):
        dt = np.dtype([("n", int), ("parity", "U4"), ("E_Ha", float), ("E_cm", float)])
        en = np.array([(0, "", 0.001, 200.0)], dtype=dt)
        with pytest.raises(ValueError, match="WAVEFUNCTIONS"):
            WavepacketEngine.from_data({"ENERGIES": en})

    def test_missing_energies_raises(self):
        n_x = 10
        wf = np.zeros((n_x, 4))
        with pytest.raises(ValueError, match="ENERGIES"):
            WavepacketEngine.from_data({"WAVEFUNCTIONS": wf})
