cmake_minimum_required(VERSION 3.21)
set(PROJECT_NAME "universal_ble")
project(${PROJECT_NAME} LANGUAGES CXX)
cmake_policy(VERSION 3.14...3.25)
include(FetchContent)
set(CPPWINRT_VERSION "2.0.220418.1")
set(PLUGIN_NAME "universal_ble_plugin")

# ############### NuGet intall begin ################
FetchContent_Declare(nuget
  URL "https://dist.nuget.org/win-x86-commandline/v6.0.0/nuget.exe"
  URL_HASH SHA256=04eb6c4fe4213907e2773e1be1bbbd730e9a655a3c9c58387ce8d4a714a5b9e1
  DOWNLOAD_NO_EXTRACT true
)

find_program(NUGET nuget)

if(NOT NUGET)
  # message("Nuget.exe not found, trying to download or use cached version.")
  FetchContent_MakeAvailable(nuget)
  set(NUGET ${nuget_SOURCE_DIR}/nuget.exe)
endif()

execute_process(COMMAND
  ${NUGET} install "Microsoft.Windows.CppWinRT" -Version ${CPPWINRT_VERSION} -OutputDirectory packages
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  RESULT_VARIABLE ret)

if(NOT ret EQUAL 0)
  message(FATAL_ERROR "Failed to install nuget package Microsoft.Windows.CppWinRT.${CPPWINRT_VERSION}")
endif()

# ############### NuGet install end ################
list(APPEND PLUGIN_SOURCES
  "src/universal_ble_plugin.cpp"
  "src/universal_ble_plugin.h"
  "src/helper/universal_enum.h"
  "src/helper/universal_ble_base.h"
  "src/helper/utils.cpp"
  "src/helper/utils.h"
  "src/ui_thread_handler.hpp"
  "src/generated/universal_ble.g.cpp"
  "src/generated/universal_ble.g.h"
  "src/pin_entry.h"
  "src/universal_ble_filter_util.cpp"
  "src/universal_ble_filter_util.h"
  "src/universal_ble_thread_safe.h"
  "src/enum_parser.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/universal_ble/universal_ble_plugin_c_api.h"
  "universal_ble_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

# ############### NuGet import begin ################
set_target_properties(${PLUGIN_NAME} PROPERTIES VS_PROJECT_IMPORT
  ${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.CppWinRT.${CPPWINRT_VERSION}/build/native/Microsoft.Windows.CppWinRT.props
)

target_link_libraries(${PLUGIN_NAME} PRIVATE
  ${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.CppWinRT.${CPPWINRT_VERSION}/build/native/Microsoft.Windows.CppWinRT.targets
)

# ############### NuGet import end ################
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

set(universal_ble_bundled_libraries
  ""
  PARENT_SCOPE
)
