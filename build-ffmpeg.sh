#!/bin/bash

set -e

# FFmpeg Universal Binary Build Script for macOS
# Builds universal (arm64 + x86_64) binaries for ffmpeg and ffprobe
# with rich codec support and static linking

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


# Parse command line arguments
FORCE_DOWNLOAD=false
for arg in "$@"; do
    case $arg in
        --force-download)
            FORCE_DOWNLOAD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force-download    Force re-download of all source archives"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Environment variables to override versions:"
            echo "  FFMPEG_VERSION, X265_VERSION, LIBVPX_VERSION, OPUS_VERSION,"
            echo "  LAME_VERSION, FDK_AAC_VERSION, OGG_VERSION, VORBIS_VERSION,"
            echo "  AOM_VERSION, FREETYPE_VERSION, FONTCONFIG_VERSION, LIBASS_VERSION,"
            echo "  FRIBIDI_VERSION, HARFBUZZ_VERSION, LIBUNIBREAK_VERSION, GLIB_VERSION,"
            echo "  WEBP_VERSION, DAV1D_VERSION, THEORA_VERSION, SOXR_VERSION,"
            echo "  LIBBLURAY_VERSION, SPEEX_VERSION, SNAPPY_VERSION, OPENJPEG_VERSION,"
            echo "  ZIMG_VERSION, ZLIB_VERSION, BROTLI_VERSION"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# Configuration
WORK_DIR="$(pwd)/build"
OUTPUT_DIR="$(pwd)/output"
CACHE_DIR="$(pwd)/.source-cache"
LOG_DIR="$(pwd)/logs"
INSTALL_DIR_ARM64="${WORK_DIR}/install-arm64"
INSTALL_DIR_X86_64="${WORK_DIR}/install-x86_64"

# Default codec library versions (can be overridden by environment variables)
DEFAULT_FFMPEG_VERSION="8.0"
DEFAULT_X265_VERSION="3.6"
DEFAULT_LIBVPX_VERSION="1.15.2"
DEFAULT_OPUS_VERSION="1.5.2"
DEFAULT_LAME_VERSION="3.100"
DEFAULT_FDK_AAC_VERSION="2.0.3"
DEFAULT_OGG_VERSION="1.3.6"
DEFAULT_VORBIS_VERSION="1.3.7"
DEFAULT_AOM_VERSION="3.13.1"
DEFAULT_FREETYPE_VERSION="2.14.1"
DEFAULT_FONTCONFIG_VERSION="2.16.0"
DEFAULT_LIBASS_VERSION="0.17.4"
DEFAULT_FRIBIDI_VERSION="1.0.16"
DEFAULT_HARFBUZZ_VERSION="10.1.0"
DEFAULT_LIBUNIBREAK_VERSION="6.1"
DEFAULT_GLIB_VERSION="2.82.4"
DEFAULT_WEBP_VERSION="1.6.0"
DEFAULT_DAV1D_VERSION="1.5.0"
DEFAULT_THEORA_VERSION="1.2.0"
DEFAULT_SOXR_VERSION="0.1.3"
DEFAULT_LIBBLURAY_VERSION="1.3.4"
DEFAULT_SPEEX_VERSION="1.2.1"
DEFAULT_SNAPPY_VERSION="1.2.1"
DEFAULT_OPENJPEG_VERSION="2.5.4"
DEFAULT_ZIMG_VERSION="3.0.5"
DEFAULT_ZLIB_VERSION="1.3.1"
DEFAULT_BROTLI_VERSION="1.1.0"

# Codec library repositories
# Note: x264 doesn't have versioned releases, so we clone the latest commit from git
X264_REPO="https://code.videolan.org/videolan/x264.git"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FFmpeg Universal Binary Build Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Function to print status messages
print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

# Check for required tools
check_dependencies() {
    print_status "Checking dependencies..."

    local missing_deps=()

    if ! command -v brew &> /dev/null; then
        print_error "Homebrew is not installed. Please install from https://brew.sh"
        exit 1
    fi

    # Check for required Homebrew packages
    local required_packages=("nasm" "pkg-config" "cmake" "autoconf" "automake" "libtool" "yasm")

    for package in "${required_packages[@]}"; do
        if ! brew list "$package" &> /dev/null; then
            missing_deps+=("$package")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "Installing missing dependencies: ${missing_deps[*]}"
        brew install "${missing_deps[@]}"
    else
        print_status "All dependencies are installed"
    fi
}

# Download file with caching
download_file() {
    local url=$1
    local filename=$2
    local cached_file="${CACHE_DIR}/${filename}"

    mkdir -p "${CACHE_DIR}"

    if [ "$FORCE_DOWNLOAD" = true ]; then
        print_status "Force downloading ${filename}..."
        curl -L "${url}" -o "${cached_file}"
    elif [ -f "${cached_file}" ]; then
        print_status "Using cached ${filename}"
    else
        print_status "Downloading ${filename}..."
        curl -L "${url}" -o "${cached_file}"
    fi

    # Copy from cache to work directory
    cp "${cached_file}" "${WORK_DIR}/"
}

# Clean previous build
clean_build() {
    print_status "Cleaning previous build..."
    rm -rf "${WORK_DIR}"
    rm -rf "${OUTPUT_DIR}"
    rm -rf "${LOG_DIR}"
    mkdir -p "${WORK_DIR}"
    mkdir -p "${OUTPUT_DIR}"
    mkdir -p "${LOG_DIR}"
    mkdir -p "${INSTALL_DIR_ARM64}"
    mkdir -p "${INSTALL_DIR_X86_64}"

    if [ "$FORCE_DOWNLOAD" = true ]; then
        print_status "Cleaning source cache..."
        rm -rf "${CACHE_DIR}"
    fi
}

# Build a library for a specific architecture
build_library() {
    local name=$1
    local arch=$2
    local build_func=$3
    local install_dir=$4

    print_status "Building ${name} for ${arch}..."

    export ARCH="${arch}"
    export INSTALL_DIR="${install_dir}"
    export MACOSX_DEPLOYMENT_TARGET="11.0"

    if [ "${arch}" = "arm64" ]; then
        export CFLAGS="-arch arm64 -mmacosx-version-min=11.0"
        export CXXFLAGS="-arch arm64 -mmacosx-version-min=11.0"
        export LDFLAGS="-arch arm64 -mmacosx-version-min=11.0"
        export HOST="aarch64-apple-darwin"
    else
        export CFLAGS="-arch x86_64 -mmacosx-version-min=11.0"
        export CXXFLAGS="-arch x86_64 -mmacosx-version-min=11.0"
        export LDFLAGS="-arch x86_64 -mmacosx-version-min=11.0"
        export HOST="x86_64-apple-darwin"
    fi

    export PKG_CONFIG_PATH="${install_dir}/lib/pkgconfig"

    $build_func

}

build_x264() {
    cd "${WORK_DIR}"
    if [ ! -d "x264" ]; then
        git clone --depth 1 "${X264_REPO}"
    fi
    cd x264

    ./configure \
        --prefix="${INSTALL_DIR}" \
        --enable-static \
        --disable-shared \
        --enable-pic \
        --host="${HOST}"

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "x264 build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

build_x265() {
    cd "${WORK_DIR}"
    if [ ! -d "x265_${X265_VERSION}" ]; then
        download_file "https://get.videolan.org/x265/x265_${X265_VERSION}.tar.gz" "x265_${X265_VERSION}.tar.gz"
        tar xzf "x265_${X265_VERSION}.tar.gz"
    fi

    cd "x265_${X265_VERSION}"

    # Patch CMakeLists.txt for CMake 4.x compatibility
    # Always restore from backup if it exists, then re-apply patch
    if [ -f "source/CMakeLists.txt.bak" ]; then
        cp source/CMakeLists.txt.bak source/CMakeLists.txt
    fi

    if [ -f "source/CMakeLists.txt" ]; then
        # Create backup if it doesn't exist
        if [ ! -f "source/CMakeLists.txt.orig" ]; then
            cp source/CMakeLists.txt source/CMakeLists.txt.orig
        fi

        # Remove obsolete policy settings
        sed -i.bak '/cmake_policy(SET CMP0025 OLD)/d' source/CMakeLists.txt
        sed -i.bak '/cmake_policy(SET CMP0054 OLD)/d' source/CMakeLists.txt
        # Update cmake_minimum_required - replace any version < 3.5 with 3.5
        sed -i.bak 's/cmake_minimum_required(VERSION 2\.[0-9]*)/cmake_minimum_required(VERSION 3.5)/' source/CMakeLists.txt
    fi

    cd build/linux

    if ! cmake -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DENABLE_SHARED=OFF \
        -DENABLE_CLI=OFF \
        -DENABLE_ASSEMBLY=OFF \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        ../../source; then
        print_error "x265 configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "x265 build failed for ${ARCH}"
        exit 1
    fi

    make install
    rm -rf ./*
}

build_libvpx() {
    cd "${WORK_DIR}"
    if [ ! -d "libvpx-${LIBVPX_VERSION}" ]; then
        download_file "https://github.com/webmproject/libvpx/archive/v${LIBVPX_VERSION}.tar.gz" "libvpx-${LIBVPX_VERSION}.tar.gz"
        tar xzf "libvpx-${LIBVPX_VERSION}.tar.gz"
    fi

    cd "libvpx-${LIBVPX_VERSION}"

    local target=""
    if [ "${ARCH}" = "arm64" ]; then
        target="arm64-darwin20-gcc"
    else
        target="x86_64-darwin20-gcc"
    fi

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --disable-examples \
        --disable-unit-tests \
        --enable-vp8 \
        --enable-vp9 \
        --enable-pic \
        --target="${target}"; then
        print_error "libvpx configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "libvpx build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

build_opus() {
    cd "${WORK_DIR}"
    if [ ! -d "opus-${OPUS_VERSION}" ]; then
        download_file "https://downloads.xiph.org/releases/opus/opus-${OPUS_VERSION}.tar.gz" "opus-${OPUS_VERSION}.tar.gz"
        tar xzf "opus-${OPUS_VERSION}.tar.gz"
    fi

    cd "opus-${OPUS_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}"; then
        print_error "opus configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "opus build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

# Build lame (MP3)
build_lame() {
    cd "${WORK_DIR}"
    if [ ! -d "lame-${LAME_VERSION}" ]; then
        download_file "https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz" "lame-${LAME_VERSION}.tar.gz"
        tar xzf "lame-${LAME_VERSION}.tar.gz"
    fi

    cd "lame-${LAME_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --disable-frontend \
        --host="${HOST}"; then
        print_error "lame configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "lame build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

build_fdk_aac() {
    cd "${WORK_DIR}"
    if [ ! -d "fdk-aac-${FDK_AAC_VERSION}" ]; then
        download_file "https://github.com/mstorsjo/fdk-aac/archive/v${FDK_AAC_VERSION}.tar.gz" "fdk-aac-${FDK_AAC_VERSION}.tar.gz"
        tar xzf "fdk-aac-${FDK_AAC_VERSION}.tar.gz"
    fi

    cd "fdk-aac-${FDK_AAC_VERSION}"

    autoreconf -fiv

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}"; then
        print_error "fdk-aac configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "fdk-aac build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

build_libogg() {
    cd "${WORK_DIR}"
    if [ ! -d "libogg-${OGG_VERSION}" ]; then
        download_file "https://downloads.xiph.org/releases/ogg/libogg-${OGG_VERSION}.tar.gz" "libogg-${OGG_VERSION}.tar.gz"
        tar xzf "libogg-${OGG_VERSION}.tar.gz"
    fi

    cd "libogg-${OGG_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}"; then
        print_error "libogg configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "libogg build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

build_libvorbis() {
    cd "${WORK_DIR}"
    if [ ! -d "libvorbis-${VORBIS_VERSION}" ]; then
        download_file "https://downloads.xiph.org/releases/vorbis/libvorbis-${VORBIS_VERSION}.tar.gz" "libvorbis-${VORBIS_VERSION}.tar.gz"
        tar xzf "libvorbis-${VORBIS_VERSION}.tar.gz"
    fi

    cd "libvorbis-${VORBIS_VERSION}"

    # Patch configure to remove obsolete linker flags for macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i.bak 's/-force_cpusubtype_ALL//g' configure
    fi

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}"; then
        print_error "libvorbis configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "libvorbis build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

# Build libaom (AV1)
build_libaom() {
    cd "${WORK_DIR}"
    if [ ! -d "libaom-${AOM_VERSION}" ]; then
        download_file "https://storage.googleapis.com/aom-releases/libaom-${AOM_VERSION}.tar.gz" "libaom-${AOM_VERSION}.tar.gz"
        tar xzf "libaom-${AOM_VERSION}.tar.gz"
    fi

    cd "libaom-${AOM_VERSION}"
    mkdir -p build_dir
    cd build_dir

    # Additional flags for cross-compilation
    local cmake_flags=""
    if [ "${ARCH}" = "arm64" ]; then
        # Building for ARM64 - enable NEON
        cmake_flags="-DENABLE_NEON=ON"
    else
        # Building for x86_64 - disable NEON and enable SSE/AVX
        cmake_flags="-DENABLE_NEON=OFF -DENABLE_SSE=ON -DENABLE_SSE2=ON -DENABLE_SSE3=ON -DENABLE_SSSE3=ON -DENABLE_SSE4_1=ON -DENABLE_SSE4_2=ON -DENABLE_AVX=ON -DENABLE_AVX2=ON"
    fi

    # Set C and CXX flags to ensure proper architecture targeting
    export CMAKE_C_FLAGS="${CFLAGS}"
    export CMAKE_CXX_FLAGS="${CXXFLAGS}"

    # shellcheck disable=SC2086
    if ! cmake .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DENABLE_EXAMPLES=OFF \
        -DENABLE_TESTS=OFF \
        -DENABLE_TOOLS=OFF \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        ${cmake_flags}; then
        print_error "libaom configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "libaom build failed for ${ARCH}"
        exit 1
    fi

    make install
    cd ..
    rm -rf build_dir
}

# Build zlib (required by freetype and others)
build_zlib() {
    cd "${WORK_DIR}"
    if [ ! -d "zlib-${ZLIB_VERSION}" ]; then
        download_file "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz" "zlib-${ZLIB_VERSION}.tar.gz"
        tar xzf "zlib-${ZLIB_VERSION}.tar.gz"
    fi

    cd "zlib-${ZLIB_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --static; then
        print_error "zlib configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "zlib build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

# Build brotli (compression library, optional for freetype)
build_brotli() {
    cd "${WORK_DIR}"
    if [ ! -d "brotli-${BROTLI_VERSION}" ]; then
        download_file "https://github.com/google/brotli/archive/v${BROTLI_VERSION}.tar.gz" "brotli-${BROTLI_VERSION}.tar.gz"
        tar xzf "brotli-${BROTLI_VERSION}.tar.gz"
    fi

    cd "brotli-${BROTLI_VERSION}"
    mkdir -p build_dir
    cd build_dir

    if ! cmake .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5; then
        print_error "brotli configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "brotli build failed for ${ARCH}"
        exit 1
    fi

    make install
    cd ..
    rm -rf build_dir
}

# Build fribidi (required by libass and harfbuzz)
build_fribidi() {
    cd "${WORK_DIR}"
    if [ ! -d "fribidi-${FRIBIDI_VERSION}" ]; then
        download_file "https://github.com/fribidi/fribidi/releases/download/v${FRIBIDI_VERSION}/fribidi-${FRIBIDI_VERSION}.tar.xz" "fribidi-${FRIBIDI_VERSION}.tar.xz"
        tar xf "fribidi-${FRIBIDI_VERSION}.tar.xz"
    fi

    cd "fribidi-${FRIBIDI_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}"; then
        print_error "fribidi configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "fribidi build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

# Build libunibreak (required by libass)
build_libunibreak() {
    cd "${WORK_DIR}"
    if [ ! -d "libunibreak-${LIBUNIBREAK_VERSION}" ]; then
        download_file "https://github.com/adah1972/libunibreak/releases/download/libunibreak_${LIBUNIBREAK_VERSION//./_}/libunibreak-${LIBUNIBREAK_VERSION}.tar.gz" "libunibreak-${LIBUNIBREAK_VERSION}.tar.gz"
        tar xzf "libunibreak-${LIBUNIBREAK_VERSION}.tar.gz"
    fi

    cd "libunibreak-${LIBUNIBREAK_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}"; then
        print_error "libunibreak configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "libunibreak build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

# Build freetype (required by fontconfig and libass) - first pass without harfbuzz
build_freetype() {
    cd "${WORK_DIR}"
    if [ ! -d "freetype-${FREETYPE_VERSION}" ]; then
        download_file "https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz" "freetype-${FREETYPE_VERSION}.tar.xz"
        tar xf "freetype-${FREETYPE_VERSION}.tar.xz"
    fi

    cd "freetype-${FREETYPE_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}" \
        --without-harfbuzz \
        --without-bzip2 \
        --without-png \
        --with-zlib=yes \
        --with-brotli=yes; then
        print_error "freetype configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "freetype build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

# Build harfbuzz (required by libass)
build_harfbuzz() {
    cd "${WORK_DIR}"
    if [ ! -d "harfbuzz-${HARFBUZZ_VERSION}" ]; then
        download_file "https://github.com/harfbuzz/harfbuzz/releases/download/${HARFBUZZ_VERSION}/harfbuzz-${HARFBUZZ_VERSION}.tar.xz" "harfbuzz-${HARFBUZZ_VERSION}.tar.xz"
        tar xf "harfbuzz-${HARFBUZZ_VERSION}.tar.xz"
    fi

    cd "harfbuzz-${HARFBUZZ_VERSION}"

    # Check if meson and ninja are available
    if ! command -v meson &> /dev/null || ! command -v ninja &> /dev/null; then
        print_error "meson and ninja are required for harfbuzz. Installing via brew..."
        brew install meson ninja
    fi

    # Set up cross-compilation file for meson
    local cross_file="${WORK_DIR}/meson-harfbuzz-${ARCH}.txt"

    local arch_flag=""
    local cpu_family=""
    if [ "${ARCH}" = "arm64" ]; then
        arch_flag="arm64"
        cpu_family="aarch64"
    else
        arch_flag="x86_64"
        cpu_family="x86_64"
    fi

    cat > "$cross_file" << EOF
[binaries]
c = 'clang'
cpp = 'clang++'
ar = 'ar'
strip = 'strip'
pkgconfig = 'pkg-config'

[built-in options]
c_args = ['-arch', '${arch_flag}', '-mmacosx-version-min=11.0']
cpp_args = ['-arch', '${arch_flag}', '-mmacosx-version-min=11.0']
c_link_args = ['-arch', '${arch_flag}', '-mmacosx-version-min=11.0']
cpp_link_args = ['-arch', '${arch_flag}', '-mmacosx-version-min=11.0']

[properties]
pkg_config_libdir = '${INSTALL_DIR}/lib/pkgconfig'

[host_machine]
system = 'darwin'
cpu_family = '${cpu_family}'
cpu = '${ARCH}'
endian = 'little'
EOF

    export PKG_CONFIG_LIBDIR="${INSTALL_DIR}/lib/pkgconfig"

    if ! meson setup build \
        --prefix="${INSTALL_DIR}" \
        --default-library=static \
        --cross-file="$cross_file" \
        -Dtests=disabled \
        -Ddocs=disabled \
        -Dbenchmark=disabled \
        -Dcairo=disabled \
        -Dicu=disabled \
        -Dglib=disabled \
        -Dgobject=disabled; then
        print_error "harfbuzz configure failed for ${ARCH}"
        exit 1
    fi

    if ! ninja -C build; then
        print_error "harfbuzz build failed for ${ARCH}"
        exit 1
    fi

    ninja -C build install
    rm -rf build
}

# Build fontconfig (required by libass)
build_fontconfig() {
    cd "${WORK_DIR}"
    if [ ! -d "fontconfig-${FONTCONFIG_VERSION}" ]; then
        download_file "https://www.freedesktop.org/software/fontconfig/release/fontconfig-${FONTCONFIG_VERSION}.tar.xz" "fontconfig-${FONTCONFIG_VERSION}.tar.xz"
        tar xf "fontconfig-${FONTCONFIG_VERSION}.tar.xz"
    fi

    cd "fontconfig-${FONTCONFIG_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}" \
        --enable-libxml2=no; then
        print_error "fontconfig configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "fontconfig build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

# Build libass (subtitle rendering)
build_libass() {
    cd "${WORK_DIR}"
    if [ ! -d "libass-${LIBASS_VERSION}" ]; then
        download_file "https://github.com/libass/libass/releases/download/${LIBASS_VERSION}/libass-${LIBASS_VERSION}.tar.xz" "libass-${LIBASS_VERSION}.tar.xz"
        tar xf "libass-${LIBASS_VERSION}.tar.xz"
    fi

    cd "libass-${LIBASS_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}"; then
        print_error "libass configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "libass build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

build_libwebp() {
    cd "${WORK_DIR}"
    if [ ! -d "libwebp-${WEBP_VERSION}" ]; then
        download_file "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz" "libwebp-${WEBP_VERSION}.tar.gz"
        tar xzf "libwebp-${WEBP_VERSION}.tar.gz"
    fi

    cd "libwebp-${WEBP_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}" \
        --disable-gl; then
        print_error "libwebp configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "libwebp build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

# Build dav1d (fast AV1 decoder)
build_dav1d() {
    cd "${WORK_DIR}"
    if [ ! -d "dav1d-${DAV1D_VERSION}" ]; then
        download_file "https://code.videolan.org/videolan/dav1d/-/archive/${DAV1D_VERSION}/dav1d-${DAV1D_VERSION}.tar.gz" "dav1d-${DAV1D_VERSION}.tar.gz"
        tar xzf "dav1d-${DAV1D_VERSION}.tar.gz"
    fi

    cd "dav1d-${DAV1D_VERSION}"

    # dav1d uses meson build system
    # Check if meson and ninja are available
    if ! command -v meson &> /dev/null || ! command -v ninja &> /dev/null; then
        print_error "meson and ninja are required for dav1d. Installing via brew..."
        brew install meson ninja
    fi

    # Set up cross-compilation file for meson
    local cross_file="${WORK_DIR}/meson-cross-${ARCH}.txt"

    # Prepare compiler flags as arrays for meson
    local arch_flag=""
    local cpu_family=""
    if [ "${ARCH}" = "arm64" ]; then
        arch_flag="arm64"
        cpu_family="aarch64"
    else
        arch_flag="x86_64"
        cpu_family="x86_64"
    fi

    cat > "$cross_file" << EOF
[binaries]
c = 'clang'
cpp = 'clang++'
ar = 'ar'
strip = 'strip'
pkgconfig = 'pkg-config'

[built-in options]
c_args = ['-arch', '${arch_flag}', '-mmacosx-version-min=11.0']
cpp_args = ['-arch', '${arch_flag}', '-mmacosx-version-min=11.0']
c_link_args = ['-arch', '${arch_flag}', '-mmacosx-version-min=11.0']
cpp_link_args = ['-arch', '${arch_flag}', '-mmacosx-version-min=11.0']

[properties]
pkg_config_libdir = '${INSTALL_DIR}/lib/pkgconfig'

[host_machine]
system = 'darwin'
cpu_family = '${cpu_family}'
cpu = '${ARCH}'
endian = 'little'
EOF

    export PKG_CONFIG_LIBDIR="${INSTALL_DIR}/lib/pkgconfig"

    if ! meson setup build \
        --prefix="${INSTALL_DIR}" \
        --default-library=static \
        --cross-file="$cross_file" \
        -Denable_tools=false \
        -Denable_tests=false; then
        print_error "dav1d configure failed for ${ARCH}"
        exit 1
    fi

    if ! ninja -C build; then
        print_error "dav1d build failed for ${ARCH}"
        exit 1
    fi

    ninja -C build install
    rm -rf build
}

build_libtheora() {
    cd "${WORK_DIR}"
    if [ ! -d "libtheora-${THEORA_VERSION}" ]; then
        download_file "https://downloads.xiph.org/releases/theora/libtheora-${THEORA_VERSION}.tar.gz" "libtheora-${THEORA_VERSION}.tar.gz"
        tar xzf "libtheora-${THEORA_VERSION}.tar.gz"
    fi

    cd "libtheora-${THEORA_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}" \
        --disable-examples; then
        print_error "libtheora configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "libtheora build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

# Build libsoxr (high-quality audio resampling)
build_soxr() {
    cd "${WORK_DIR}"
    if [ ! -d "soxr-${SOXR_VERSION}-Source" ]; then
        download_file "https://sourceforge.net/projects/soxr/files/soxr-${SOXR_VERSION}-Source.tar.xz" "soxr-${SOXR_VERSION}-Source.tar.xz"
        tar xf "soxr-${SOXR_VERSION}-Source.tar.xz"
    fi

    cd "soxr-${SOXR_VERSION}-Source"
    mkdir -p build_dir
    cd build_dir

    if ! cmake .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DWITH_OPENMP=OFF \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5; then
        print_error "soxr configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "soxr build failed for ${ARCH}"
        exit 1
    fi

    make install
    cd ..
    rm -rf build_dir
}

# Build libbluray (Blu-ray support)
build_libbluray() {
    cd "${WORK_DIR}"
    if [ ! -d "libbluray-${LIBBLURAY_VERSION}" ]; then
        download_file "https://download.videolan.org/pub/videolan/libbluray/${LIBBLURAY_VERSION}/libbluray-${LIBBLURAY_VERSION}.tar.bz2" "libbluray-${LIBBLURAY_VERSION}.tar.bz2"
        tar xjf "libbluray-${LIBBLURAY_VERSION}.tar.bz2"
    fi

    cd "libbluray-${LIBBLURAY_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}" \
        --disable-bdjava-jar \
        --disable-examples; then
        print_error "libbluray configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "libbluray build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

build_speex() {
    cd "${WORK_DIR}"
    if [ ! -d "speex-${SPEEX_VERSION}" ]; then
        download_file "https://downloads.xiph.org/releases/speex/speex-${SPEEX_VERSION}.tar.gz" "speex-${SPEEX_VERSION}.tar.gz"
        tar xzf "speex-${SPEEX_VERSION}.tar.gz"
    fi

    cd "speex-${SPEEX_VERSION}"

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}"; then
        print_error "speex configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "speex build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

build_snappy() {
    cd "${WORK_DIR}"
    if [ ! -d "snappy-${SNAPPY_VERSION}" ]; then
        download_file "https://github.com/google/snappy/archive/refs/tags/${SNAPPY_VERSION}.tar.gz" "snappy-${SNAPPY_VERSION}.tar.gz"
        tar xzf "snappy-${SNAPPY_VERSION}.tar.gz"
    fi

    cd "snappy-${SNAPPY_VERSION}"
    mkdir -p build_dir
    cd build_dir

    if ! cmake .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DSNAPPY_BUILD_TESTS=OFF \
        -DSNAPPY_BUILD_BENCHMARKS=OFF \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5; then
        print_error "snappy configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "snappy build failed for ${ARCH}"
        exit 1
    fi

    make install
    cd ..
    rm -rf build_dir
}

# Build openjpeg (JPEG 2000)
build_openjpeg() {
    cd "${WORK_DIR}"
    if [ ! -d "openjpeg-${OPENJPEG_VERSION}" ]; then
        download_file "https://github.com/uclouvain/openjpeg/archive/v${OPENJPEG_VERSION}.tar.gz" "openjpeg-${OPENJPEG_VERSION}.tar.gz"
        tar xzf "openjpeg-${OPENJPEG_VERSION}.tar.gz"
    fi

    cd "openjpeg-${OPENJPEG_VERSION}"
    mkdir -p build_dir
    cd build_dir

    if ! cmake .. \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTING=OFF \
        -DBUILD_CODEC=OFF \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5; then
        print_error "openjpeg configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "openjpeg build failed for ${ARCH}"
        exit 1
    fi

    make install
    cd ..
    rm -rf build_dir
}

# Build zimg (image scaling)
build_zimg() {
    cd "${WORK_DIR}"
    if [ ! -d "zimg-release-${ZIMG_VERSION}" ]; then
        download_file "https://github.com/sekrit-twc/zimg/archive/refs/tags/release-${ZIMG_VERSION}.tar.gz" "zimg-${ZIMG_VERSION}.tar.gz"
        tar xzf "zimg-${ZIMG_VERSION}.tar.gz"
    fi

    cd "zimg-release-${ZIMG_VERSION}"

    ./autogen.sh

    if ! ./configure \
        --prefix="${INSTALL_DIR}" \
        --disable-shared \
        --enable-static \
        --host="${HOST}"; then
        print_error "zimg configure failed for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "zimg build failed for ${ARCH}"
        exit 1
    fi

    make install
    make clean
}

# Build all codec libraries for a specific architecture
build_all_codecs() {
    local arch=$1
    local install_dir=$2

    print_status "Building all codec libraries for ${arch}..."

    # Build foundation libraries first
    build_library "zlib" "${arch}" build_zlib "${install_dir}"
    build_library "brotli" "${arch}" build_brotli "${install_dir}"
    build_library "libogg" "${arch}" build_libogg "${install_dir}"
    build_library "fribidi" "${arch}" build_fribidi "${install_dir}"
    build_library "libunibreak" "${arch}" build_libunibreak "${install_dir}"
    build_library "freetype" "${arch}" build_freetype "${install_dir}"

    # harfbuzz needs freetype and fribidi
    build_library "harfbuzz" "${arch}" build_harfbuzz "${install_dir}"

    # Libraries that depend on libogg and freetype
    build_library "libvorbis" "${arch}" build_libvorbis "${install_dir}"
    build_library "libtheora" "${arch}" build_libtheora "${install_dir}"
    build_library "fontconfig" "${arch}" build_fontconfig "${install_dir}"

    # Audio codecs
    build_library "opus" "${arch}" build_opus "${install_dir}"
    build_library "lame" "${arch}" build_lame "${install_dir}"
    build_library "fdk-aac" "${arch}" build_fdk_aac "${install_dir}"
    build_library "speex" "${arch}" build_speex "${install_dir}"
    build_library "soxr" "${arch}" build_soxr "${install_dir}"

    # Video codecs
    build_library "x264" "${arch}" build_x264 "${install_dir}"
    build_library "x265" "${arch}" build_x265 "${install_dir}"
    build_library "libvpx" "${arch}" build_libvpx "${install_dir}"
    build_library "libaom" "${arch}" build_libaom "${install_dir}"
    build_library "dav1d" "${arch}" build_dav1d "${install_dir}"

    # Image and subtitle libraries (libass depends on freetype, fontconfig, fribidi, harfbuzz, and libunibreak)
    build_library "libass" "${arch}" build_libass "${install_dir}"
    build_library "libwebp" "${arch}" build_libwebp "${install_dir}"
    build_library "openjpeg" "${arch}" build_openjpeg "${install_dir}"
    build_library "zimg" "${arch}" build_zimg "${install_dir}"

    # Container/format support
    # Note: libbluray disabled due to symbol conflict with FFmpeg (dec_init)
    # build_library "libbluray" "${arch}" build_libbluray "${install_dir}"
    build_library "snappy" "${arch}" build_snappy "${install_dir}"
}

download_ffmpeg() {
    print_status "Downloading FFmpeg ${FFMPEG_VERSION}..."
    cd "${WORK_DIR}"

    if [ ! -d "ffmpeg-${FFMPEG_VERSION}" ]; then
        download_file "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" "ffmpeg-${FFMPEG_VERSION}.tar.xz"
        tar xf "ffmpeg-${FFMPEG_VERSION}.tar.xz"
    fi
}

# Build FFmpeg for a specific architecture
build_ffmpeg() {
    local arch=$1
    local install_dir=$2

    print_status "Building FFmpeg for ${arch}..."

    cd "${WORK_DIR}/ffmpeg-${FFMPEG_VERSION}"

    export MACOSX_DEPLOYMENT_TARGET="11.0"
    export PKG_CONFIG_PATH="${install_dir}/lib/pkgconfig"

    local arch_flags=""
    if [ "${arch}" = "arm64" ]; then
        arch_flags="--arch=arm64 --enable-cross-compile --target-os=darwin"
        export CFLAGS="-arch arm64 -mmacosx-version-min=11.0"
        export CXXFLAGS="-arch arm64 -mmacosx-version-min=11.0"
        export LDFLAGS="-arch arm64 -mmacosx-version-min=11.0"
    else
        arch_flags="--arch=x86_64"
        export CFLAGS="-arch x86_64 -mmacosx-version-min=11.0"
        export CXXFLAGS="-arch x86_64 -mmacosx-version-min=11.0"
        export LDFLAGS="-arch x86_64 -mmacosx-version-min=11.0"
    fi

    # shellcheck disable=SC2086
    if ! ./configure \
        --prefix="${install_dir}" \
        ${arch_flags} \
        --enable-gpl \
        --enable-nonfree \
        --enable-version3 \
        --enable-static \
        --disable-shared \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libvpx \
        --enable-libopus \
        --enable-libmp3lame \
        --enable-libfdk-aac \
        --enable-libvorbis \
        --enable-libaom \
        --enable-libdav1d \
        --enable-libtheora \
        --enable-libspeex \
        --enable-libsoxr \
        --enable-libass \
        --enable-libfreetype \
        --enable-fontconfig \
        --enable-libwebp \
        --enable-libsnappy \
        --enable-libopenjpeg \
        --enable-libzimg \
        --enable-videotoolbox \
        --enable-audiotoolbox \
        --pkg-config-flags="--static" \
        --extra-cflags="-I${install_dir}/include" \
        --extra-ldflags="-L${install_dir}/lib" \
        --extra-libs="-lpthread -lm -lz -liconv -framework CoreFoundation -framework CoreMedia -framework CoreVideo -framework VideoToolbox -framework AudioToolbox"; then
        print_error "FFmpeg configure failed for ${arch}for ${ARCH}"
        exit 1
    fi

    if ! make -j"$(sysctl -n hw.ncpu)"; then
        print_error "FFmpeg build failed for ${arch}for ${ARCH}"
        exit 1
    fi

    make install
    make distclean

}

create_universal_binaries() {
    print_status "Creating universal binaries..."

    lipo -create \
        "${INSTALL_DIR_ARM64}/bin/ffmpeg" \
        "${INSTALL_DIR_X86_64}/bin/ffmpeg" \
        -output "${OUTPUT_DIR}/ffmpeg"

    lipo -create \
        "${INSTALL_DIR_ARM64}/bin/ffprobe" \
        "${INSTALL_DIR_X86_64}/bin/ffprobe" \
        -output "${OUTPUT_DIR}/ffprobe"

    chmod +x "${OUTPUT_DIR}/ffmpeg"
    chmod +x "${OUTPUT_DIR}/ffprobe"

    print_status "Verifying universal binaries..."
    echo ""
    echo "ffmpeg architectures:"
    lipo -info "${OUTPUT_DIR}/ffmpeg"
    echo ""
    echo "ffprobe architectures:"
    lipo -info "${OUTPUT_DIR}/ffprobe"
    echo ""
}

# Main build process
main() {
    # Use environment variables if set, otherwise use defaults
    FFMPEG_VERSION="${FFMPEG_VERSION:-$DEFAULT_FFMPEG_VERSION}"
    X265_VERSION="${X265_VERSION:-$DEFAULT_X265_VERSION}"
    LIBVPX_VERSION="${LIBVPX_VERSION:-$DEFAULT_LIBVPX_VERSION}"
    OPUS_VERSION="${OPUS_VERSION:-$DEFAULT_OPUS_VERSION}"
    LAME_VERSION="${LAME_VERSION:-$DEFAULT_LAME_VERSION}"
    FDK_AAC_VERSION="${FDK_AAC_VERSION:-$DEFAULT_FDK_AAC_VERSION}"
    OGG_VERSION="${OGG_VERSION:-$DEFAULT_OGG_VERSION}"
    VORBIS_VERSION="${VORBIS_VERSION:-$DEFAULT_VORBIS_VERSION}"
    AOM_VERSION="${AOM_VERSION:-$DEFAULT_AOM_VERSION}"
    FREETYPE_VERSION="${FREETYPE_VERSION:-$DEFAULT_FREETYPE_VERSION}"
    FONTCONFIG_VERSION="${FONTCONFIG_VERSION:-$DEFAULT_FONTCONFIG_VERSION}"
    LIBASS_VERSION="${LIBASS_VERSION:-$DEFAULT_LIBASS_VERSION}"
    FRIBIDI_VERSION="${FRIBIDI_VERSION:-$DEFAULT_FRIBIDI_VERSION}"
    HARFBUZZ_VERSION="${HARFBUZZ_VERSION:-$DEFAULT_HARFBUZZ_VERSION}"
    LIBUNIBREAK_VERSION="${LIBUNIBREAK_VERSION:-$DEFAULT_LIBUNIBREAK_VERSION}"
    GLIB_VERSION="${GLIB_VERSION:-$DEFAULT_GLIB_VERSION}"
    WEBP_VERSION="${WEBP_VERSION:-$DEFAULT_WEBP_VERSION}"
    DAV1D_VERSION="${DAV1D_VERSION:-$DEFAULT_DAV1D_VERSION}"
    THEORA_VERSION="${THEORA_VERSION:-$DEFAULT_THEORA_VERSION}"
    SOXR_VERSION="${SOXR_VERSION:-$DEFAULT_SOXR_VERSION}"
    LIBBLURAY_VERSION="${LIBBLURAY_VERSION:-$DEFAULT_LIBBLURAY_VERSION}"
    SPEEX_VERSION="${SPEEX_VERSION:-$DEFAULT_SPEEX_VERSION}"
    SNAPPY_VERSION="${SNAPPY_VERSION:-$DEFAULT_SNAPPY_VERSION}"
    OPENJPEG_VERSION="${OPENJPEG_VERSION:-$DEFAULT_OPENJPEG_VERSION}"
    ZIMG_VERSION="${ZIMG_VERSION:-$DEFAULT_ZIMG_VERSION}"
    ZLIB_VERSION="${ZLIB_VERSION:-$DEFAULT_ZLIB_VERSION}"
    BROTLI_VERSION="${BROTLI_VERSION:-$DEFAULT_BROTLI_VERSION}"

    echo ""
    echo "Building with the following versions:"
    echo "  FFmpeg:      ${FFMPEG_VERSION}"
    echo "  x264:        latest from git"
    echo "  x265:        ${X265_VERSION}"
    echo "  libvpx:      ${LIBVPX_VERSION}"
    echo "  opus:        ${OPUS_VERSION}"
    echo "  lame:        ${LAME_VERSION}"
    echo "  fdk-aac:     ${FDK_AAC_VERSION}"
    echo "  libogg:      ${OGG_VERSION}"
    echo "  libvorbis:   ${VORBIS_VERSION}"
    echo "  libaom:      ${AOM_VERSION}"
    echo "  freetype:    ${FREETYPE_VERSION}"
    echo "  fontconfig:  ${FONTCONFIG_VERSION}"
    echo "  libass:      ${LIBASS_VERSION}"
    echo "  fribidi:     ${FRIBIDI_VERSION}"
    echo "  harfbuzz:    ${HARFBUZZ_VERSION}"
    echo "  libunibreak: ${LIBUNIBREAK_VERSION}"
    echo "  libwebp:     ${WEBP_VERSION}"
    echo "  dav1d:       ${DAV1D_VERSION}"
    echo "  libtheora:   ${THEORA_VERSION}"
    echo "  soxr:        ${SOXR_VERSION}"
    echo "  libbluray:   ${LIBBLURAY_VERSION}"
    echo "  speex:       ${SPEEX_VERSION}"
    echo "  snappy:      ${SNAPPY_VERSION}"
    echo "  openjpeg:    ${OPENJPEG_VERSION}"
    echo "  zimg:        ${ZIMG_VERSION}"
    echo "  zlib:        ${ZLIB_VERSION}"
    echo "  brotli:      ${BROTLI_VERSION}"
    echo ""

    check_dependencies
    clean_build

    # Build codec libraries for both architectures
    build_all_codecs "arm64" "${INSTALL_DIR_ARM64}"
    build_all_codecs "x86_64" "${INSTALL_DIR_X86_64}"

    download_ffmpeg

    # Build FFmpeg for both architectures
    build_ffmpeg "arm64" "${INSTALL_DIR_ARM64}"
    build_ffmpeg "x86_64" "${INSTALL_DIR_X86_64}"

    create_universal_binaries

    print_status "Build complete!"
    print_status "Universal binaries are located in: ${OUTPUT_DIR}"
    print_status "Build logs are located in: ${LOG_DIR}"
    echo ""

    # Display binary info
    "${OUTPUT_DIR}/ffmpeg" -version

    echo ""
    print_status "Build finished successfully!"
}

# Run main
main
