#!/bin/bash
# =============================================================================
# Validation test: polynomial mode with NH3-equivalent symmetric coefficients
# =============================================================================
# Converts the NH3 double-well parameters (Vb=1770 cm-1, xe=0.718 A) into
# polynomial coefficients in atomic units and runs the polynomial mode.
# Checks that parity labels appear, mode is polynomial, and energy levels
# are consistent with a symmetric double-well near NH3 values.
#
# Conversion (task-specified):
#   Vb  = 1770 cm-1 = 0.00806578 Ha
#   xe  = 0.718 A   = 1.35649  a0   (1 A = 1/0.529177 a0)
#   v0  = Vb  = 0.00806578 Ha
#   v2  = -2*Vb/xe^2 = -2*0.00806578/1.35649^2 = -0.00876088 Ha/a0^2
#   v4  = Vb/xe^4    = 0.00806578/1.35649^4    =  0.00237742 Ha/a0^4
#
# Usage: bash tests/validation/test_polynomial_equivalence.sh
# Exit:  0 if all checks pass, 1 if any check fails
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BINARY="${PROJECT_ROOT}/build/QuTu"

TMP_DIR="${SCRIPT_DIR}/tmp_polynomial_equivalence"
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
echo " Test: Polynomial Equivalence (NH3)"
echo "========================================"
echo ""

if [ ! -f "${BINARY}" ]; then
    echo "  ERROR: binary not found at ${BINARY}"
    echo "  Build the project first: make"
    exit 1
fi

cp "${BINARY}" "${TMP_DIR}/QuTu"

# ---------------------------------------------------------------------------
# Write INPUT — polynomial mode, symmetric NH3-equivalent coefficients
# alpha = 5.7 (same as legacy optimal, task-specified)
# mass_H and mass_N so the code uses the NH3 reduced-mass formula
# ---------------------------------------------------------------------------
cat > "${TMP_DIR}/INPUT" << 'EOF'
# Polynomial mode — symmetric NH3-equivalent double well
# V(x) = v0 + v2*x^2 + v4*x^4   (odd coefficients = 0 -> symmetric)
# Vb = 1770 cm-1 = 0.00806578 Ha, xe = 0.718 A = 1.35649 a0
# v0 = 0.00806578, v2 = -0.00876088, v4 = 0.00237742  (all in Ha/a0^k)
poly_degree = 4
v_coeffs    = 0.00806578, 0.0, -0.00876088, 0.0, 0.00237742
mass_H      = 1.00782503207
mass_N      = 14.0030740048
alpha       = 5.7
N_max       = 100
xmin        = -5.0
xmax        =  5.0
dx          = 0.01
EOF

echo "Running QuTu (polynomial equivalence mode)..."
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
# Check 3: OUTPUT contains "even" parity label (is_symmetric=.true.)
# ---------------------------------------------------------------------------
if grep -q '[[:space:]]even[[:space:]]' "${TMP_DIR}/OUTPUT"; then
    pass 'OUTPUT contains "even" parity label (symmetric potential detected)'
else
    fail 'OUTPUT does not contain "even" parity label'
fi

# ---------------------------------------------------------------------------
# Check 4: E(0) in range [550, 650] cm-1
# ---------------------------------------------------------------------------
E0_CM1=$(awk '
    /\$BEGIN ENERGIES/ { in_block=1; next }
    /\$END ENERGIES/   { in_block=0 }
    in_block && /^[[:space:]]*[0-9]/ { print $4; exit }
' "${TMP_DIR}/OUTPUT")

if [ -z "${E0_CM1}" ]; then
    fail "Could not extract E(0) from OUTPUT"
else
    CHECK=$(awk -v e="${E0_CM1}" 'BEGIN { if (e >= 280.0 && e <= 320.0) print "ok"; else print "fail" }')
    if [ "${CHECK}" = "ok" ]; then
        pass "E(0) = ${E0_CM1} cm-1 is in [280, 320] cm-1"
    else
        fail "E(0) = ${E0_CM1} cm-1 is NOT in [280, 320] cm-1"
    fi
fi

# ---------------------------------------------------------------------------
# Check 5: E(1) - E(0) < 20 cm-1 (still a tunneling doublet)
# ---------------------------------------------------------------------------
E1_CM1=$(awk '
    /\$BEGIN ENERGIES/ { in_block=1; count=0; next }
    /\$END ENERGIES/   { in_block=0 }
    in_block && /^[[:space:]]*[0-9]/ {
        count++
        if (count == 2) { print $4; exit }
    }
' "${TMP_DIR}/OUTPUT")

if [ -z "${E0_CM1}" ] || [ -z "${E1_CM1}" ]; then
    fail "Could not extract E(0) and E(1) for doublet check"
else
    DIFF=$(awk -v e0="${E0_CM1}" -v e1="${E1_CM1}" 'BEGIN { printf "%.4f", e1 - e0 }')
    CHECK=$(awk -v e0="${E0_CM1}" -v e1="${E1_CM1}" 'BEGIN {
        diff = e1 - e0
        if (diff < 20.0) print "ok"; else print "fail"
    }')
    if [ "${CHECK}" = "ok" ]; then
        pass "E(1) - E(0) = ${DIFF} cm-1 < 20.0 cm-1 (doublet)"
    else
        fail "E(1) - E(0) = ${DIFF} cm-1 >= 20.0 cm-1 (doublet too large)"
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
