#!/usr/bin/env bash

platform="win64"
gamedir="./loe"
zsync="/home/djazz/Downloads/AppImage-zsync-curl/src/zsync_curl"
mkdir -p "$gamedir"

versions="https://patches.legendsofequestria.com/zsync/versions3.json"
version=`curl -sL "$versions" | jq -r .$platform`

baseurl="https://patches.legendsofequestria.com/zsync/$version/"

index=`curl --progress-bar -L "$baseurl/.zsync-control.jar"`

IFS=$'\n' relativeContentUrls=(`echo "$index" | jq -r '.Content[].RelativeContentUrl'`)
IFS=$'\n' fileHashes=(`echo "$index" | jq -r '.Content[].FileHash'`)
IFS=$'\n' installPaths=(`echo "$index" | jq -r '.Content[]._installPath'`)

#curl -ivL "${baseurl}loe/${relativeContentUrls[0]}"

for i in "${!relativeContentUrls[@]}"; do
	url="${baseurl}loe/${relativeContentUrls[$i]}"
	filehash="${fileHashes[$i]}"
	path="${installPaths[$i]//\\/\/}"
	echo $url $path
	echo zsync_curl -o "${path%.jar.zsync.jar}" "$url"
	mkdir -p $(dirname "$gamedir/$path")
	# currently does not handle gzip. Running again generates .zs-old files
	(cd "$gamedir" && $zsync -o "${path%.jar.zsync.jar}" "$url")
done
