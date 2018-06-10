include(ExternalProject)
include(ProcessorCount)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/src)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/src)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY  ${CMAKE_CURRENT_LIST_DIR}/../bin)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -undefined dynamic_lookup")

if(NOT $ENV{DART_SDK} STREQUAL "")
    message("Dart SDK path: $ENV{DART_SDK}")
else()
    message(FATAL_ERROR "DART_SDK is not defined")
endif()

include_directories($ENV{DART_SDK}/include)
add_definitions(-DDART_SHARED_LIB=1)
add_library(hypertext SHARED
        src/http-parser/http_parser.h src/http-parser/http_parser.c
        src/hypertext.h src/hypertext.cc)

install(TARGETS hypertext DESTINATION lib)