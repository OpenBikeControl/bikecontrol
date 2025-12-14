# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "windows_iap")
project(${PROJECT_NAME} LANGUAGES CXX)

include(FetchContent)
set(CPPWINRT_VERSION "2.0.221121.5")

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "windows_iap_plugin")

################ NuGet intall begin ################
FetchContent_Declare(nuget
  URL "https://dist.nuget.org/win-x86-commandline/v6.4.0/nuget.exe"
  URL_HASH SHA256=26730829b240581a3e6a4e276b9ace088930032df0c680d5591beccf6452374e
  DOWNLOAD_NO_EXTRACT true
)

find_program(NUGET nuget)
if (NOT NUGET)
    message("Nuget.exe not found, trying to download or use cached version.")
    FetchContent_MakeAvailable(nuget)
    set(NUGET ${nuget_SOURCE_DIR}/nuget.exe)
endif()

execute_process(COMMAND
    ${NUGET} install "Microsoft.Windows.CppWinRT" -Version ${CPPWINRT_VERSION} -OutputDirectory packages
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    RESULT_VARIABLE ret)
if (NOT ret EQUAL 0)
    message(FATAL_ERROR "Failed to install nuget package Microsoft.Windows.CppWinRT.${CPPWINRT_VERSION}")
endif()
################ NuGet install end ################

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "windows_iap_plugin.cpp"
  "windows_iap_plugin.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/windows_iap/windows_iap_plugin_c_api.h"
  "windows_iap_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

################ NuGet import begin ################
set_target_properties(${PLUGIN_NAME} PROPERTIES VS_PROJECT_IMPORT
  ${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.CppWinRT.${CPPWINRT_VERSION}/build/native/Microsoft.Windows.CppWinRT.props
)

target_link_libraries(${PLUGIN_NAME} PRIVATE
  ${CMAKE_BINARY_DIR}/packages/Microsoft.Windows.CppWinRT.${CPPWINRT_VERSION}/build/native/Microsoft.Windows.CppWinRT.targets
)
################ NuGet import end ################

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(windows_iap_bundled_libraries
  ""
  PARENT_SCOPE
)
