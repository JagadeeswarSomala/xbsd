# XBSD

XBSD is a lightweight toolkit for cross-compiling FreeBSD binaries on Linux using Clang, LLVM, and LLD.

It automates the two parts of FreeBSD cross-compilation:

* Downloading official FreeBSD base archives
* Creating a complete FreeBSD sysroot ready for Clang and CMake

---

## Features

* Download official FreeBSD base archives
* Supports `amd64` and `arm64`
* Interactive and non-interactive modes
* Automatically generates:

  * `env.sh`
  * `toolchain.cmake`
* Uses Clang + LLD
* Performs a test compilation automatically

---

## Why XBSD?

Building software for older versions of FreeBSD can be surprisingly difficult.

Suppose you want to build a binary targeting FreeBSD 11 so that it runs on:

* FreeBSD 11
* FreeBSD 12
* FreeBSD 13
* FreeBSD 14
* newer releases as well

That is the safest way to maximize binary compatibility across FreeBSD versions.

Unfortunately, older FreeBSD releases present several challenges:

* Official package repositories may be unavailable or incomplete.
* Installing modern development tools like CMake, Git can be difficult or impossible.
* Setting up legacy build environments often requires virtual machines, jails, or manual system maintenance.

XBSD solves this by allowing you to build FreeBSD binaries entirely from Linux using a modern
LLVM toolchain while targeting an older FreeBSD release.

In short, XBSD lets you develop on modern Linux while producing binaries that run reliably across multiple FreeBSD generations.

## Requirements

Install LLVM tools on your Linux host.

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install clang llvm lld
```

### Fedora

```bash
sudo dnf install clang llvm lld
```

### Arch Linux

```bash
sudo pacman -S clang llvm lld
```

---

# Usage

## Step 1: Download FreeBSD Base

### Interactive Mode

```bash
./get-freebsd-base.sh
```

The script will:

* Prompt for architecture
* Prompt for download location
* Fetch available FreeBSD versions
* Automatically suggest the latest release

---

### Non-Interactive Mode

```bash
./get-freebsd-base.sh \
    --arch amd64 \
    --version 13.5 \
    --output ~/Downloads
```

Downloaded file:

```text
~/Downloads/freebsd-amd64-13.5-base.txz
```

---

## Step 2: Create the Sysroot

### Automatic Detection

```bash
./setup-freebsd-sysroot.sh \
    ~/Downloads/freebsd-amd64-13.5-base.txz
```

The script automatically detects:

* Architecture
* FreeBSD version

---

### Explicit Parameters

```bash
./setup-freebsd-sysroot.sh \
    --arch amd64 \
    --version 13.5 \
    ~/Downloads/freebsd-amd64-13.5-base.txz
```

---

## Installation Location

```text
~/.local/xbsd/
└── freebsd-amd64-13.5/
    ├── sysroot/
    ├── env.sh
    ├── toolchain.cmake
    ├── test.c
    └── test_bin
```

---

# Building Projects

## Using Make

```bash
source ~/.local/xbsd/freebsd-amd64-13.5/env.sh
make
```

---

## Using CMake

```bash
cmake -B build \
      -S . \
      -DCMAKE_TOOLCHAIN_FILE=$HOME/.local/xbsd/freebsd-amd64-13.5/toolchain.cmake

cmake --build build
```

---

# Example

```bash
cat > hello.c <<EOF
#include <stdio.h>

int main(void)
{
    printf("Hello, FreeBSD!\n");
    return 0;
}
EOF

source ~/.local/xbsd/freebsd-amd64-13.5/env.sh

$CC hello.c -o hello
file hello
```

Expected output:

```text
hello: ELF 64-bit LSB executable, x86-64, version 1 (FreeBSD)
```

---

# Environment Variables

After sourcing `env.sh`, the following tools are configured automatically:

* `CC`
* `CXX`
* `CPP`
* `LD`
* `AR`
* `RANLIB`
* `NM`
* `STRIP`
* `OBJCOPY`
* `OBJDUMP`

---

# Supported Architectures

* `amd64`
* `arm64`

---

# How It Works

1. Downloads `base.txz` from the official FreeBSD archive.
2. Extracts it into a dedicated sysroot.
3. Generates compiler environment scripts.
4. Generates a CMake toolchain file.
5. Verifies the installation with a test build.

---

# License

MIT License
