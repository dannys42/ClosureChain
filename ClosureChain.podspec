#
# Be sure to run `pod lib lint ClosureChain.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ClosureChain'
  s.version          = '0.0.1'
  s.summary          = 'Simplifies sequential async completion methods by providing a familiar try-catch pattern'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
ClosureChain simplifies sequential async completion methods for Swift. It
provides a familiar try-catch pattern for sequential async methods.

                       DESC

  s.homepage         = 'https://github.com/dannys42/ClosureChain'
  s.license          = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.author           = { 'dannys42' => 'danny@dannysung.com' }
  s.source           = { :git => 'https://github.com/dannys42/ClosureChain.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '11.0'

  s.source_files = 'Sources/ClosureChain/**/*.swift'

  s.swift_versions = [ '5.1', '5.2', '5.3' ]
end
