"""Unit tests for visualize._generate_script()."""

import ast
import sys
from pathlib import Path

import pytest

SCRIPTS = Path(__file__).parents[2] / "scripts"
sys.path.insert(0, str(SCRIPTS))
from visualize import PlotState, _generate_script


class TestGenerateScript:
    def _state(self, filepath="/some/dir/OUTPUT", **kwargs):
        return PlotState(filepath=filepath, **kwargs)

    def test_valid_python_syntax(self):
        """Generated script must pass ast.parse without error."""
        state = self._state(show_potential=True, show_energies=True)
        src = _generate_script(state, "/some/dir/figure.py")
        ast.parse(src)  # raises SyntaxError if invalid

    def test_contains_parse_output_import(self):
        state = self._state()
        src = _generate_script(state, "/tmp/fig.py")
        assert "qutu-parse-output" in src

    def test_contains_plotengine_import(self):
        state = self._state()
        src = _generate_script(state, "/tmp/fig.py")
        assert "PlotEngine" in src

    def test_uses_relative_path(self):
        """Script should reference OUTPUT by name, not absolute path."""
        state = self._state(filepath="/absolute/path/to/OUTPUT")
        src = _generate_script(state, "/absolute/path/to/figure.py")
        # Should contain the bare filename 'OUTPUT', not the full absolute path
        assert "OUTPUT" in src
        assert "/absolute/path/to/OUTPUT" not in src

    def test_has_style_file_reference(self):
        state = self._state()
        src = _generate_script(state, "/tmp/fig.py")
        assert "QuTu.mplstyle" in src

    def test_has_dirname_dunder_file(self):
        """Portability: paths must be relative to __file__."""
        state = self._state()
        src = _generate_script(state, "/tmp/fig.py")
        assert "__file__" in src

    def test_config_embeds_show_potential(self):
        state = self._state(show_potential=False)
        src = _generate_script(state, "/tmp/fig.py")
        assert "'show_potential': False" in src or '"show_potential": False' in src

    def test_config_embeds_scales(self):
        state = self._state(scale_wf=500.0, scale_dens=750.0)
        src = _generate_script(state, "/tmp/fig.py")
        assert "500.0" in src
        assert "750.0" in src

    def test_savefig_call_present(self):
        state = self._state()
        src = _generate_script(state, "/tmp/fig.py")
        assert "savefig" in src

    def test_matplotlib_agg_backend(self):
        """Headless export: script must use non-interactive backend."""
        state = self._state()
        src = _generate_script(state, "/tmp/fig.py")
        assert "Agg" in src

    def test_returns_string(self):
        state = self._state()
        result = _generate_script(state, "/tmp/fig.py")
        assert isinstance(result, str)
        assert len(result) > 100
