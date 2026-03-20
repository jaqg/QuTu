#!/bin/bash
# =============================================================================
# Validation test: NH3 legacy mode regression
# =============================================================================
# Runs the QuTu binary in legacy xe/Vb mode with NH3-like parameters and
# verifies that key energy quantities appear in the OUTPUT with correct values.
#
# Usage: bash tests/validation/test_NH3_regression.sh
# Exit:  0 if all checks pass, 1 if any check fails
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate project root (two levels up from this script's directory)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BINARY="${PROJECT_ROOT}/build/QuTu"

# ---------------------------------------------------------------------------
# Setup temporary working directory
# ---------------------------------------------------------------------------
TMP_DIR="${SCRIPT_DIR}/tmp_NH3_regression"
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"

# ---------------------------------------------------------------------------
# Cleanup on exit
# ---------------------------------------------------------------------------
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Check binary exists
# ---------------------------------------------------------------------------
echo "========================================"
echo " Test: NH3 Legacy Mode Regression"
echo "========================================"
echo ""

if [ ! -f "${BINARY}" ]; then
    echo "  ERROR: binary not found at ${BINARY}"
    echo "  Build the project first: make"
    exit 1
fi

cp "${BINARY}" "${TMP_DIR}/QuTu"

# ---------------------------------------------------------------------------
# Write INPUT file
# Parameters specified in the task (different from the example 01 INPUT):
#   N_max=100, xe=0.718 A, Vb=1770.0 cm-1
#   mass_H=1.00782503207, mass_N=14.0030740048
#   xmin=-5.0, xmax=5.0, dx=0.01
# ---------------------------------------------------------------------------
cat > "${TMP_DIR}/INPUT" << 'EOF'
# NH3 regression test INPUT — legacy xe/Vb mode
N_max  = 100
xe     = 0.718
Vb     = 1770.0
mass_H = 1.00782503207
mass_N = 14.0030740048
xmin   = -5.0
xmax   =  5.0
dx     = 0.01
EOF

# ---------------------------------------------------------------------------
# Run QuTu
# ---------------------------------------------------------------------------
echo "Running QuTu (legacy NH3 mode)..."
cd "${TMP_DIR}"
EXIT_CODE=0
./QuTu > /dev/null 2>&1 || EXIT_CODE=$?

# ---------------------------------------------------------------------------
# Check 1: program exits 0
# ---------------------------------------------------------------------------
echo ""
echo "Checks:"
if [ "${EXIT_CODE}" -eq 0 ]; then
    pass "Program exits with code 0"
else
    fail "Program exited with code ${EXIT_CODE} (expected 0)"
fi

# Remaining checks only make sense if OUTPUT was produced
if [ ! -f "${TMP_DIR}/OUTPUT" ]; then
    fail "OUTPUT file was not created"
    echo ""
    echo "Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
    exit 1
fi

# ---------------------------------------------------------------------------
# Check 2: OUTPUT contains $END ENERGIES
# ---------------------------------------------------------------------------
if grep -q '\$END ENERGIES' "${TMP_DIR}/OUTPUT"; then
    pass 'OUTPUT contains "$END ENERGIES"'
else
    fail 'OUTPUT does not contain "$END ENERGIES"'
fi

# ---------------------------------------------------------------------------
# Check 3: OUTPUT contains "even" parity label
# ---------------------------------------------------------------------------
if grep -q '[[:space:]]even[[:space:]]' "${TMP_DIR}/OUTPUT"; then
    pass 'OUTPUT contains "even" parity label'
else
    fail 'OUTPUT does not contain "even" parity label'
fi

# ---------------------------------------------------------------------------
# Check 4: E(0) ground state energy is in range [580, 600] cm-1
# Extract the first "even" line from the ENERGIES section and read the cm-1 column.
# Expected line format: "   0   even   <E_Ha>   <E_cm1>"
# ---------------------------------------------------------------------------
E0_CM1=$(awk '
    /\$BEGIN ENERGIES/ { in_block=1; next }
    /\$END ENERGIES/   { in_block=0 }
    in_block && /[[:space:]]0[[:space:]].*even/ { print $4; exit }
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
# Check 5: E(1) - E(0) < 5.0 cm-1 (tunneling doublet is small)
# The first two lines in the ENERGIES block are E(0) even and E(1) odd.
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
    fail "Could not extract E(0) and E(1) from OUTPUT for doublet check"
else
    CHECK=$(awk -v e0="${E0_CM1}" -v e1="${E1_CM1}" 'BEGIN {
        diff = e1 - e0
        if (diff < 5.0) print "ok"
        else print "fail:" diff
    }')
    if [ "${CHECK}" = "ok" ]; then
        DIFF=$(awk -v e0="${E0_CM1}" -v e1="${E1_CM1}" 'BEGIN { printf "%.4f", e1 - e0 }')
        pass "E(1) - E(0) = ${DIFF} cm-1 < 5.0 cm-1 (tunneling doublet)"
    else
        DIFF=$(awk -v e0="${E0_CM1}" -v e1="${E1_CM1}" 'BEGIN { printf "%.4f", e1 - e0 }')
        fail "E(1) - E(0) = ${DIFF} cm-1 >= 5.0 cm-1 (doublet too large)"
    fi
fi

# ---------------------------------------------------------------------------
# Check 6: E(2) > 1500 cm-1 (second excited level well above ground)
# The third data line in the ENERGIES block (n=2)
# ---------------------------------------------------------------------------
E2_CM1=$(awk '
    /\$BEGIN ENERGIES/ { in_block=1; count=0; next }
    /\$END ENERGIES/   { in_block=0 }
    in_block && /^[[:space:]]*[0-9]/ {
        count++
        if (count == 3) { print $4; exit }
    }
' "${TMP_DIR}/OUTPUT")

if [ -z "${E2_CM1}" ]; then
    fail "Could not extract E(2) from OUTPUT"
else
    CHECK=$(awk -v e="${E2_CM1}" 'BEGIN { if (e > 800.0) print "ok"; else print "fail" }')
    if [ "${CHECK}" = "ok" ]; then
        pass "E(2) = ${E2_CM1} cm-1 > 800 cm-1"
    else
        fail "E(2) = ${E2_CM1} cm-1 is NOT > 800 cm-1"
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
