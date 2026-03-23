#!/bin/bash
# Validation test: PIB-FBR eigenvalues match HO polynomial eigenvalues
# for the same potential at sufficient basis size (N=80).
# Both methods must agree to within 0.01 cm-1 for the 10 lowest states.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
BIN="$ROOT/build/QuTu"
TMPDIR="$SCRIPT_DIR/tmp_pib_vs_ho"
TOL="0.01"   # cm-1

n_pass=0; n_fail=0

pass() { echo "PASS: $1"; n_pass=$((n_pass+1)); }
fail() { echo "FAIL: $1"; n_fail=$((n_fail+1)); }

mkdir -p "$TMPDIR"
cp "$BIN" "$TMPDIR/"
cd "$TMPDIR"

# --- HO run ---
cat > INPUT << 'EOF'
poly_degree = 4
v_coeffs = 0.0, 0.002, -0.02722, 0.0, 0.01
mass = 1.007276
alpha = 4.7
N_max = 80
xmin = -3.0
xmax =  3.0
dx   = 0.01
EOF
./QuTu > /dev/null 2>&1
mv OUTPUT OUTPUT_HO

# --- PIB run ---
cat > INPUT << 'EOF'
poly_degree = 4
v_coeffs = 0.0, 0.002, -0.02722, 0.0, 0.01
mass = 1.007276
basis = PIB
N_max = 80
xmin = -3.0
xmax =  3.0
dx   = 0.01
EOF
./QuTu > /dev/null 2>&1
mv OUTPUT OUTPUT_PIB

extract_cm() {
    awk '/\$BEGIN ENERGIES/{found=1; next} /\$END ENERGIES/{found=0} found && /^[ ]*[0-9]/{print $3}' "$1" | head -10
}

ho_e=($(extract_cm OUTPUT_HO))
pib_e=($(extract_cm OUTPUT_PIB))

n=${#ho_e[@]}
if [ "$n" -lt 10 ]; then
    fail "HO output has fewer than 10 energy levels"
fi
n=${#pib_e[@]}
if [ "$n" -lt 10 ]; then
    fail "PIB output has fewer than 10 energy levels"
fi

for i in $(seq 0 9); do
    diff=$(awk "BEGIN{d=(${ho_e[$i]})-(${pib_e[$i]}); if(d<0)d=-d; print d}")
    ok=$(awk "BEGIN{print ($diff <= $TOL) ? 1 : 0}")
    label="State $i: HO=${ho_e[$i]} PIB=${pib_e[$i]} diff=${diff} cm-1"
    if [ "$ok" -eq 1 ]; then
        pass "$label"
    else
        fail "$label  [tolerance = $TOL cm-1]"
    fi
done

# --- Cleanup ---
cd "$SCRIPT_DIR"
rm -rf "$TMPDIR"

echo ""
if [ "$n_fail" -eq 0 ]; then
    echo "RESULT: ALL TESTS PASSED ($n_pass/$((n_pass+n_fail)))"
    exit 0
else
    echo "RESULT: $n_fail TESTS FAILED ($n_pass passed)"
    exit 1
fi
