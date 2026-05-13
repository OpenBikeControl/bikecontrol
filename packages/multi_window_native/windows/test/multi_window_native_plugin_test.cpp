#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "multi_window_native_plugin.h"

namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(MultiWindowNativePlugin, GetMessengerCount) {
  // Test the messenger count functionality
  int initial_count = static_cast<int>(MultiWindowNativePlugin::GetMessengers().size());
  
  // The messenger count should be a non-negative integer
  EXPECT_GE(initial_count, 0);
  
  // Test that we can clear messengers
  MultiWindowNativePlugin::ClearMessengers();
  int cleared_count = static_cast<int>(MultiWindowNativePlugin::GetMessengers().size());
  EXPECT_EQ(cleared_count, 0);
}

}  // namespace test
