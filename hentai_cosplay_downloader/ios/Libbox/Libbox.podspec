Pod::Spec.new do |s|
  s.name             = 'Libbox'
  s.version          = '1.0.0'
  s.summary          = 'Sing-box Libbox engine for iOS'
  s.homepage         = 'https://github.com/SagerNet/sing-box'
  s.license          = { :type => 'GPLv3' }
  s.author           = { 'SagerNet' => 'support@sagernet.org' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '15.0'
  s.vendored_frameworks = 'Libbox.xcframework'
  s.libraries        = 'resolv'
end
