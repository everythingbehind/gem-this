require 'rubygems'
require 'shoulda'
require 'fileutils'
require 'tempfile'
require 'yaml'
require 'timeout'
require 'rake'

class GemBuilder
  attr_reader :gem_path

  def initialize(name, &block)
    @name = name
    @gem_path = temporary_gem_name
    FileUtils.mkdir_p(@gem_path)
    FileUtils.cd(@gem_path) do
      instance_eval &block
    end
  end

  def method_missing(name, *args)
    in_directory(name) do
      args.each { |f| file(f) }
      yield if block_given?
    end
  end

  def in_directory(name, &block)
    path = File.join(@gem_path, name.to_s)
    FileUtils.mkdir_p(path)
    FileUtils.cd(path, &block)
  end

  def file(name)
    FileUtils.touch(name)
  end

  def path_to_gem
    File.join(@gem_path, "pkg", @name + "-0.1.0.gem")
  end

  def build
    result = nil
    FileUtils.cd(@gem_path) do
      result = GemThis.new(@name, :debug => false, :silent => true).create_rakefile
      `rake package 2>&1`
    end
    result
  end

  private

  def temporary_gem_name
    t = Tempfile.new('gem-this')
    gem_name = t.path
    t.unlink
    File.join(gem_name, @name)
  end
end

class Test::Unit::TestCase
  def assert_gem_contains(*paths)
    paths.each do |path|
      assert gem_spec.files.include?(path), "gem should include #{path}"
    end
  end

  def assert_gem_spec(part, value, message = nil)
    assert_equal value, gem_spec.send(part), message
  end

  def assert_rake_task(task)
    tasks =  in_gem { `rake -T`.split("\n").map { |line| line.split[1] } }
    assert tasks.include?(task.to_s), tasks.inspect
  end

  def assert_default_rake_task_dependencies_contains(task)
    in_gem {
      assert prerequisites_for('default').include?(task.to_s), prerequisites_for('default').inspect
    }
  end

  def assert_doesnt_hang(duration=5, message=nil, &block)
    assert_nothing_raised("should return within #{duration} seconds") do
      Timeout::timeout(duration, &block)
    end
  end

  def in_gem(&block)
    result = nil
    FileUtils.cd(@gem.gem_path) do
      load 'RakeFile'
      result = block.call
    end
    result
  end

  def create_gem(name="test_gem", &block)
    @gem = GemBuilder.new(name, &block)
  end

  def build_gem(name="test_gem", &block)
    create_gem(name, &block).build
  end

  def gem_spec
    in_gem { YAML.load(`gem specification #{@gem.path_to_gem}`) }
  end

  private
  def find_task(task_name)
    @tasks ||= Rake.application.tasks
    @tasks.select{|task| task.name == task_name}[0]
  end

  def prerequisites_for(task_name)
    find_task(task_name).prerequisites
  end
end
