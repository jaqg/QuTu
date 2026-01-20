# =============================================================================
# Makefile for NH3 Double-Well Quantum Tunneling Simulation
# Modern Fortran 2003/2008 version
# =============================================================================

# Compiler and flags
FC = gfortran
FFLAGS = -O2 -Wall -Wextra -pedantic -std=f2008 -fcheck=all
FFLAGS_DEBUG = -g -O0 -Wall -Wextra -pedantic -std=f2008 -fcheck=all -fbacktrace
FFLAGS_RELEASE = -O3 -march=native -flto -std=f2008

# Libraries
LIBS = -llapack -lblas
LDFLAGS = -L/usr/local/lib

# Directories
MOD_DIR = modules
BUILD_DIR = build
DATA_DIR = data

# Module source files (in dependency order)
MOD_SRCS = $(MOD_DIR)/constants.f90 \
           $(MOD_DIR)/types.f90 \
           $(MOD_DIR)/harmonic_oscillator.f90 \
           $(MOD_DIR)/hamiltonian.f90 \
           $(MOD_DIR)/wavepacket.f90 \
           $(MOD_DIR)/io.f90 \
           $(MOD_DIR)/input_reader.f90

# Main program
MAIN_SRC = doble_pozo_NH3.f90

# Object files
MOD_OBJS = $(BUILD_DIR)/constants.o \
           $(BUILD_DIR)/types.o \
           $(BUILD_DIR)/harmonic_oscillator.o \
           $(BUILD_DIR)/hamiltonian.o \
           $(BUILD_DIR)/wavepacket.o \
           $(BUILD_DIR)/io.o \
           $(BUILD_DIR)/input_reader.o

MAIN_OBJ = $(BUILD_DIR)/doble_pozo_NH3.o

# Executable
EXEC = doble_pozo_NH3

# =============================================================================
# Targets
# =============================================================================

.PHONY: all clean run debug release help

# Default target
all: $(BUILD_DIR) $(EXEC)

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Link executable
$(EXEC): $(MOD_OBJS) $(MAIN_OBJ)
	$(FC) $(FFLAGS) -o $@ $^ $(LDFLAGS) $(LIBS)

# Compile modules (with dependencies)
$(BUILD_DIR)/constants.o: $(MOD_DIR)/constants.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/types.o: $(MOD_DIR)/types.f90 $(BUILD_DIR)/constants.o | $(BUILD_DIR)
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/harmonic_oscillator.o: $(MOD_DIR)/harmonic_oscillator.f90 $(BUILD_DIR)/constants.o | $(BUILD_DIR)
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/hamiltonian.o: $(MOD_DIR)/hamiltonian.f90 $(BUILD_DIR)/constants.o $(BUILD_DIR)/types.o | $(BUILD_DIR)
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/wavepacket.o: $(MOD_DIR)/wavepacket.f90 $(BUILD_DIR)/constants.o $(BUILD_DIR)/types.o | $(BUILD_DIR)
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/io.o: $(MOD_DIR)/io.f90 $(BUILD_DIR)/constants.o $(BUILD_DIR)/types.o | $(BUILD_DIR)
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/input_reader.o: $(MOD_DIR)/input_reader.f90 $(BUILD_DIR)/constants.o | $(BUILD_DIR)
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

# Compile main program
$(BUILD_DIR)/doble_pozo_NH3.o: $(MAIN_SRC) $(MOD_OBJS) | $(BUILD_DIR)
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -c -o $@ $<

# Debug build
debug: FFLAGS = $(FFLAGS_DEBUG)
debug: clean all

# Release build (optimized)
release: FFLAGS = $(FFLAGS_RELEASE)
release: clean all

# Run the program
run: all
	@echo "Cleaning old output files..."
	@rm -f $(DATA_DIR)/out-*.dat
	@echo "Running simulation..."
	./$(EXEC)

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -f $(EXEC)
	rm -f *.mod

# Clean everything including output
distclean: clean
	rm -f $(DATA_DIR)/out-*.dat

# Help
help:
	@echo "NH3 Double-Well Quantum Tunneling Simulation"
	@echo "============================================="
	@echo ""
	@echo "Available targets:"
	@echo "  all      - Build the program (default)"
	@echo "  debug    - Build with debug flags"
	@echo "  release  - Build with optimization flags"
	@echo "  run      - Build and run the program"
	@echo "  clean    - Remove build artifacts"
	@echo "  distclean- Remove all generated files"
	@echo "  help     - Show this help message"
	@echo ""
	@echo "Example usage:"
	@echo "  make          # Build"
	@echo "  make run      # Build and run"
	@echo "  make debug    # Build with debug info"
	@echo "  make release  # Build optimized version"
