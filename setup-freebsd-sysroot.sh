#!/usr/bin/env bash
set -e

BASE_DIR="$HOME/.local/xbsd"

# -----------------------------
# Help
# -----------------------------
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] <base.txz>

Options:
  -a, --arch <arch>        amd64 | arm64
  -v, --version <version>   FreeBSD version (e.g. 11.0, 13.2)
  -h, --help               Show help

Example:
  $0 freebsd-amd64-11.0-base.txz
EOF
}

# -----------------------------
# Parse args
# -----------------------------
ARCH=""
VERSION=""
INPUT_FILE=""

if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--arch)
            ARCH="$2"; shift ;;
        -v|--version)
            VERSION="$2"; shift ;;
        -h|--help)
            show_help; exit 0 ;;
        *)
            INPUT_FILE="$1" ;;
    esac
    shift
done

if [[ -z "$INPUT_FILE" ]]; then
    echo "Error: base.txz file is required"
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: file not found: $INPUT_FILE"
    exit 1
fi

# -----------------------------
# Infer metadata from filename
# -----------------------------
FILENAME=$(basename "$INPUT_FILE")

if [[ -z "$ARCH" || -z "$VERSION" ]]; then
    if [[ "$FILENAME" =~ freebsd-(amd64|arm64)-([0-9]+\.[0-9]+)-base\.txz ]]; then
        ARCH="${BASH_REMATCH[1]}"
        VERSION="${BASH_REMATCH[2]}"
        echo "Detected: ARCH=$ARCH VERSION=$VERSION"
    else
        echo "Could not infer metadata from filename"

        read -rp "Architecture (amd64/arm64): " ARCH
        read -rp "FreeBSD version (e.g. 11.0 / 13.2): " VERSION
    fi
fi

# -----------------------------
# Validate
# -----------------------------
if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
    echo "Invalid architecture"
    exit 1
fi

if [[ -z "$VERSION" ]]; then
    echo "Version required"
    exit 1
fi

# -----------------------------
# Target triple mapping
# -----------------------------
if [[ "$ARCH" == "amd64" ]]; then
    TARGET_TRIPLE="x86_64-unknown-freebsd${VERSION}"
else
    TARGET_TRIPLE="aarch64-unknown-freebsd${VERSION}"
fi

# -----------------------------
# Layout
# -----------------------------
TARGET="$BASE_DIR/freebsd-${ARCH}-${VERSION}"
SYSROOT="$TARGET/sysroot"

echo "Target directory: $TARGET"
echo "Target triple: $TARGET_TRIPLE"

# -----------------------------
# Handle overwrite
# -----------------------------
if [[ -d "$TARGET" ]]; then
    echo "Warning: sysroot already exists"
    read -rp "Overwrite? (y/N): " ans
    if [[ ! "$ans" =~ ^[Yy]$ ]]; then
        echo "Aborting"
        exit 0
    fi
    rm -rf "$TARGET"
fi

mkdir -p "$SYSROOT"

# -----------------------------
# Extract sysroot
# -----------------------------
echo "Extracting base.txz..."
tar --warning=no-unknown-keyword -xf "$INPUT_FILE" -C "$SYSROOT"

# -----------------------------
# env.sh
# -----------------------------
cat > "$TARGET/env.sh" <<EOF
export SYSROOT="$SYSROOT"
export TARGET_TRIPLE="$TARGET_TRIPLE"

export CC="clang --target=\$TARGET_TRIPLE --sysroot=\$SYSROOT"
export CXX="clang++ --target=\$TARGET_TRIPLE --sysroot=\$SYSROOT"
export CPP="clang-cpp --target=\$TARGET_TRIPLE --sysroot=\$SYSROOT"

export CFLAGS="--target=\$TARGET_TRIPLE --sysroot=\$SYSROOT"
export CXXFLAGS="--target=\$TARGET_TRIPLE --sysroot=\$SYSROOT"
export LDFLAGS="--target=\$TARGET_TRIPLE --sysroot=\$SYSROOT"

# Force LLD linker (important for consistency)
export LD="ld.lld"
export AR="llvm-ar"
export RANLIB="llvm-ranlib"
export NM="llvm-nm"
export STRIP="llvm-strip"
export OBJCOPY="llvm-objcopy"
export OBJDUMP="llvm-objdump"

export CFLAGS="--target=\$TARGET_TRIPLE --sysroot=\$SYSROOT"
export CXXFLAGS="--target=\$TARGET_TRIPLE --sysroot=\$SYSROOT"
export LDFLAGS="-fuse-ld=lld --target=\$TARGET_TRIPLE --sysroot=\$SYSROOT"
ENVSH
EOF

# -----------------------------
# CMake toolchain file
# -----------------------------
cat > "$TARGET/toolchain.cmake" <<EOF
set(CMAKE_SYSTEM_NAME FreeBSD)
set(CMAKE_SYSTEM_VERSION ${VERSION})
set(CMAKE_SYSTEM_PROCESSOR ${ARCH})

set(CMAKE_SYSROOT "${SYSROOT}")

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

set(CMAKE_C_COMPILER_TARGET ${TARGET_TRIPLE})
set(CMAKE_CXX_COMPILER_TARGET ${TARGET_TRIPLE})

set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-fuse-ld=lld")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-fuse-ld=lld")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

# -----------------------------
# Test compile (real FreeBSD target test)
# -----------------------------
echo "Testing sysroot..."

TEST_FILE="$TARGET/test.c"
cat > "$TEST_FILE" <<EOF
int main() { return 0; }
EOF

if command -v clang >/dev/null 2>&1; then
    if clang \
        --target="$TARGET_TRIPLE" \
        --sysroot="$SYSROOT" \
        -fuse-ld=lld \
        "$TEST_FILE" -o "$TARGET/test_bin" 2>/dev/null; then

        echo "✔ Test compile successful"
    else
        echo "⚠ Test compile failed (sysroot may still be usable)"
    fi
else
    echo "⚠ clang not found, skipping test compile"
fi

# -----------------------------
# Done
# -----------------------------
echo ""
echo "✔ FreeBSD sysroot setup complete"
echo "Location: $TARGET"
echo ""
echo "XBSD environment is ready."
echo
echo "Usage:"
echo "  For Make-based projects:"
echo "    $ source \"$TARGET/env.sh\""
echo "    $ make"
echo
echo "  For CMake projects:"
echo "    $ cmake -B build \\"
echo "          -DCMAKE_TOOLCHAIN_FILE=\"$TARGET/toolchain.cmake\" \\"
echo "          -S ."
echo "    $ cmake --build build"
echo