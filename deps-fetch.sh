#!/usr/bin/env bash

set -e

. ./env.sh

declare -a deps
$LINUX && [ "$CROSSWIN" == "false" ] && deps+=('appimagetool.AppImage,https://github.com/AppImage/AppImageKit/releases/download/10/appimagetool-x86_64.AppImage')
$LINUX && [ "$CROSSWIN" == "false" ] && deps+=('LibcWrapGenerator.vala,https://raw.githubusercontent.com/AppImage/AppImageKit/master/LibcWrapGenerator/LibcWrapGenerator.vala')
$MACOS && deps+=('dylibbundler,https://github.com/auriamg/macdylibbundler/archive/84440587e1b2e4e9e0727cbba7a455b96820e40a.zip')
deps+=('SDL2,https://www.libsdl.org/release/SDL2-2.0.7.tar.gz')
deps+=('SDL2_image,https://www.libsdl.org/projects/SDL_image/release/SDL2_image-2.0.2.tar.gz')
# deps+=('SDL2_ttf,https://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.14.tar.gz')
deps+=('aria2,https://github.com/aria2/aria2/releases/download/release-1.33.1/aria2-1.33.1.tar.xz')
[ "$CROSSWIN" == "false" ] && deps+=('zlib,https://www.zlib.net/zlib-1.2.11.tar.gz')
# deps+=('freetype,http://download.savannah.gnu.org/releases/freetype/freetype-2.7.1.tar.gz')
[ "$CROSSWIN" == "false" ] && deps+=('libpng,https://sourceforge.net/projects/libpng/files/libpng16/1.6.34/libpng-1.6.34.tar.xz/download')
# deps+=('c-ares,https://c-ares.haxx.se/download/c-ares-1.13.0.tar.gz') # used by aria2
[ "$CROSSWIN" == "false" ] && deps+=('openssl,https://www.openssl.org/source/openssl-1.1.0g.tar.gz')
rm -rf deps
mkdir -p deps

echo "Downloading dependencies"
for i in "${deps[@]}"; do
	IFS=',' read -a dep <<< "$i"
	name="${dep[0]}"
	url="${dep[1]}"
	echo "Downloading $url"
	filename="${url%/download}"
	case "$filename" in
	*.zip)
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
		curl --progress-bar -L "$url" -o deps/$name
		chmod +x deps/$name
		;;
	esac
done
