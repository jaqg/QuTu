#!/usr/bin/env python3
"""parse_output.py — Parser for QuTu OUTPUT files.

Sections use $BEGIN / $END markers with # comment headers.

Public API
----------
parse_output(filepath)          -> dict[str, array | dict | None]
list_sections(filepath)         -> list[str]
get_section(data, section)      -> np.ndarray | dict | None
"""

from __future__ import annotations

import sys
import argparse
from pathlib import Path
from typing import Optional

import numpy as np


# ---------------------------------------------------------------------------
# Section metadata
# ---------------------------------------------------------------------------

KNOWN_SECTIONS = {
    "POTENTIAL", "ENERGIES", "CONVERGENCE", "N_VS_ENERGY",
    "WAVEFUNCTIONS", "DENSITIES", "WAVEPACKETS_2STATE", "SURVIVAL_2STATE",
    "WAVEPACKETS_4STATE", "SURVIVAL_4STATE", "EXPECTATION_X",
    "TURNING_POINTS", "COEFFICIENTS",
}

# Sections whose rows are grouped by a leading alpha(deg) column
ALPHA_SECTIONS = {
    "WAVEPACKETS_4STATE", "SURVIVAL_4STATE", "EXPECTATION_X", "TURNING_POINTS",
}

# Column names for each section (for documentation / CSV export)
SECTION_COLS: dict[str, list[str]] = {
    "POTENTIAL":          ["x_a0", "x_A", "V_Ha", "V_cm"],
    "CONVERGENCE":        ["n", "N_conv", "E_conv_Ha", "E_conv_cm", "E_max_Ha", "E_max_cm"],
    "N_VS_ENERGY":        ["N", "W0_cm", "W1_cm", "W2_cm", "W3_cm"],
    "WAVEFUNCTIONS":      ["x_a0", "x_A", "Phi0", "Phi1", "Phi2", "Phi3", "Phi4", "Phi5"],
    "DENSITIES":          ["x_a0", "x_A", "dPhi0", "dPhi1", "dPhi2", "dPhi3", "dPhi4", "dPhi5"],
    "WAVEPACKETS_2STATE": ["x_a0", "x_A",
                           "Psi_A", "dPsi_A", "Psi_B", "dPsi_B",
                           "Psi_C", "dPsi_C", "Psi_D", "dPsi_D"],
    "SURVIVAL_2STATE":    ["t_ps", "Ps_A", "Ps_C"],
    "WAVEPACKETS_4STATE": ["alpha_deg", "x_A", "Psi", "dPsi", "E_cm"],
    "SURVIVAL_4STATE":    ["alpha_deg", "t_ps", "Ps"],
    "EXPECTATION_X":      ["alpha_deg", "t_ps", "x_exp_A"],
    "TURNING_POINTS":     ["alpha_deg", "E_cm", "x1_A", "x2_A", "x3_A", "x4_A"],
}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _parse_section_raw(lines: list[str]) -> list[list[str]]:
    """Strip comment/blank lines; return list of token-lists."""
    rows: list[list[str]] = []
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        rows.append(stripped.split())
    return rows


def _is_float(token: str) -> bool:
    """Return True if token looks like a floating-point literal."""
    try:
        float(token)
        return "." in token or "e" in token.lower()
    except ValueError:
        return False


def _parse_generic(raw: list[list[str]], n_cols: int = 0) -> np.ndarray:
    """Parse raw token rows into a plain float ndarray."""
    if not raw:
        return np.empty((0, n_cols or 0))
    return np.array([[float(t) for t in row] for row in raw], dtype=float)


def _parse_energies(raw: list[list[str]]) -> np.ndarray:
    """Parse ENERGIES; detects optional 'even'/'odd' parity column.

    Returns a numpy structured array with fields:
        n (int), parity (U4), E_Ha (float), E_cm (float)
    For asymmetric systems parity is an empty string.
    """
    dt = np.dtype([("n", int), ("parity", "U4"), ("E_Ha", float), ("E_cm", float)])
    if not raw:
        return np.zeros(0, dtype=dt)

    # Detect parity column: if second token is non-numeric
    has_parity = False
    if len(raw[0]) >= 2:
        try:
            float(raw[0][1])
        except ValueError:
            has_parity = True

    rows = []
    for row in raw:
        try:
            if has_parity:
                rows.append((int(row[0]), row[1].strip(), float(row[2]), float(row[3])))
            else:
                rows.append((int(row[0]), "", float(row[1]), float(row[2])))
        except (ValueError, IndexError):
            continue
    return np.array(rows, dtype=dt)


def _parse_alpha_indexed(
    raw: list[list[str]], n_cols: int = 0
) -> dict[float, np.ndarray]:
    """Parse alpha-indexed sections into dict[alpha_deg -> 2D ndarray].

    Rows are grouped by the first (alpha) column value.
    """
    groups: dict[float, list[list[float]]] = {}
    for row in raw:
        try:
            alpha = float(row[0])
            data_row = [float(t) for t in row]
        except (ValueError, IndexError):
            continue
        groups.setdefault(alpha, []).append(data_row)
    return {alpha: np.array(rows, dtype=float) for alpha, rows in groups.items()}


def _parse_coefficients(raw: list[list[str]]) -> dict[str, np.ndarray]:
    """Parse COEFFICIENTS section: even+odd side-by-side physical lines.

    Each physical line: i_even  even  c0 c2 c4   i_odd  odd  c1 c3 c5

    Returns dict with keys 'even' and 'odd', each a structured ndarray with
    fields (i, c0, c2, c4) and (i, c1, c3, c5) respectively.
    """
    dt_even = np.dtype([("i", int), ("c_Phi0", float), ("c_Phi2", float), ("c_Phi4", float)])
    dt_odd  = np.dtype([("i", int), ("c_Phi1", float), ("c_Phi3", float), ("c_Phi5", float)])

    even_rows: list[tuple] = []
    odd_rows:  list[tuple] = []

    for row in raw:
        tokens = row

        # ── Even side ──────────────────────────────────────────────────────
        try:
            ei = tokens.index("even")
            i_e = int(tokens[ei - 1])
            coefs_e: list[float] = []
            for t in tokens[ei + 1:]:
                if len(coefs_e) == 3:
                    break
                if _is_float(t):
                    coefs_e.append(float(t))
                else:
                    break  # hit an integer index or keyword → stop
            if len(coefs_e) == 3:
                even_rows.append((i_e, *coefs_e))
        except (ValueError, IndexError):
            pass

        # ── Odd side ───────────────────────────────────────────────────────
        try:
            # 'odd ' → stripped to 'odd' by split()
            oi = tokens.index("odd")
            i_o = int(tokens[oi - 1])
            coefs_o: list[float] = []
            for t in tokens[oi + 1:]:
                if len(coefs_o) == 3:
                    break
                if _is_float(t):
                    coefs_o.append(float(t))
                else:
                    break
            if len(coefs_o) == 3:
                odd_rows.append((i_o, *coefs_o))
        except (ValueError, IndexError):
            pass

    return {
        "even": np.array(even_rows, dtype=dt_even) if even_rows
                else np.zeros(0, dtype=dt_even),
        "odd":  np.array(odd_rows,  dtype=dt_odd)  if odd_rows
                else np.zeros(0, dtype=dt_odd),
    }


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def parse_output(filepath: str) -> dict:
    """Parse a QuTu OUTPUT file.

    Returns a dict keyed by section name.  Known sections not present in the
    file are mapped to None.  Values:
      - plain ndarray for most sections
      - structured ndarray for ENERGIES and COEFFICIENTS (dict with even/odd)
      - dict[float, ndarray] for alpha-indexed sections
    """
    filepath_path = Path(filepath)
    with filepath_path.open("r") as fh:
        all_lines = fh.readlines()

    # ── Collect raw section lines ───────────────────────────────────────────
    sections_raw: dict[str, list[str]] = {}
    current: Optional[str] = None
    current_buf: list[str] = []

    for line in all_lines:
        stripped = line.strip()
        if stripped.startswith("$BEGIN "):
            current = stripped[7:].strip()
            current_buf = []
        elif stripped.startswith("$END "):
            if current is not None:
                sections_raw[current] = current_buf
                current = None
                current_buf = []
        elif current is not None:
            current_buf.append(line)

    # ── Initialize result ───────────────────────────────────────────────────
    result: dict = {name: None for name in KNOWN_SECTIONS}

    # ── Parse each found section ────────────────────────────────────────────
    for name, lines in sections_raw.items():
        raw = _parse_section_raw(lines)

        if name == "ENERGIES":
            result[name] = _parse_energies(raw)

        elif name == "COEFFICIENTS":
            result[name] = _parse_coefficients(raw)

        elif name in ALPHA_SECTIONS:
            n_cols = len(SECTION_COLS.get(name, []))
            result[name] = _parse_alpha_indexed(raw, n_cols)

        elif name in SECTION_COLS:
            n_cols = len(SECTION_COLS[name])
            result[name] = _parse_generic(raw, n_cols)

        else:
            # Unknown section — parse as plain floats
            result[name] = _parse_generic(raw)

    return result


def list_sections(filepath: str) -> list[str]:
    """Return the names of all $BEGIN markers present in the file."""
    sections: list[str] = []
    with open(filepath, "r") as fh:
        for line in fh:
            stripped = line.strip()
            if stripped.startswith("$BEGIN "):
                sections.append(stripped[7:].strip())
    return sections


def get_section(data: dict, section: str) -> Optional[np.ndarray]:
    """Return a parsed section, raising KeyError for unknown section names."""
    if section not in KNOWN_SECTIONS:
        raise KeyError(
            f"Unknown section '{section}'. "
            f"Valid names: {sorted(KNOWN_SECTIONS)}"
        )
    return data.get(section)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def _to_csv(arr, col_names: list[str], path: Optional[str] = None) -> None:
    """Write array to CSV (stdout if path is None)."""
    try:
        import pandas as pd  # type: ignore
        if isinstance(arr, np.ndarray) and arr.dtype.names:
            df = pd.DataFrame(arr)
        elif isinstance(arr, np.ndarray):
            cols = col_names if len(col_names) == arr.shape[1] else None
            df = pd.DataFrame(arr, columns=cols)
        else:
            df = pd.DataFrame(arr)
        if path:
            df.to_csv(path, index=False)
        else:
            print(df.to_csv(index=False), end="")
    except ImportError:
        # Fallback: numpy savetxt
        if isinstance(arr, np.ndarray) and not arr.dtype.names:
            header = ",".join(col_names) if col_names else ""
            if path:
                np.savetxt(path, arr, delimiter=",", header=header, comments="")
            else:
                import io
                buf = io.StringIO()
                np.savetxt(buf, arr, delimiter=",", header=header, comments="")
                print(buf.getvalue(), end="")
        else:
            print(repr(arr))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Parse and inspect QuTu OUTPUT files."
    )
    parser.add_argument("filepath", help="Path to OUTPUT file")
    parser.add_argument("--section", metavar="NAME",
                        help="Section to extract (default: list all)")
    parser.add_argument("--alpha", type=float, metavar="DEG",
                        help="Alpha value (degrees) for alpha-indexed sections")
    parser.add_argument("--output", metavar="FILE",
                        help="Write section to CSV file (default: stdout)")
    args = parser.parse_args()

    if args.section is None:
        # List sections
        secs = list_sections(args.filepath)
        print("\n".join(secs))
        return

    data = parse_output(args.filepath)
    try:
        val = get_section(data, args.section)
    except KeyError as exc:
        sys.exit(str(exc))

    if val is None:
        print(f"Section '{args.section}' not present in file.")
        return

    col_names = SECTION_COLS.get(args.section, [])

    if args.section in ALPHA_SECTIONS:
        # val is dict[float, ndarray]
        if args.alpha is None:
            alphas = sorted(val.keys())
            print(f"Alpha values present: {alphas}")
            return
        # Find closest alpha
        closest = min(val.keys(), key=lambda a: abs(a - args.alpha))
        arr = val[closest]
        _to_csv(arr, col_names, args.output)

    elif args.section == "COEFFICIENTS":
        # val is dict with 'even' and 'odd'
        import io
        for key in ("even", "odd"):
            sub = val[key]
            names = list(sub.dtype.names) if sub.dtype.names else []
            _to_csv(sub, names, args.output)
    else:
        _to_csv(val, col_names, args.output)


if __name__ == "__main__":
    main()
