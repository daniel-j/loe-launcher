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
#export LFLAGS="-static-libgcc -static-libstdc++"
export CC="clang"
export CXX="clang++"
export CFLAGS=""
export CXXFLAGS="-g -O2 -stdlib=libc++"
export LFLAGS=""
$CROSSWIN && MINGW="x86_64-w64-mingw32"
$CROSSWIN && export HOST="$MINGW"
$CROSSWIN && export PREFIX="${PREFIX}-win"
$CROSSWIN && export CC="$MINGW-gcc"
$CROSSWIN && export CXX="$MINGW-g++"
$CROSSWIN && export CXXFLAGS=""

echo "Building dependencies"

# multicore compilation
$MACOS && makearg="-j$(sysctl -n hw.ncpu)" || makearg="-j$(nproc)"

rm -rf "$PREFIX"
mkdir -pv "$PREFIX"

$LINUX && [ "$CROSSWIN" == "false" ] && (
	echo "Building LibcWrapGenerator"
	cd "$SRC"
	valac --pkg gee-0.8 --pkg posix --pkg glib-2.0 --pkg gio-2.0 ./LibcWrapGenerator.vala
	mkdir -p "$PREFIX/bin/"
	mv -v ./LibcWrapGenerator "$PREFIX/bin/"
	LibcWrapGenerator --target 2.10 --libdir /lib --output "$PREFIX/libcwrap.h"
	echo
)

$LINUX && [ "$CROSSWIN" == "false" ] && export CC="$CC -U_FORTIFY_SOURCE -include $PREFIX/libcwrap.h"
$LINUX && [ "$CROSSWIN" == "false" ] && export CXX="$CXX -U_FORTIFY_SOURCE -D_GLIBCXX_USE_CXX11_ABI=0 -include $PREFIX/libcwrap.h"

$CROSSWIN && (
	# make -f win32/Makefile.gcc SHARED_MODE=1 CC="$MINGW-gcc" AR="$MINGW-ar" RC="$MINGW-windres" STRIP="$MINGW-strip" IMPLIB=libz.dll.a
	# install -d "$PREFIX/"{bin,include,lib}
	# install -m644 -t "$PREFIX/include" zlib.h zconf.h
	# install -m644 -t "$PREFIX/lib" libz.a libz.dll.a
	# install -m755 -t "$PREFIX/bin" zlib1.dll
	# install -d "$PREFIX/lib/pkgconfig"
	# sed "s,@prefix@,$PREFIX,;s,@exec_prefix@,\${prefix},;s,@libdir@,\${exec_prefix}/lib,;s,@sharedlibdir@,\${libdir},;s,@includedir@,\${prefix}/include,;s,@VERSION@,1.2.11," < zlib.pc.in > "$PREFIX/lib/pkgconfig/zlib.pc"
	# make clean -f win32/Makefile.gcc
	# make clean
	# $MINGW-strip -x -g "$PREFIX/bin/zlib1.dll"
	# $MINGW-strip -g $PREFIX/lib/libz*
	echo
) || (
	echo "Building zlib"
	cd "$SRC/zlib"
	./configure --prefix="$PREFIX"
	make $makearg
	make install
	make distclean
)

$LINUX && [ "$CROSSWIN" == "false" ] && (
	echo "Building OpenSSL"
	cd "$SRC/openssl"
	./Configure --prefix="$PREFIX" linux-x86_64 shared
	make $makearg
	make install
	make distclean
)

[ "$CROSSWIN" == "false" ] && (
	echo "Building libpng"
	cd "$SRC/libpng"
	./configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" LFLAGS="$LFLAGS" CXXFLAGS="$CXXFLAGS"
	make $makearg
	make install
	make distclean
)

# echo "Building FreeType"
# cd "$SRC/freetype"
# ./configure --prefix="$PREFIX" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" --with-harfbuzz=no --with-png=yes --with-bzip2=no
# make $makearg
# make install
# make distclean

echo "Building SDL2"
cd "$SRC/SDL2"
bash ./autogen.sh || true
mkdir -p build
cd build
../configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" LFLAGS="$LFLAGS" CXXFLAGS="$CXXFLAGS" \
	--enable-sdl-dlopen \
	--disable-arts --disable-esd --disable-nas \
	--enable-alsa --enable-pulseaudio-shared \
	--enable-video-wayland --enable-wayland-shared \
	--enable-x11-shared --enable-ibus --enable-fcitx --enable-ime \
	--disable-rpath --disable-input-tslib --disable-audio --disable-atomic \
	--disable-haptic --disable-joystick --disable-power --disable-threads \
	--disable-file --disable-loadso --disable-cpuinfo
make $makearg
make install
make distclean

echo "Building SDL2_image"
cd "$SRC/SDL2_image"
bash ./autogen.sh || true
./configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" LFLAGS="$LFLAGS" CXXFLAGS="$CXXFLAGS" \
	--with-sdl-prefix="$PREFIX" --disable-webp --disable-gif --disable-lbm \
	--disable-pcx --disable-pnm --disable-tga --disable-xpm --disable-xv --disable-xcf \
	--enable-png --enable-png-shared --disable-tif
make $makearg
make install
make distclean

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

$MACOS && (
	echo "Building dylibbundler"
	cd "$SRC/dylibbundler"
	make install PREFIX="$PREFIX"
	make clean
)

echo "Building aria2"
cd "$SRC/aria2"
./configure --prefix="$PREFIX" --host="$HOST" PKG_CONFIG_PATH="$PKG_CONFIG_PATH" CC="$CC" CXX="$CXX" LFLAGS="$LFLAGS" CXXFLAGS="$CXXFLAGS"  \
	--disable-metalink --disable-websocket --enable-libaria2 \
	--disable-rpath --without-sqlite3 --without-libxml2 --without-libexpat \
	--without-libssh2 --enable-bittorrent --without-libcares --without-gnutls
make $makearg
make install
make distclean || true
make clean || true

touch "$PREFIX/built_libs"
