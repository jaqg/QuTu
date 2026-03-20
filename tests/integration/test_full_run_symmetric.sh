#!/bin/bash
# Integration test: full pipeline — polynomial mode with symmetric potential
# Checks output files created, energies ordered, wavefunctions section present.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
BIN="$ROOT/build/QuTu"
TMPDIR="$SCRIPT_DIR/tmp_symmetric"

n_pass=0; n_fail=0

pass() { echo "PASS: $1"; n_pass=$((n_pass+1)); }
fail() { echo "FAIL: $1"; n_fail=$((n_fail+1)); }

# Setup
mkdir -p "$TMPDIR"
cp "$BIN" "$TMPDIR/"
cd "$TMPDIR"

cat > INPUT << 'EOF'
# Integration test: symmetric polynomial DW
poly_degree = 4
v_coeffs = 0.008066, 0.0, -0.008761, 0.0, 0.002377
mass_H = 1.00782503207
mass_N = 14.0030740048
alpha = 5.7
N_max = 50
xmin = -5.0
xmax =  5.0
dx   = 0.05
EOF

# Run
if ./QuTu > /dev/null 2>&1; then
    pass "Program exits successfully"
else
    fail "Program exited with error"
fi

# OUTPUT file created
if [ -f OUTPUT ]; then
    pass "OUTPUT file created"
else
    fail "OUTPUT file not found"
    echo "RESULT: SOME TESTS FAILED"; exit 1
fi

# Mode shown as polynomial
if grep -q "Mode        = polynomial" OUTPUT; then
    pass "Mode = polynomial shown in output"
else
    fail "Mode = polynomial not found in output"
fi

# Parity labels present (symmetric)
if grep -q "even" OUTPUT; then
    pass "Parity labels present (symmetric)"
else
    fail "Parity labels missing for symmetric polynomial"
fi

# Energies section present and non-empty
if grep -q '\$BEGIN ENERGIES' OUTPUT && grep -q '\$END ENERGIES' OUTPUT; then
    pass "ENERGIES section present"
else
    fail "ENERGIES section missing"
fi

# Energies are ordered (E0 < E1 < E2)
E0=$(grep -A 20 'BEGIN ENERGIES' OUTPUT | grep '^\s*0 ' | awk '{print $3}')
E1=$(grep -A 20 'BEGIN ENERGIES' OUTPUT | grep '^\s*1 ' | awk '{print $3}')
E2=$(grep -A 20 'BEGIN ENERGIES' OUTPUT | grep '^\s*2 ' | awk '{print $3}')
if [ -n "$E0" ] && [ -n "$E1" ] && [ -n "$E2" ]; then
    ordered=$(awk "BEGIN { print ($E0 < $E1 && $E1 < $E2) ? 1 : 0 }")
    if [ "$ordered" = "1" ]; then
        pass "Energies are ordered E0 < E1 < E2"
    else
        fail "Energies are NOT ordered: E0=$E0 E1=$E1 E2=$E2"
    fi
else
    fail "Could not parse energy values"
fi

# Wavefunctions section present
if grep -q 'BEGIN WAVEFUNCTIONS' OUTPUT; then
    pass "WAVEFUNCTIONS section present"
else
    fail "WAVEFUNCTIONS section missing"
fi

# Completion message
if grep -q 'CALCULATION COMPLETED SUCCESSFULLY' OUTPUT; then
    pass "Completion message present"
else
    fail "Completion message missing"
fi

# Cleanup
cd "$SCRIPT_DIR"
rm -rf "$TMPDIR"

echo ""
echo "Integration (symmetric): $n_pass passed, $n_fail failed"
[ "$n_fail" -eq 0 ]
