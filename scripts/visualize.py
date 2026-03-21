"""visualize.py — Interactive static visualizer for QuTu OUTPUT files.

Usage
-----
    python visualize.py [path/to/OUTPUT]
"""

from __future__ import annotations

import ast
import sys
import textwrap
from dataclasses import dataclass, field
from pathlib import Path
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
                    color="gray", lw=1.2, label=lbl, zorder=1)

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
                ax.plot(x_arr, y_arr, label=lbl, zorder=3)

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
                    ax.plot(x_arr, wp2[:, dens_col], label=lbl, zorder=3)

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
            ax.plot(x_arr, y_arr, label=lbl, zorder=3)

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
        '"""Auto-generated by QuTu visualize.py — reproduces the PDF figure.',
        "Place this script next to parse_output.py and visualize.py.",
        '"""',
        "import sys",
        "from pathlib import Path",
        "import matplotlib",
        'matplotlib.use("Agg")',
        "import matplotlib.pyplot as plt",
        "",
        "_THIS = Path(__file__).parent",
        "sys.path.insert(0, str(_THIS))",
        "import parse_output as _po",
        "from visualize import PlotEngine, PlotState",
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
        ttk.Button(frm_file, text="Open OUTPUT",
                   command=self._on_open).pack(side=tk.LEFT, padx=2, pady=2)
        self._lbl_file = ttk.Label(frm_file, text="(none)", foreground="gray")
        self._lbl_file.pack(side=tk.LEFT, padx=4)

        # ── 2. What to plot ───────────────────────────────────────────────
        frm_what = ttk.LabelFrame(self._inner, text="What to plot")
        frm_what.pack(fill=tk.X, **pad)

        self._var_potential = tk.BooleanVar(value=True)
        self._var_energies  = tk.BooleanVar(value=True)
        ttk.Checkbutton(frm_what, text="Potential V(x)",
                        variable=self._var_potential,
                        command=self._on_plot_change).pack(anchor=tk.W)
        ttk.Checkbutton(frm_what, text="Energy levels",
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
        self._frm_wf_subs.pack(fill=tk.X, padx=16)
        self._vars_wf = []
        for n in range(6):
            v = tk.BooleanVar(value=(n == 0))
            self._vars_wf.append(v)
            cb = ttk.Checkbutton(self._frm_wf_subs, text=f"Φ{n}",
                                 variable=v, command=self._on_plot_change)
            cb.grid(row=0, column=n)
        self._frm_wf_subs.pack_forget()

        # Densities group
        self._var_dens = tk.BooleanVar(value=False)
        frm_dens = ttk.Frame(frm_what)
        frm_dens.pack(fill=tk.X)
        ttk.Checkbutton(frm_dens, text="Densities |Φn|²",
                        variable=self._var_dens,
                        command=self._on_dens_toggle).pack(anchor=tk.W)
        self._frm_dens_subs = ttk.Frame(frm_dens)
        self._frm_dens_subs.pack(fill=tk.X, padx=16)
        self._vars_dens = []
        for n in range(6):
            v = tk.BooleanVar(value=(n == 0))
            self._vars_dens.append(v)
            cb = ttk.Checkbutton(self._frm_dens_subs, text=f"|Φ{n}|²",
                                 variable=v, command=self._on_plot_change)
            cb.grid(row=0, column=n)
        self._frm_dens_subs.pack_forget()

        # 2-state wavepackets group
        self._var_wp2 = tk.BooleanVar(value=False)
        frm_wp2 = ttk.Frame(frm_what)
        frm_wp2.pack(fill=tk.X)
        ttk.Checkbutton(frm_wp2, text="2-state wavepackets",
                        variable=self._var_wp2,
                        command=self._on_wp2_toggle).pack(anchor=tk.W)
        self._frm_wp2_subs = ttk.Frame(frm_wp2)
        self._frm_wp2_subs.pack(fill=tk.X, padx=16)
        self._vars_wp2: dict[str, tk.BooleanVar] = {}
        for col_idx, key in enumerate("ABCD"):
            v = tk.BooleanVar(value=False)
            self._vars_wp2[key] = v
            ttk.Checkbutton(self._frm_wp2_subs, text=f"Ψ{key}",
                            variable=v, command=self._on_plot_change
                            ).grid(row=0, column=col_idx)
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
        ttk.Label(self._frm_wp4_subs, text="α =").pack(side=tk.LEFT)
        self._wp4_alpha_var = tk.StringVar(value="0.0")
        self._wp4_combo = ttk.Combobox(self._frm_wp4_subs,
                                        textvariable=self._wp4_alpha_var,
                                        width=8)
        self._wp4_combo.pack(side=tk.LEFT)
        self._wp4_combo.bind("<<ComboboxSelected>>", lambda e: self._on_plot_change())
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

        # ── 5. Line labels ────────────────────────────────────────────────
        self._frm_labels = ttk.LabelFrame(self._inner, text="Line labels")
        self._frm_labels.pack(fill=tk.X, **pad)
        self._label_entries: dict[str, tk.StringVar] = {}

        # ── 6. Style & Export ─────────────────────────────────────────────
        frm_export = ttk.LabelFrame(self._inner, text="Style & Export")
        frm_export.pack(fill=tk.X, **pad)

        self._style_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(frm_export, text="QuTu.mplstyle (export only)",
                        variable=self._style_var).pack(anchor=tk.W)

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
        import parse_output as _po
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

        self._rebuild_label_entries()
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
        if self._style_var.get() and STYLE_FILE.exists():
            with plt.style.context(str(STYLE_FILE)):
                fig2 = plt.figure(figsize=(8, 5))
                self.engine.render(self.state, fig2)
                fig2.savefig(path, bbox_inches="tight")
                plt.close(fig2)
        else:
            fig2 = plt.figure(figsize=(8, 5))
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

        # Sync labels from entries
        for key, svar in self._label_entries.items():
            s.labels[key] = svar.get()

    def _rebuild_label_entries(self):
        tk  = self._tk
        ttk = self._ttk
        for w in self._frm_labels.winfo_children():
            w.destroy()
        self._label_entries.clear()

        entries: list[tuple[str, str]] = []
        if self.state.data.get("POTENTIAL") is not None:
            entries.append(("potential", r"$V(x)$"))
        energies = self.state.data.get("ENERGIES")
        if energies is not None:
            for n in range(min(len(energies), 6)):
                entries.append((f"energy_{n}", f"$E_{{{n}}}$"))
        for n in range(6):
            entries.append((f"wf_{n}", rf"$\Phi_{{{n}}}$"))
            entries.append((f"dens_{n}", rf"$|\Phi_{{{n}}}|^2$"))
        for key in "ABCD":
            entries.append((f"wp2_{key}", rf"$|\Psi_{key}|^2$"))
        entries.append(("wp4", r"$|\Psi(\alpha)|^2$"))

        for row_idx, (key, default) in enumerate(entries):
            ttk.Label(self._frm_labels, text=key + ":").grid(
                row=row_idx, column=0, sticky=tk.W, padx=2)
            v = tk.StringVar(value=self.state.labels.get(key, default))
            self._label_entries[key] = v
            e = ttk.Entry(self._frm_labels, textvariable=v, width=20)
            e.grid(row=row_idx, column=1, sticky=tk.EW, padx=2)
            e.bind("<FocusOut>", lambda ev: self._on_plot_change())

    # ── Rendering ───────────────────────────────────────────────────────────

    def _render(self):
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
    _run(sys.argv[1] if len(sys.argv) > 1 else None)
