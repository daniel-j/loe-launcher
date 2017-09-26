#!/usr/bin/env bash

set -e

. ./env.sh

root=$(pwd)

SRC="$root/deps"
LIBDIR=/usr/lib64
export SHELL=/bin/bash
export PREFIX="$root/prefix-${ARCH}"
export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
OPENSSLTARGET=linux-x86_64-clang
#export LDFLAGS="-static-libgcc -static-libstdc++"
export CC="clang"
export CXX="clang++"
export CFLAGS=""
export CXXFLAGS="-g -O2 -stdlib=libc++"
export LDFLAGS=""
export HOST="x86_64-pc-linux-gnu"

$LINUX && [ "$CROSSWIN" == "false" ] && export CC="$CC -U_FORTIFY_SOURCE -include $PREFIX/libcwrap.h"
$LINUX && [ "$CROSSWIN" == "false" ] && export CXX="$CXX -U_FORTIFY_SOURCE -D_GLIBCXX_USE_CXX11_ABI=0 -include $PREFIX/libcwrap.h"

$CROSSWIN && MINGW="x86_64-w64-mingw32"
$CROSSWIN && export CXXFLAGS=""

if [ "$ARCH" != "x86_64" ]; then
	export HOST="i686-pc-linux-gnu"
	export CFLAGS="-m32 $CFLAGS"
	export LDFLAGS="-m32 $LDFLAGS"
	export CXXFLAGS="-m32 $CXXFLAGS"
	LIBDIR=/usr/lib32
	OPENSSLTARGET=linux-x86-clang
	$CROSSWIN && MINGW="i686-w64-mingw32"
	$CROSSWIN && export CXXFLAGS="-m32"
	export CPPFLAGS="-m32"
fi

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
$CROSSWIN && export HOST="$MINGW"
$CROSSWIN && export PREFIX="${PREFIX}-win"
$CROSSWIN && export CC="$MINGW-gcc"
$CROSSWIN && export CXX="$MINGW-g++"

# multicore compilation
$MACOS && makearg="-j$(sysctl -n hw.ncpu)" || makearg="-j$(nproc)"

clean_prefix() {
	rm -rf "$PREFIX"
	mkdir -pv "$PREFIX"
}

build_libcwrap() {
	$LINUX && [ "$CROSSWIN" == "false" ] || return 0
	echo "Building LibcWrapGenerator"
	cd "$SRC"
	CC="clang" valac --pkg gee-0.8 --pkg posix --pkg glib-2.0 --pkg gio-2.0 ./LibcWrapGenerator.vala
	mkdir -p "$PREFIX/bin/"
	mv -v ./LibcWrapGenerator "$PREFIX/bin/"
}

run_libcwrap() {
	$LINUX && [ "$CROSSWIN" == "false" ] || return 0
	LibcWrapGenerator --target 2.10 --libdir $LIBDIR --output "$PREFIX/libcwrap.h"
}

build_zlib() {
	[ "$CROSSWIN" == "false" ] || return 0
	echo "Building zlib"
	cd "$SRC/zlib"
	./configure --prefix="$PREFIX"
	make $makearg
	make install
	make distclean
}

build_openssl() {
	$LINUX && [ "$CROSSWIN" == "false" ] || return 0
	echo "Building OpenSSL"
	cd "$SRC/openssl"
	./Configure --prefix="$PREFIX" $OPENSSLTARGET shared
	make $makearg
	make install
	make distclean
}

build_libpng() {
	[ "$CROSSWIN" == "false" ] || return 0
	echo "Building libpng"
	cd "$SRC/libpng"
	./configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" LDFLAGS="$LDFLAGS" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS"
	make $makearg
	make install
	make distclean
}

# echo "Building FreeType"
# cd "$SRC/freetype"
# ./configure --prefix="$PREFIX" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" --with-harfbuzz=no --with-png=yes --with-bzip2=no
# make $makearg
# make install
# make distclean

build_SDL2() {
	echo "Building SDL2"
	cd "$SRC/SDL2"
	bash ./autogen.sh || true
	mkdir -p build
	cd build
	../configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" LDFLAGS="$LDFLAGS" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" \
		--enable-sdl-dlopen \
		--disable-audio \
		--enable-video-wayland --enable-wayland-shared \
		--enable-x11-shared --enable-ibus --enable-fcitx --enable-ime \
		--disable-rpath --disable-video-vulkan --disable-input-tslib \
		#--disable-input-tslib --disable-atomic \
		#--disable-haptic --disable-joystick --disable-power \
		#--disable-file --disable-loadso --disable-cpuinfo
	make $makearg
	make install
	make distclean
}

build_SDL2_image() {
	echo "Building SDL2_image"
	cd "$SRC/SDL2_image"
	bash ./autogen.sh || true
	./configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" LDFLAGS="$LDFLAGS" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" \
		--with-sdl-prefix="$PREFIX" --disable-webp --disable-gif --disable-lbm \
		--disable-pcx --disable-pnm --disable-tga --disable-xpm --disable-xv --disable-xcf \
		--enable-png --disable-png-shared --disable-tif --disable-jpg --disable-jpg-shared
	make $makearg
	make install
	make distclean
}

# echo "Building c-ares"
# cd "$SRC/c-ares"
# ./configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
# make $makearg
# make install
# make clean


# echo "Building nativefiledialog"
# cd "$SRC/nfd"
# $CROSSWIN && cd build/gmake_windows || $LINUX && cd build/gmake_linux
# $MACOS && cd build/gmake_macosx
# make config=release_x64 $makearg
# mkdir -p "$PREFIX/lib/" "$PREFIX/include/"
# cp ../lib/Release/x64/libnfd.a "$PREFIX/lib/"
# cp -r ../../src/include/. "$PREFIX/include/"
# make clean


build_dylibbundler() {
	$MACOS || return 0
	echo "Building dylibbundler"
	cd "$SRC/dylibbundler"
	make install PREFIX="$PREFIX"
	make clean
}

build_aria2() {
	echo "Building aria2"
	cd "$SRC/aria2"
	./configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" LDFLAGS="$LDFLAGS" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS"  \
		--disable-metalink --disable-websocket --enable-libaria2 \
		--disable-rpath --without-sqlite3 --without-libxml2 --without-libexpat \
		--without-libssh2 --enable-bittorrent --without-libcares --without-gnutls \
		--with-ca-bundle='/etc/ssl/certs/ca-certificates.crt'
	make $makearg
	make install
	make distclean || true
	make clean || true
}

# START OF BUILD PROCESS

if [ "$1" == "all" ]; then
	echo "Building all dependencies"
	clean_prefix

	build_dylibbundler
	build_libcwrap
	run_libcwrap

	build_zlib

	build_openssl

	build_libpng

	build_SDL2
	build_SDL2_image

	build_aria2

elif [ ! -z "$1" ]; then
	echo "Building dependencies $1"
	$1
fi

touch "$PREFIX/built_libs"
