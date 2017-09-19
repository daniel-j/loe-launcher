#!/usr/bin/env bash

DEV="/Volumes/$2"

rm -rf dmgsource
mkdir -p dmgsource
mkdir -p "dmgsource/Legends of Equestria.app"
cp -r "$1/." "dmgsource/Legends of Equestria.app"

APP_SIZE=`expr $(du -smx dmgsource | cut -f 1) + 1`

hdiutil detach "$DEV"
rmdir "$DEV"
rm -f LoE.dmg

echo "Creating dmg..."
hdiutil create -srcfolder dmgsource -volname "$2" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${APP_SIZE}m LoE.dmg
rm -rf dmgsource

echo "Attaching dmg..."
hdiutil attach -readwrite -noverify -noautoopen LoE.dmg
sleep 1

echo "Adding Applications shortcut..."
ln -s /Applications "$DEV/Applications"

echo "Setting icon..."
cp -v "$1/Contents/Resources/loe.icns" "$DEV/.VolumeIcon.icns"
SetFile -c icnC "$DEV/.VolumeIcon.icns"

chmod -Rfv go-w "$DEV" &> /dev/null || true

echo "Blessing..."
bless --folder "$DEV" --openfolder "$DEV"

echo "SetFile..."
SetFile -a C "$DEV"

echo "Detaching dmg..."
hdiutil detach "$DEV"

echo "Compressing dmg..."
hdiutil convert LoE.dmg -format UDZO -imagekey zlib-level=9 -o LoE-compressed.dmg
mv LoE-compressed.dmg LoE.dmg

