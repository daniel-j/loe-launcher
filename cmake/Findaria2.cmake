

find_path(ARIA2_INCLUDE_DIR aria2.h
        HINTS
        ENV ARIA2DIR
        ENV PREFIX
        PATH_SUFFIXES aria2
        include/aria2 include
        PATHS ${ARIA2_PATH}
        )

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(VC_LIB_PATH_SUFFIX lib/x64 lib)
else()
    set(VC_LIB_PATH_SUFFIX lib/x86 lib)
endif()

find_library(ARIA2_LIBRARY
        NAMES aria2
        HINTS
        ENV ARIA2DIR
        PATH_SUFFIXES lib ${VC_LIB_PATH_SUFFIX}
        PATHS ${ARIA2_PATH}
        )

set(ARIA2_INCLUDE_DIRS ${ARIA2_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)

FIND_PACKAGE_HANDLE_STANDARD_ARGS(aria2
        REQUIRED_VARS ARIA2_LIBRARY ARIA2_INCLUDE_DIR)

# for backward compatibility
set(ARIA2_LIBRARY ${ARIA2_LIBRARIES})
set(ARIA2_INCLUDE_DIR ${ARIA2_INCLUDE_DIRS})
set(ARIA2_FOUND ${ARIA2_FOUND})

mark_as_advanced(ARIA2_LIBRARY ARIA2_INCLUDE_DIR)
