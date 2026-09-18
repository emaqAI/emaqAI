#!/usr/bin/env bash
# Installs the PSn00bSDK toolchain (MIPS cross GCC + PSX libraries) and
# mkpsxiso, needed to build games/tetris-psx into a bootable PSX disc image.
#
# Usage: ./setup.sh [install_prefix]
#   install_prefix defaults to ~/.psn00bsdk
set -euo pipefail

PREFIX="${1:-$HOME/.psn00bsdk}"
JOBS="$(nproc 2>/dev/null || echo 2)"

mkdir -p "$PREFIX"
cd "$PREFIX"

echo "==> Installing PSn00bSDK to $PREFIX"

if [ ! -d PSn00bSDK ]; then
  git clone --recursive https://github.com/Lameguy64/PSn00bSDK.git
fi
cd PSn00bSDK

cmake --preset default -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build cmake-build --target install -- -j"$JOBS"

echo "==> Building mkpsxiso"
cd "$PREFIX"
if [ ! -d mkpsxiso ]; then
  git clone --recursive https://github.com/Lameguy64/mkpsxiso.git
fi
cd mkpsxiso
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$JOBS"
cp build/mkpsxiso "$PREFIX/bin/" 2>/dev/null || cp mkpsxiso/build/mkpsxiso "$PREFIX/bin/"

echo "==> Done. Add to your shell profile:"
echo "    export PATH=\"$PREFIX/bin:\$PATH\""
echo "    export PSN00BSDK_LIBS=\"$PREFIX/lib/libpsn00b\""
