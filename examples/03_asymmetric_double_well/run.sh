#!/usr/bin/env bash
# =============================================================================
# run.sh — Example 03: Asymmetric double-well (HO vs PIB comparison)
#
# Runs the same asymmetric double-well potential with both the HO and PIB
# basis sets, then compares the first 10 eigenvalues (cm-1).
# =============================================================================
set -euo pipefail

QUTU="../../build/QuTu"
if [ ! -x "$QUTU" ]; then
    echo "ERROR: QuTu executable not found at $QUTU"
    echo "       Run 'make' from the project root first."
    exit 1
fi

echo "============================================================"
echo " Example 03: Asymmetric double-well"
echo "============================================================"
echo ""

# --- HO run ---
echo ">>> Running HO basis (INPUT_HO)..."
cp INPUT_HO INPUT
"$QUTU"
mv OUTPUT OUTPUT_HO
echo "    Done — results in OUTPUT_HO"
echo ""

# --- PIB run ---
echo ">>> Running PIB-FBR basis (INPUT_PIB)..."
cp INPUT_PIB INPUT
"$QUTU"
mv OUTPUT OUTPUT_PIB
echo "    Done — results in OUTPUT_PIB"
echo ""

# --- Extract energies for comparison ---
extract_energies() {
    local file="$1"
    awk '/\$BEGIN ENERGIES/{found=1; next} /\$END ENERGIES/{found=0} found && /^[ ]*[0-9]/{print $2, $3}' "$file" | head -10
}

echo "============================================================"
echo " Comparison: first 10 eigenvalues (cm-1)"
echo "============================================================"
printf "%-6s  %-18s  %-18s  %-14s\n" "State" "HO (cm-1)" "PIB (cm-1)" "Diff (cm-1)"
printf "%s\n" "--------------------------------------------------------------"

ho_energies=$(extract_energies OUTPUT_HO)
pib_energies=$(extract_energies OUTPUT_PIB)

paste <(echo "$ho_energies") <(echo "$pib_energies") | \
awk 'BEGIN{n=0} {
    ho_e=$2; pib_e=$4
    diff = ho_e - pib_e
    if (diff < 0) diff = -diff
    printf "%-6d  %18.4f  %18.4f  %14.6f\n", n, ho_e, pib_e, diff
    n++
}'

echo ""
echo "============================================================"
echo " DONE"
echo "============================================================"
