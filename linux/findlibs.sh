#!/usr/bin/env bash

set -e

scan_libs() {
	if [ ! -f "$1" ]; then return; fi
	local libs=$(objdump -x "$1" | awk '$1 == "NEEDED" { print $2 }' | grep -E -v '(libc[^_a-zA-Z0-9])|(libm[^_a-zA-Z0-9])|libpthread|(librt[^_a-zA-Z0-9])|(libdl[^_a-zA-Z0-9])|(libcrypt[^_a-zA-Z0-9])|(libutil[^_a-zA-Z0-9])|(libnsl[^_a-zA-Z0-9])|(libresolv[^_a-zA-Z0-9])|libasound|libglib|libgcc_s|libX11|ld-linux|libgnutls|(libstdc\+\+[^_a-zA-Z0-9])|(libz[^_a-zA-Z0-9])')
	if [ -z "$libs" ]; then return; fi
	local lddoutput=$(ldd "$1")
	#echo $3${1##*/}
	local indent="  $4"
	local IFS=$'\n'
	while read -r file
	do
		if [ -z "$file" ]; then continue; fi
		local filepath=$(echo "$lddoutput" | grep -F "$file" | awk '{print $3}')
		if [ -e "$filepath" ]; then
			echo "$indent$file"
			if [ -e "$filepath" ] && [ ! -e "$2/$file" ]; then
				cp "$filepath" "$2/"
				scan_libs "$filepath" "$2" "" "$indent"
			fi
		fi
		if [ ! -e "$filepath" ]; then
			echo "$filepath not found"
		fi
	done <<< "$libs"

	# handle extras
	local IFS=' '
	while read -r file
	do
		if [ -z "$file" ]; then continue; fi
		local filepath="$PREFIX/lib/$file"
		if [ -e "$filepath" ] && [ ! -e "$2/$file" ]; then
			echo "$indent$file"
			cp "$filepath" "$2/"
			scan_libs "$filepath" "$2" "" "$indent"
		fi
		if [ ! -e "$filepath" ]; then
			echo "$filepath not found"
		fi
	done <<< "$3"
}

echo "Scanning and copying libraries..."
scan_libs "$1" "$2"
