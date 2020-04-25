#
#  Be sure to run `pod spec lint EarpieceLib.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see https://guides.cocoapods.org/syntax/podspec.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |spec|

  # --- General infos
  spec.name         = "TransparentVideo"
  spec.version      = "0.0.1"
  spec.summary      = "Play transparent video using vertically split export (normal + alpha channel)"
  spec.homepage     = "https://www.alexiscreuzot.com"
  spec.license      = "Reserved to Alexis Creuzot"

  spec.author       = { "Alexis Creuzot" => "alexis.creuzot@gmail.com" }
  # --- Platform
  spec.platform     = :ios, "12.0"
  spec.swift_versions = '5'

  # --- Source
  spec.source       = { :git => "https://github.com/kirualex/MyTransparentVideoExample.git", :tag => "#{spec.version}" }
  spec.source_files = "MyTransparentVideoExample/lib/**/*.swift"
  spec.frameworks   = "AVFoundation", "CoreImage", "Metal"

end