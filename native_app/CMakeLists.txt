cmake_minimum_required(VERSION 3.16)
project(native_app LANGUAGES CXX)

# Use modern C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Main application target
add_executable(native_app src/main.cpp)

# Enable testing and configure GoogleTest via FetchContent (no system dependency)
include(CTest)
enable_testing()

include(FetchContent)
# Prefer system policy off; we'll vendor googletest to avoid apt-get/apt-utils issues
set(BUILD_GMOCK OFF CACHE BOOL "Build GoogleMock" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "Disable install for gtest" FORCE)

FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
)
# For older cmake, we need this to avoid overriding parent's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "Use shared CRT" FORCE)
FetchContent_MakeAvailable(googletest)

# Add tests
add_executable(native_app_tests
  tests/test_sample.cpp
)

target_link_libraries(native_app_tests
  GTest::gtest
  GTest::gtest_main
)

# PUBLIC_INTERFACE: ctest registration of unit tests
# Discover tests automatically
include(GoogleTest)
gtest_discover_tests(native_app_tests
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
  DISCOVERY_TIMEOUT 30
)
