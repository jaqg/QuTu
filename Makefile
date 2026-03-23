# =============================================================================
# Makefile for QuTu - Quantum Tunneling Simulation
# Modern Fortran 2008 version with modular structure
# =============================================================================

# Compiler and flags
FC = gfortran
FFLAGS_COMMON = -Wall -Wextra -pedantic -std=f2008
FFLAGS = -O2 $(FFLAGS_COMMON) -fcheck=all
FFLAGS_DEBUG = -g -O0 $(FFLAGS_COMMON) -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow
FFLAGS_RELEASE = -O3 -march=native -flto -std=f2008

# Libraries
LIBS = -llapack -lblas
LDFLAGS = -L/usr/local/lib

# Directories
SRC_DIR = src
MAIN_DIR = $(SRC_DIR)/main
MOD_DIR = $(SRC_DIR)/modules
BUILD_DIR = build
BUILD_DIR_DEBUG = $(BUILD_DIR)/debug
BUILD_DIR_RELEASE = $(BUILD_DIR)/release
DATA_DIR = data
EXAMPLES_DIR = examples
TESTS_DIR = tests

# Module source files (in dependency order)
MOD_SRCS = $(MOD_DIR)/constants.f90 \
           $(MOD_DIR)/types.f90 \
           $(MOD_DIR)/harmonic_oscillator.f90 \
           $(MOD_DIR)/hamiltonian.f90 \
           $(MOD_DIR)/pib.f90 \
           $(MOD_DIR)/wavepacket.f90 \
           $(MOD_DIR)/io.f90 \
           $(MOD_DIR)/input_reader.f90

# Main program
MAIN_SRC = $(MAIN_DIR)/qutu.f90

# Object files (default build)
MOD_OBJS = $(BUILD_DIR)/constants.o \
           $(BUILD_DIR)/types.o \
           $(BUILD_DIR)/harmonic_oscillator.o \
           $(BUILD_DIR)/hamiltonian.o \
           $(BUILD_DIR)/pib.o \
           $(BUILD_DIR)/wavepacket.o \
           $(BUILD_DIR)/io.o \
           $(BUILD_DIR)/input_reader.o

MAIN_OBJ = $(BUILD_DIR)/qutu.o

# Executables
EXEC = QuTu
EXEC_PATH = $(BUILD_DIR)/$(EXEC)

# =============================================================================
# Targets
# =============================================================================

.PHONY: all clean run debug release help test install

# Default target
all: $(BUILD_DIR) $(EXEC_PATH)

# Create build directory
$(BUILD_DIR):
	@echo "Creating build directory..."
	@mkdir -p $(BUILD_DIR)

# Link executable
$(EXEC_PATH): $(MOD_OBJS) $(MAIN_OBJ)
	@echo "Linking executable..."
	$(FC) $(FFLAGS) -o $@ $^ $(LDFLAGS) $(LIBS)
	@echo "✓ Build complete: $(EXEC_PATH)"

# Compile modules (with dependencies)
$(BUILD_DIR)/constants.o: $(MOD_DIR)/constants.f90 | $(BUILD_DIR)
	@echo "Compiling constants module..."
	$(FC) $(FFLAGS) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/types.o: $(MOD_DIR)/types.f90 $(BUILD_DIR)/constants.o | $(BUILD_DIR)
	@echo "Compiling types module..."
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/harmonic_oscillator.o: $(MOD_DIR)/harmonic_oscillator.f90 $(BUILD_DIR)/constants.o | $(BUILD_DIR)
	@echo "Compiling harmonic_oscillator module..."
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/hamiltonian.o: $(MOD_DIR)/hamiltonian.f90 $(BUILD_DIR)/constants.o $(BUILD_DIR)/types.o | $(BUILD_DIR)
	@echo "Compiling hamiltonian module..."
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/pib.o: $(MOD_DIR)/pib.f90 $(BUILD_DIR)/constants.o $(BUILD_DIR)/types.o | $(BUILD_DIR)
	@echo "Compiling pib module..."
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/wavepacket.o: $(MOD_DIR)/wavepacket.f90 $(BUILD_DIR)/constants.o $(BUILD_DIR)/types.o | $(BUILD_DIR)
	@echo "Compiling wavepacket module..."
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/io.o: $(MOD_DIR)/io.f90 $(BUILD_DIR)/constants.o $(BUILD_DIR)/types.o | $(BUILD_DIR)
	@echo "Compiling io module..."
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

$(BUILD_DIR)/input_reader.o: $(MOD_DIR)/input_reader.f90 $(BUILD_DIR)/constants.o | $(BUILD_DIR)
	@echo "Compiling input_reader module..."
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) -c -o $@ $<

# Compile main program
$(BUILD_DIR)/qutu.o: $(MAIN_SRC) $(MOD_OBJS) | $(BUILD_DIR)
	@echo "Compiling main program..."
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -c -o $@ $<

# =============================================================================
# Special builds
# =============================================================================

# Debug build
debug: FFLAGS = $(FFLAGS_DEBUG)
debug: BUILD_DIR = $(BUILD_DIR_DEBUG)
debug: MOD_OBJS = $(patsubst $(BUILD_DIR)/%.o,$(BUILD_DIR_DEBUG)/%.o,$(MOD_OBJS))
debug: MAIN_OBJ = $(BUILD_DIR_DEBUG)/qutu.o
debug: EXEC_PATH = $(BUILD_DIR_DEBUG)/$(EXEC)
debug: clean_debug
	@echo "Building DEBUG version..."
	@$(MAKE) BUILD_DIR=$(BUILD_DIR_DEBUG) FFLAGS="$(FFLAGS_DEBUG)" $(EXEC_PATH)
	@echo "✓ Debug build complete: $(EXEC_PATH)"

# Release build (optimized)
release: FFLAGS = $(FFLAGS_RELEASE)
release: BUILD_DIR = $(BUILD_DIR_RELEASE)
release: MOD_OBJS = $(patsubst $(BUILD_DIR)/%.o,$(BUILD_DIR_RELEASE)/%.o,$(MOD_OBJS))
release: MAIN_OBJ = $(BUILD_DIR_RELEASE)/qutu.o
release: EXEC_PATH = $(BUILD_DIR_RELEASE)/$(EXEC)
release: clean_release
	@echo "Building RELEASE version..."
	@$(MAKE) BUILD_DIR=$(BUILD_DIR_RELEASE) FFLAGS="$(FFLAGS_RELEASE)" $(EXEC_PATH)
	@echo "✓ Release build complete: $(EXEC_PATH)"

# =============================================================================
# Utility targets
# =============================================================================

# Run the program
run: all
	@echo "Cleaning old output files..."
	@rm -f $(DATA_DIR)/out-*.dat
	@echo "Running simulation..."
	@mkdir -p $(DATA_DIR)
	./$(EXEC_PATH)

# Install (copy to /usr/local/bin or user-specified location)
install: release
	@echo "Installing QuTu..."
	@install -m 755 $(BUILD_DIR_RELEASE)/$(EXEC) /usr/local/bin/$(EXEC)
	@echo "✓ QuTu installed to /usr/local/bin/$(EXEC)"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -f $(EXEC)
	@rm -f *.mod *.o
	@echo "✓ Clean complete"

clean_debug:
	@rm -rf $(BUILD_DIR_DEBUG)

clean_release:
	@rm -rf $(BUILD_DIR_RELEASE)

# Clean everything including output
distclean: clean
	@echo "Cleaning all generated files..."
	@rm -rf $(DATA_DIR)/out-*.dat
	@echo "✓ Distribution clean complete"

# =============================================================================
# Testing targets
# =============================================================================

# Unit test executables
TEST_UNIT_SRCS = tests/unit/test_xk_recursion.f90 \
                 tests/unit/test_parity_detection.f90 \
                 tests/unit/test_input_parser.f90 \
                 tests/unit/test_pib_matrix.f90

TEST_UNIT_EXECS = $(patsubst tests/unit/%.f90,$(BUILD_DIR)/%,$(TEST_UNIT_SRCS))

# Common module objects needed by unit tests
TEST_MOD_OBJS = $(BUILD_DIR)/constants.o \
                $(BUILD_DIR)/types.o \
                $(BUILD_DIR)/harmonic_oscillator.o \
                $(BUILD_DIR)/hamiltonian.o \
                $(BUILD_DIR)/pib.o \
                $(BUILD_DIR)/input_reader.o

# Build a unit test executable
$(BUILD_DIR)/test_%: tests/unit/test_%.f90 $(MOD_OBJS) | $(BUILD_DIR)
	$(FC) $(FFLAGS) -I$(BUILD_DIR) -o $@ $< $(MOD_OBJS) $(LDFLAGS) $(LIBS)

# Run all tests
test: test-unit test-validation test-integration

# Run unit tests
test-unit: all $(TEST_UNIT_EXECS)
	@echo ""; echo "=== Unit Tests ==="
	@n_pass=0; n_fail=0; \
	for t in $(TEST_UNIT_EXECS); do \
	    echo "--- $$t ---"; \
	    if $$t; then n_pass=$$((n_pass+1)); else n_fail=$$((n_fail+1)); fi; \
	done; \
	echo ""; echo "Unit tests: $$n_pass passed, $$n_fail failed"; \
	[ $$n_fail -eq 0 ]

# Run validation tests
test-validation: all
	@echo ""; echo "=== Validation Tests ==="
	@n_pass=0; n_fail=0; \
	for t in tests/validation/*.sh; do \
	    echo "--- $$t ---"; \
	    if bash $$t; then n_pass=$$((n_pass+1)); else n_fail=$$((n_fail+1)); fi; \
	done; \
	echo ""; echo "Validation tests: $$n_pass passed, $$n_fail failed"; \
	[ $$n_fail -eq 0 ]

# Run integration tests
test-integration: all
	@echo ""; echo "=== Integration Tests ==="
	@n_pass=0; n_fail=0; \
	for t in tests/integration/*.sh; do \
	    echo "--- $$t ---"; \
	    if bash $$t; then n_pass=$$((n_pass+1)); else n_fail=$$((n_fail+1)); fi; \
	done; \
	echo ""; echo "Integration tests: $$n_pass passed, $$n_fail failed"; \
	[ $$n_fail -eq 0 ]

# =============================================================================
# Help
# =============================================================================

help:
	@echo "QuTu - Quantum Tunneling Simulation"
	@echo "===================================="
	@echo ""
	@echo "Available targets:"
	@echo "  all          - Build the program (default)"
	@echo "  debug        - Build with debug flags"
	@echo "  release      - Build with optimization flags"
	@echo "  run          - Build and run the program"
	@echo "  clean        - Remove build artifacts"
	@echo "  distclean    - Remove all generated files"
	@echo "  install      - Install to /usr/local/bin (requires sudo)"
	@echo "  test         - Run all tests"
	@echo "  test-unit    - Run unit tests"
	@echo "  test-integration - Run integration tests"
	@echo "  test-validation  - Run validation tests"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Example usage:"
	@echo "  make              # Build with default settings"
	@echo "  make run          # Build and run"
	@echo "  make debug        # Build with debug info"
	@echo "  make release      # Build optimized version"
	@echo "  make clean        # Clean build artifacts"
	@echo ""
	@echo "Build output:"
	@echo "  Executable: $(BUILD_DIR)/$(EXEC)"
	@echo "  Debug:      $(BUILD_DIR_DEBUG)/$(EXEC)"
	@echo "  Release:    $(BUILD_DIR_RELEASE)/$(EXEC)"
	@echo ""
