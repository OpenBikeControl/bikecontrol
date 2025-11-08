#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'media_key_detector_ios'
  s.version          = '0.0.1'
  s.summary          = 'An iOS implementation of the media_key_detector plugin.'
  s.description      = <<-DESC
  A macOS implementation of the media_key_detector plugin.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'

  s.platform = :ios, '13.0'
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'
end

