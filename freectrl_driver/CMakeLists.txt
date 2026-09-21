cmake_minimum_required(VERSION 3.20)
project(freectrl_driver VERSION 1.0.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Driver name and paths
set(DRIVER_NAME "freectrl")
set(DRIVER_BINARY_NAME "driver_${DRIVER_NAME}")

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

# Driver library target (to be implemented in workspace-qoj.5/6)
# add_library(${DRIVER_BINARY_NAME} MODULE src/controller_driver.cpp src/device_provider.cpp ...)
# target_link_libraries(${DRIVER_BINARY_NAME} PRIVATE openvr_api)
# set_target_properties(${DRIVER_BINARY_NAME} PROPERTIES
#   PREFIX ""
#   SUFFIX "${CMAKE_SHARED_MODULE_SUFFIX}"
#   OUTPUT_NAME "${DRIVER_BINARY_NAME}"
# )
# install(TARGETS ${DRIVER_BINARY_NAME}
#   DESTINATION "${STEAMVR_DRIVER_INSTALL_DIR}/bin/${PLATFORM_ARCH}"
# )

# For now, create a placeholder to verify install layout
add_custom_target(verify_install_layout
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/install/drivers/${DRIVER_NAME}"
  COMMAND ${CMAKE_COMMAND} -E copy driver.vrdrivermanifest "${CMAKE_BINARY_DIR}/install/drivers/${DRIVER_NAME}/"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/install/drivers/${DRIVER_NAME}/input"
  COMMAND ${CMAKE_COMMAND} -E copy input/vive_controller_profile.json "${CMAKE_BINARY_DIR}/install/drivers/${DRIVER_NAME}/input/"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/install/drivers/${DRIVER_NAME}/resources/icons"
  COMMAND ${CMAKE_COMMAND} -E copy resources/icons/vive_controller.svg "${CMAKE_BINARY_DIR}/install/drivers/${DRIVER_NAME}/resources/icons/"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/install/drivers/${DRIVER_NAME}/resources/settings"
  COMMAND ${CMAKE_COMMAND} -E copy resources/settings/default.vrsettings "${CMAKE_BINARY_DIR}/install/drivers/${DRIVER_NAME}/resources/settings/"
  COMMENT "Verifying driver install layout"
)

# Build-time verification
add_custom_target(check_profile_json
  COMMAND python3 -c "
import json, sys
with open('input/vive_controller_profile.json') as f:
  data = json.load(f)
  assert data.get('jsonid') == 'input_profile', 'jsonid must be input_profile'
  assert data.get('controller_type') == 'vive_controller', 'controller_type must be vive_controller'
  assert data.get('input_bindingui_mode') == 'controller_handed', 'input_bindingui_mode must be controller_handed'
  sources = data.get('input_source', {})
  required = ['/input/system', '/input/application_menu', '/input/grip', '/input/trigger', '/input/trackpad', '/output/haptic']
  for req in required:
    assert req in sources, f'Missing required input source: {req}'
  print('Profile JSON validation passed')
  "
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  COMMENT "Validating vive_controller_profile.json"
)

add_custom_target(verify_all DEPENDS verify_install_layout check_profile_json)