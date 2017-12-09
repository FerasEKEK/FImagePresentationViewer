Pod::Spec.new do |s|
s.platform = :ios
s.ios.deployment_target = '9.0'
s.name = "FImagePresentationViewer"
s.summary = "Simple and easy to use image viewer written in swift."
s.requires_arc = true
s.version = "0.1.0"
s.license = { :type => "MIT", :file => "LICENSE" }
s.author = { "[Firas Al Khatib Al Khalidi]" => "[fir_khalidi@hotmail.com]" }
s.homepage = "https://github.com/FirasAKAK/FImagePresentationViewer"
s.source = { :git => "https://github.com/FirasAKAK/FImagePresentationViewer.git", :tag => "#{s.version}"}
s.framework = "UIKit"
s.dependency 'PBImageView'
s.source_files = "FImagePresentationViewer/**/*.{swift}"
s.resources = "FImagePresentationViewer/**/*.{png,jpeg,jpg,storyboard,xib}"
end
