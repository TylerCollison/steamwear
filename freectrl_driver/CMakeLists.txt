cmake_minimum_required(VERSION 3.20)
project(freectrl_driver VERSION 1.0.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Driver name and paths
set(DRIVER_NAME "freectrl")
set(DRIVER_BINARY_NAME "driver_${DRIVER_NAME}")

# Default the install prefix to <build>/install so the SteamVR driver layout
# is assembled under build/install/ out of the box. Override with
# -DCMAKE_INSTALL_PREFIX=/path/to/steamvr to install straight into SteamVR.
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH
    "Install prefix (root of the SteamVR driver layout)" FORCE)
endif()

# Installation prefix for SteamVR driver layout
# SteamVR expects: <steamvr>/drivers/<driver_name>/bin/<platform>/<driver_binary>
#                    <steamvr>/drivers/<driver_name>/resources/
#                    <steamvr>/drivers/<driver_name>/input/
set(STEAMVR_DRIVER_INSTALL_DIR "${CMAKE_INSTALL_PREFIX}/drivers/${DRIVER_NAME}")

# Platform-specific binary directory
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(PLATFORM_ARCH "win64")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(PLATFORM_ARCH "osx64")
else()
  set(PLATFORM_ARCH "linux64")
endif()

# ---------------------------------------------------------------------------
# OpenVR SDK headers (header-only dependency)
#
# Only headers are needed at build time: the driver API is a pure virtual
# interface + C API table and vrserver resolves symbols when it loads the
# driver, so nothing is linked against an OpenVR import lib.
#
# Override with -DOPENVR_HEADERS_DIR=/path/to/openvr/headers. Sensible
# defaults: the OPENVR_HEADERS environment variable (set by the project build
# container), an openvr_headers/ symlink or copy next to this file, or a
# system-wide /opt/openvr/headers (as installed by the build container).
# ---------------------------------------------------------------------------
set(OPENVR_HEADERS_DIR "" CACHE PATH
  "Path to the OpenVR SDK headers (openvr_driver.h, openvr.h, openvr_capi.h)")

if(NOT OPENVR_HEADERS_DIR)
  if(DEFINED ENV{OPENVR_HEADERS} AND EXISTS "$ENV{OPENVR_HEADERS}/openvr_driver.h")
    set(OPENVR_HEADERS_DIR "$ENV{OPENVR_HEADERS}")
  elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/openvr_headers/openvr_driver.h")
    set(OPENVR_HEADERS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/openvr_headers")
  elseif(EXISTS "/opt/openvr/headers/openvr_driver.h")
    set(OPENVR_HEADERS_DIR "/opt/openvr/headers")
  endif()
endif()

if(OPENVR_HEADERS_DIR)
  if(EXISTS "${OPENVR_HEADERS_DIR}/openvr_driver.h")
    message(STATUS "OpenVR headers: ${OPENVR_HEADERS_DIR}")
  else()
    message(WARNING
      "OPENVR_HEADERS_DIR is set to ${OPENVR_HEADERS_DIR} but openvr_driver.h "
      "was not found there. Sources that include openvr_driver.h will fail to "
      "compile; pass a valid -DOPENVR_HEADERS_DIR instead.")
  endif()
else()
  message(WARNING
    "OpenVR headers not found. Pass -DOPENVR_HEADERS_DIR=/path/to/openvr/headers "
    "(headers: https://github.com/ValveSoftware/openvr/tree/master/headers). "
    "Sources that include openvr_driver.h will fail to compile until then.")
endif()

# ---------------------------------------------------------------------------
# Driver library target (MODULE: dlopen'd by vrserver at runtime)
# Later tasks (workspace-qoj.2..7) add sources incrementally to this target.
# ---------------------------------------------------------------------------
add_library(${DRIVER_BINARY_NAME} MODULE
  src/driver_entry.cpp       # placeholder entry point (real one: workspace-qoj.6)
)

target_include_directories(${DRIVER_BINARY_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/src
)

if(OPENVR_HEADERS_DIR)
  target_include_directories(${DRIVER_BINARY_NAME} PRIVATE ${OPENVR_HEADERS_DIR})
endif()

# Output name: driver_freectrl.dll|.so (no "lib" prefix)
set_target_properties(${DRIVER_BINARY_NAME} PROPERTIES
  PREFIX ""
  OUTPUT_NAME "${DRIVER_BINARY_NAME}"
)

# Platform specifics
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  # WinSock2 for the upcoming UDP receiver tasks (workspace-qoj.2)
  target_link_libraries(${DRIVER_BINARY_NAME} PRIVATE ws2_32)
else()
  # pthread for the UDP receiver threads on Linux/macOS (workspace-qoj.2);
  # -fPIC is implied for MODULE targets but set explicitly for clarity.
  set_target_properties(${DRIVER_BINARY_NAME} PROPERTIES POSITION_INDEPENDENT_CODE ON)
  find_package(Threads REQUIRED)
  target_link_libraries(${DRIVER_BINARY_NAME} PRIVATE Threads::Threads)
endif()

# ---------------------------------------------------------------------------
# Install: assemble the SteamVR driver folder layout
#   <prefix>/drivers/freectrl/driver.vrdrivermanifest
#   <prefix>/drivers/freectrl/bin/<platform>arch/driver_freectrl.dll|.so
#   <prefix>/drivers/freectrl/input/...
#   <prefix>/drivers/freectrl/resources/...
# ---------------------------------------------------------------------------
install(TARGETS ${DRIVER_BINARY_NAME}
  DESTINATION "${STEAMVR_DRIVER_INSTALL_DIR}/bin/${PLATFORM_ARCH}"
)

# Install driver manifest
install(FILES
  driver.vrdrivermanifest
  DESTINATION "${STEAMVR_DRIVER_INSTALL_DIR}"
)

# Install input profile JSON
install(FILES
  input/vive_controller_profile.json
  DESTINATION "${STEAMVR_DRIVER_INSTALL_DIR}/input"
)

# Install icons
install(DIRECTORY resources/icons/
  DESTINATION "${STEAMVR_DRIVER_INSTALL_DIR}/resources/icons"
  FILES_MATCHING PATTERN "*.svg"
)

# Install settings (default.vrsettings will be added by workspace-qoj.7)
install(DIRECTORY resources/settings/
  DESTINATION "${STEAMVR_DRIVER_INSTALL_DIR}/resources/settings"
  FILES_MATCHING PATTERN "*.vrsettings"
)

# Assemble the full driver layout under the install prefix
# (default: build/install/drivers/freectrl/...).
add_custom_target(install_layout
  COMMAND ${CMAKE_COMMAND} --install "${CMAKE_BINARY_DIR}"
  COMMENT "Assembling SteamVR driver layout under ${CMAKE_INSTALL_PREFIX}"
)

# Build-time verification (scripted to keep the Makefile rules valid)
add_custom_target(check_profile_json
  COMMAND python3 "${CMAKE_CURRENT_SOURCE_DIR}/cmake/check_profile_json.py"
  COMMENT "Validating vive_controller_profile.json"
)

add_custom_target(verify_all DEPENDS ${DRIVER_BINARY_NAME} install_layout check_profile_json)
