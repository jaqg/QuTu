#!/usr/bin/env python3
"""animate.py — Wavepacket dynamics animator for QuTu OUTPUT files.

Usage
-----
    python animate.py [path/to/OUTPUT]
"""

from __future__ import annotations

import importlib.util
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


def _import_sibling(filename: str):
    """Import a hyphen-named .py file from the same directory as this script."""
    path = Path(__file__).parent / filename
    spec = importlib.util.spec_from_file_location(filename.replace("-", "_").removesuffix(".py"), path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

import numpy as np
import matplotlib

STYLE_FILE = Path(__file__).parent / "QuTu.mplstyle"

# Physical constants (CODATA / NIST)
HP    = 6.62607015e-34    # Planck constant  [J·s]
CLUZ  = 29979245800.0     # speed of light   [cm/s]
HBAR  = HP / (2.0 * np.pi)


# ---------------------------------------------------------------------------
# WavepacketEngine — numerical time evolution
# ---------------------------------------------------------------------------

class WavepacketEngine:
    """Compute Ψ(x,t) = Σ_n c_n Φ_n(x) exp(−i E_n t / ℏ).

    Energies are stored internally in Joules; t is supplied in ps.
    """

    def __init__(self, phi_arr: np.ndarray, E_cm: np.ndarray,
                 coefficients: np.ndarray):
        """
        Parameters
        ----------
        phi_arr      : (n_x, n_states) real ndarray — wave functions on grid
        E_cm         : (n_states,) float ndarray — energies in cm⁻¹
        coefficients : (n_states,) complex ndarray — initial coefficients
        """
        self.phi  = phi_arr                          # (n_x, n_states)
        self.E_J  = E_cm * HP * CLUZ                 # convert cm⁻¹ → Joules
        self.n_states = phi_arr.shape[1]
        self.set_coefficients(coefficients)

    # ── Construction helpers ─────────────────────────────────────────────────

    @classmethod
    def from_data(cls, data: dict,
                  coefficients: Optional[np.ndarray] = None
                  ) -> "WavepacketEngine":
        """Build engine from a parsed OUTPUT data dict."""
        wf = data.get("WAVEFUNCTIONS")
        en = data.get("ENERGIES")
        if wf is None or en is None:
            raise ValueError("WAVEFUNCTIONS and ENERGIES sections required.")

        n_states = min(6, wf.shape[1] - 2, len(en["E_cm"]))
        phi_arr  = wf[:, 2:2 + n_states]            # columns Phi0..Phi5
        E_cm     = en["E_cm"][:n_states]

        if coefficients is None:
            # Default: Psi_A = (Phi0 + Phi1) / sqrt(2)
            c = np.zeros(n_states)
            if n_states >= 2:
                c[0] = c[1] = 1.0 / np.sqrt(2.0)
            elif n_states == 1:
                c[0] = 1.0
            coefficients = c

        return cls(phi_arr, E_cm, coefficients)

    # ── Public interface ─────────────────────────────────────────────────────

    def set_coefficients(self, c: np.ndarray) -> None:
        """Set new coefficients (normalized on assignment)."""
        c = np.asarray(c, dtype=complex)
        norm = float(np.sqrt(np.sum(np.abs(c) ** 2)))
        self.c = c / norm if norm > 1e-30 else c

    def compute_psi(self, t_ps: float) -> np.ndarray:
        """Return complex Ψ(x, t) array of shape (n_x,)."""
        t_s = t_ps * 1e-12
        phases = np.exp(-1j * self.E_J[:len(self.c)] * t_s / HBAR)
        # phi: (n_x, n_states), c*phases: (n_states,) → broadcast
        return self.phi[:, :len(self.c)] @ (self.c * phases)

    def compute_density(self, t_ps: float) -> np.ndarray:
        """Return |Ψ(x,t)|² — real, non-negative, shape (n_x,)."""
        psi = self.compute_psi(t_ps)
        return (psi.conj() * psi).real

    def compute_re_psi(self, t_ps: float) -> np.ndarray:
        """Return Re[Ψ(x,t)], shape (n_x,)."""
        return self.compute_psi(t_ps).real

    @property
    def x_grid(self) -> int:
        return self.phi.shape[0]


# ---------------------------------------------------------------------------
# Preset coefficient sets
# ---------------------------------------------------------------------------

def _preset_2state(key: str, n_states: int) -> np.ndarray:
    """Return coefficient array for 2-state presets A/B/C/D."""
    c = np.zeros(n_states, dtype=complex)
    s = 1.0 / np.sqrt(2.0)
    if key == "A" and n_states >= 2:
        c[0] = c[1] = s
    elif key == "B" and n_states >= 2:
        c[0] = s; c[1] = -s
    elif key == "C" and n_states >= 4:
        c[2] = c[3] = s
    elif key == "D" and n_states >= 4:
        c[2] = s; c[3] = -s
    elif n_states >= 1:
        c[0] = 1.0
    return c


def _preset_4state(alpha_deg: float, n_states: int) -> np.ndarray:
    """Return coefficient array for 4-state alpha preset."""
    c = np.zeros(n_states, dtype=complex)
    a = np.radians(alpha_deg)
    cos_a = np.cos(a) / np.sqrt(2.0)
    sin_a = np.sin(a) / np.sqrt(2.0)
    if n_states >= 4:
        c[0] = c[1] = cos_a
        c[2] = c[3] = sin_a
    elif n_states >= 2:
        c[0] = c[1] = cos_a
    return c


# ---------------------------------------------------------------------------
# AnimateApp
# ---------------------------------------------------------------------------

class AnimateApp:
    """Main animation window."""

    PANEL_WIDTH = 310

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
        master.title("QuTu Animator")
        master.geometry("1200x700")

        self.engine: Optional[WavepacketEngine] = None
        self.data:   dict = {}

        # Animation state
        self._playing   = False
        self._t_current = 0.0
        self._after_id  = None

        # Display state
        self._show_density = True
        self._show_re_psi  = False
        self._scale        = 200.0
        self._t_start      = 0.0
        self._t_end        = 50.0
        self._dt           = 0.05
        self._fps          = 30

        self._build_left_panel(master)
        self._build_right_panel(master)

        if filepath:
            self._load_file(filepath)

    # ── Left panel ──────────────────────────────────────────────────────────

    def _build_left_panel(self, master):
        tk  = self._tk
        ttk = self._ttk

        left_outer = tk.Frame(master, width=self.PANEL_WIDTH, bg="#f0f0f0")
        left_outer.pack(side=tk.LEFT, fill=tk.Y)
        left_outer.pack_propagate(False)

        scroll_canvas = tk.Canvas(left_outer, bg="#f0f0f0", highlightthickness=0)
        scrollbar = tk.Scrollbar(left_outer, orient=tk.VERTICAL,
                                 command=scroll_canvas.yview)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        scroll_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scroll_canvas.configure(yscrollcommand=scrollbar.set)

        self._inner = tk.Frame(scroll_canvas, bg="#f0f0f0")
        scroll_canvas.create_window((0, 0), window=self._inner, anchor="nw")
        self._inner.bind(
            "<Configure>",
            lambda e: scroll_canvas.configure(
                scrollregion=scroll_canvas.bbox("all")
            ),
        )
        scroll_canvas.bind_all(
            "<MouseWheel>",
            lambda e: scroll_canvas.yview_scroll(
                -1 * (e.delta // 120), "units"),
        )

        pad = {"padx": 4, "pady": 2}

        # ── 1. File ───────────────────────────────────────────────────────
        frm_file = ttk.LabelFrame(self._inner, text="File")
        frm_file.pack(fill=tk.X, **pad)
        ttk.Button(frm_file, text="Open OUTPUT",
                   command=self._on_open).pack(side=tk.LEFT, padx=2, pady=2)
        self._lbl_file = ttk.Label(frm_file, text="(none)", foreground="gray")
        self._lbl_file.pack(side=tk.LEFT, padx=4)

        # ── 2. Wavepacket ─────────────────────────────────────────────────
        frm_wp = ttk.LabelFrame(self._inner, text="Wavepacket")
        frm_wp.pack(fill=tk.X, **pad)

        # 2-state presets
        ttk.Label(frm_wp, text="2-state preset:").pack(anchor=tk.W)
        frm_preset = ttk.Frame(frm_wp)
        frm_preset.pack(fill=tk.X)
        for key in "ABCD":
            ttk.Button(frm_preset, text=f"Ψ{key}", width=4,
                       command=lambda k=key: self._on_preset_2state(k)
                       ).pack(side=tk.LEFT, padx=1)

        # 4-state alpha
        ttk.Label(frm_wp, text="4-state (α°):").pack(anchor=tk.W)
        frm_4s = ttk.Frame(frm_wp)
        frm_4s.pack(fill=tk.X)
        self._wp4_alpha_var = tk.StringVar(value="0.0")
        self._wp4_combo = ttk.Combobox(frm_4s, textvariable=self._wp4_alpha_var,
                                        width=8)
        self._wp4_combo.pack(side=tk.LEFT)
        ttk.Button(frm_4s, text="Set",
                   command=self._on_preset_4state).pack(side=tk.LEFT, padx=2)

        # Custom coefficients
        ttk.Label(frm_wp, text="Custom c₀–c₅:").pack(anchor=tk.W)
        self._coef_vars: list[tk.StringVar] = []
        frm_coef = ttk.Frame(frm_wp)
        frm_coef.pack(fill=tk.X)
        for n in range(6):
            v = tk.StringVar(value="0.0" if n > 1 else "0.7071")
            self._coef_vars.append(v)
            ttk.Label(frm_coef, text=f"c{n}:").grid(row=n // 3, column=(n % 3) * 2)
            ttk.Entry(frm_coef, textvariable=v, width=6).grid(
                row=n // 3, column=(n % 3) * 2 + 1)
        ttk.Button(frm_wp, text="Set custom + Normalize",
                   command=self._on_custom_coef).pack(pady=2)

        # ── 3. Display ────────────────────────────────────────────────────
        frm_disp = ttk.LabelFrame(self._inner, text="Display")
        frm_disp.pack(fill=tk.X, **pad)

        self._var_dens   = tk.BooleanVar(value=True)
        self._var_repsi  = tk.BooleanVar(value=False)
        ttk.Checkbutton(frm_disp, text="Show |Ψ|²",   variable=self._var_dens,
                        command=self._on_display_change).pack(anchor=tk.W)
        ttk.Checkbutton(frm_disp, text="Show Re[Ψ]", variable=self._var_repsi,
                        command=self._on_display_change).pack(anchor=tk.W)

        ttk.Label(frm_disp, text="Scale:").pack(anchor=tk.W)
        frm_sc = ttk.Frame(frm_disp)
        frm_sc.pack(fill=tk.X)
        self._scale_var = tk.StringVar(value="200.0")
        ent = ttk.Entry(frm_sc, textvariable=self._scale_var, width=8)
        ent.pack(side=tk.LEFT)
        ent.bind("<Return>",   lambda e: self._on_display_change())
        ent.bind("<FocusOut>", lambda e: self._on_display_change())
        ttk.Button(frm_sc, text="Auto",
                   command=self._on_auto_scale).pack(side=tk.LEFT, padx=2)

        # ── 4. Time ───────────────────────────────────────────────────────
        frm_time = ttk.LabelFrame(self._inner, text="Time")
        frm_time.pack(fill=tk.X, **pad)

        def _time_row(label, row, attr, default):
            ttk.Label(frm_time, text=label).grid(
                row=row, column=0, sticky=tk.W)
            v = tk.StringVar(value=str(default))
            ttk.Entry(frm_time, textvariable=v, width=8).grid(
                row=row, column=1)
            setattr(self, f"_{attr}_var", v)

        _time_row("t start (ps):", 0, "t_start", 0.0)
        _time_row("t end (ps):",   1, "t_end",   50.0)
        _time_row("dt (ps):",      2, "dt",       0.05)
        ttk.Button(frm_time, text="Apply",
                   command=self._on_time_apply).grid(row=3, column=0,
                                                     columnspan=2, pady=2)

        # ── 5. Playback ───────────────────────────────────────────────────
        frm_play = ttk.LabelFrame(self._inner, text="Playback")
        frm_play.pack(fill=tk.X, **pad)

        frm_btns = ttk.Frame(frm_play)
        frm_btns.pack()
        ttk.Button(frm_btns, text="Play",  command=self._on_play ).pack(side=tk.LEFT, padx=2)
        ttk.Button(frm_btns, text="Pause", command=self._on_pause).pack(side=tk.LEFT, padx=2)
        ttk.Button(frm_btns, text="Reset", command=self._on_reset).pack(side=tk.LEFT, padx=2)

        ttk.Label(frm_play, text="FPS:").pack(anchor=tk.W)
        self._fps_var = tk.StringVar(value="30")
        ent_fps = ttk.Entry(frm_play, textvariable=self._fps_var, width=6)
        ent_fps.pack(anchor=tk.W)
        ent_fps.bind("<Return>",   lambda e: self._sync_playback())
        ent_fps.bind("<FocusOut>", lambda e: self._sync_playback())

        self._lbl_time = ttk.Label(frm_play, text="t = 0.0000 ps")
        self._lbl_time.pack(anchor=tk.W, pady=2)

        # ── 6. Export ─────────────────────────────────────────────────────
        frm_exp = ttk.LabelFrame(self._inner, text="Export")
        frm_exp.pack(fill=tk.X, **pad)

        ttk.Label(frm_exp, text="Export FPS:").pack(anchor=tk.W)
        self._export_fps_var = tk.StringVar(value="30")
        ttk.Entry(frm_exp, textvariable=self._export_fps_var,
                  width=6).pack(anchor=tk.W)
        ttk.Button(frm_exp, text="Export MP4",
                   command=self._on_export_mp4).pack(fill=tk.X, padx=2, pady=2)

        ttk.Button(self._inner, text="Exit",
                   command=self.master.quit).pack(fill=tk.X, padx=4, pady=6)

    # ── Right panel ─────────────────────────────────────────────────────────

    def _build_right_panel(self, master):
        import matplotlib.pyplot as plt
        from matplotlib.backends.backend_tkagg import (
            FigureCanvasTkAgg, NavigationToolbar2Tk,
        )
        tk = self._tk

        right = tk.Frame(master)
        right.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        self._fig, self._ax = plt.subplots(figsize=(8, 5))
        self._canvas = FigureCanvasTkAgg(self._fig, master=right)
        self._canvas.draw()
        toolbar = NavigationToolbar2Tk(self._canvas, right)
        toolbar.update()
        toolbar.pack(side=tk.TOP, fill=tk.X)
        self._canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)

        # Dynamic line objects (set once, updated each frame)
        self._line_dens, = self._ax.plot([], [], label=r"$|\Psi|^2$", zorder=4)
        self._line_re,   = self._ax.plot([], [], label=r"$\mathrm{Re}[\Psi]$",
                                         ls="--", zorder=4, visible=False)
        self._txt_time   = self._ax.text(
            0.02, 0.95, "t = 0.0000 ps",
            transform=self._ax.transAxes,
            verticalalignment="top",
        )

    # ── File loading ─────────────────────────────────────────────────────────

    def _on_open(self):
        path = self._fd.askopenfilename(
            title="Open OUTPUT file",
            filetypes=[("OUTPUT files", "*"), ("All files", "*.*")],
        )
        if path:
            self._load_file(path)

    def _load_file(self, path: str):
        _po = _import_sibling("qutu-parse-output.py")
        try:
            self.data = _po.parse_output(path)
        except Exception as exc:
            self._mb.showerror("Error", f"Could not parse:\n{exc}")
            return

        self._lbl_file.configure(text=Path(path).name, foreground="black")

        # Populate 4-state alpha dropdown
        wp4 = self.data.get("WAVEPACKETS_4STATE")
        if wp4:
            self._wp4_combo["values"] = [str(a) for a in sorted(wp4.keys())]

        # Build engine with default Psi_A preset
        try:
            self.engine = WavepacketEngine.from_data(self.data)
        except ValueError as exc:
            self._mb.showerror("Error", str(exc))
            return

        self._t_current = self._t_start
        self._draw_static_elements()
        self._frame_update(self._t_current)

    # ── Static background elements ───────────────────────────────────────────

    def _draw_static_elements(self):
        ax = self._ax
        ax.cla()

        data = self.data
        potential = data.get("POTENTIAL")
        energies  = data.get("ENERGIES")

        if potential is not None and len(potential):
            ax.plot(potential[:, 1], potential[:, 3],
                    color="gray", lw=1.2, zorder=1, label=r"$V(x)$")

        E_vals = None
        if energies is not None and len(energies):
            E_vals = energies["E_cm"]
            for E_n in E_vals:
                ax.axhline(E_n, color="gray", lw=0.6, ls="--", alpha=0.4, zorder=2)

        ax.set_xlabel(r"$x\ (\AA)$")
        ax.set_ylabel(r"$E\ (\mathrm{cm^{-1}})$")

        if potential is not None and len(potential):
            ax.set_xlim(potential[:, 1].min(), potential[:, 1].max())

        if E_vals is not None and len(E_vals):
            margin = (E_vals[-1] - E_vals[0]) * 0.1
            ax.set_ylim(E_vals[0] - margin, E_vals[-1] + margin)

        # Re-create dynamic lines after cla()
        self._line_dens, = ax.plot([], [], label=r"$|\Psi|^2$",
                                   color="#1f77b4", lw=1.5, zorder=4)
        self._line_re,   = ax.plot([], [], label=r"$\mathrm{Re}[\Psi]$",
                                   color="#ff7f0e", lw=1.2, ls="--",
                                   zorder=4, visible=False)
        self._txt_time   = ax.text(
            0.02, 0.95, "t = 0.0000 ps",
            transform=ax.transAxes,
            verticalalignment="top",
        )
        self._canvas.draw()

    # ── Frame update (called each animation tick) ────────────────────────────

    def _frame_update(self, t: float):
        if self.engine is None:
            return

        en = self.data.get("ENERGIES")
        E_pkt = float(self.engine.c[0] ** 2 * self.engine.E_J[0] / (HP * CLUZ)) \
                if len(self.engine.E_J) > 0 else 0.0
        # Weighted mean energy in cm-1
        E_pkt = float(np.sum(np.abs(self.engine.c) ** 2
                             * self.engine.E_J[:len(self.engine.c)] / (HP * CLUZ)))

        # x grid (Angstrom column of WAVEFUNCTIONS)
        wf = self.data.get("WAVEFUNCTIONS")
        if wf is None:
            return
        x_arr = wf[:, 1]

        if self._show_density:
            dens = self.engine.compute_density(t)
            self._line_dens.set_data(x_arr, dens * self._scale + E_pkt)
            self._line_dens.set_visible(True)
        else:
            self._line_dens.set_visible(False)

        if self._show_re_psi:
            re = self.engine.compute_re_psi(t)
            self._line_re.set_data(x_arr, re * self._scale + E_pkt)
            self._line_re.set_visible(True)
        else:
            self._line_re.set_visible(False)

        self._txt_time.set_text(f"t = {t:.4f} ps")
        self._lbl_time.configure(text=f"t = {t:.4f} ps")
        self._canvas.draw_idle()

    # ── Animation loop ───────────────────────────────────────────────────────

    def _tick(self):
        if not self._playing:
            return
        self._t_current += self._dt
        if self._t_current > self._t_end:
            self._t_current = self._t_start
        self._frame_update(self._t_current)
        delay_ms = max(1, int(1000 / self._fps))
        self._after_id = self.master.after(delay_ms, self._tick)

    # ── Event handlers ────────────────────────────────────────────────────────

    def _on_play(self):
        if self._playing:
            return
        self._playing = True
        self._tick()

    def _on_pause(self):
        self._playing = False
        if self._after_id is not None:
            self.master.after_cancel(self._after_id)

    def _on_reset(self):
        self._on_pause()
        self._t_current = self._t_start
        self._frame_update(self._t_current)

    def _sync_playback(self):
        try:
            self._fps = max(1, int(self._fps_var.get()))
        except ValueError:
            pass

    def _on_display_change(self):
        self._show_density = self._var_dens.get()
        self._show_re_psi  = self._var_repsi.get()
        try:
            self._scale = float(self._scale_var.get())
        except ValueError:
            pass
        self._frame_update(self._t_current)

    def _on_auto_scale(self):
        """Scale so peak density fills ~17% of visible y range."""
        if self.engine is None:
            return
        wf = self.data.get("WAVEFUNCTIONS")
        en = self.data.get("ENERGIES")
        if wf is None or en is None:
            return
        E_cm   = en["E_cm"]
        v_range = float(E_cm[-1] - E_cm[0]) if len(E_cm) > 1 else 1000.0
        target = 0.17 * v_range
        dens = self.engine.compute_density(self._t_current)
        peak = float(np.max(dens))
        if peak > 1e-30:
            self._scale = target / peak
        self._scale_var.set(f"{self._scale:.4g}")
        self._frame_update(self._t_current)

    def _on_time_apply(self):
        try:
            self._t_start = float(self._t_start_var.get())
            self._t_end   = float(self._t_end_var.get())
            self._dt      = float(self._dt_var.get())
        except ValueError:
            pass
        self._t_current = self._t_start
        self._frame_update(self._t_current)

    def _on_preset_2state(self, key: str):
        if self.engine is None:
            return
        c = _preset_2state(key, self.engine.n_states)
        self.engine.set_coefficients(c)
        self._t_current = self._t_start
        self._frame_update(self._t_current)

    def _on_preset_4state(self):
        if self.engine is None:
            return
        try:
            alpha = float(self._wp4_alpha_var.get())
        except ValueError:
            return
        c = _preset_4state(alpha, self.engine.n_states)
        self.engine.set_coefficients(c)
        self._t_current = self._t_start
        self._frame_update(self._t_current)

    def _on_custom_coef(self):
        if self.engine is None:
            return
        try:
            c = np.array([float(v.get()) for v in self._coef_vars], dtype=complex)
        except ValueError:
            self._mb.showerror("Error", "All coefficients must be numbers.")
            return
        self.engine.set_coefficients(c)
        self._t_current = self._t_start
        self._frame_update(self._t_current)

    def _on_export_mp4(self):
        """Export animation as MP4 using FuncAnimation + FFMpegWriter."""
        import matplotlib.animation as animation
        import matplotlib.pyplot as plt

        if self.engine is None:
            self._mb.showerror("Error", "No data loaded.")
            return

        # Check for ffmpeg
        try:
            from matplotlib.animation import FFMpegWriter
            writer = FFMpegWriter(fps=int(self._export_fps_var.get()))
        except Exception:
            self._mb.showerror(
                "Error",
                "FFMpeg not found.  Install ffmpeg and ensure it is on PATH.",
            )
            return

        path = self._fd.asksaveasfilename(
            title="Save MP4",
            defaultextension=".mp4",
            filetypes=[("MP4 video", "*.mp4")],
        )
        if not path:
            return

        self._on_pause()
        wf  = self.data.get("WAVEFUNCTIONS")
        if wf is None:
            return
        x_arr = wf[:, 1]
        E_pkt = float(np.sum(np.abs(self.engine.c) ** 2
                             * self.engine.E_J[:len(self.engine.c)] / (HP * CLUZ)))

        n_frames = max(2, int((self._t_end - self._t_start) / self._dt))
        t_arr    = np.linspace(self._t_start, self._t_end, n_frames)

        # Use QuTu.mplstyle for the exported figure
        ctx = (
            self._plt.style.context(str(STYLE_FILE))
            if STYLE_FILE.exists() else self._plt.style.context("default")
        )
        with ctx:
            fig_ex, ax_ex = plt.subplots(figsize=(8, 5))
            potential = self.data.get("POTENTIAL")
            energies  = self.data.get("ENERGIES")
            if potential is not None and len(potential):
                ax_ex.plot(potential[:, 1], potential[:, 3],
                           color="gray", lw=1.2)
            if energies is not None and len(energies):
                for E_n in energies["E_cm"]:
                    ax_ex.axhline(E_n, color="gray", lw=0.6, ls="--", alpha=0.4)
            if potential is not None and len(potential):
                ax_ex.set_xlim(potential[:, 1].min(), potential[:, 1].max())
            ax_ex.set_xlabel(r"$x\ (\AA)$")
            ax_ex.set_ylabel(r"$E\ (\mathrm{cm^{-1}})$")

            line_d, = ax_ex.plot([], [], color="#1f77b4", lw=1.5)
            txt_t   = ax_ex.text(0.02, 0.95, "", transform=ax_ex.transAxes,
                                 verticalalignment="top")

            def _init():
                line_d.set_data([], [])
                return line_d,

            def _update(frame_idx):
                t = t_arr[frame_idx]
                dens = self.engine.compute_density(t)
                line_d.set_data(x_arr, dens * self._scale + E_pkt)
                txt_t.set_text(f"t = {t:.4f} ps")
                return line_d, txt_t

            anim = animation.FuncAnimation(
                fig_ex, _update, init_func=_init,
                frames=n_frames, interval=1000 // self._fps, blit=True,
            )
            anim.save(path, writer=writer)
            plt.close(fig_ex)

        self._mb.showinfo("Export", f"Saved: {path}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def _run(filepath: Optional[str] = None) -> None:
    import tkinter as tk
    matplotlib.use("TkAgg")
    root = tk.Tk()
    _app = AnimateApp(root, filepath)
    root.mainloop()


if __name__ == "__main__":
    _run(sys.argv[1] if len(sys.argv) > 1 else None)
