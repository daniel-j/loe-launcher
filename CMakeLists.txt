cmake_minimum_required(VERSION 3.1)
set (CMAKE_CXX_STANDARD 11)

project(loelauncher)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR "Building in the source directory is not supported, try building in a 'build' directory.")
endif()

file(GLOB_RECURSE sources
    ${CMAKE_SOURCE_DIR}/src/*.cpp
)

add_executable(${PROJECT_NAME}
    ${sources}
)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake")

find_package(SDL2 REQUIRED)
find_package(SDL2_image REQUIRED)
# find_package(SDL2_ttf REQUIRED)
find_package(aria2 REQUIRED)

include_directories(
    prefix/include
)

MESSAGE( STATUS "Aria2: " ${ARIA2_LIBRARY} )
target_link_libraries(
    ${PROJECT_NAME}
    ${SDL2_LIBRARY}
    ${SDL2_IMAGE_LIBRARIES}
    # ${SDL2_TTF_LIBRARIES}
    ${ARIA2_LIBRARY}
)

# C++ Linting. Produces warnings but doesn't prevent compiling
# https://github.com/google/styleguide/tree/gh-pages/cpplint
find_program(CPPLINT cpplint)
if(CPPLINT)
    file(GLOB_RECURSE srcs
        ${sources}
        ${CMAKE_SOURCE_DIR}/src/*.hpp
    )
    add_custom_target(GoogleStyle ALL
        cpplint
        --output=eclipse
        --filter=-legal/copyright,-build/include,-build/header_guard
        --linelength=100
        ${srcs} || true)
endif()