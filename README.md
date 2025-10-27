# FFmpeg Universal Binary Build Script for macOS

This project provides a build script for compiling universal (Intel + Apple Silicon) binaries of [FFmpeg](https://ffmpeg.org/ffmpeg.html) and [FFprobe](https://ffmpeg.org/ffprobe.html) with rich codec support and static linking.

<a href="https://www.buymeacoffee.com/waynekoorts" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-yellow.png" alt="Buy Me A Coffee" height="26" width="113"></a>

## Table of Contents

- [Purpose](#purpose)
- [Prerequisites](#prerequisites)
  - [Xcode Command Line Tools](#xcode-command-line-tools)
  - [Homebrew](#homebrew)
  - [Build Dependencies](#build-dependencies)
  - [Dependency Details](#dependency-details)
- [Usage](#usage)
  - [Basic Build](#basic-build)
  - [Force Re-download](#force-re-download)
  - [Clean Build](#clean-build)
  - [Output](#output)
- [Build Process Overview](#build-process-overview)
  - [1. Codec Library Compilation](#1-codec-library-compilation)
  - [2. FFmpeg Compilation](#2-ffmpeg-compilation)
  - [3. Universal Binary Creation](#3-universal-binary-creation)
- [Build Time](#build-time)
- [Troubleshooting](#troubleshooting)
  - [Build Failures](#build-failures)
  - [Disk Space](#disk-space)
  - [Network Issues](#network-issues)
- [Version Management](#version-management)
  - [Default Versions](#default-versions)
  - [Overriding Versions](#overriding-versions)
- [Verifying Universal Binaries](#verifying-universal-binaries)
- [License Considerations](#license-considerations)
- [Additional Notes](#additional-notes)

## Purpose

The `build-ffmpeg.sh` script automates the process of:

- Downloading the latest stable FFmpeg source code
- Compiling essential codec libraries from source
- Building FFmpeg for both arm64 and x86_64 architectures
- Creating universal binaries using `lipo`

The resulting binaries are self-contained with no external dependencies, making them suitable for distribution with applications.

## Prerequisites

### Xcode Command Line Tools

First, ensure you have Xcode Command Line Tools installed. This provides essential build tools including `git`, `make`, `lipo`, and compilers:

```bash
xcode-select --install
```

To verify installation:

```bash
xcode-select -p
```

This should output a path like `/Library/Developer/CommandLineTools` or `/Applications/Xcode.app/Contents/Developer`.

### Homebrew

The script requires Homebrew for installing build dependencies. If not already installed, get it from [https://brew.sh](https://brew.sh).

### Build Dependencies

Install the following build dependencies via Homebrew:

```bash
brew install nasm pkg-config cmake autoconf automake libtool yasm meson ninja
```

### Dependency Details

**Required system tools** (installed via Xcode Command Line Tools):

- **git**: Version control system (required to clone x264 repository)
- **curl**: Command-line HTTP client (required to download source archives)
- **make**: Build automation tool
- **lipo**: Creates universal (fat) binaries from architecture-specific binaries
- **C/C++ compilers**: Apple Clang compiler toolchain

**Required Homebrew packages:**

- **nasm**: Assembler for x86/x86_64 assembly code (required for many codecs)
- **pkg-config**: Helper tool for compiling applications and libraries
- **cmake**: Build system generator (required for some codec libraries)
- **autoconf**: Generates configuration scripts
- **automake**: Tool for generating Makefile.in files
- **libtool**: Generic library support script
- **yasm**: Modular assembler (alternative to nasm for some components)
- **meson**: Build system (required for dav1d)
- **ninja**: Small build system used by meson

The build script will automatically check for the Homebrew packages and offer to install missing ones.

## Usage

### Basic Build

Simply run the script from this directory:

```bash
./build-ffmpeg.sh
```

The script caches downloaded source archives in `.source-cache/` to avoid re-downloading on subsequent builds.

### Force Re-download

If you want to force re-download all source archives (e.g., to get updated versions):

```bash
./build-ffmpeg.sh --force-download
```

### Clean Build

If you encounter issues or want to start completely fresh:

```bash
rm -rf build/ output/ .source-cache/
./build-ffmpeg.sh
```

The script will:

1. Check for required dependencies
2. Download FFmpeg 8.0 and all codec library sources (cached in `.source-cache/`)
3. Build each codec library for both architectures
4. Build FFmpeg for both architectures
5. Create universal binaries
6. Output the final binaries to the `output/` directory

### Output

The universal binaries will be placed in:

- `output/ffmpeg` - Main FFmpeg binary
- `output/ffprobe` - FFprobe utility binary

Build artifacts and intermediate files are stored in the `build/` directory. Source archives are cached in `.source-cache/` to speed up subsequent builds.

## Build Process Overview

The script performs the following steps:

### 1. Codec Library Compilation

Each codec library is built twice (once for arm64, once for x86_64) with static linking:

**Audio Codecs:**

- **libogg** - Container format for Vorbis and Theora
- **libvorbis** - Vorbis audio codec
- **opus** - Opus audio codec (modern, efficient)
- **lame** - MP3 audio encoder
- **fdk-aac** - High-quality AAC audio encoder
- **speex** - Speex audio codec (VoIP/telephony)
- **soxr** - High-quality audio resampling library

**Video Codecs:**

- **x264** - H.264/AVC video encoder (widely compatible)
- **x265** - H.265/HEVC video encoder (high efficiency)
- **libvpx** - VP8/VP9 video codecs (WebM)
- **libaom** - AV1 video encoder (next-gen compression)
- **dav1d** - Fast AV1 video decoder
- **libtheora** - Theora video codec (open format)

**Subtitle & Font Rendering:**

- **freetype** - Font rendering engine
- **fontconfig** - Font configuration library
- **libass** - Advanced subtitle renderer (ASS/SSA)

**Image & Format Support:**

- **libwebp** - WebP image format
- **openjpeg** - JPEG 2000 codec
- **zimg** - High-quality image scaling
- **snappy** - Fast compression library

### 2. FFmpeg Compilation

FFmpeg is built with comprehensive codec and format support:

**Video Encoding & Decoding:**

- H.264/AVC (x264) - Industry standard, widely compatible
- H.265/HEVC (x265) - High efficiency video coding
- VP8/VP9 (libvpx) - WebM video codecs
- AV1 encoding (libaom) - Next-generation codec with superior compression
- AV1 decoding (dav1d) - Fast, optimized AV1 decoder
- Theora (libtheora) - Open video format
- VideoToolbox - macOS hardware acceleration for H.264/HEVC

**Audio Encoding & Decoding:**

- AAC (fdk-aac) - High-quality AAC encoder
- MP3 (lame) - Universal MP3 encoder
- Opus - Modern, low-latency audio codec
- Vorbis - Open audio format
- Speex - Optimized for speech/VoIP
- High-quality audio resampling (soxr)
- AudioToolbox - macOS native audio acceleration

**Subtitle Support:**

- Advanced SubStation Alpha (ASS/SSA) rendering (libass)
- TrueType/OpenType font rendering (freetype)
- System font integration (fontconfig)

**Image & Container Formats:**

- WebP images (libwebp)
- JPEG 2000 (openjpeg)
- High-quality image scaling (zimg)
- Snappy compression (libsnappy)

**Build Configuration:**

- GPL, non-free, and version3 licenses enabled for maximum codec support
- Static linking for all dependencies (no external library requirements)
- Minimum macOS version: 11.0 (Big Sur)
- Universal binary (runs natively on Intel and Apple Silicon)

### 3. Universal Binary Creation

The `lipo` tool combines the arm64 and x86_64 binaries into universal binaries that work on both Intel and Apple Silicon Macs.

## Troubleshooting

### Build Failures

If the build fails:

1. Check that all dependencies are installed: `brew list`
2. Ensure you have Xcode Command Line Tools: `xcode-select --install`
3. Review the error messages for missing dependencies or configuration issues
4. Try cleaning the build directory: `rm -rf build/ output/`

### Network Issues

If downloads fail, you may need to retry the script. The script caches downloaded source archives in the `.source-cache/` directory, so re-running will skip already downloaded sources.

## Version Management

### Default Versions

The script uses hardcoded default versions for all libraries that are known to work well together. The current defaults are:

**Core:**

- FFmpeg: 8.0
- x264: latest from git

**Video Codecs:**

- x265: 3.6
- libvpx: 1.15.2
- libaom: 3.13.1
- dav1d: 1.5.0
- libtheora: 1.2.0

**Audio Codecs:**

- opus: 1.5.2
- lame: 3.100
- fdk-aac: 2.0.3
- libogg: 1.3.6
- libvorbis: 1.3.7
- speex: 1.2.1
- soxr: 0.1.3

**Subtitle & Fonts:**

- freetype: 2.14.1
- fontconfig: 2.16.0
- libass: 0.17.4

**Image & Format:**

- libwebp: 1.6.0
- openjpeg: 2.5.4
- zimg: 3.0.5
- snappy: 1.2.1

### Overriding Versions

You can override any version by setting environment variables before running the script:

```bash
# Pin FFmpeg to a specific version
export FFMPEG_VERSION="7.1"
./build-ffmpeg.sh

# Pin multiple libraries
export FFMPEG_VERSION="8.0"
export X265_VERSION="3.5"
export LIBVPX_VERSION="1.13.0"
./build-ffmpeg.sh
```

Available version variables:

**Core:**

- `FFMPEG_VERSION` - FFmpeg version (note: x264 always builds from latest git)

**Video Codecs:**

- `X265_VERSION` - x265 HEVC encoder
- `LIBVPX_VERSION` - VP8/VP9 encoder
- `AOM_VERSION` - AV1 encoder
- `DAV1D_VERSION` - AV1 decoder
- `THEORA_VERSION` - Theora codec

**Audio Codecs:**

- `OPUS_VERSION` - Opus audio codec
- `LAME_VERSION` - MP3 encoder
- `FDK_AAC_VERSION` - AAC encoder
- `OGG_VERSION` - Ogg container
- `VORBIS_VERSION` - Vorbis audio codec
- `SPEEX_VERSION` - Speex codec
- `SOXR_VERSION` - Audio resampler

**Subtitle & Fonts:**

- `FREETYPE_VERSION` - Font rendering
- `FONTCONFIG_VERSION` - Font configuration
- `LIBASS_VERSION` - Subtitle rendering

**Image & Format:**

- `WEBP_VERSION` - WebP images
- `OPENJPEG_VERSION` - JPEG 2000
- `ZIMG_VERSION` - Image scaling
- `SNAPPY_VERSION` - Compression

## Verifying Universal Binaries

After the build completes, you can verify the binaries contain both architectures:

```bash
lipo -info output/ffmpeg
lipo -info output/ffprobe
```

Expected output:

```text
Architectures in the fat file: output/ffmpeg are: x86_64 arm64
Architectures in the fat file: output/ffprobe are: x86_64 arm64
```

## License Considerations

The binaries produced by this script include GPL, non-free, and version3 licensed components:

- **GPL**: x264, x265
- **Non-free**: fdk-aac (more restrictive licensing)

Ensure your application's licensing is compatible with these requirements before distributing the binaries.

## Additional Notes

- The build script uses `set -e` to exit immediately if any command fails
- All codec libraries are compiled with Position Independent Code (PIC) for compatibility
- Downloaded source archives are cached in `.source-cache/` between runs to save time
- The `build/` directory contains extracted sources and compilation artifacts
- After successful build, you can safely delete `build/` to save disk space (keep `.source-cache/` to avoid re-downloading)
