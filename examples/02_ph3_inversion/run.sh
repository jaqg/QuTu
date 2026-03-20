#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Running PH3 umbrella inversion..."
../../build/QuTu
echo "Done. Results in OUTPUT"
