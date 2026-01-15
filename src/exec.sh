#!/usr/bin/env bash
rm -f data/out-*.dat
gfortran doble_pozo_NH3.f90 subrutinas/*.f90 -o doble_pozo_NH3 -L/usr/local/lib/ -llapack -lblas
./doble_pozo_NH3
