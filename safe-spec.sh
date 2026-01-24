#!/bin/bash
# safe-spec: Detached, non-blocking spec runner for Crystal
# Prevents AI provider hangs during long compilations.

# 1. Cleanup old zombie processes
pkill -9 -f crystal > /dev/null 2>&1 || true
rm -f spec_out.txt

# 2. Fast Checks (Foreground)
echo "[FORMAT] Running Crystal format..."
crystal tool format

echo "[LINT] Running Ameba..."
ameba --format progress

# 3. Heavy Lift (Detached)
echo "[SPEC] Compiling and Running Specs (Detached)..."
# "$@" allows passing specific files: safe-spec spec/models/user_spec.cr
(nohup crystal spec --no-color "$@" > spec_out.txt 2>&1 &)

# 4. The Wait & Peek
echo "[WAIT] Waiting 10s for LLVM optimization..."
sleep 10
echo "------------------------------------------------"
cat spec_out.txt
echo "------------------------------------------------"
echo "[HINT] If results are missing, run 'cat spec_out.txt' in 5 seconds."
