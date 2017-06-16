Pod::Spec.new do |s|
  s.name             = 'Clink'
  s.version          = '0.0.1'
  s.summary          = 'Share data accross nearby peers over BLE'

  s.description      = <<-DESC
    Share data accross nearby peers over BLE
                       DESC

  s.homepage         = 'https://github.com/nicksweet/Clink'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Nick Sweet' => 'nasweet@gmail.com' }
  s.source           = { :git => 'https://github.com/nicksweet/Clink.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/_nicksweet'

  s.ios.deployment_target = '10.0'

  s.source_files = 'Clink/Classes/**/*'
end
