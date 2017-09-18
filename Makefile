TARGET = loelauncher
LIBS = -laria2 -lSDL2 -lSDL2_image -lstdc++fs
INCLUDES = -Iaria2-release-1.32.0/src/includes -Laria2-release-1.32.0/src/.libs
INCLUDESWIN = -ISDL2-2.0.5/x86_64-w64-mingw32/include -ISDL2-2.0.5/x86_64-w64-mingw32/include/SDL2 -LSDL2-2.0.5/x86_64-w64-mingw32/lib -ISDL2_image-2.0.1/x86_64-w64-mingw32/include -LSDL2_image-2.0.1/x86_64-w64-mingw32/lib -Iaria2-release-1.32.0/src/includes
LFLAGS =
CC = g++
CFLAGS = -g -Wall -O2 -std=c++14
SOURCE = src

CCWIN = x86_64-w64-mingw32-g++

.PHONY: default all clean windows

default: $(TARGET)
all: default

OBJECTS = $(patsubst %.cpp, %.o, $(wildcard $(SOURCE)/*.cpp))
OBJECTSWIN = $(patsubst %.cpp, %.owin, $(wildcard $(SOURCE)/*.cpp))
HEADERS = $(wildcard $(SOURCE)/*.h)

%.o: %.cpp $(HEADERS)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

%.owin: %.cpp $(HEADERS)
	$(CCWIN) $(CFLAGS) $(INCLUDESWIN) -c $< -o $@

.PRECIOUS: $(TARGET) $(OBJECTS)

$(TARGET): $(OBJECTS)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $(OBJECTS) $(LFLAGS) $(LIBS) 

windows: $(TARGET).exe
$(TARGET).exe: $(OBJECTSWIN)
	$(CCWIN) $(CFLAGS) $(INCLUDESWIN) -o $@ $(OBJECTSWIN) $(LFLAGS) $(LIBS) 

clean:
	-rm -f $(SOURCE)/*.o $(SOURCE)/*.owin
	-rm -f $(TARGET) $(TARGET).exe
