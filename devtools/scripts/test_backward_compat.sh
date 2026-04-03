#!/bin/bash
# Test pydca backward compatibility across Python versions using Docker.
#
# Uses unpinned biopython — older Pythons get older biopython naturally.
# Python 3.7.8 matches the version in how_to_docker.md.
#
# numba/llvmlite are only installed when a compatible wheel exists;
# meanfield_dca tests are skipped otherwise.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Test matrix: "python_tag  label" ---
MATRIX=(
  "3.7.8  docker-doc"
  "3.7    latest-3.7"
  "3.9    latest-3.9"
  "3.11   latest-3.11"
  "3.13   latest-3.13"
)

pass_count=0
fail_count=0
skip_count=0
results=()

for entry in "${MATRIX[@]}"; do
  read -r pyver label <<< "$entry"
  tag="Python ${pyver} (${label})"
  echo ""
  echo "============================================"
  echo "  ${tag}"
  echo "============================================"

  # Run tests inside a Docker container
  output=$(docker run --rm \
    -v "${REPO_DIR}:/app:ro" \
    -w /app \
    "python:${pyver}" \
    bash -c '
      # Upgrade pip first (old images ship ancient pip)
      pip install --upgrade pip setuptools wheel 2>&1 | tail -3

      # Install deps (unpinned biopython — resolver picks version for this Python)
      pip install biopython scipy numpy matplotlib requests 2>&1 | tail -5

      # Try to install numba + llvmlite (optional)
      HAVE_NUMBA=0
      if pip install numba llvmlite 2>/dev/null; then
        HAVE_NUMBA=1
      fi

      echo "--- Installed biopython version ---"
      python -c "import Bio; print(Bio.__version__)"

      echo "--- Testing old API availability ---"
      python -c "
try:
    from Bio.SubsMat.MatrixInfo import blosum62
    from Bio import pairwise2
    print(\"OLD API: available\")
except ImportError:
    print(\"OLD API: not available\")
"

      echo "--- Testing new API availability ---"
      python -c "
try:
    from Bio.Align import substitution_matrices, PairwiseAligner
    print(\"NEW API: available\")
except ImportError:
    print(\"NEW API: not available\")
"

      echo "--- Running fasta_reader and sequence_backmapper tests ---"
      PYTHONPATH=. python -m unittest \
        tests.fasta_reader_test \
        tests.sequence_backmapper_test \
        -v 2>&1

      # Run meanfield_dca test only if numba is available
      if [ "$HAVE_NUMBA" = "1" ]; then
        echo "--- Running meanfield_dca tests (numba available) ---"
        PYTHONPATH=. python -m unittest tests.meanfield_dca_test -v 2>&1
      else
        echo "--- Skipping meanfield_dca tests (numba not available) ---"
      fi
    ' 2>&1) && rc=0 || rc=$?

  echo "$output"

  if [ $rc -eq 0 ]; then
    echo -e "${GREEN}>>> PASS: ${tag}${NC}"
    results+=("PASS  ${tag}")
    ((pass_count++))
  elif echo "$output" | grep -q "Could not find a version"; then
    echo -e "${YELLOW}>>> SKIP: ${tag} (deps unavailable)${NC}"
    results+=("SKIP  ${tag}")
    ((skip_count++))
  else
    echo -e "${RED}>>> FAIL: ${tag}${NC}"
    results+=("FAIL  ${tag}")
    ((fail_count++))
  fi
done

echo ""
echo "============================================"
echo "  SUMMARY"
echo "============================================"
for r in "${results[@]}"; do
  case "$r" in
    PASS*) echo -e "${GREEN}${r}${NC}" ;;
    FAIL*) echo -e "${RED}${r}${NC}" ;;
    SKIP*) echo -e "${YELLOW}${r}${NC}" ;;
  esac
done
echo ""
echo "Passed: ${pass_count}  Failed: ${fail_count}  Skipped: ${skip_count}"

if [ $fail_count -gt 0 ]; then
  exit 1
fi
