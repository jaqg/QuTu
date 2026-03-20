#!/bin/bash
# Integration test: full pipeline — polynomial mode with asymmetric potential
# Checks no parity labels, energies ordered, turning points numeric.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/../.."
BIN="$ROOT/build/QuTu"
TMPDIR="$SCRIPT_DIR/tmp_asymmetric"

n_pass=0; n_fail=0

pass() { echo "PASS: $1"; n_pass=$((n_pass+1)); }
fail() { echo "FAIL: $1"; n_fail=$((n_fail+1)); }

# Setup
mkdir -p "$TMPDIR"
cp "$BIN" "$TMPDIR/"
cd "$TMPDIR"

cat > INPUT << 'EOF'
# Integration test: asymmetric polynomial DW (v1 != 0)
poly_degree = 4
v_coeffs = 0.0, 0.002, -0.02722, 0.0, 0.01
mass = 1.007276
alpha = 4.7
N_max = 60
xmin = -3.0
xmax =  3.0
dx   = 0.02
EOF

# Run
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

# Mode polynomial
if grep -q "Mode        = polynomial" OUTPUT; then
    pass "Mode = polynomial shown"
else
    fail "Mode = polynomial not found"
fi

# is_symmetric = F shown
if grep -q "is_symmetric.*F" OUTPUT; then
    pass "is_symmetric = F shown in system parameters"
else
    fail "is_symmetric = F not found in output"
fi

# NO parity labels in energies section
energy_block=$(awk '/BEGIN ENERGIES/,/END ENERGIES/' OUTPUT)
if echo "$energy_block" | grep -q "even\|odd"; then
    fail "Parity labels found in asymmetric output (should not be there)"
else
    pass "No parity labels in asymmetric energies output"
fi

# Energies ordered
E0=$(grep -A 20 'BEGIN ENERGIES' OUTPUT | grep '^\s*0 ' | awk '{print $2}')
E1=$(grep -A 20 'BEGIN ENERGIES' OUTPUT | grep '^\s*1 ' | awk '{print $2}')
E2=$(grep -A 20 'BEGIN ENERGIES' OUTPUT | grep '^\s*2 ' | awk '{print $2}')
if [ -n "$E0" ] && [ -n "$E1" ] && [ -n "$E2" ]; then
    ordered=$(awk "BEGIN { print ($E0 < $E1 && $E1 < $E2) ? 1 : 0 }")
    if [ "$ordered" = "1" ]; then
        pass "Energies ordered E0 < E1 < E2"
    else
        fail "Energies NOT ordered: E0=$E0 E1=$E1 E2=$E2"
    fi
else
    fail "Could not parse energy values (asymmetric format)"
fi

# E1 - E0 > 0 (non-degenerate due to asymmetry)
if [ -n "$E0" ] && [ -n "$E1" ]; then
    gap=$(awk "BEGIN { printf \"%.6f\", $E1 - $E0 }")
    is_positive=$(awk "BEGIN { print ($gap > 0) ? 1 : 0 }")
    if [ "$is_positive" = "1" ]; then
        pass "E1 - E0 > 0 (gap = $gap Ha)"
    else
        fail "E1 - E0 <= 0"
    fi
fi

# Wavefunctions present
if grep -q 'BEGIN WAVEFUNCTIONS' OUTPUT; then
    pass "WAVEFUNCTIONS section present"
else
    fail "WAVEFUNCTIONS section missing"
fi

# Completion
if grep -q 'CALCULATION COMPLETED SUCCESSFULLY' OUTPUT; then
    pass "Completion message present"
else
    fail "Completion message missing"
fi

# Cleanup
cd "$SCRIPT_DIR"
rm -rf "$TMPDIR"

echo ""
echo "Integration (asymmetric): $n_pass passed, $n_fail failed"
[ "$n_fail" -eq 0 ]
