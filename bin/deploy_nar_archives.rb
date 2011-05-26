#!/usr/bin/env ruby

require 'fileutils'

PROJECT_ROOT = File.expand_path('../..',  __FILE__)
SENSOR_NATIVE_PATH = File.join(PROJECT_ROOT, '/java/sensor-native')
DESTINATION_ROOT = File.join(PROJECT_ROOT, '/app')

%w{macosx-ppc macosx-i386 macosx-x86_64 win32}.each do |arch|
  source = SENSOR_NATIVE_PATH + "/native-archives/vernier-goio-#{arch}-nar.jar"
  to_path = DESTINATION_ROOT + '/public/jnlp/org/concord/sensor/vernier/vernier-goio/'
  new_jar_index = Dir["#{to_path}/*#{arch}*__*.jar"].sort.last[/-(\d+)\.jar$/, 1].to_i + 1
  version_str = '__V1.5.0-' + Time.now.strftime("%Y%m%d.%H%M%S") + "-#{new_jar_index}"
  versioned_name = "vernier-goio-#{arch}-nar" + version_str + '.jar'
  destination = to_path + versioned_name
  if File.exists?(source)
    FileUtils.cp(source, destination)
    system("ruby #{DESTINATION_ROOT}/bin/resign-jars.rb #{versioned_name}")
  end
end
