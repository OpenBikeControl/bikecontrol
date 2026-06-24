cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "screen_recorder")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "screen_recorder_plugin")

add_library(${PLUGIN_NAME} SHARED
  "screen_recorder_plugin.cpp"
  "screen_recorder_plugin_c_api.cpp"
  "capture_recorder.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_STANDARD 17)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  d3d11 dxgi mf mfplat mfreadwrite mfuuid windowsapp)

set(screen_recorder_bundled_libraries "" PARENT_SCOPE)
