Pod::Spec.new do |s|
  s.name             = 'background_task'
  s.version          = '0.2.0'
  s.summary          = 'Processes location updates while a Flutter app is in the background.'
  s.description      = <<-DESC
Processes location updates after a Flutter application transitions to the background.
                       DESC
  s.homepage         = 'https://github.com/never-inc/flutter_background_task'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Never Inc.'
  s.source           = { :path => '.' }
  s.source_files     = 'background_task/Sources/background_task/**/*.swift'
  s.resource_bundles = {
    'background_task_privacy' => [
      'background_task/Sources/background_task/PrivacyInfo.xcprivacy',
    ]
  }
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
