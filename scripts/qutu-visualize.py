#!/usr/bin/env python3
"""visualize.py — Interactive static visualizer for QuTu OUTPUT files.

Usage
-----
    python visualize.py [path/to/OUTPUT]
"""

from __future__ import annotations

import ast
import importlib.util
import json
import sys
import textwrap
from dataclasses import dataclass, field
from pathlib import Path


def _import_sibling(filename: str):
    """Import a hyphen-named .py file from the same directory as this script."""
    path = Path(__file__).parent / filename
    spec = importlib.util.spec_from_file_location(filename.replace("-", "_").removesuffix(".py"), path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
from typing import Optional

import numpy as np
import matplotlib

STYLE_FILE = Path(__file__).parent / "QuTu.mplstyle"


# ---------------------------------------------------------------------------
# PlotState — pure data, no widgets
# ---------------------------------------------------------------------------

@dataclass
class PlotState:
    filepath: str = ""
    data: dict = field(default_factory=dict)

    # What to plot
    show_potential:        bool = True
    show_energies:         bool = True
    show_wavefunctions:    bool = False
    wf_active:             list = field(default_factory=lambda: [False] * 6)
    show_densities:        bool = False
    dens_active:           list = field(default_factory=lambda: [False] * 6)
    show_wp2:              bool = False
    wp2_active:            dict = field(default_factory=lambda: {
                               "A": False, "B": False, "C": False, "D": False})
    show_wp4:              bool = False
    wp4_alpha:             float = 0.0

    # Amplitude scaling
    scale_wf:   float = 200.0
    scale_dens: float = 200.0

    # Axis
    x_units: str  = "A"    # "A" or "a0"
    e_units: str  = "cm"   # "cm" or "Ha"
    x_min:   Optional[float] = None
    x_max:   Optional[float] = None
    y_min:   Optional[float] = None
    y_max:   Optional[float] = None
    xlabel:  str = r"$x\ (\AA)$"
    ylabel:  str = r"$E\ (\mathrm{cm^{-1}})$"
    title:   str = ""

    # Line labels  {line_id -> label_str}
    labels: dict = field(default_factory=dict)


# ---------------------------------------------------------------------------
# PlotEngine — stateless renderer
# ---------------------------------------------------------------------------

class PlotEngine:
    """Renders a PlotState into a matplotlib Figure.  No tkinter dependency."""

    # Wavefunction/density column index offset in arrays
    # WAVEFUNCTIONS cols: x_a0, x_A, Phi0..Phi5  (Phi_n at col 2+n)
    # DENSITIES cols:     x_a0, x_A, dPhi0..dPhi5 (dPhi_n at col 2+n)

    def render(self, state: PlotState, fig) -> None:
        fig.clear()
        ax = fig.add_subplot(111)

        data = state.data
        if not data:
            ax.set_title("No data loaded")
            if hasattr(fig, "canvas"):
                fig.canvas.draw_idle()
            return

        # ── Choose x/energy columns ─────────────────────────────────────
        x_col   = 1 if state.x_units == "A" else 0   # col index in spatial arrays
        e_field = "E_cm" if state.e_units == "cm" else "E_Ha"

        # ── Potential ───────────────────────────────────────────────────
        potential = data.get("POTENTIAL")
        if state.show_potential and potential is not None and len(potential):
            v_col = 3 if state.e_units == "cm" else 2
            lbl = state.labels.get("potential", r"$V(x)$")
            ax.plot(potential[:, x_col], potential[:, v_col],
                    color="gray", ls="-", lw=1.2, label=lbl, zorder=1)

        # ── Energy levels ───────────────────────────────────────────────
        energies = data.get("ENERGIES")
        E_vals = None
        if energies is not None and len(energies):
            E_vals = energies[e_field]

        turning = data.get("TURNING_POINTS")

        if state.show_energies and E_vals is not None:
            x_range = self._x_range(state, potential, x_col)
            for n_idx, E_n in enumerate(E_vals):
                # Draw turning-point lines if available
                if turning is not None:
                    self._draw_energy_level_with_turning(
                        ax, n_idx, E_n, turning, x_range, state
                    )
                else:
                    lbl = state.labels.get(f"energy_{n_idx}",
                                           f"$E_{{{n_idx}}}$")
                    ax.axhline(E_n, color="black", lw=0.8, ls="--",
                               alpha=0.5, zorder=2)

        # Reset cycler so the first data line always gets index 0
        ax.set_prop_cycle(None)

        # ── Wavefunctions ────────────────────────────────────────────────
        wf = data.get("WAVEFUNCTIONS")
        if state.show_wavefunctions and wf is not None and len(wf):
            for n_idx in range(6):
                if not state.wf_active[n_idx]:
                    continue
                if wf.shape[1] < 3 + n_idx:
                    continue
                x_arr  = wf[:, x_col]
                phi    = wf[:, 2 + n_idx]
                offset = E_vals[n_idx] if E_vals is not None and n_idx < len(E_vals) else 0.0
                y_arr  = phi * state.scale_wf + offset
                lbl    = state.labels.get(f"wf_{n_idx}",
                                          rf"$\Phi_{{{n_idx}}}(x)$")
                ax.plot(x_arr, y_arr, label=lbl, zorder=3)

        # ── Densities ────────────────────────────────────────────────────
        dens = data.get("DENSITIES")
        if state.show_densities and dens is not None and len(dens):
            for n_idx in range(6):
                if not state.dens_active[n_idx]:
                    continue
                if dens.shape[1] < 3 + n_idx:
                    continue
                x_arr  = dens[:, x_col]
                dphi   = dens[:, 2 + n_idx]
                offset = E_vals[n_idx] if E_vals is not None and n_idx < len(E_vals) else 0.0
                y_arr  = dphi * state.scale_dens + offset
                lbl    = state.labels.get(f"dens_{n_idx}",
                                          rf"$|\Phi_{{{n_idx}}}|^2$")
                line, = ax.plot(x_arr, y_arr, label=lbl, zorder=3)
                ax.fill_between(x_arr, offset, y_arr,
                                color=line.get_color(), alpha=0.5, zorder=2)

        # ── 2-state wavepackets ──────────────────────────────────────────
        wp2 = data.get("WAVEPACKETS_2STATE")
        if state.show_wp2 and wp2 is not None and len(wp2):
            # cols: x_a0, x_A, Psi_A, dPsi_A, Psi_B, dPsi_B, Psi_C, dPsi_C, Psi_D, dPsi_D
            wp2_map = {"A": (2, 3), "B": (4, 5), "C": (6, 7), "D": (8, 9)}
            x_arr = wp2[:, x_col]
            for key, (wf_col, dens_col) in wp2_map.items():
                if not state.wp2_active.get(key, False):
                    continue
                if wp2.shape[1] > dens_col:
                    lbl = state.labels.get(f"wp2_{key}",
                                           rf"$|\Psi_{key}|^2$")
                    y_wp2 = wp2[:, dens_col]
                    line, = ax.plot(x_arr, y_wp2, label=lbl, zorder=3)
                    ax.fill_between(x_arr, 0, y_wp2,
                                    color=line.get_color(), alpha=0.7, zorder=2)

        # ── 4-state wavepackets ──────────────────────────────────────────
        wp4_dict = data.get("WAVEPACKETS_4STATE")
        if state.show_wp4 and wp4_dict:
            closest = min(wp4_dict.keys(), key=lambda a: abs(a - state.wp4_alpha))
            arr4 = wp4_dict[closest]
            # cols: alpha_deg, x_A, Psi, |Psi|^2, E_cm
            x_arr  = arr4[:, 1]   # always Angstrom in this section
            dpsi   = arr4[:, 3]
            E_pkt  = arr4[0, 4] if len(arr4) else 0.0
            y_arr  = dpsi * state.scale_dens + E_pkt
            lbl    = state.labels.get("wp4",
                                      rf"$|\Psi(\alpha={closest:.0f}^\circ)|^2$")
            line, = ax.plot(x_arr, y_arr, label=lbl, zorder=3)
            ax.fill_between(x_arr, E_pkt, y_arr,
                            color=line.get_color(), alpha=0.7, zorder=2)

        # ── Axis styling ─────────────────────────────────────────────────
        if state.x_min is not None and state.x_max is not None:
            ax.set_xlim(state.x_min, state.x_max)
        if state.y_min is not None and state.y_max is not None:
            ax.set_ylim(state.y_min, state.y_max)

        ax.set_xlabel(state.xlabel)
        ax.set_ylabel(state.ylabel)
        if state.title:
            ax.set_title(state.title)

        handles, lbls = ax.get_legend_handles_labels()
        if handles:
            ax.legend(loc="upper right")

        if hasattr(fig, "canvas"):
            fig.canvas.draw_idle()

    # -- private helpers -----------------------------------------------------

    def _x_range(self, state: PlotState, potential, x_col: int):
        if state.x_min is not None and state.x_max is not None:
            return state.x_min, state.x_max
        if potential is not None and len(potential):
            return potential[:, x_col].min(), potential[:, x_col].max()
        return None, None

    def _draw_energy_level_with_turning(self, ax, n_idx, E_n, turning,
                                         x_range, state):
        """Draw energy level using turning points when available."""
        # turning points keyed by alpha; for static view use alpha=0 or full range
        if not turning:
            ax.axhline(E_n, color="gray", lw=0.8, ls="--", alpha=0.5)
            return
        # Use x_range as fallback
        x0, x1 = x_range if x_range[0] is not None else (None, None)
        ax.axhline(E_n, xmin=0, xmax=1, color="gray", lw=0.8, ls="--",
                   alpha=0.5, zorder=2)


def auto_scale(state: PlotState) -> tuple[float, float]:
    """Compute amplitude scales so each active function uses ~17% of y range.

    Returns (scale_wf, scale_dens).
    """
    data = state.data
    energies = data.get("ENERGIES")
    wf   = data.get("WAVEFUNCTIONS")
    dens = data.get("DENSITIES")

    if energies is None or len(energies) == 0:
        return state.scale_wf, state.scale_dens

    e_field = "E_cm" if state.e_units == "cm" else "E_Ha"
    E_vals = energies[e_field]

    # Visible y range
    if state.y_min is not None and state.y_max is not None:
        visible_range = state.y_max - state.y_min
    elif len(E_vals) > 0:
        visible_range = float(E_vals[-1] - E_vals[0])
        if visible_range < 1e-12:
            visible_range = 1000.0
    else:
        return state.scale_wf, state.scale_dens

    target = 0.17 * visible_range
    scale_wf   = state.scale_wf
    scale_dens = state.scale_dens

    active_wf = [i for i, a in enumerate(state.wf_active) if a]
    if wf is not None and len(wf) and active_wf:
        max_amp = max(
            float(np.max(np.abs(wf[:, 2 + n]))) for n in active_wf
            if wf.shape[1] > 2 + n
        )
        if max_amp > 1e-30:
            scale_wf = target / max_amp

    active_dens = [i for i, a in enumerate(state.dens_active) if a]
    if dens is not None and len(dens) and active_dens:
        max_amp = max(
            float(np.max(np.abs(dens[:, 2 + n]))) for n in active_dens
            if dens.shape[1] > 2 + n
        )
        if max_amp > 1e-30:
            scale_dens = target / max_amp

    return scale_wf, scale_dens


_CONFIG_FIELDS = (
    "show_potential", "show_energies",
    "show_wavefunctions", "wf_active",
    "show_densities",    "dens_active",
    "show_wp2",          "wp2_active",
    "show_wp4",          "wp4_alpha",
    "scale_wf",          "scale_dens",
    "x_units",           "e_units",
    "x_min",             "x_max",
    "y_min",             "y_max",
    "xlabel",            "ylabel",
    "title",             "labels",
)


def _export_config(state: PlotState, path: str) -> None:
    """Serialize plot configuration (no data) to a JSON file."""
    cfg = {f: getattr(state, f) for f in _CONFIG_FIELDS}
    Path(path).write_text(json.dumps(cfg, indent=2))


def _load_config(path: str) -> dict:
    """Read a JSON config file and return it as a dict."""
    return json.loads(Path(path).read_text())


def _generate_script(state: PlotState, output_path: str) -> str:
    """Generate a standalone Python script reproducing the current plot as PDF."""

    # Serialisable CONFIG dict (everything except filepath and data)
    config_fields = [
        f for f in state.__dataclass_fields__
        if f not in ("filepath", "data", "labels")
    ]
    config_lines = "\n".join(
        f"    {f!r}: {getattr(state, f)!r}," for f in config_fields
    )

    output_name = str(Path(state.filepath).name) if state.filepath else "OUTPUT"

    lines = [
        "#!/usr/bin/env python3",
        '"""Auto-generated by QuTu visualize.py — reproduces the PDF figure."""',
        "import argparse",
        "import importlib.util",
        "import sys",
        "from pathlib import Path",
        "",
        "_ap = argparse.ArgumentParser(description='Render QuTu figure to PDF')",
        "_ap.add_argument('-sd', '--scripts-dir', default='.',",
        "    metavar='DIR', help='directory containing qutu-*.py scripts (default: .)')",
        "_args = _ap.parse_args()",
        "",
        "import matplotlib",
        'matplotlib.use("Agg")',
        "import matplotlib.pyplot as plt",
        "",
        "_THIS = Path(__file__).parent",
        "_SCRIPTS_DIR = Path(_args.scripts_dir).resolve()",
        "def _load(fn):",
        "    for _dir in [_THIS, _SCRIPTS_DIR]:",
        "        _p = _dir / fn",
        "        if _p.exists():",
        "            _s = importlib.util.spec_from_file_location(",
        "                fn.replace('-','_').removesuffix('.py'), _p)",
        "            _m = importlib.util.module_from_spec(_s)",
        "            _s.loader.exec_module(_m)",
        "            return _m",
        "    print(f'Error: {fn} not found in {_THIS} or {_SCRIPTS_DIR}', file=sys.stderr)",
        "    print('Specify the location of the qutu-*.py scripts with:', file=sys.stderr)",
        "    print('  python <script>.py -sd /path/to/scripts', file=sys.stderr)",
        "    print('  python <script>.py --scripts-dir /path/to/scripts', file=sys.stderr)",
        "    sys.exit(1)",
        "_po  = _load('qutu-parse-output.py')",
        "_vis = _load('qutu-visualize.py')",
        "PlotEngine = _vis.PlotEngine",
        "PlotState  = _vis.PlotState",
        "",
        "# -- Configuration --------------------------------------------------",
        "CONFIG = {",
        config_lines,
        "}",
        "",
        f"OUTPUT_FILE = _THIS / {output_name!r}",
        '_STYLE_FILE  = _THIS / "QuTu.mplstyle"',
        "OUTPUT_PDF  = Path(__file__).with_suffix('.pdf')",
        "",
        "# -- Load data -------------------------------------------------------",
        "data = _po.parse_output(str(OUTPUT_FILE))",
        "state = PlotState(filepath=str(OUTPUT_FILE), data=data, **CONFIG)",
        "",
        "# -- Render ----------------------------------------------------------",
        "plt.style.use(str(_STYLE_FILE))",
        "fig = plt.figure()",
        "PlotEngine().render(state, fig)",
        "fig.savefig(str(OUTPUT_PDF), bbox_inches='tight')",
        "print(f'Saved: {OUTPUT_PDF}')",
    ]
    src = "\n".join(lines) + "\n"

    # Validate syntax before returning
    ast.parse(src)
    return src


# ---------------------------------------------------------------------------
# Application (tkinter — only loaded when running as a script/app)
# ---------------------------------------------------------------------------

class QuTuApp:
    """Main application window."""

    PANEL_WIDTH = 300

    def __init__(self, master, filepath: Optional[str] = None):
        import tkinter as tk
        from tkinter import ttk, filedialog, messagebox
        from matplotlib.backends.backend_tkagg import (
            FigureCanvasTkAgg, NavigationToolbar2Tk,
        )
        import matplotlib.pyplot as plt

        self._tk  = tk
        self._ttk = ttk
        self._fd  = filedialog
        self._mb  = messagebox
        self._plt = plt

        self.master = master
        master.title("QuTu Visualizer")
        master.geometry("1200x700")

        self.state  = PlotState()
        self.engine = PlotEngine()

        # ── Layout: left panel + right canvas ────────────────────────────
        self._build_left_panel(master)
        self._build_right_panel(master)

        # ── Load file if provided ─────────────────────────────────────────
        if filepath:
            self._load_file(filepath)

    # ── Left panel ─────────────────────────────────────────────────────────

    def _build_left_panel(self, master):
        tk = self._tk
        ttk = self._ttk

        left_outer = tk.Frame(master, width=self.PANEL_WIDTH, bg="#f0f0f0")
        left_outer.pack(side=tk.LEFT, fill=tk.Y)
        left_outer.pack_propagate(False)

        # Scrollable canvas inside the outer frame
        scroll_canvas = tk.Canvas(left_outer, bg="#f0f0f0",
                                  highlightthickness=0)
        scrollbar = tk.Scrollbar(left_outer, orient=tk.VERTICAL,
                                 command=scroll_canvas.yview)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        scroll_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scroll_canvas.configure(yscrollcommand=scrollbar.set)

        self._inner = tk.Frame(scroll_canvas, bg="#f0f0f0")
        win_id = scroll_canvas.create_window(
            (0, 0), window=self._inner, anchor="nw"
        )
        self._inner.bind(
            "<Configure>",
            lambda e: scroll_canvas.configure(
                scrollregion=scroll_canvas.bbox("all")
            ),
        )
        # Mouse-wheel scrolling
        scroll_canvas.bind_all("<MouseWheel>",
                               lambda e: scroll_canvas.yview_scroll(
                                   -1 * (e.delta // 120), "units"))

        pad = {"padx": 4, "pady": 2}

        # ── 1. File ───────────────────────────────────────────────────────
        frm_file = ttk.LabelFrame(self._inner, text="File")
        frm_file.pack(fill=tk.X, **pad)
        row_open = ttk.Frame(frm_file)
        row_open.pack(fill=tk.X, padx=2, pady=2)
        ttk.Button(row_open, text="Open OUTPUT",
                   command=self._on_open).pack(side=tk.LEFT, padx=2)
        self._lbl_file = ttk.Label(row_open, text="(none)", foreground="gray")
        self._lbl_file.pack(side=tk.LEFT, padx=4)
        row_cfg = ttk.Frame(frm_file)
        row_cfg.pack(fill=tk.X, padx=2, pady=(0, 2))
        ttk.Button(row_cfg, text="Load config",
                   command=self._on_load_config).pack(side=tk.LEFT, padx=2)
        ttk.Button(row_cfg, text="Export config",
                   command=self._on_export_config).pack(side=tk.LEFT, padx=2)

        # ── 2. What to plot ───────────────────────────────────────────────
        frm_what = ttk.LabelFrame(self._inner, text="What to plot")
        frm_what.pack(fill=tk.X, **pad)

        # Helper: one row with [checkbox text] [label entry]
        def _item_row(parent, cb_text, bool_var, lbl_var, indent=0):
            row = ttk.Frame(parent)
            row.pack(fill=tk.X, padx=(indent, 0))
            ttk.Checkbutton(row, text=cb_text, variable=bool_var,
                            command=self._on_plot_change).pack(side=tk.LEFT)
            ttk.Entry(row, textvariable=lbl_var, width=16).pack(
                side=tk.RIGHT, fill=tk.X, expand=True, padx=(2, 0))
            lbl_var.trace_add("write", lambda *_: self._on_plot_change())

        # Potential
        self._var_potential = tk.BooleanVar(value=True)
        self._lbl_potential = tk.StringVar(value=r"$V(x)$")
        _item_row(frm_what, "Potential V(x)", self._var_potential,
                  self._lbl_potential)

        # Energy levels (no per-level label)
        self._var_energies = tk.BooleanVar(value=True)
        row_en = ttk.Frame(frm_what)
        row_en.pack(fill=tk.X)
        ttk.Checkbutton(row_en, text="Energy levels",
                        variable=self._var_energies,
                        command=self._on_plot_change).pack(anchor=tk.W)

        # Wavefunctions group
        self._var_wf = tk.BooleanVar(value=False)
        frm_wf = ttk.Frame(frm_what)
        frm_wf.pack(fill=tk.X)
        ttk.Checkbutton(frm_wf, text="Wavefunctions",
                        variable=self._var_wf,
                        command=self._on_wf_toggle).pack(anchor=tk.W)
        self._frm_wf_subs = ttk.Frame(frm_wf)
        self._frm_wf_subs.pack(fill=tk.X)
        self._vars_wf: list = []
        self._lbls_wf: list = []
        for n in range(6):
            v = tk.BooleanVar(value=(n == 0))
            lv = tk.StringVar(value=rf"$\Phi_{{{n}}}$")
            self._vars_wf.append(v)
            self._lbls_wf.append(lv)
            _item_row(self._frm_wf_subs, f"Φ{n}", v, lv, indent=16)
        self._frm_wf_subs.pack_forget()

        # Densities group
        self._var_dens = tk.BooleanVar(value=False)
        frm_dens = ttk.Frame(frm_what)
        frm_dens.pack(fill=tk.X)
        ttk.Checkbutton(frm_dens, text="Densities |Φn|²",
                        variable=self._var_dens,
                        command=self._on_dens_toggle).pack(anchor=tk.W)
        self._frm_dens_subs = ttk.Frame(frm_dens)
        self._frm_dens_subs.pack(fill=tk.X)
        self._vars_dens: list = []
        self._lbls_dens: list = []
        for n in range(6):
            v = tk.BooleanVar(value=(n == 0))
            lv = tk.StringVar(value=rf"$|\Phi_{{{n}}}|^2$")
            self._vars_dens.append(v)
            self._lbls_dens.append(lv)
            _item_row(self._frm_dens_subs, f"|Φ{n}|²", v, lv, indent=16)
        self._frm_dens_subs.pack_forget()

        # 2-state wavepackets group
        self._var_wp2 = tk.BooleanVar(value=False)
        frm_wp2 = ttk.Frame(frm_what)
        frm_wp2.pack(fill=tk.X)
        ttk.Checkbutton(frm_wp2, text="2-state wavepackets",
                        variable=self._var_wp2,
                        command=self._on_wp2_toggle).pack(anchor=tk.W)
        self._frm_wp2_subs = ttk.Frame(frm_wp2)
        self._frm_wp2_subs.pack(fill=tk.X)
        self._vars_wp2: dict = {}
        self._lbls_wp2: dict = {}
        for key in "ABCD":
            v = tk.BooleanVar(value=False)
            lv = tk.StringVar(value=rf"$|\Psi_{key}|^2$")
            self._vars_wp2[key] = v
            self._lbls_wp2[key] = lv
            _item_row(self._frm_wp2_subs, f"Ψ{key}", v, lv, indent=16)
        self._frm_wp2_subs.pack_forget()

        # 4-state wavepackets group
        self._var_wp4 = tk.BooleanVar(value=False)
        frm_wp4 = ttk.Frame(frm_what)
        frm_wp4.pack(fill=tk.X)
        ttk.Checkbutton(frm_wp4, text="4-state wavepackets",
                        variable=self._var_wp4,
                        command=self._on_wp4_toggle).pack(anchor=tk.W)
        self._frm_wp4_subs = ttk.Frame(frm_wp4)
        self._frm_wp4_subs.pack(fill=tk.X, padx=16)
        row_wp4 = ttk.Frame(self._frm_wp4_subs)
        row_wp4.pack(fill=tk.X)
        ttk.Label(row_wp4, text="α =").pack(side=tk.LEFT)
        self._wp4_alpha_var = tk.StringVar(value="0.0")
        self._wp4_combo = ttk.Combobox(row_wp4, textvariable=self._wp4_alpha_var,
                                        width=6)
        self._wp4_combo.pack(side=tk.LEFT)
        self._wp4_combo.bind("<<ComboboxSelected>>", lambda e: self._on_plot_change())
        self._lbl_wp4 = tk.StringVar(value=r"$|\Psi(\alpha)|^2$")
        ttk.Entry(row_wp4, textvariable=self._lbl_wp4, width=14).pack(
            side=tk.RIGHT, fill=tk.X, expand=True, padx=(2, 0))
        self._lbl_wp4.trace_add("write", lambda *_: self._on_plot_change())
        self._frm_wp4_subs.pack_forget()

        # ── 3. Amplitude scaling ──────────────────────────────────────────
        frm_scale = ttk.LabelFrame(self._inner, text="Amplitude scaling")
        frm_scale.pack(fill=tk.X, **pad)

        ttk.Label(frm_scale, text="Wavefunctions:").grid(
            row=0, column=0, sticky=tk.W)
        self._scale_wf_var = tk.StringVar(value="200.0")
        ent_wf = ttk.Entry(frm_scale, textvariable=self._scale_wf_var, width=8)
        ent_wf.grid(row=0, column=1)
        ent_wf.bind("<Return>", lambda e: self._on_scale_change())
        ent_wf.bind("<FocusOut>", lambda e: self._on_scale_change())

        ttk.Label(frm_scale, text="Densities:").grid(
            row=1, column=0, sticky=tk.W)
        self._scale_dens_var = tk.StringVar(value="200.0")
        ent_dens = ttk.Entry(frm_scale, textvariable=self._scale_dens_var, width=8)
        ent_dens.grid(row=1, column=1)
        ent_dens.bind("<Return>", lambda e: self._on_scale_change())
        ent_dens.bind("<FocusOut>", lambda e: self._on_scale_change())

        ttk.Button(frm_scale, text="Auto-Scale",
                   command=self._on_auto_scale).grid(row=2, column=0,
                                                     columnspan=2, pady=2)

        # ── 4. Axis ───────────────────────────────────────────────────────
        frm_axis = ttk.LabelFrame(self._inner, text="Axis")
        frm_axis.pack(fill=tk.X, **pad)

        tk = self._tk
        ttk = self._ttk

        self._x_units_var = tk.StringVar(value="A")
        self._e_units_var = tk.StringVar(value="cm")
        ttk.Label(frm_axis, text="x units:").grid(row=0, column=0, sticky=tk.W)
        ttk.Radiobutton(frm_axis, text="Å",   variable=self._x_units_var,
                        value="A",  command=self._on_axis_apply).grid(row=0, column=1)
        ttk.Radiobutton(frm_axis, text="a₀",  variable=self._x_units_var,
                        value="a0", command=self._on_axis_apply).grid(row=0, column=2)

        ttk.Label(frm_axis, text="E units:").grid(row=1, column=0, sticky=tk.W)
        ttk.Radiobutton(frm_axis, text="cm⁻¹", variable=self._e_units_var,
                        value="cm", command=self._on_axis_apply).grid(row=1, column=1)
        ttk.Radiobutton(frm_axis, text="Ha",   variable=self._e_units_var,
                        value="Ha", command=self._on_axis_apply).grid(row=1, column=2)

        def _rng_row(parent, label, row, attr):
            ttk.Label(parent, text=label).grid(row=row, column=0, sticky=tk.W)
            v_from = tk.StringVar(value="")
            v_to   = tk.StringVar(value="")
            e_from = ttk.Entry(parent, textvariable=v_from, width=7)
            e_to   = ttk.Entry(parent, textvariable=v_to,   width=7)
            e_from.grid(row=row, column=1, padx=1)
            e_to.grid(row=row,   column=2, padx=1)
            setattr(self, f"_{attr}_from", v_from)
            setattr(self, f"_{attr}_to",   v_to)

        _rng_row(frm_axis, "x range:", 2, "xrng")
        _rng_row(frm_axis, "y range:", 3, "yrng")

        def _lbl_row(parent, label, row, attr, default):
            ttk.Label(parent, text=label).grid(row=row, column=0, sticky=tk.W)
            v = tk.StringVar(value=default)
            e = ttk.Entry(parent, textvariable=v, width=20)
            e.grid(row=row, column=1, columnspan=2, sticky=tk.EW)
            setattr(self, f"_{attr}_var", v)

        _lbl_row(frm_axis, "xlabel:", 4, "xlabel", r"$x\ (\AA)$")
        _lbl_row(frm_axis, "ylabel:", 5, "ylabel", r"$E\ (\mathrm{cm^{-1}})$")
        _lbl_row(frm_axis, "title:",  6, "title",  "")

        ttk.Button(frm_axis, text="Apply",
                   command=self._on_axis_apply).grid(row=7, column=0,
                                                     columnspan=3, pady=2)

        # ── 5. Style & Export ─────────────────────────────────────────────
        frm_export = ttk.LabelFrame(self._inner, text="Style & Export")
        frm_export.pack(fill=tk.X, **pad)

        # Style selector row
        row_style = ttk.Frame(frm_export)
        row_style.pack(fill=tk.X, padx=2, pady=(4, 1))
        ttk.Label(row_style, text="Style:").pack(side=tk.LEFT)
        self._style_path = tk.StringVar(value=str(STYLE_FILE))
        self._style_combo = ttk.Combobox(row_style, textvariable=self._style_path,
                                         width=14, state="readonly")
        self._style_combo["values"] = [str(STYLE_FILE)]
        self._style_combo.current(0)
        self._style_combo.pack(side=tk.LEFT, padx=2, fill=tk.X, expand=True)
        self._style_combo.bind("<<ComboboxSelected>>", self._on_style_selected)
        ttk.Button(row_style, text="Browse…",
                   command=self._on_style_browse).pack(side=tk.LEFT, padx=2)

        # Preview / Export toggle buttons
        row_style_tog = ttk.Frame(frm_export)
        row_style_tog.pack(fill=tk.X, padx=2, pady=(0, 4))
        self._style_preview_var = tk.BooleanVar(value=False)
        self._style_export_var  = tk.BooleanVar(value=False)
        self._btn_style_preview = ttk.Checkbutton(
            row_style_tog, text="Preview", variable=self._style_preview_var,
            command=self._on_style_preview_toggle)
        self._btn_style_preview.pack(side=tk.LEFT, padx=2)
        ttk.Checkbutton(
            row_style_tog, text="Export", variable=self._style_export_var,
        ).pack(side=tk.LEFT, padx=2)

        ttk.Button(frm_export, text="Export PDF",
                   command=self._on_export_pdf).pack(fill=tk.X, padx=2, pady=1)
        ttk.Button(frm_export, text="Export static script",
                   command=self._on_export_script).pack(fill=tk.X, padx=2, pady=1)
        ttk.Button(frm_export, text="Exit",
                   command=self.master.quit).pack(fill=tk.X, padx=2, pady=4)

    # ── Right panel (matplotlib canvas) ────────────────────────────────────

    def _build_right_panel(self, master):
        import matplotlib.pyplot as plt
        from matplotlib.backends.backend_tkagg import (
            FigureCanvasTkAgg, NavigationToolbar2Tk,
        )
        tk = self._tk

        right = tk.Frame(master)
        right.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        self._fig = plt.figure(figsize=(8, 5))
        self._canvas = FigureCanvasTkAgg(self._fig, master=right)
        self._canvas.draw()

        toolbar = NavigationToolbar2Tk(self._canvas, right)
        toolbar.update()
        toolbar.pack(side=tk.TOP, fill=tk.X)
        self._canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)

    # ── Event handlers ──────────────────────────────────────────────────────

    def _on_open(self):
        path = self._fd.askopenfilename(title="Open OUTPUT file",
                                        filetypes=[("OUTPUT files", "*"),
                                                   ("All files", "*.*")])
        if path:
            self._load_file(path)

    def _load_file(self, path: str):
        _po = _import_sibling("qutu-parse-output.py")
        try:
            data = _po.parse_output(path)
        except Exception as exc:
            self._mb.showerror("Error", f"Could not parse file:\n{exc}")
            return

        self.state.filepath = path
        self.state.data = data
        self._lbl_file.configure(text=Path(path).name, foreground="black")

        # Populate alpha dropdown
        wp4 = data.get("WAVEPACKETS_4STATE")
        if wp4:
            alphas = sorted(wp4.keys())
            self._wp4_combo["values"] = [str(a) for a in alphas]
            self._wp4_alpha_var.set(str(alphas[0]))
            self.state.wp4_alpha = alphas[0]

        self._render()

    def _on_plot_change(self):
        self._sync_state()
        self._render()

    def _on_wf_toggle(self):
        if self._var_wf.get():
            self._frm_wf_subs.pack(fill=self._tk.X, padx=16)
        else:
            self._frm_wf_subs.pack_forget()
        self._on_plot_change()

    def _on_dens_toggle(self):
        if self._var_dens.get():
            self._frm_dens_subs.pack(fill=self._tk.X, padx=16)
        else:
            self._frm_dens_subs.pack_forget()
        self._on_plot_change()

    def _on_wp2_toggle(self):
        if self._var_wp2.get():
            self._frm_wp2_subs.pack(fill=self._tk.X, padx=16)
        else:
            self._frm_wp2_subs.pack_forget()
        self._on_plot_change()

    def _on_wp4_toggle(self):
        if self._var_wp4.get():
            self._frm_wp4_subs.pack(fill=self._tk.X, padx=16)
        else:
            self._frm_wp4_subs.pack_forget()
        self._on_plot_change()

    def _on_scale_change(self):
        try:
            self.state.scale_wf   = float(self._scale_wf_var.get())
            self.state.scale_dens = float(self._scale_dens_var.get())
        except ValueError:
            pass
        self._render()

    def _on_auto_scale(self):
        self._sync_state()
        wf_s, dens_s = auto_scale(self.state)
        self.state.scale_wf   = wf_s
        self.state.scale_dens = dens_s
        self._scale_wf_var.set(f"{wf_s:.4g}")
        self._scale_dens_var.set(f"{dens_s:.4g}")
        self._render()

    def _on_axis_apply(self):
        self._sync_state()
        self._render()

    def _on_export_pdf(self):
        import matplotlib.pyplot as plt
        path = self._fd.asksaveasfilename(
            title="Save PDF",
            defaultextension=".pdf",
            filetypes=[("PDF files", "*.pdf")],
        )
        if not path:
            return
        self._sync_state()
        style = self._style_path.get()
        fig2 = plt.figure(figsize=(8, 5))
        if self._style_export_var.get() and Path(style).exists():
            with plt.style.context(style):
                self.engine.render(self.state, fig2)
        else:
            self.engine.render(self.state, fig2)
        fig2.savefig(path, bbox_inches="tight")
        plt.close(fig2)
        self._mb.showinfo("Export", f"Saved: {path}")

    def _on_export_script(self):
        self._sync_state()
        path = self._fd.asksaveasfilename(
            title="Save script",
            defaultextension=".py",
            filetypes=[("Python scripts", "*.py")],
        )
        if not path:
            return
        try:
            src = _generate_script(self.state, path)
        except SyntaxError as exc:
            self._mb.showerror("Error", f"Generated script has syntax error:\n{exc}")
            return
        Path(path).write_text(src)
        self._mb.showinfo("Export", f"Script saved: {path}")

    def _on_style_browse(self):
        path = self._fd.askopenfilename(
            title="Select .mplstyle file",
            filetypes=[("Matplotlib style", "*.mplstyle"), ("All files", "*.*")],
        )
        if not path:
            return
        vals = list(self._style_combo["values"])
        if path not in vals:
            vals.append(path)
            self._style_combo["values"] = vals
        self._style_path.set(path)
        self._on_style_selected()

    def _on_style_selected(self, _event=None):
        if self._style_preview_var.get():
            self._render()

    def _on_style_preview_toggle(self):
        self._render()

    def _on_export_config(self):
        self._sync_state()
        path = self._fd.asksaveasfilename(
            title="Save config",
            defaultextension=".json",
            filetypes=[("JSON config", "*.json"), ("All files", "*.*")],
        )
        if not path:
            return
        _export_config(self.state, path)
        self._mb.showinfo("Export", f"Config saved: {path}")

    def _on_load_config(self):
        path = self._fd.askopenfilename(
            title="Load config",
            filetypes=[("JSON config", "*.json"), ("All files", "*.*")],
        )
        if not path:
            return
        try:
            cfg = _load_config(path)
        except Exception as exc:
            self._mb.showerror("Error", f"Could not read config:\n{exc}")
            return
        self._apply_config(cfg)
        self._render()

    def _apply_config(self, cfg: dict):
        """Push a config dict into all widget variables and PlotState."""
        s = self.state

        def _set(key, default=None):
            return cfg.get(key, getattr(s, key, default))

        self._var_potential.set(_set("show_potential", True))
        self._var_energies.set(_set("show_energies",  True))

        self._var_wf.set(_set("show_wavefunctions", False))
        for n, v in enumerate(_set("wf_active", [False]*6)):
            self._vars_wf[n].set(v)
        if _set("show_wavefunctions", False):
            self._frm_wf_subs.pack(fill=self._tk.X)
        else:
            self._frm_wf_subs.pack_forget()

        self._var_dens.set(_set("show_densities", False))
        for n, v in enumerate(_set("dens_active", [False]*6)):
            self._vars_dens[n].set(v)
        if _set("show_densities", False):
            self._frm_dens_subs.pack(fill=self._tk.X)
        else:
            self._frm_dens_subs.pack_forget()

        self._var_wp2.set(_set("show_wp2", False))
        for k, v in _set("wp2_active", {k: False for k in "ABCD"}).items():
            if k in self._vars_wp2:
                self._vars_wp2[k].set(v)
        if _set("show_wp2", False):
            self._frm_wp2_subs.pack(fill=self._tk.X)
        else:
            self._frm_wp2_subs.pack_forget()

        self._var_wp4.set(_set("show_wp4", False))
        self._wp4_alpha_var.set(str(_set("wp4_alpha", 0.0)))
        if _set("show_wp4", False):
            self._frm_wp4_subs.pack(fill=self._tk.X)
        else:
            self._frm_wp4_subs.pack_forget()

        self._scale_wf_var.set(str(_set("scale_wf",   200.0)))
        self._scale_dens_var.set(str(_set("scale_dens", 200.0)))

        self._x_units_var.set(_set("x_units", "A"))
        self._e_units_var.set(_set("e_units", "cm"))

        def _str(v): return "" if v is None else str(v)
        self._xrng_from.set(_str(_set("x_min")))
        self._xrng_to.set(  _str(_set("x_max")))
        self._yrng_from.set(_str(_set("y_min")))
        self._yrng_to.set(  _str(_set("y_max")))
        self._xlabel_var.set(_set("xlabel", r"$x\ (\AA)$"))
        self._ylabel_var.set(_set("ylabel", r"$E\ (\mathrm{cm^{-1}})$"))
        self._title_var.set( _set("title",  ""))

        labels = _set("labels", {})
        if "potential" in labels:
            self._lbl_potential.set(labels["potential"])
        for n in range(6):
            if f"wf_{n}"   in labels: self._lbls_wf[n].set(labels[f"wf_{n}"])
            if f"dens_{n}" in labels: self._lbls_dens[n].set(labels[f"dens_{n}"])
        for k in "ABCD":
            if f"wp2_{k}" in labels: self._lbls_wp2[k].set(labels[f"wp2_{k}"])
        if "wp4" in labels:
            self._lbl_wp4.set(labels["wp4"])

        self._sync_state()

    # ── State sync ──────────────────────────────────────────────────────────

    def _sync_state(self):
        s = self.state
        s.show_potential     = self._var_potential.get()
        s.show_energies      = self._var_energies.get()
        s.show_wavefunctions = self._var_wf.get()
        s.wf_active          = [v.get() for v in self._vars_wf]
        s.show_densities     = self._var_dens.get()
        s.dens_active        = [v.get() for v in self._vars_dens]
        s.show_wp2           = self._var_wp2.get()
        s.wp2_active         = {k: v.get() for k, v in self._vars_wp2.items()}
        s.show_wp4           = self._var_wp4.get()
        try:
            s.wp4_alpha = float(self._wp4_alpha_var.get())
        except ValueError:
            pass
        try:
            s.scale_wf   = float(self._scale_wf_var.get())
            s.scale_dens = float(self._scale_dens_var.get())
        except ValueError:
            pass

        s.x_units = self._x_units_var.get()
        s.e_units = self._e_units_var.get()

        def _parse_float(svar):
            try:
                return float(svar.get())
            except ValueError:
                return None

        s.x_min = _parse_float(self._xrng_from)
        s.x_max = _parse_float(self._xrng_to)
        s.y_min = _parse_float(self._yrng_from)
        s.y_max = _parse_float(self._yrng_to)
        s.xlabel = self._xlabel_var.get()
        s.ylabel = self._ylabel_var.get()
        s.title  = self._title_var.get()

        # Sync labels from inline entries
        s.labels["potential"] = self._lbl_potential.get()
        for n in range(6):
            s.labels[f"wf_{n}"]   = self._lbls_wf[n].get()
            s.labels[f"dens_{n}"] = self._lbls_dens[n].get()
        for key in "ABCD":
            s.labels[f"wp2_{key}"] = self._lbls_wp2[key].get()
        s.labels["wp4"] = self._lbl_wp4.get()

    # ── Rendering ───────────────────────────────────────────────────────────

    def _render(self):
        import matplotlib.pyplot as plt
        style = self._style_path.get()
        if self._style_preview_var.get() and Path(style).exists():
            with plt.style.context(style):
                self.engine.render(self.state, self._fig)
        else:
            self.engine.render(self.state, self._fig)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def _run(filepath: Optional[str] = None) -> None:
    import tkinter as tk
    matplotlib.use("TkAgg")
    root = tk.Tk()
    _app = QuTuApp(root, filepath)
    root.mainloop()


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(
        description="Interactive static visualizer for QuTu OUTPUT files."
    )
    parser.add_argument("filepath", nargs="?", default="OUTPUT",
                        help="Path to OUTPUT file (default: ./OUTPUT)")
    args = parser.parse_args()
    _run(args.filepath)
