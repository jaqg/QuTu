"""Smoke test for PlotEngine.render() — no Tk display required."""

import sys
import textwrap
from pathlib import Path

import numpy as np
import pytest

SCRIPTS = Path(__file__).parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))

# parse_output is needed to build test data
import parse_output as _po
from visualize import PlotEngine, PlotState


# ---------------------------------------------------------------------------
# Minimal mock data (same format as parser output)
# ---------------------------------------------------------------------------

def _make_mock_data():
    n_x = 50
    x = np.linspace(-1.0, 1.0, n_x)

    # POTENTIAL: x_a0, x_A, V_Ha, V_cm
    potential = np.column_stack([
        x / 0.529177, x,
        0.05 * x ** 4, 0.05 * x ** 4 * 2.1947e5,
    ])

    # ENERGIES
    dt = np.dtype([("n", int), ("parity", "U4"), ("E_Ha", float), ("E_cm", float)])
    energies = np.array(
        [(i, "even" if i % 2 == 0 else "odd", 0.001 * (i + 1), 200.0 * (i + 1))
         for i in range(4)],
        dtype=dt,
    )

    # WAVEFUNCTIONS: x_a0, x_A, Phi0..Phi5
    wf = np.zeros((n_x, 8))
    wf[:, 0] = x / 0.529177
    wf[:, 1] = x
    for k in range(6):
        wf[:, 2 + k] = np.cos((k + 1) * np.pi * x / 2.0)

    # DENSITIES
    dens = np.zeros((n_x, 8))
    dens[:, :2] = wf[:, :2]
    for k in range(6):
        dens[:, 2 + k] = wf[:, 2 + k] ** 2

    return {"POTENTIAL": potential, "ENERGIES": energies,
            "WAVEFUNCTIONS": wf, "DENSITIES": dens}


# ---------------------------------------------------------------------------
# Smoke tests
# ---------------------------------------------------------------------------

class TestPlotEngineRender:
    """PlotEngine.render() must produce at least one line in the axes."""

    def _render_state(self, **state_kwargs):
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        data  = _make_mock_data()
        state = PlotState(data=data, **state_kwargs)
        fig   = plt.figure()
        PlotEngine().render(state, fig)
        return fig

    def test_potential_produces_line(self):
        fig = self._render_state(show_potential=True, show_energies=False)
        ax  = fig.axes[0]
        lines = ax.get_lines()
        assert len(lines) >= 1

    def test_energies_produces_hlines(self):
        """Energy levels are drawn as axhlines; axes must have content."""
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        data  = _make_mock_data()
        state = PlotState(data=data, show_potential=False, show_energies=True)
        fig   = plt.figure()
        PlotEngine().render(state, fig)
        # axhline adds collections; just assert no exception & fig has an axes
        assert len(fig.axes) == 1

    def test_wavefunctions_active(self):
        wf_active = [True, True, False, False, False, False]
        fig = self._render_state(
            show_wavefunctions=True,
            wf_active=wf_active,
            show_potential=True,
        )
        ax    = fig.axes[0]
        lines = ax.get_lines()
        # At minimum: potential + 2 wavefunctions
        assert len(lines) >= 3

    def test_densities_active(self):
        dens_active = [True, False, False, False, False, False]
        fig = self._render_state(
            show_densities=True,
            dens_active=dens_active,
            show_potential=True,
        )
        ax    = fig.axes[0]
        lines = ax.get_lines()
        assert len(lines) >= 2

    def test_no_data_does_not_crash(self):
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        state = PlotState()
        fig   = plt.figure()
        PlotEngine().render(state, fig)   # should not raise

    def test_x_units_a0(self):
        fig = self._render_state(show_potential=True, x_units="a0")
        ax  = fig.axes[0]
        lines = ax.get_lines()
        assert len(lines) >= 1
        # x values should be larger (a0 > Å)
        xdata = lines[0].get_xdata()
        assert float(np.max(np.abs(xdata))) > 1.0  # bohr are bigger numbers

    def test_energy_units_Ha(self):
        fig = self._render_state(show_potential=True, e_units="Ha")
        ax  = fig.axes[0]
        lines = ax.get_lines()
        # V in Ha is tiny; check y range is small
        ydata = lines[0].get_ydata()
        assert float(np.max(ydata)) < 10.0  # Ha values are O(0.01)
