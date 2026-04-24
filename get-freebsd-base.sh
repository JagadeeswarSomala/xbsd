#!/usr/bin/env bash

set -e

BASE_URL="http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases"

INTERACTIVE=true
ARCH=""
VERSION=""
DOWNLOAD_PATH=""

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -i, --interactive        Run in interactive mode (default)
  -a, --arch <arch>        Architecture (amd64 or arm64)
  -v, --version <version>  FreeBSD version (e.g., 13.2)
  -o, --output <path>      Download directory
  -h, --help               Show this help message

Examples:
  $0
  $0 -a amd64 -v 13.2 -o ~/Downloads
EOF
}

# ---- Parse args ----
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--interactive) INTERACTIVE=true ;;
        -a|--arch) ARCH="$2"; shift ;;
        -v|--version) VERSION="$2"; shift; INTERACTIVE=false ;;
        -o|--output) DOWNLOAD_PATH="$2"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# ---- Defaults ----
ARCH=${ARCH:-amd64}
DOWNLOAD_PATH=${DOWNLOAD_PATH:-"$HOME/Downloads"}

mkdir -p "$DOWNLOAD_PATH"

# ---- Fetch versions ----
fetch_versions() {
    curl -s "$BASE_URL/$ARCH/" \
        | grep -oE 'href="[0-9]+\.[0-9]+-RELEASE/' \
        | sed 's/href="//; s/-RELEASE\///'
}

# ---- Sort versions (with fallback) ----
sort_versions() {
    if sort -V </dev/null >/dev/null 2>&1; then
        sort -V -r
    else
        # fallback: numeric sort (less accurate but works)
        sort -r
    fi
}

# ---- Interactive mode ----
if $INTERACTIVE && [[ -z "$VERSION" ]]; then
    read -rp "Select architecture (amd64/arm64) [amd64]: " input_arch
    ARCH=${input_arch:-$ARCH}

    read -rp "Download path [$DOWNLOAD_PATH]: " input_path
    DOWNLOAD_PATH=${input_path:-$DOWNLOAD_PATH}

    echo "Fetching available versions for $ARCH..."

    VERSIONS=$(fetch_versions)

    # Filter amd64 >= 9.0
    if [[ "$ARCH" == "amd64" ]]; then
        VERSIONS=$(echo "$VERSIONS" | awk '$1 >= 9.0')
    fi

    VERSIONS=$(echo "$VERSIONS" | sort_versions)

    # ---- Auto-select latest ----
    LATEST=$(echo "$VERSIONS" | head -n 1)
    echo "Latest version detected: $LATEST"

    read -rp "Use latest version? [Y/n]: " use_latest
    use_latest=${use_latest:-Y}

    if [[ "$use_latest" =~ ^[Yy]$ ]]; then
        VERSION="$LATEST"
    else
        echo "Available versions:"
        select VERSION in $VERSIONS; do
            [[ -n "$VERSION" ]] && break
        done
    fi
fi

# ---- Validate ----
if [[ -z "$VERSION" ]]; then
    echo "Error: version is required"
    exit 1
fi

FILE_URL="$BASE_URL/$ARCH/${VERSION}-RELEASE/base.txz"
OUT_FILE="$DOWNLOAD_PATH/freebsd-${ARCH}-${VERSION}-base.txz"

echo "Downloading:"
echo "  $FILE_URL"
echo "Saving to:"
echo "  $OUT_FILE"

# ---- Download (curl → wget fallback) ----
if command -v curl >/dev/null 2>&1; then
    curl -L "$FILE_URL" -o "$OUT_FILE"
elif command -v wget >/dev/null 2>&1; then
    wget "$FILE_URL" -O "$OUT_FILE"
else
    echo "Error: neither curl nor wget is installed"
    exit 1
fi

echo "Download complete!"