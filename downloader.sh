#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

platform="Linux"
gamedir="./dl"
zsync="zsync_curl"
mkdir -p "$gamedir"


versions="https://patches.legendsofequestria.com/zsync/versions3.json"
version=`curl -sL "$versions" | jq -r .$platform`

baseurl="https://patches.legendsofequestria.com/zsync/$version/"

index=`curl -f --progress-bar -L "$baseurl/.zsync-control.jar"`

IFS=$'\n' relativeContentUrls=(`echo "$index" | jq -r '.Content[].RelativeContentUrl'`)
IFS=$'\n' fileHashes=(`echo "$index" | jq -r '.Content[].FileHash'`)
IFS=$'\n' installPaths=(`echo "$index" | jq -r '.Content[]._installPath'`)

for i in "${!relativeContentUrls[@]}"; do
	url="${baseurl}loe/${relativeContentUrls[$i]}"
	filehash="${fileHashes[$i]}"
	path="${installPaths[$i]//\\/\/}"
	echo $url $path
	echo zsync_curl -o "${path%.jar.zsync.jar}" "$url"
	mkdir -p $(dirname "$gamedir/$path")

	if [ ! -f "$gamedir/${path%.jar.zsync.jar}.gz" ] && [ -f "$gamedir/${path%.jar.zsync.jar}" ]; then
		echo "Compressing ${path%.jar.zsync.jar}..."
		gzip -vf "$gamedir/${path%.jar.zsync.jar}"
	fi
	(cd "$gamedir" && $zsync -o "${path%.jar.zsync.jar}.gz" "$url")
	echo "Extracting ${path%.jar.zsync.jar}..."
	gzip -dvf "$gamedir/${path%.jar.zsync.jar}.gz"
	rm -fv "$gamedir/${path%.jar.zsync.jar}.gz.zs-old"
done
