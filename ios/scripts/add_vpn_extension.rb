#!/usr/bin/env ruby
# Add VPNTunnel Network Extension target to iOS pbxproj
# Usage: ruby ios/scripts/add_vpn_extension.rb

require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 鈹€鈹€ Check if VPNTunnel already exists 鈹€鈹€
if project.targets.any? { |t| t.name == 'VPNTunnel' }
  puts "[SKIP] VPNTunnel target already exists"
  project.save
  exit 0
end

runner_target = project.targets.find { |t| t.name == 'Runner' }
unless runner_target
  puts "[ERROR] Runner target not found"
  exit 1
end

puts "[INFO] Adding VPNTunnel extension..."

# 鈹€鈹€ Create VPNTunnel group 鈹€鈹€
vpn_group = project.main_group.new_group('VPNTunnel', 'VPNTunnel')

# 鈹€鈹€ Add VPNTunnel source files 鈹€鈹€
vpn_files = [
  { name: 'PacketTunnelProvider.swift', path: 'VPNTunnel/PacketTunnelProvider.swift' },
  { name: 'Info.plist', path: 'VPNTunnel/Info.plist' },
  { name: 'VPNTunnel.entitlements', path: 'VPNTunnel/VPNTunnel.entitlements' },
]

file_refs = {}
vpn_files.each do |f|
  path = File.join(Dir.pwd, f[:path])
  if File.exist?(path)
    ref = vpn_group.new_file(f[:path])
    file_refs[f[:name]] = ref
    puts "  Added: #{f[:path]}"
  else
    puts "  [WARN] Missing: #{f[:path]}"
  end
end

# 鈹€鈹€ Create VPNTunnel target 鈹€鈹€
vpn_target = project.new_target(
  :app_extension,
  'VPNTunnel',
  :ios,
  '13.0'
)

vpn_target.product_reference.name = 'VPNTunnel.appex'
vpn_target.product_reference.path = 'VPNTunnel.appex'

# Add source files to VPNTunnel
if file_refs['PacketTunnelProvider.swift']
  vpn_target.add_file_references([file_refs['PacketTunnelProvider.swift']])
end

# Add Info.plist
if file_refs['Info.plist']
  info_ref = file_refs['Info.plist']
  vpn_target.build_configurations.each do |config|
    config.build_settings['INFOPLIST_FILE'] = 'VPNTunnel/Info.plist'
  end
end

# Configure VPNTunnel build settings
vpn_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.netsignory.app.VPNTunnel'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'VPNTunnel/VPNTunnel.entitlements'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'VPNTunnel'
  config.build_settings['INFOPLIST_KEY_NSHumanReadableCopyright'] = ''
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['VERSIONING_SYSTEM'] = 'apple-generic'
end

# 鈹€鈹€ Add VPNTunnel to Embed App Extensions 鈹€鈹€
runner_target.add_dependency(vpn_target)

# Add to Embed App Extensions build phase
embed_phase = runner_target.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' } ||
              runner_target.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :plug_ins } ||
              runner_target.new_copy_files_build_phase('Embed App Extensions')

embed_phase.name = 'Embed App Extensions'
embed_phase.symbol_dst_subfolder_spec = :plug_ins
embed_phase.dst_path = ''

vpn_build_file = embed_phase.add_file_reference(vpn_target.product_reference, true)
vpn_build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# 鈹€鈹€ Add NetworkExtension capability 鈹€鈹€
runner_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

# Ensure Runner.entitlements file reference exists
ent_path = 'Runner/Runner.entitlements'
existing_ref = project.files.find { |f| f.path == ent_path }
unless existing_ref
  runner_group = project.main_group.find_subpath('Runner', false)
  if runner_group && File.exist?(File.join(Dir.pwd, ent_path))
    runner_group.new_file(ent_path)
    puts "  Added: #{ent_path}"
  end
end

project.save
puts "[DONE] VPNTunnel extension added successfully"
