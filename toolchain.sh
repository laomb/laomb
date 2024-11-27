#!/bin/bash

###
# NotBonzo's Pentium MMX Optimized GCC Installer.
###

echo "--------------------------"
echo "NotBonzo's Pentium MMX GCC Installer"
echo "--------------------------"
echo ""

ARCHITECTURE="i586-elf"
INSTALL_DIR="$HOME/toolchain-i586"
SYMLINK="neither"

BINUTILS_VERSION="2.42"
GCC_VERSION="14.1.0"

function install_packages() {
    if [ -f "/etc/os-release" ]; then
        . /etc/os-release
    else
        echo "Error: /etc/os-release not found. Cannot determine distribution." >&2
        exit 0
    fi

    declare -A pkgs=(
        [curl]="curl"
        [tar]="tar"
        [make]="make"
        [gcc]="gcc"
        [gcc-c++]="g++"
        [bison]="bison"
        [flex]="flex"
        [gmp-devel]="libgmp-dev"
        [libmpc-devel]="libmpc-dev"
        [mpfr-devel]="libmpfr-dev"
        [texinfo]="texinfo"
        [nasm]="nasm"
    )

    if [[ $ID == "fedora" || $ID == "rhel" || $ID == "centos" ]]; then
        pkgs[gcc-c++]="gcc-c++"
        pkgs[gmp-devel]="gmp-devel"
        pkgs[libmpc-devel]="libmpc-devel"
        pkgs[mpfr-devel]="mpfr-devel"
    fi

    if [[ $ID == "arch" || $ID == "manjaro" ]]; then
        pkgs[gmp-devel]="gmp"
        pkgs[libmpc-devel]="libmpc"
        pkgs[mpfr-devel]="mpfr"
    fi

    packages="${pkgs[@]}"

    case $ID in
        debian|ubuntu|pop)
            sudo apt-get update
            sudo apt-get install -y $packages
            ;;
        fedora|rhel|centos)
            sudo dnf update -y
            sudo dnf install -y $packages
            ;;
        arch|manjaro)
            sudo pacman -Syu --noconfirm $packages
            ;;
        opensuse|opensuse-leap|opensuse-tumbleweed)
            sudo zypper refresh
            sudo zypper install -y $packages
            ;;
        *)
            echo "Error: Unsupported distribution '$ID'. Please install the required packages manually:" >&2
            echo "${!pkgs[@]}"
            exit 0
            ;;
    esac
}

function check_requirements() {
    for cmd in curl tar make gcc realpath g++ bison flex nasm; do
        if ! command -v $cmd &> /dev/null; then
            echo "Error: Required command '$cmd' is not installed." >&2
            exit 0
        fi
    done
}

function install_toolchain() {
    echo "Installing i586 toolchain optimized for Pentium MMX in $INSTALL_DIR..."
    TOOLCHAIN_PREFIX=$(realpath -m "$INSTALL_DIR/$ARCHITECTURE")

    mkdir -p "$TOOLCHAIN_PREFIX"

    cd "$TOOLCHAIN_PREFIX" || { echo "Failed to change directory to $TOOLCHAIN_PREFIX"; exit 0; }

    MAKEFLAGS="-j$(nproc)"

    function fetch() {
        url="$1"
        filename="${url##*/}"
        if [ ! -f "$filename" ]; then
            echo "Downloading $filename..."
            curl -LO "$url" || { echo "Failed to download $filename"; exit 0; }
        fi
        if [ ! -s "$filename" ]; then
            echo "Error: Downloaded file $filename is empty." >&2
            exit 0
        fi
    }

    BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz"
    GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"

    fetch "$BINUTILS_URL"
    fetch "$GCC_URL"

    echo "Extracting GCC..."
    tar -xf "gcc-${GCC_VERSION}.tar.xz" || { echo "Failed to extract GCC."; exit 0; }
    echo "Extracting Binutils..."
    tar -xf "binutils-${BINUTILS_VERSION}.tar.xz" || { echo "Failed to extract Binutils."; exit 0; }

    mkdir -p "$TOOLCHAIN_PREFIX/build-binutils"
    mkdir -p "$TOOLCHAIN_PREFIX/build-gcc"

    pushd "$TOOLCHAIN_PREFIX/build-binutils" > /dev/null
    ../binutils-${BINUTILS_VERSION}/configure \
        --prefix="$TOOLCHAIN_PREFIX"              \
        --target=$ARCHITECTURE                    \
        --disable-nls                             \
        --disable-werror && make $MAKEFLAGS && make install
    popd > /dev/null

    pushd "$TOOLCHAIN_PREFIX/build-gcc" > /dev/null
    ../gcc-${GCC_VERSION}/configure \
        --prefix="$TOOLCHAIN_PREFIX"       \
        --target=$ARCHITECTURE             \
        --disable-nls                      \
        --enable-languages=c,c++           \
        --without-headers                  \
        --with-arch=pentium-mmx            \
        --with-tune=pentium-mmx            \
        CFLAGS_FOR_TARGET="-march=pentium-mmx -mtune=pentium-mmx" \
        CXXFLAGS_FOR_TARGET="-march=pentium-mmx -mtune=pentium-mmx" \
        && make $MAKEFLAGS all-gcc all-target-libgcc && make install-gcc install-target-libgcc
    popd > /dev/null

    echo "Installation complete."
    echo "Run $ARCHITECTURE-gcc for the GNU C Compiler"
    echo "Run $ARCHITECTURE-ld for the GNU Linker"
    echo "Run $ARCHITECTURE-as for the GNU Assembler"
    echo "Run $ARCHITECTURE-g++ for the GNU C++ Compiler"
}

check_requirements
install_packages
install_toolchain
