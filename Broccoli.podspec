Pod::Spec.new do |s|

s.name         = "Broccoli"
s.version      = "0.0.1"
s.summary      = "Solution for CoreData with CloudKit written in Swift"

s.description  = <<-DESC
Broccoli is a solution for CoreData with CloudKit written in Swift.
DESC

s.homepage     = "https://github.com/derekcoder/Broccoli"
s.license      = { :type => 'MIT', :file => 'LICENSE' }
s.author       = { "derekcoder" => "derekcoder@gmail.com" }
s.source       = { :git => "https://github.com/derekcoder/Broccoli.git", :tag => s.version.to_s }

s.ios.deployment_target = '10.0'

s.source_files  = ['Broccoli/Sources/*.swift', 'Broccoli/Broccoli.h']
s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.0' }

end
