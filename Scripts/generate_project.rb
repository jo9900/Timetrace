require 'xcodeproj'

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.new(File.join(root, 'Timetrace.xcodeproj'))
project.root_object.attributes['LastUpgradeCheck'] = '2630'
locales = ['zh-Hans', 'zh-Hant', 'ja', 'en']
project.root_object.known_regions = locales
project.root_object.development_region = 'zh-Hans'
app = project.new_target(:application, 'Timetrace', :ios, '17.0')
unit = project.new_target(:unit_test_bundle, 'TimetraceTests', :ios, '17.0')
ui = project.new_target(:ui_test_bundle, 'TimetraceUITests', :ios, '17.0')
unit.add_dependency(app)
ui.add_dependency(app)

[app, unit, ui].each do |target|
  target.build_configurations.each do |config|
    config.build_settings.merge!({
      'SWIFT_VERSION' => '5.0',
      'IPHONEOS_DEPLOYMENT_TARGET' => '17.0',
      'TARGETED_DEVICE_FAMILY' => '1',
      'PRODUCT_BUNDLE_IDENTIFIER' => "com.yuanzheng.#{target.name.downcase}",
      'CODE_SIGN_STYLE' => 'Automatic',
      'DEVELOPMENT_TEAM' => '54BTJHJKUU',
      'MARKETING_VERSION' => '1.0.0',
      'CURRENT_PROJECT_VERSION' => '1',
      'GENERATE_INFOPLIST_FILE' => 'YES',
      'SWIFT_STRICT_CONCURRENCY' => 'targeted'
    })
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG' if config.name == 'Debug'
  end
end
app.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'Sources/Resources/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
  config.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end
unit.build_configurations.each do |config|
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Timetrace.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Timetrace'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end
ui.build_configurations.each do |config|
  config.build_settings['TEST_TARGET_NAME'] = 'Timetrace'
end

[['Sources', app], ['Tests', unit], ['UITests', ui]].each do |folder, target|
  group = project.main_group.new_group(folder, folder)
  Dir.glob(File.join(root, folder, '**', '*.swift')).sort.each do |file|
    relative = file.delete_prefix(File.join(root, folder) + '/')
    reference = group.new_file(relative)
    target.source_build_phase.add_file_reference(reference)
  end
end
resources = project.main_group.new_group('Resources', 'Sources/Resources')
['Localizable.strings', 'InfoPlist.strings'].each do |filename|
  variant = resources.new_variant_group(filename)
  locales.each do |locale|
    ref = variant.new_file("#{locale}.lproj/#{filename}")
    ref.name = locale
  end
  app.resources_build_phase.add_file_reference(variant)
end
ref = resources.new_file('PrivacyInfo.xcprivacy')
app.resources_build_phase.add_file_reference(ref)
app.resources_build_phase.add_file_reference(resources.new_file('Assets.xcassets'))
fonts = resources.new_group('Fonts', 'Fonts')
Dir.glob(File.join(root, 'Sources/Resources/Fonts', '*.{otf,txt}')).sort.each do |file|
  app.resources_build_phase.add_file_reference(fonts.new_file(File.basename(file)))
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(unit)
scheme.add_test_target(ui)
scheme.set_launch_target(app)
scheme.save_as(project.path, 'Timetrace', true)
puts project.path
