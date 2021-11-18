#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint marketing_cloud_messaging_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'marketing_cloud_messaging_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Sales Force Marketing Cloud Implementation.'
  s.description      = 'Sales Force Marketing Cloud Implementation.'
  s.homepage         = 'https://github.com/cacianokroth'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Caciano & CIA LTDA' => 'caciano.kroths@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '10.0'
  s.ios.deployment_target  = '10.0'
  s.dependency 'MarketingCloudSDK', '7.6.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.1'
end
