TARGET = loelauncher
LIBS = -laria2 -lSDL2 -lSDL2_image
INCLUDES = -I/Users/daniel/prefix/include -L/Users/daniel/prefix/lib
INCLUDESWIN = -ISDL2-2.0.5/x86_64-w64-mingw32/include -ISDL2-2.0.5/x86_64-w64-mingw32/include/SDL2 -LSDL2-2.0.5/x86_64-w64-mingw32/lib -ISDL2_image-2.0.1/x86_64-w64-mingw32/include -LSDL2_image-2.0.1/x86_64-w64-mingw32/lib -Iprefix/include -Lprefix/lib
LFLAGS = -static-libgcc -static-libstdc++
CFLAGS = -g -Wall -O2 -std=c++11
SOURCE = src

CCWIN = x86_64-w64-mingw32-g++

MACOSAPP = .loe.app
DMGVOLNAME = Legends of Equestria installer

.PHONY: default all clean windows windowsinstaller macosapp

default: $(TARGET)
all: default

OBJECTS = $(patsubst %.cpp, %.o, $(wildcard $(SOURCE)/*.cpp))
OBJECTSWIN = $(patsubst %.cpp, %.owin, $(wildcard $(SOURCE)/*.cpp))
HEADERS = $(wildcard $(SOURCE)/*.h)

%.o: %.cpp $(HEADERS)
	$(CXX) $(CFLAGS) $(INCLUDES) -c $< -o $@

%.owin: %.cpp $(HEADERS)
	$(CCWIN) $(CFLAGS) $(INCLUDESWIN) -c $< -o $@

.PRECIOUS: $(TARGET) $(OBJECTS) $(OBJECTSWIN)

$(TARGET): $(OBJECTS)
	$(CXX) $(CFLAGS) $(INCLUDES) -o $@ $(OBJECTS) $(LFLAGS) $(LIBS)
	strip -x $@

windows/icon.ico: assets/icon.png
	convert assets/icon.png windows/icon.ico

windows: $(TARGET).exe
$(TARGET).exe: $(OBJECTSWIN) windows/icon.ico
	x86_64-w64-mingw32-windres windows/exe.rc -O coff -o src/res.owin
	$(CCWIN) $(CFLAGS) $(INCLUDESWIN) -o $@ $(OBJECTSWIN) src/res.owin $(LFLAGS) $(LIBS)
	x86_64-w64-mingw32-strip -x $@

windowsinstaller: $(TARGET).exe windows/icon.ico install-loe.msi
install-loe.msi:
	rm -rf wininst
	mkdir -p wininst
	cp loelauncher.exe wininst/
	cp -r assets wininst/
	cp -r windows/*.dll wininst/
	rm -f install-loe.msi
	msi-packager -n "Legends of Equestria" -v "1.0" -m "Legends of Equestria" -a x64 \
		-u 4A00EFB3-F9D9-497E-B0FE-1EB313EF8ECE -i windows/icon.ico -e loelauncher.exe -l \
		wininst "install-loe.msi"
	rm -rf wininst

$(MACOSAPP):
	mkdir -p "Legends of Equestria.app"
	ln -s "Legends of Equestria.app" "$(MACOSAPP)"

$(MACOSAPP)/Contents/MacOS/run.sh: $(MACOSAPP) macos/run.sh
	mkdir -p "$(MACOSAPP)/Contents/MacOS/"
	cp macos/run.sh "$(MACOSAPP)/Contents/MacOS/run.sh"

$(MACOSAPP)/Contents/MacOS/loelauncher: $(MACOSAPP) loelauncher
	mkdir -p "$(MACOSAPP)/Contents/MacOS/"
	cp loelauncher "$(MACOSAPP)/Contents/MacOS/"
	dylibbundler -od -b -x "$(MACOSAPP)/Contents/MacOS/loelauncher" -d "$(MACOSAPP)/Contents/libs"

$(MACOSAPP)/Contents/Info.plist: $(MACOSAPP) macos/Info.plist
	mkdir -p "$(MACOSAPP)/Contents/"
	cp macos/Info.plist "$(MACOSAPP)/Contents/"

$(MACOSAPP)/Contents/Resources/loe.icns: $(MACOSAPP) assets/icon.png
	mkdir -p loe.iconset
	@for SIZE in 16 32 64 128 256 512; do \
		sips -z $$SIZE $$SIZE assets/icon.png --out loe.iconset/icon_$${SIZE}x$${SIZE}.png; \
	done
	@for SIZE in 32 64 128 256 512 1024; do \
		sips -z $$SIZE $$SIZE assets/icon.png --out loe.iconset/icon_$$(expr $$SIZE / 2)x$$(expr $$SIZE / 2)@2x.png; \
	done
	mkdir -p "$(MACOSAPP)/Contents/Resources/"
	iconutil --convert icns -o "$(MACOSAPP)/Contents/Resources/loe.icns" loe.iconset
	rm -rf loe.iconset

$(MACOSAPP)/Contents/MacOS/assets: $(MACOSAPP) assets
	mkdir -p "$(MACOSAPP)/Contents/MacOS/"
	cp -r assets "$(MACOSAPP)/Contents/MacOS/"

LoE.dmg: $(MACOSAPP)
	@macos/createdmg.sh "$(MACOSAPP)" "$(DMGVOLNAME)"

macosapp: $(MACOSAPP) $(MACOSAPP)/Contents/Info.plist $(MACOSAPP)/Contents/MacOS/run.sh $(MACOSAPP)/Contents/Resources/loe.icns $(MACOSAPP)/Contents/MacOS/assets $(MACOSAPP)/Contents/MacOS/loelauncher


clean:
	-rm -f $(SOURCE)/*.o $(SOURCE)/*.owin
	-rm -f $(TARGET) $(TARGET).exe "install-loe.msi" "windows/exe.res" "windows/icon.ico"
	-rm -rf "$(MACOSAPP)" "Legends of Equestria.app"
