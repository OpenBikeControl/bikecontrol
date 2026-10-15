#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gamepads_darwin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gamepads_darwin'
  s.version          = '0.1.1'
  s.summary          = 'iOS and macOS implementation of gamepads.'
  s.description      = <<-DESC
iOS and macOS implementation of gamepads, a Flutter plugin to handle gamepad input across multiple platforms.
                       DESC
  s.homepage         = 'https://flame-engine.org'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Luan' => 'luan@blue-fire.xyz' }

  s.source           = { :path => '.' }
  s.source_files     = 'gamepads_darwin/Sources/gamepads_darwin/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'

  s.ios.deployment_target = '13.0'
  s.osx.frameworks = 'IOKit'
  s.osx.deployment_target = '10.15'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.0'
end
