TARGET = loelauncher

export PATH := prefix/bin:$(PATH)

LFLAGS +=
CFLAGS += -g -Wall -O2 -std=c++11
SOURCE += src

PLATFORM := $(shell uname -s)
# Linux
ifeq ($(PLATFORM),Linux)
    LIBS += -Lprefix/lib -laria2 -lSDL2 -lSDL2_image
    INCLUDES += -Iprefix/include

    MINGW = x86_64-w64-mingw32
    LIBSWIN += $(LIBS)
    INCLUDESWIN += $(INCLUDES)
    CCWIN = $(MINGW)-g++
endif
# macOS
ifeq ($(PLATFORM),Darwin)
    LIBS += -Lprefix/lib -laria2 -lSDL2 -lSDL2_image
    INCLUDES += -Iprefix/include

    DMGVOLNAME = Legends of Equestria installer
    # Workaround because make doesn't like spaces in target filenames
    MACOSAPP = .loe.app
endif

.PHONY: default all clean windows windowsinstaller macosapp macosinstaller

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

$(TARGET): $(OBJECTS) Makefile
	$(CXX) $(CFLAGS) $(INCLUDES) -o $@ $(OBJECTS) $(LFLAGS) $(LIBS)
	strip -x $@

windows/icon.ico: assets/icon.png
	convert assets/icon.png windows/icon.ico

windows: $(TARGET).exe
$(TARGET).exe: $(OBJECTSWIN) windows/icon.ico Makefile
	$(MINGW)-windres windows/exe.rc -O coff -o src/res.owin
	$(CCWIN) $(CFLAGS) $(INCLUDESWIN) -o $@ $(OBJECTSWIN) src/res.owin $(LFLAGS) $(LIBSWIN)
	$(MINGW)-strip -x $@

windowsinstaller: $(TARGET).exe windows/icon.ico install-loe.msi
install-loe.msi:
	rm -rf wininst
	mkdir -p wininst
	cp loelauncher.exe wininst/
	cp -r assets wininst/
	cp -r windows/*.dll wininst/
	rm -f install-loe.msi
	msi-packager -n "Legends of Equestria" -v "1.0.0" -m "Legends of Equestria" -a x64 \
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
	strip -x "$(MACOSAPP)/Contents/MacOS/loelauncher" $(MACOSAPP)/Contents/libs/*.dylib

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

macosapp: $(MACOSAPP) $(MACOSAPP)/Contents/Info.plist $(MACOSAPP)/Contents/MacOS/run.sh $(MACOSAPP)/Contents/Resources/loe.icns $(MACOSAPP)/Contents/MacOS/assets $(MACOSAPP)/Contents/MacOS/loelauncher

macosinstaller: macosapp LoE.dmg
LoE.dmg:
	@macos/createdmg.sh "$(MACOSAPP)" "$(DMGVOLNAME)"


clean:
	-rm -f $(SOURCE)/*.o $(SOURCE)/*.owin
	-rm -f $(TARGET) $(TARGET).exe "install-loe.msi" "windows/exe.res" "windows/icon.ico"
	-rm -rf "$(MACOSAPP)" "Legends of Equestria.app" "LoE.dmg"
