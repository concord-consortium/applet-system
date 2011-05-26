#!/usr/bin/env ruby

require 'yaml'

PROJECT_ROOT = File.expand_path('../..',  __FILE__)
BIN_PATH = File.join(PROJECT_ROOT, 'bin')
CONFIG_PATH = File.join(PROJECT_ROOT, 'config')

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

LIBRARY_MANIFEST_PATH = File.join(CONFIG_PATH, 'manifest-library')
JAR_MANIFEST_PATH = File.join(CONFIG_PATH, 'manifest-jar')
SIGNED_JAR_MANIFEST_PATH = File.join(CONFIG_PATH, 'manifest-signed-jar')
JAR_SERVICES_DIR = File.join(CONFIG_PATH, 'services')

CMD_LOGGING = false

regex = ARGV[0]
if opts = ARGV[1]
  nosign = opts == '--nosign'
end

def cmd(command)
  if CMD_LOGGING
    cmd_log = command.gsub(/-storepass\s+\S+/, '-storepass ******')
    puts "\n    #{cmd_log}\n"
  end
  system(command)
end

jars = Dir["#{PUBLIC_ROOT}/jnlp/**/*.jar"]
if regex
  jars = jars.grep(/#{regex}/) 
end
puts "\nprocessing #{jars.length} jars ...\n"
jars.each do |jar_path|
  path = File.dirname(jar_path)
  name = File.basename(jar_path)
  library = name[/-nar(__V.*?|)\.jar/]
  Dir.chdir(path) do
    puts "\nworking in dir: #{path}\n"
    unless nosign
      puts "\nremoving content in meta-inf directory in: #{path}/#{name}"
      cmd("zip -d #{name} META-INF/\*") 
    end
    if library
      puts "\ncreating 'Trusted-Library: true' manifest in: #{path}/#{name}"
      cmd("jar umf #{LIBRARY_MANIFEST_PATH} #{name}")
    else
      # tip from AppletFriendlyXMLDecoder.java to fix spurious requests
      # in applets to: meta-inf/services/javax.xml.parsers.SAXParserFactory
      puts "\nadding META-INF/services directory to: #{path}/#{name}"
      cmd("jar uf #{name} -C #{CONFIG_PATH} META-INF")
      if nosign
        # system("jar umf #{JAR_MANIFEST_PATH} #{name}")
      else
        puts "\ncreating 'Trusted-Library: true' manifest in: #{path}/#{name}"
        cmd("jar umf #{SIGNED_JAR_MANIFEST_PATH} #{name}")
      end
    end
    #
    # 
    # Packing and unpacking MW can produce siging errors -- example:
    #   jarsigner: java.lang.SecurityException: SHA1 digest error for 
    #     org/concord/mw2d/models/AtomicModel$8.class
    #
    # So I am telling pack200 to create just 1 large segment file during processing.
    #
    # From the pack200 man page:
    #
    #    Larger archive segments result in less fragmentation and  better 
    #    compression, but processing them requires more memory.
    #
    # see: Digital signatures are invalid after unpacking
    #      http://bugs.sun.com/bugdatabase/view_bug.do?bug_id=5078608
    #
    puts "\nrepacking: #{path}/#{name}"
    cmd("pack200 --repack --segment-limit=-1 #{name}")
    unless nosign
      puts "\nsigning: #{path}/#{name}"
      cmd("jarsigner -storepass #{CONFIG[:password]} #{name} #{CONFIG[:alias]}")
      puts "\nverifying: #{path}/#{name}\n"
      cmd("jarsigner -verify #{name}")
    end
    unless library
      puts "\ncreating: #{path}/#{name}.pack.gz"
      cmd("pack200  --segment-limit=-1 #{name}.pack.gz  #{name}")
      unless nosign
        puts "\nunpacking and verifying: #{path}/#{name}.pack.gz\n"
        FileUtils.rm("#{PROJECT_ROOT}/packgz-extraction-#{name}") if File.exists?("#{PROJECT_ROOT}/packgz-extraction-#{name}")
        system("unpack200 #{path}/#{name}.pack.gz #{PROJECT_ROOT}/packgz-extraction-#{name}")
        if system("jarsigner -verify #{PROJECT_ROOT}/packgz-extraction-#{name}")
          system("rm -f #{PROJECT_ROOT}/packgz-extraction-#{name}")
        else
          puts "\n*** error with signature: #{PROJECT_ROOT}/packgz-extraction-#{name} \n"
        end
      end
    end
  end
  puts
end
