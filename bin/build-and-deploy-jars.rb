#!/usr/bin/env ruby

require 'fileutils'
require 'yaml'

PROJECT_ROOT = File.expand_path('../..',  __FILE__)
CONFIG_PATH = File.join(PROJECT_ROOT, 'config')
BIN_PATH = File.join(PROJECT_ROOT, 'bin')


begin
  CONFIG = YAML.load_file(File.join(CONFIG_PATH, 'config.yml'))
rescue Errno::ENOENT
  msg = <<-HEREDOC


*** missing config/config.yml

    cp config/config_sample.yml config/config.yml

    and edit appropriately ...
  
  HEREDOC
  raise msg
end

PUBLIC_ROOT = File.join(PROJECT_ROOT, 'app', 'public')

JAVA_PROJECTS_PATH = File.join(PROJECT_ROOT, 'java')

TIMESTAMP = Time.now.strftime("%Y%m%d.%H%M%S")

MAVEN_CLEAN = "mvn clean"

MAVEN_STD_BUILD = "mvn -Dmaven.compiler.source=1.5 -Dmaven.test.skip=true package"
MAVEN_STD_CLEAN_BUILD = MAVEN_CLEAN + ';' + MAVEN_STD_BUILD

MAVEN_SMALL_BUILD = "mvn -Dmaven.compiler.source=1.5 -Dmaven.compiler.debuglevel=none -Dmaven.test.skip=true package"
MAVEN_SMALL_CLEAN_BUILD = MAVEN_CLEAN + ';' + MAVEN_SMALL_BUILD

MANUAL_JAR_BUILD = "rm -rf bin; mkdir bin; find src -name *.java | xargs javac -target 5 -sourcepath src -classpath /System/Library/Frameworks/JavaVM.framework/Home/lib/plugin.jar -d bin"

MW_ANT_BUILD = "ant clean; ant dist2"

# Compiling with -Dmaven.compiler.debuglevel=none can produce jars 25% smaller
# however stack traces will not have nearly as much useful information.
#
# For this to work properly maven.compiler.debug must also be true. This is the
# default value -- but it can also be set like this: -Dmaven.compiler.debug=true
#
# Compiling MW this way drops the size from 7.2 to 5.4 MB 

PROJECT_LIST = {
  'otrunk'         => { :path => 'org/concord/otrunk',
                        :build_type => :maven,
                        :build => MAVEN_STD_CLEAN_BUILD,
                        :has_applet_class => true,
                        :sign => true },                                                            

  'framework'      => { :path => 'org/concord/framework',
                        :build_type => :maven,
                        :build => MAVEN_STD_CLEAN_BUILD,
                        :sign => true },                                                            

  'data'           => { :path => 'org/concord/data',
                        :build_type => :maven,
                        :build => MAVEN_STD_CLEAN_BUILD,
                        :sign => true },                                                            

  'sensor'         => { :path => 'org/concord/sensor',
                        :build_type => :maven,
                        :build => MAVEN_STD_CLEAN_BUILD,
                        :sign => true },                                                

  'sensor-applets' => { :path => 'org/concord/sensor/sensor-applets',
                        :build_type => :maven,
                        :build => MAVEN_STD_CLEAN_BUILD,
                        :has_applet_class => true,
                        :sign => true },                                                            

  'sensor-native'  => { :path => 'org/concord/sensor-native',
                        :build_type => :maven,
                        :build => MAVEN_STD_CLEAN_BUILD,
                        :sign => true },                                                            

  'frameworkview'  => { :path => 'org/concord/frameworkview',
                        :build_type => :maven,
                        :build => MAVEN_STD_CLEAN_BUILD,
                        :sign => true },

  'energy2d'       => { :path => 'org/concord/energy2d',
                        :build_type => :custom,
                        :version => '0.1.0',
                        :build => MANUAL_JAR_BUILD,
                        :has_applet_class => true,
                        :sign => false },

  'mw'             => { :path => 'org/concord/modeler',
                        :build_type => :maven,
                        # :version => '2.1.0', 
                        :build => MAVEN_STD_CLEAN_BUILD,
                        :has_applet_class => true,
                        :sign => true },

  'mw-plugins'     => { :path => 'org/concord/modeler/plugins',                         
                        :build_type => :copy_jars,
                        :has_applet_class => true,
                        :sign => true },

  'nlogo'          => { :path => 'org/nlogo',                         
                        :build_type => :copy_jars,
                        :has_applet_class => true,
                        :sign => false },
  

  'test-applets'   => { :path => 'org/concord/applet',
                        :build_type => :custom,
                        :version => '0.1.0',
                        :build => MANUAL_JAR_BUILD,
                        :has_applet_class => true,
                        :sign => false },
}

projects = {}
if ARGV[0]
  project_path = PROJECT_LIST[ARGV[0]]
  projects = { ARGV[0] => project_path } if project_path
else
  projects = PROJECT_LIST
end

def prep_project(project, options, project_path)
  version_template = source = ''
  Dir.chdir(project_path) do
    puts "\n************************************************************\n"
    case options[:build_type]
    when :maven
      print "\nbuilding maven project: #{project} ... \n\n"
      start = Time.now
      system(options[:build])
      puts sprintf("%d.1s", Time.now-start)
      source = Dir["#{project_path}/target/#{project}*SNAPSHOT.jar"][0]
      version_template = source[/#{project}-(.*?)-SNAPSHOT/, 1]
      return [ { :source => source, :version_template => version_template } ]
    when :ant
      print "\nbuilding ant project: #{project} ... \n\n"
      start = Time.now
      system(options[:build])
      puts sprintf("%d.1s", Time.now-start)
      source = Dir["#{project_path}/bin/#{project}.jar"][0]
      source = "#{project_path}/dist/#{project}.jar"
      version_template = options[:version]
      return [ { :source => source, :version_template => version_template } ]
    when :custom
      print "\nbuilding project: #{project} ... \n\n"
      start = Time.now
      system(options[:build])
      puts sprintf("%d.1s", Time.now-start)
      print "\ncreating jar:: #{project}.jar ... \n\n"
      version_template = options[:version]
      start = Time.now
      jar_name = "#{project}-#{version_template}.jar"
      `jar cf #{project}-#{version_template}.jar -C bin .`
      puts sprintf("%d.1s", Time.now-start)
      source = "#{project_path}/#{jar_name}"
      return [ { :source => source, :version_template => version_template } ]
    when :copy_jars
      project_jars = Dir["#{project_path}/*.jar"]
      print "\ncopying #{project_jars.length} jars from project: #{project} ... \n\n"
      return project_jars.collect { |pj| { :source => pj, :version_template => nil } }
    end
  end
end

projects.each do |project, options|
  project_path = File.join(JAVA_PROJECTS_PATH, project)
  project_tokens = prep_project(project, options, project_path)
  project_tokens.each do |project_token|
    source = project_token[:source]
    version_template = project_token[:version_template]
    
    to_path = "#{PUBLIC_ROOT}/jnlp/#{options[:path]}"
    if options[:build_type] == :copy_jars
      versioned_name = File.basename(source)
    else
      existing_jars = Dir["#{to_path}/*.jar"]
      if existing_jars.empty?
        new_jar_index = 1
      else
        new_jar_index = existing_jars.sort.last[/-(\d+)\.jar$/, 1].to_i + 1
      end
      version_str = "__V#{version_template}-" + TIMESTAMP + "-#{new_jar_index}"
      versioned_name = project + version_str + '.jar'
    end
    destination = "#{to_path}/#{versioned_name}"
    puts "\ncopy: #{source} \nto:   #{destination}"
    FileUtils.mkdir_p(to_path) unless File.exists?(to_path)
    FileUtils.cp(source, destination)
    pack_and_sign_cmd = "ruby #{BIN_PATH}/pack-and-resign-jars.rb #{versioned_name}"
    if options[:sign]
      system(pack_and_sign_cmd)
    else
      system(pack_and_sign_cmd + ' --nosign')
    end
  end
end