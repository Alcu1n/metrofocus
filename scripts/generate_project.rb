require 'xcodeproj'
root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.new(File.join(root, 'MetroFocus.xcodeproj'))
app = project.new_target(:application, 'MetroFocus', :ios, '18.0')
widget = project.new_target(:app_extension, 'MetroFocusLiveActivity', :ios, '18.0')
tests = project.new_target(:unit_test_bundle, 'MetroFocusTests', :ios, '18.0')
uitests = project.new_target(:ui_test_bundle, 'MetroFocusUITests', :ios, '18.0')
[app, widget, tests, uitests].each do |target|
  target.build_configurations.each do |config|
    config.build_settings.merge!({
      'SWIFT_VERSION'=>'5.0', 'IPHONEOS_DEPLOYMENT_TARGET'=>'18.0',
      'TARGETED_DEVICE_FAMILY'=>'1', 'CODE_SIGN_STYLE'=>'Automatic',
      'GENERATE_INFOPLIST_FILE'=>'YES', 'SWIFT_EMIT_LOC_STRINGS'=>'YES',
      'ENABLE_USER_SCRIPT_SANDBOXING'=>'YES', 'MARKETING_VERSION'=>'1.0.0',
      'CURRENT_PROJECT_VERSION'=>'1', 'SUPPORTED_PLATFORMS'=>'iphoneos iphonesimulator',
      'SUPPORTS_MACCATALYST'=>'NO', 'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'=>'NO',
      'PRODUCT_BUNDLE_IDENTIFIER'=> "com.metrofocus.#{target.name == 'MetroFocus' ? 'app' : target.name.downcase}",
    })
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)' if config.name == 'Debug'
  end
end
app.build_configurations.each do |c|
 c.build_settings.merge!({'INFOPLIST_FILE'=>'MetroFocus/Info.plist','ASSETCATALOG_COMPILER_APPICON_NAME'=>'AppIcon','INFOPLIST_KEY_CFBundleDisplayName'=>'MetroFocus'})
end
widget.build_configurations.each do |c|
 c.build_settings.merge!({'INFOPLIST_FILE'=>'MetroFocusLiveActivity/Info.plist','SKIP_INSTALL'=>'YES','APPLICATION_EXTENSION_API_ONLY'=>'YES','PRODUCT_BUNDLE_IDENTIFIER'=>'com.metrofocus.app.liveactivity'})
end
tests.build_configurations.each do |c|
 c.build_settings.merge!({'TEST_HOST'=>'$(BUILT_PRODUCTS_DIR)/MetroFocus.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/MetroFocus','BUNDLE_LOADER'=>'$(TEST_HOST)'})
end
uitests.build_configurations.each { |c| c.build_settings['TEST_TARGET_NAME']='MetroFocus' }
def add_sources(project, target, directory)
 group = project.main_group.new_group(directory, directory)
 Dir.glob(File.join(directory, '**', '*.swift')).sort.each do |path|
   next if path.include?('/Shared/')
   ref = group.new_file(path.delete_prefix(directory + '/'))
   target.source_build_phase.add_file_reference(ref)
 end
 Dir.glob(File.join(directory, '**', '*')).sort.each do |path|
   next unless File.file?(path) && ['.wav','.xcstrings','.ahap'].include?(File.extname(path))
   ref = group.new_file(path.delete_prefix(directory + '/'))
   target.resources_build_phase.add_file_reference(ref)
 end
 Dir.glob(File.join(directory,'**','*.xcassets')).each do |path|
   ref = group.new_file(path.delete_prefix(directory+'/'))
   target.resources_build_phase.add_file_reference(ref)
 end
end
Dir.chdir(root) do
 add_sources(project,app,'MetroFocus')
 add_sources(project,widget,'MetroFocusLiveActivity')
 add_sources(project,tests,'MetroFocusTests')
 add_sources(project,uitests,'MetroFocusUITests')
 shared = project.main_group.new_group('Shared', 'MetroFocus/Shared')
 Dir.glob('MetroFocus/Shared/*.swift').each do |path|
   ref = shared.new_file(File.basename(path))
   app.source_build_phase.add_file_reference(ref)
   widget.source_build_phase.add_file_reference(ref)
 end
end
app.add_dependency(widget)
embed = app.new_copy_files_build_phase('Embed App Extensions')
embed.dst_subfolder_spec = '13'
embed.add_file_reference(widget.product_reference)
tests.add_dependency(app)
uitests.add_dependency(app)
project.root_object.attributes['LastUpgradeCheck'] = '2700'
project.root_object.known_regions = ['en','zh-Hans','Base']
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.set_launch_target(app)
scheme.add_test_target(tests)
scheme.add_test_target(uitests)
scheme.save_as(project.path,'MetroFocus',true)
puts "Generated #{project.path}"
