#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint audio_waveforms.podspec` to validate before publishing.
#
# Fork of SimformSolutionsPvtLtd/audio_waveforms (MIT). See FORK.md at the
# repository root. The podspec is kept so CocoaPods consumers are not broken;
# the Swift Package Manager integration lives in ios/audio_waveforms/Package.swift.
Pod::Spec.new do |s|
  s.name             = 'audio_waveforms'
  s.version          = '2.0.3'
  s.summary          = 'A Flutter package that allow you to generate waveform while recording audio or from audio file.'
  s.description      = <<-DESC
A Flutter package that allow you to generate waveform while recording audio or from audio file.
                       DESC
  s.homepage         = 'https://github.com/ChristopherCfly/audio_waveforms'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Simform Solutions (fork maintained by ChristopherCfly)' => 'christopher@cinefly.io' }
  s.source           = { :path => '.' }
  s.source_files = 'audio_waveforms/Sources/audio_waveforms/**/*.{h,m,swift}'
  s.public_header_files = 'audio_waveforms/Sources/audio_waveforms/include/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
