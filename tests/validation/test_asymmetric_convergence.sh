#!/bin/bash
# =============================================================================
# Validation test: asymmetric double-well convergence
# =============================================================================
# Adds a linear bias term (v1 = 0.001 Ha/a0) to the symmetric NH3-equivalent
# polynomial coefficients. This breaks parity, so:
#   - No "even"/"odd" parity labels should appear in the energies section
#   - Mode should be polynomial
#   - is_symmetric=F should appear in the OUTPUT
#   - Energies should be ordered E(0) < E(1) < E(2)
#
# INPUT parameters (task-specified):
#   v_coeffs = 0.00806578, 0.001, -0.00876088, 0.0, 0.00237742
#   alpha = 5.7
#   mass_H = 1.00782503207, mass_N = 14.0030740048
#   N_max = 100, xmin=-5.0, xmax=5.0, dx=0.01
#
# Usage: bash tests/validation/test_asymmetric_convergence.sh
# Exit:  0 if all checks pass, 1 if any check fails
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BINARY="${PROJECT_ROOT}/build/QuTu"

TMP_DIR="${SCRIPT_DIR}/tmp_asymmetric_convergence"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo "  PASS: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "  FAIL: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo "========================================"
echo " Test: Asymmetric Double-Well Convergence"
echo "========================================"
echo ""

if [ ! -f "${BINARY}" ]; then
    echo "  ERROR: binary not found at ${BINARY}"
    echo "  Build the project first: make"
    exit 1
fi

cp "${BINARY}" "${TMP_DIR}/QuTu"

# ---------------------------------------------------------------------------
# Write INPUT — asymmetric: v1=0.001 breaks symmetry
# ---------------------------------------------------------------------------
cat > "${TMP_DIR}/INPUT" << 'EOF'
# Asymmetric double-well: NH3-equivalent + linear bias v1 = 0.001 Ha/a0
# V(x) = v0 + v1*x + v2*x^2 + v3*x^3 + v4*x^4
# v0 = 0.00806578, v1 = 0.001 (bias), v2 = -0.00876088, v3 = 0.0, v4 = 0.00237742
# Odd coefficient v1 != 0  ->  is_symmetric = .false.
poly_degree = 4
v_coeffs    = 0.00806578, 0.001, -0.00876088, 0.0, 0.00237742
mass_H      = 1.00782503207
mass_N      = 14.0030740048
alpha       = 5.7
N_max       = 100
xmin        = -5.0
xmax        =  5.0
dx          = 0.01
EOF

echo "Running QuTu (asymmetric polynomial mode)..."
cd "${TMP_DIR}"
EXIT_CODE=0
./QuTu > /dev/null 2>&1 || EXIT_CODE=$?

echo ""
echo "Checks:"

# ---------------------------------------------------------------------------
# Check 1: program exits 0
# ---------------------------------------------------------------------------
if [ "${EXIT_CODE}" -eq 0 ]; then
    pass "Program exits with code 0"
else
    fail "Program exited with code ${EXIT_CODE} (expected 0)"
fi

if [ ! -f "${TMP_DIR}/OUTPUT" ]; then
    fail "OUTPUT file was not created"
    echo ""
    echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
    exit 1
fi

# ---------------------------------------------------------------------------
# Check 2: OUTPUT contains "Mode        = polynomial"
# ---------------------------------------------------------------------------
if grep -q 'Mode[[:space:]]*=[[:space:]]*polynomial' "${TMP_DIR}/OUTPUT"; then
    pass 'OUTPUT contains "Mode        = polynomial"'
else
    fail 'OUTPUT does not contain "Mode        = polynomial"'
fi

# ---------------------------------------------------------------------------
# Check 3: parity labels absent from the ENERGIES section
# The word "even" should NOT appear inside the $BEGIN ENERGIES ... $END ENERGIES block.
# ---------------------------------------------------------------------------
EVEN_IN_ENERGIES=$(awk '
    /\$BEGIN ENERGIES/ { in_block=1; next }
    /\$END ENERGIES/   { in_block=0 }
    in_block && /[[:space:]]even[[:space:]]/ { print "found"; exit }
' "${TMP_DIR}/OUTPUT")

if [ -z "${EVEN_IN_ENERGIES}" ]; then
    pass 'No "even" parity label in ENERGIES section (asymmetric as expected)'
else
    fail '"even" parity label found in ENERGIES section (unexpected for asymmetric potential)'
fi

# ---------------------------------------------------------------------------
# Check 4: is_symmetric=F appears in the OUTPUT (SYSTEM PARAMETERS section)
# ---------------------------------------------------------------------------
if grep -qi 'is_symmetric[[:space:]]*=[[:space:]]*[Ff]' "${TMP_DIR}/OUTPUT"; then
    pass 'OUTPUT contains is_symmetric = F (or false)'
else
    fail 'OUTPUT does not contain is_symmetric = F'
fi

# ---------------------------------------------------------------------------
# Check 5: E(0) < E(1) < E(2)  (energies ordered)
# Extract the first 3 data lines from the ENERGIES block (cm-1 column)
# ---------------------------------------------------------------------------
mapfile -t ENERGIES_CM1 < <(awk '
    /\$BEGIN ENERGIES/ { in_block=1; count=0; next }
    /\$END ENERGIES/   { in_block=0 }
    in_block && /^[[:space:]]*[0-9]/ {
        count++
        print $3
        if (count == 3) exit
    }
' "${TMP_DIR}/OUTPUT")

if [ "${#ENERGIES_CM1[@]}" -lt 3 ]; then
    fail "Could not extract 3 energy levels from OUTPUT (found ${#ENERGIES_CM1[@]})"
else
    E0="${ENERGIES_CM1[0]}"
    E1="${ENERGIES_CM1[1]}"
    E2="${ENERGIES_CM1[2]}"

    CHECK=$(awk -v e0="${E0}" -v e1="${E1}" -v e2="${E2}" 'BEGIN {
        if (e0 < e1 && e1 < e2) print "ok"; else print "fail"
    }')
    if [ "${CHECK}" = "ok" ]; then
        pass "Energies ordered: E(0)=${E0} < E(1)=${E1} < E(2)=${E2} cm-1"
    else
        fail "Energies NOT ordered: E(0)=${E0}, E(1)=${E1}, E(2)=${E2} cm-1"
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
echo " Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
echo "========================================"

if [ "${FAIL_COUNT}" -gt 0 ]; then
    exit 1
fi
exit 0
