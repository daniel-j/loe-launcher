#!/usr/bin/env bash

set -e

. ./env.sh

declare -a deps
deps+=('SDL2,https://www.libsdl.org/release/SDL2-2.0.5.tar.gz')
deps+=('SDL2_image,https://www.libsdl.org/projects/SDL_image/release/SDL2_image-2.0.1.tar.gz')
deps+=('aria2,https://github.com/aria2/aria2/releases/download/release-1.32.0/aria2-1.32.0.tar.xz')
#deps+=('nfd,https://github.com/mlabbe/nativefiledialog/archive/5cfe5002eb0fac1e49777a17dec70134147931e2.zip')
#deps+=('zlib,https://zlib.net/zlib-1.2.11.tar.gz')
# deps+=('freetype,http://download.savannah.gnu.org/releases/freetype/freetype-2.7.1.tar.gz')
#deps+=('libpng,https://sourceforge.net/projects/libpng/files/libpng16/1.6.32/libpng-1.6.32.tar.xz/download')
#deps+=('c-ares,https://c-ares.haxx.se/download/c-ares-1.13.0.tar.gz')
$MACOS && deps+=('dylibbundler,https://github.com/auriamg/macdylibbundler/archive/3c79be6efb0867775bd0571011331946f76f36a6.zip')

rm -rf deps

echo "Downloading dependencies"
for i in "${deps[@]}"; do
	IFS=',' read -a dep <<< "$i"
	name="${dep[0]}"
	url="${dep[1]}"
	echo "Downloading $url"
	filename="${url%/download}"
	case "$filename" in
	*.zip)
		mkdir -p deps
		curl --progress-bar -L "$url" -o deps/$name.zip
		mkdir -p "deps/$name.tmp"
		unzip -q deps/$name.zip -d "deps/$name.tmp"
		rm deps/$name.zip
		mv "deps/$name.tmp/"* "deps/$name"
		rmdir "deps/$name.tmp"
		;;

	*.tar|*.tar.gz|*.tar.xz|*.tar.bz2|*.tgz)
		case "$filename" in
		*xz)	compressor=J ;;
		*bz2)	compressor=j ;;
		*gz)	compressor=z ;;
		*)	compressor= ;;
		esac
		mkdir -p "deps/$name"
		curl --progress-bar -L "$url" | tar -x$compressor -C "deps/$name" --strip-components=1
		;;

	*)
		echo "Unsupported archive format"
		false
	esac
done