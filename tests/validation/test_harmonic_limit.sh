#!/bin/bash
# =============================================================================
# Validation test: harmonic oscillator limit
# =============================================================================
# Sets the polynomial potential to a pure harmonic V(x) = v2*x^2 (v0=v1=0,
# v2=0.05) and verifies that the energy levels are equally spaced (quantum
# harmonic oscillator eigenvalues En = (n+1/2)*omega, so E_{n+1} - E_n is
# constant).
#
# INPUT parameters (task-specified):
#   v_coeffs = 0.0, 0.0, 0.05    (pure quadratic, symmetric)
#   mass = 1.0 amu
#   alpha = 10.0
#   N_max = 30
#   xmin = -5.0, xmax = 5.0, dx = 0.05
#
# Checks:
#   1. Program exits 0
#   2. OUTPUT contains "Mode        = polynomial"
#   3. OUTPUT contains "even" parity label (symmetric)
#   4. E(0) > 0  (positive zero-point energy)
#   5. Energy levels 1..4 equally spaced:
#      |E_{n+1} - E_n - (E_1 - E_0)| < 1e-4 Ha for n = 1, 2, 3
#
# Usage: bash tests/validation/test_harmonic_limit.sh
# Exit:  0 if all checks pass, 1 if any check fails
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BINARY="${PROJECT_ROOT}/build/QuTu"

TMP_DIR="${SCRIPT_DIR}/tmp_harmonic_limit"
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
echo " Test: Harmonic Oscillator Limit"
echo "========================================"
echo ""

if [ ! -f "${BINARY}" ]; then
    echo "  ERROR: binary not found at ${BINARY}"
    echo "  Build the project first: make"
    exit 1
fi

cp "${BINARY}" "${TMP_DIR}/QuTu"

# ---------------------------------------------------------------------------
# Write INPUT — pure harmonic potential V(x) = 0.05 * x^2
# ---------------------------------------------------------------------------
cat > "${TMP_DIR}/INPUT" << 'EOF'
# Pure harmonic oscillator: V(x) = 0.05 * x^2  (Ha/a0^2 * a0^2 = Ha)
# v_coeffs = v0, v1, v2  with v0=0, v1=0, v2=0.05
# Symmetric -> even parity labels expected
poly_degree = 2
v_coeffs    = 0.0, 0.0, 0.05
mass        = 1.0
alpha       = 10.0
N_max       = 30
xmin        = -5.0
xmax        =  5.0
dx          = 0.05
EOF

echo "Running QuTu (harmonic limit)..."
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
# Check 2: Mode = polynomial
# ---------------------------------------------------------------------------
if grep -q 'Mode[[:space:]]*=[[:space:]]*polynomial' "${TMP_DIR}/OUTPUT"; then
    pass 'OUTPUT contains "Mode        = polynomial"'
else
    fail 'OUTPUT does not contain "Mode        = polynomial"'
fi

# ---------------------------------------------------------------------------
# Check 3: "even" parity label (symmetric polynomial)
# ---------------------------------------------------------------------------
if grep -q '[[:space:]]even[[:space:]]' "${TMP_DIR}/OUTPUT"; then
    pass 'OUTPUT contains "even" parity label'
else
    fail 'OUTPUT does not contain "even" parity label'
fi

# ---------------------------------------------------------------------------
# Extract the first 5 energy values (in Ha) from the ENERGIES block
# Lines look like: "   0   even   <E_Ha>   <E_cm1>"
# ---------------------------------------------------------------------------
mapfile -t ENERGIES_HA < <(awk '
    /\$BEGIN ENERGIES/ { in_block=1; count=0; next }
    /\$END ENERGIES/   { in_block=0 }
    in_block && /^[[:space:]]*[0-9]/ {
        count++
        print $3
        if (count == 5) exit
    }
' "${TMP_DIR}/OUTPUT")

if [ "${#ENERGIES_HA[@]}" -lt 5 ]; then
    fail "Could not extract 5 energy levels from OUTPUT (found ${#ENERGIES_HA[@]})"
else
    # ---------------------------------------------------------------------------
    # Check 4: E(0) > 0
    # ---------------------------------------------------------------------------
    E0="${ENERGIES_HA[0]}"
    CHECK=$(awk -v e="${E0}" 'BEGIN { if (e > 0.0) print "ok"; else print "fail" }')
    if [ "${CHECK}" = "ok" ]; then
        pass "E(0) = ${E0} Ha > 0 (positive zero-point energy)"
    else
        fail "E(0) = ${E0} Ha is NOT positive"
    fi

    # ---------------------------------------------------------------------------
    # Check 5: equal spacing — compute reference spacing delta = E(1) - E(0),
    # then verify |E(n+1) - E(n) - delta| < 1e-4 Ha for n = 1, 2, 3
    # ---------------------------------------------------------------------------
    SPACING_OK=true
    DELTA=$(awk -v e0="${ENERGIES_HA[0]}" -v e1="${ENERGIES_HA[1]}" \
        'BEGIN { printf "%.10f", e1 - e0 }')

    for N in 1 2 3; do
        EN="${ENERGIES_HA[$N]}"
        EN1="${ENERGIES_HA[$((N+1))]}"
        CHECK=$(awk -v en="${EN}" -v en1="${EN1}" -v delta="${DELTA}" 'BEGIN {
            diff = en1 - en - delta
            if (diff < 0) diff = -diff
            if (diff < 1e-4) print "ok"; else print "fail:" diff
        }')
        if [ "${CHECK}" != "ok" ]; then
            SPACING_OK=false
            GAP=$(awk -v en="${EN}" -v en1="${EN1}" 'BEGIN { printf "%.6f", en1 - en }')
            fail "Equal spacing violated at n=${N}: E(${N}+1)-E(${N}) = ${GAP} Ha, expected ~${DELTA} Ha"
        fi
    done

    if [ "${SPACING_OK}" = "true" ]; then
        pass "Energy levels n=0..4 equally spaced (delta ~ ${DELTA} Ha)"
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
