#
# Be sure to run `pod lib lint MyLibrary.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "RestKitMapper"
  s.version          = "0.1.1"
  s.summary          = "Declarative-style configurator for RestKit."
  s.description      = <<-DESC
                       RestKitMapper allows to perform declarative-style configuration of RestKit
                       for your application using property file.
                       
                       The following RestKit features are supported:
                       * Attributes mappings
                       * Primary keys
                       * Relationships (by reference and by primary key value)
                       * Request mappings
                       * Error mappings
                       DESC
  s.homepage         = "https://github.com/xfyre/RestKitMapper"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Ilya Obshadko" => "xfyre@xfyre.com" }
  s.source           = { :git => "https://github.com/xfyre/RestKitMapper.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Classes'
  s.resource_bundles = {
    'RestKitMapper' => ['Assets/*']
  }
  
  s.prefix_header_contents = <<-EOS
    #ifdef __OBJC__
      #import <Foundation/Foundation.h>
      #import <CoreData/CoreData.h>
      #import <SystemConfiguration/SystemConfiguration.h>
      #import <MobileCoreServices/MobileCoreServices.h>
    #endif
  EOS

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.dependency 'RestKit'
end
