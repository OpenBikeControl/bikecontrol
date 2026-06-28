Pod::Spec.new do |s|
  s.name             = 'screen_recorder'
  s.version          = '0.0.1'
  s.summary          = 'In-repo screen recorder.'
  s.description      = 'macOS ScreenCaptureKit screen recording.'
  s.homepage         = 'https://bikecontrol.app'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'BikeControl' => 'jonas@bikecontrol.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
