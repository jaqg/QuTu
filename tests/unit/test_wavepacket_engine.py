"""Unit tests for animate.WavepacketEngine."""

import sys
from pathlib import Path

import numpy as np
import pytest

SCRIPTS = Path(__file__).parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
from animate import WavepacketEngine, HP, CLUZ, HBAR


def _make_engine(n_states: int = 4, n_x: int = 200,
                 coef=None) -> WavepacketEngine:
    """Build a minimal WavepacketEngine with synthetic data."""
    x = np.linspace(-1.0, 1.0, n_x)
    # Synthetic normalised eigenfunctions (harmonic-oscillator-like)
    phi = np.zeros((n_x, n_states))
    E_cm = np.zeros(n_states)
    for n in range(n_states):
        # Simple non-degenerate functions
        phi[:, n] = np.sin((n + 1) * np.pi * (x + 1.0) / 2.0)
        norm = np.sqrt(np.trapezoid(phi[:, n] ** 2, x))
        phi[:, n] /= norm
        E_cm[n] = float(200 + n * 100)  # 200, 300, 400, ... cm-1

    if coef is None:
        c = np.zeros(n_states, dtype=complex)
        c[0] = c[1] = 1.0 / np.sqrt(2.0)
    else:
        c = np.asarray(coef, dtype=complex)

    return WavepacketEngine(phi, E_cm, c), phi, E_cm, x


class TestNormalization:
    def test_coefficients_normalized_on_init(self):
        eng, _, _, _ = _make_engine(coef=[2.0, 0.0, 0.0, 0.0])
        norm = np.sum(np.abs(eng.c) ** 2)
        assert norm == pytest.approx(1.0, rel=1e-10)

    def test_set_coefficients_normalizes(self):
        eng, _, _, _ = _make_engine()
        eng.set_coefficients(np.array([3.0, 4.0, 0.0, 0.0]))
        norm = np.sum(np.abs(eng.c) ** 2)
        assert norm == pytest.approx(1.0, rel=1e-10)

    def test_density_integrates_to_one(self):
        eng, phi, E_cm, x = _make_engine()
        dens = eng.compute_density(0.0)
        # Numerical integration
        integral = np.trapezoid(dens, x)
        assert integral == pytest.approx(1.0, rel=1e-3)


class TestInitialState:
    def test_psi_at_t0_equals_superposition(self):
        """Ψ(x, 0) = Σ c_n Φ_n(x)."""
        eng, phi, _, x = _make_engine(n_states=4)
        psi_0 = eng.compute_psi(0.0)
        expected = phi @ eng.c
        np.testing.assert_allclose(psi_0.real, expected.real, atol=1e-12)
        np.testing.assert_allclose(psi_0.imag, expected.imag, atol=1e-12)


class TestDensityProperties:
    def test_density_is_real(self):
        eng, _, _, _ = _make_engine()
        dens = eng.compute_density(1.0)
        assert dens.dtype == float or np.isrealobj(dens)

    def test_density_non_negative(self):
        eng, _, _, _ = _make_engine()
        dens = eng.compute_density(1.0)
        assert np.all(dens >= -1e-15)

    def test_density_shape(self):
        eng, _, _, _ = _make_engine(n_x=150)
        dens = eng.compute_density(0.5)
        assert dens.shape == (150,)


class TestTimeEvolution:
    def test_two_state_density_oscillates(self):
        """For a 2-state superposition (c0=c1=1/√2), |Ψ|² oscillates.

        The period is T = h / (E1 - E0) [in seconds].
        At t=T the density should be identical to t=0.
        """
        n_states = 2
        eng, phi, E_cm, x = _make_engine(n_states=n_states,
                                          coef=[1 / np.sqrt(2),
                                                1 / np.sqrt(2)])
        dE_J = (E_cm[1] - E_cm[0]) * HP * CLUZ
        T_s  = HP / dE_J          # full period in seconds
        T_ps = T_s * 1e12

        dens_t0 = eng.compute_density(0.0)
        dens_tT = eng.compute_density(T_ps)
        np.testing.assert_allclose(dens_t0, dens_tT, atol=1e-10)

    def test_density_changes_with_time(self):
        """Density at t=0 should differ from density at a non-trivial time."""
        eng, _, E_cm, _ = _make_engine()
        dE_J = (E_cm[1] - E_cm[0]) * HP * CLUZ
        T_ps = HP / dE_J * 1e12
        dens_t0   = eng.compute_density(0.0)
        dens_half = eng.compute_density(T_ps / 2)
        assert not np.allclose(dens_t0, dens_half, atol=1e-6)

    def test_single_state_density_constant(self):
        """Pure eigenstate: |Ψ|² constant in time."""
        eng, _, _, _ = _make_engine(coef=[1.0, 0.0, 0.0, 0.0])
        dens_t0 = eng.compute_density(0.0)
        dens_t5 = eng.compute_density(5.0)
        np.testing.assert_allclose(dens_t0, dens_t5, atol=1e-12)


class TestComputeRePsi:
    def test_shape(self):
        eng, _, _, _ = _make_engine(n_x=80)
        re = eng.compute_re_psi(2.0)
        assert re.shape == (80,)

    def test_is_real(self):
        eng, _, _, _ = _make_engine()
        re = eng.compute_re_psi(1.0)
        assert np.isrealobj(re)


class TestFromData:
    def test_builds_from_dict(self):
        """WavepacketEngine.from_data should work with minimal data dict."""
        n_x = 50
        x = np.linspace(-1, 1, n_x)
        wf_arr = np.zeros((n_x, 8))
        wf_arr[:, 0] = x / 0.529
        wf_arr[:, 1] = x
        for k in range(6):
            wf_arr[:, 2 + k] = np.cos(k * np.pi * x)

        dt = np.dtype([("n", int), ("parity", "U4"), ("E_Ha", float), ("E_cm", float)])
        en_arr = np.array(
            [(i, "", 0.0, 200.0 + i * 100) for i in range(6)], dtype=dt
        )
        data = {"WAVEFUNCTIONS": wf_arr, "ENERGIES": en_arr}
        eng = WavepacketEngine.from_data(data)
        assert eng.n_states <= 6
        assert eng.phi.shape[0] == n_x
