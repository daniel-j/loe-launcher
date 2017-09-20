#!/usr/bin/env bash

set -e

. ./env.sh

root=$(pwd)

SRC="$root/deps"
export SHELL=/bin/bash
export PREFIX="$root/prefix"
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
$CROSSWIN && MINGW="x86_64-w64-mingw32"
$CROSSWIN && export HOST="$MINGW"
$CROSSWIN && export PREFIX="${PREFIX}-win"

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

$LINUX && (
	echo "Building LibcWrapGenerator"
	cd "$SRC"
	valac --pkg gee-0.8 --pkg posix --pkg glib-2.0 --pkg gio-2.0 ./LibcWrapGenerator.vala
	mkdir -p "$PREFIX/bin/"
	mv -v ./LibcWrapGenerator "$PREFIX/bin/"
	LibcWrapGenerator --target 2.7 --libdir /lib --output "$PREFIX/libcwrap.h"
	export CC="gcc -U_FORTIFY_SOURCE -include \"$PREFIX/libcwrap.h\""
  export CXX="g++ -U_FORTIFY_SOURCE -include \"$PREFIX/libcwrap.h\""
)

echo "Building SDL2"
cd "$SRC/SDL2"
bash ./autogen.sh || true
mkdir -p build
cd build
../configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" \
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
bash ./autogen.sh || true
./configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" --with-sdl-prefix="$PREFIX" --disable-static
make $makearg
make install
make distclean

echo "Building c-ares"
cd "$SRC/c-ares"
./configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" --disable-static
make $makearg
make install
make distclean

echo "Building aria2"
cd "$SRC/aria2"
./configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" \
	--disable-metalink --disable-websocket --enable-libaria2 \
	--disable-rpath --without-sqlite3 --without-libxml2 --without-libexpat \
	--without-libssh2 --enable-bittorrent --disable-static
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

$MACOS && (
	echo "Building dylibbundler"
	cd "$SRC/dylibbundler"
	make install PREFIX="$PREFIX"
	make clean
)

touch "$PREFIX/built_libs"
