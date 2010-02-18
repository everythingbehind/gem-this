require 'rubygems/command_manager' 
require 'rubygems/command'
require 'gem_this'

class Gem::Commands::ThisCommand < Gem::Command
  def initialize
    super 'this', GemThis::SUMMARY, :debug => false
    add_option('-d', '--debug', GemThis::DEBUG_MESSAGE) do |debug, options|
      options[:debug] = debug
    end
    add_option('-g', '--spec', "Generate a static .gemspec file.") do |spec, options|
      options[:spec] = spec
    end
  end
  
  def summary
    GemThis::SUMMARY
  end
  
  def execute
    GemThis.new(options[:args].first || File.basename(Dir.pwd), options).create_rakefile
  end
end

Gem::CommandManager.instance.register_command :this
