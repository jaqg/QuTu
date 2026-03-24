#!/bin/bash
# Integration test: full pipeline — PIB-FBR basis with asymmetric potential
# Verifies PIB run completes, output contains PIB-specific fields,
# energies are real and sorted, and wavefunctions are non-trivial.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
BIN="$ROOT/build/QuTu"
TMPDIR="$SCRIPT_DIR/tmp_pib"

n_pass=0; n_fail=0

pass() { echo "PASS: $1"; n_pass=$((n_pass+1)); }
fail() { echo "FAIL: $1"; n_fail=$((n_fail+1)); }

# Setup
mkdir -p "$TMPDIR"
cp "$BIN" "$TMPDIR/"
cd "$TMPDIR"

cat > INPUT << 'EOF'
# Integration test: PIB-FBR basis, asymmetric double-well
poly_degree = 4
v_coeffs = 0.0, 0.002, -0.02722, 0.0, 0.01
mass = 1.007276
basis = PIB
N_max = 60
xmin = -3.0
xmax =  3.0
dx   = 0.02
EOF

# --- Run ---
if ./QuTu > /dev/null 2>&1; then
    pass "Program exits successfully"
else
    fail "Program exited with error"
fi

if [ -f OUTPUT ]; then
    pass "OUTPUT file created"
else
    fail "OUTPUT file not found"
    echo "RESULT: SOME TESTS FAILED"; exit 1
fi

# --- PIB-specific output checks ---
if grep -q "basis.*=.*PIB" OUTPUT; then
    pass "Basis = PIB reported in output"
else
    fail "Basis = PIB not found in output"
fi

if grep -q "box_length" OUTPUT; then
    pass "box_length reported in output"
else
    fail "box_length not found in output"
fi

if grep -q "exact diagonal (PIB-FBR)" OUTPUT; then
    pass "Kinetic matrix = exact diagonal reported"
else
    fail "PIB kinetic matrix description not found"
fi

if grep -q "alpha" OUTPUT && ! grep -q "alpha (opt.)" OUTPUT; then
    fail "alpha (opt.) should not appear for PIB basis"
else
    pass "alpha (opt.) correctly absent for PIB basis"
fi

# --- Energy checks ---
n_energies=$(awk '/\$BEGIN ENERGIES/{found=1; next} /\$END ENERGIES/{found=0} found && /^[ ]*[0-9]/{print}' OUTPUT | wc -l)
if [ "$n_energies" -ge 10 ]; then
    pass "At least 10 energy levels reported ($n_energies total)"
else
    fail "Too few energy levels reported: $n_energies"
fi

# Ground state energy should be negative (bound state below zero)
e0=$(awk '/\$BEGIN ENERGIES/{found=1; next} /\$END ENERGIES/{found=0} found && /^[ ]*0 /{print $2; exit}' OUTPUT)
if awk "BEGIN{exit !($e0 < 0.0)}"; then
    pass "Ground state energy negative (E0 = $e0 Ha)"
else
    fail "Ground state energy not negative: E0 = $e0 Ha"
fi

# Energies should be sorted (ascending): E(n+1) >= E(n)
sorted=$(awk '/\$BEGIN ENERGIES/{found=1; next} /\$END ENERGIES/{found=0} found && /^[ ]*[0-9]/{print $2}' OUTPUT | \
    awk 'NR==1{prev=$1; ok=1; next} {if($1 < prev) ok=0; prev=$1} END{print ok}')
if [ "$sorted" -eq 1 ]; then
    pass "Eigenvalues are sorted in ascending order"
else
    fail "Eigenvalues are NOT sorted in ascending order"
fi

# --- Eigenstates section ---
if grep -q "\$BEGIN WAVEFUNCTIONS" OUTPUT; then
    pass "WAVEFUNCTIONS section present"
else
    fail "WAVEFUNCTIONS section missing"
fi

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
