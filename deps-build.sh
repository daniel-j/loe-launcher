#!/usr/bin/env bash

set -e

root=$(pwd)

CROSSWIN="false"
UNAME=`uname -s`
MACOS=$([ "$UNAME" == "Darwin" ] && echo true || echo false)
LINUX=$([ "$UNAME" == "Linux" ] && echo true || echo false)


SRC="$root/deps"
export SHELL=/bin/bash
export PREFIX="$root/prefix"
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

echo "Building dependencies"

# multicore compilation
$MACOS && makearg="-j$(sysctl -n hw.ncpu)" || makearg="-j$(nproc)"

rm -rf "$PREFIX"
mkdir -pv "$PREFIX"

# echo "Building libpng"
# cd "$SRC/libpng"
# ./configure --prefix="$PREFIX" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" --disable-static
# make $makearg
# make install
# make distclean

# echo "Building FreeType"
# cd "$SRC/freetype"
# ./configure --prefix="$PREFIX" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" --disable-static --with-harfbuzz=no --with-png=yes --with-bzip2=no
# make $makearg
# make install
# make distclean

echo "Building SDL2"
cd "$SRC/SDL2"
bash ./autogen.sh
mkdir -p build
cd build
../configure --prefix="$PREFIX" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
	--enable-sdl-dlopen \
	--disable-arts --disable-esd --disable-nas \
	--enable-alsa --enable-pulseaudio-shared \
	--enable-video-wayland --enable-wayland-shared \
	--enable-x11-shared --enable-ibus --enable-fcitx --enable-ime \
	--disable-rpath --disable-input-tslib
make $makearg
make install
make distclean

echo "Building SDL2_image"
cd "$SRC/SDL2_image"
bash ./autogen.sh
./configure --prefix="$PREFIX" --with-sdl-prefix="$PREFIX" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" --disable-static
make $makearg
make install
make distclean

echo "Building aria2"
cd "$SRC/aria2"
./configure --prefix="$PREFIX" --disable-metalink --disable-websocket --enable-libaria2 \
	--disable-rpath --without-sqlite3 --without-libxml2 --without-libexpat \
	--without-libssh2 --enable-bittorrent PKG_CONFIG_PATH="$PKG_CONFIG_PATH" --disable-static
make $makearg
make install

# echo "Building nativefiledialog"
# cd "$SRC/nfd"
# $CROSSWIN && cd build/gmake_windows || $LINUX && cd build/gmake_linux
# $MACOS && cd build/gmake_macosx
# make config=release_x64 $makearg
# mkdir -p "$PREFIX/lib/" "$PREFIX/include/"
# cp ../lib/Release/x64/libnfd.a "$PREFIX/lib/"
# cp -r ../../src/include/. "$PREFIX/include/"
# make clean

touch "$PREFIX/built_libs"
