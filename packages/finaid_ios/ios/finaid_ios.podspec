Pod::Spec.new do |s|
  s.name             = 'finaid_ios'
  s.version          = '0.1.0'
  s.summary          = 'Puente nativo de Finaid para iOS.'
  s.description      = 'Face ID / código, selector de archivos y avisos locales para Finaid.'
  s.homepage         = 'https://github.com/IAN63k/Finaid'
  s.license          = { :type => 'Proprietary', :text => 'Finaid' }
  s.author           = { 'Finaid' => 'https://github.com/IAN63k/Finaid' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'LocalAuthentication', 'UserNotifications'
  s.weak_frameworks  = 'UniformTypeIdentifiers'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
