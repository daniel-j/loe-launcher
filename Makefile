TARGET = loelauncher

CXX = clang++

export PATH := prefix/bin:prefix-win/bin:$(PATH)

CXXFLAGS += -g -Wall -O2 -std=c++11 -stdlib=libc++
SOURCE += src

PLATFORM := $(shell uname -s)
# Linux
ifeq ($(PLATFORM),Linux)
    CXX := $(CXX) -U_FORTIFY_SOURCE -D_GLIBCXX_USE_CXX11_ABI=0 -include "prefix/libcwrap.h"
    LFLAGS += -static-libgcc -static-libstdc++
    LIBS += -lc++ -lc++abi -Lprefix/lib -laria2 -lSDL2 -lSDL2_image
    INCLUDES += -Iprefix/include

    MINGW = x86_64-w64-mingw32
    LIBSWIN += -lmingw32 -lSDL2main -mwindows -lole32 -loleaut32 -lcomdlg32 -luuid -Lprefix-win/lib -laria2 -lSDL2 -lSDL2_image
    INCLUDESWIN += -Iprefix-win/include
    CXXWIN = $(MINGW)-g++
    CXXWINFLAGS += -g -Wall -O2 -std=c++11
    APPDIR = LoE.AppDir
endif
# macOS
ifeq ($(PLATFORM),Darwin)
    LFLAGS = -static-libstdc++
    LIBS += -Lprefix/lib -laria2 -lSDL2 -lSDL2_image
    INCLUDES += -Iprefix/include

    DMGVOLNAME = Legends of Equestria installer
    # Workaround because make doesn't like spaces in target filenames
    MACOSAPP = .loe.app
endif

.PHONY: default all clean appimage windows windowsinstaller macosapp macosinstaller

all: default

SOURCES := $(shell find $(SOURCE) -name '*.cpp')
OBJECTS := $(patsubst %.cpp, %.o, $(SOURCES))
OBJECTSWIN := $(patsubst %.cpp, %.owin, $(SOURCES))
HEADERS := $(shell find $(SOURCE) -name '*.hpp')

# %.o: %.cpp $(HEADERS)
# 	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

%.owin: %.cpp $(HEADERS)
	$(CXXWIN) $(CXXWINFLAGS) $(INCLUDESWIN) -c $< -o $@

.PRECIOUS: $(TARGET) $(OBJECTS) $(OBJECTSWIN)

# $(TARGET): $(OBJECTS) Makefile
# 	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $(OBJECTS) $(LFLAGS) $(LIBS)

default:
	@mkdir -p build
	@cd build && cmake .. && make -s
	@cp build/loelauncher $(TARGET)

windows/icon.ico: assets/icon.png
	convert assets/icon.png windows/icon.ico

windows: $(TARGET).exe
$(TARGET).exe: $(OBJECTSWIN) windows/icon.ico Makefile
	$(MINGW)-windres windows/exe.rc -O coff -o src/res.owin
	$(CXXWIN) $(CXXWINFLAGS) $(INCLUDESWIN) -o $@ $(OBJECTSWIN) src/res.owin $(LFLAGS) $(LIBSWIN)

windowsinstaller:
	rm -rf wininst
	mkdir -p wininst
	cp loelauncher.exe wininst/
	cp -r assets wininst/
	cp /usr/$(MINGW)/bin/libwinpthread-1.dll wininst/
	cp /usr/$(MINGW)/bin/zlib1.dll wininst/
	cp /usr/$(MINGW)/bin/libpng16-16.dll wininst/
	cp /usr/$(MINGW)/bin/libgcc_s_seh-1.dll wininst/
	cp /usr/$(MINGW)/bin/libstdc++-6.dll wininst/
	cp prefix-win/bin/*.dll* wininst/
	$(MINGW)-strip -x wininst/*.dll* || true
	rm -f loe-install-x86_64.msi
	msi-packager -n "Legends of Equestria" -v "1.0.0" -m "Legends of Equestria" -a x64 \
		-u 4A00EFB3-F9D9-497E-B0FE-1EB313EF8ECE -i windows/icon.ico -e loelauncher.exe -l \
		wininst "loe-install-x86_64.msi"
	# rm -rf wininst

appimage:
	rm -rf $(APPDIR)
	mkdir -p $(APPDIR)
	cp loelauncher $(APPDIR)/
	cp -r assets $(APPDIR)/
	mkdir -p $(APPDIR)/libs
	LD_LIBRARY_PATH=prefix/lib ./linux/findlibs.sh ./loelauncher $(APPDIR)/libs
	cp linux/AppRun $(APPDIR)/
	cp linux/loe.desktop $(APPDIR)/
	ln -s assets/icon.png $(APPDIR)/.DirIcon
	chmod 755 $(APPDIR)/libs/*.so*
	strip -x $(APPDIR)/loelauncher $(APPDIR)/libs/*.so*
	deps/appimagetool.AppImage $(APPDIR) -v LoE.AppImage
	mv LoE.AppImage "Legends of Equestria.AppImage"


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

macosinstaller:
	@macos/createdmg.sh "$(MACOSAPP)" "$(DMGVOLNAME)"

lint:
	@mkdir -p build
	@cd build && cmake .. && make -s lint

clean:
	-rm -f $(TARGET) $(SOURCE)/*.o $(SOURCE)/*.owin
	-rm -rf build/
	-rm -f $(TARGET).exe "install-loe.msi" "windows/exe.res" "windows/icon.ico"
	-rm -rf "$(MACOSAPP)" "Legends of Equestria.app" "LoE.dmg"
