#!/usr/bin/env bash
# Builds tetris.exe with the PSn00bSDK toolchain and packs it into a
# bootable PSX disc image (tetris.bin/.cue) using mkpsxiso.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

: "${PSN00BSDK_LIBS:?Set PSN00BSDK_LIBS to the PSn00bSDK lib/libpsn00b path (see toolchain/setup.sh)}"

TOOLCHAIN_FILE="$(dirname "$PSN00BSDK_LIBS")/cmake/sdk.cmake"
if [ ! -f "$TOOLCHAIN_FILE" ]; then
  # Fallback: PSn00bSDK ships the toolchain file at lib/libpsn00b/cmake/sdk.cmake
  TOOLCHAIN_FILE="$PSN00BSDK_LIBS/cmake/sdk.cmake"
fi

cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc 2>/dev/null || echo 2)"

mkpsxiso -y -o build/tetris.bin -c build/tetris.cue iso/iso.xml

echo "==> Built build/tetris.bin + build/tetris.cue"
