#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Running asymmetric double-well..."
../../build/QuTu
echo "Done. Results in OUTPUT"
