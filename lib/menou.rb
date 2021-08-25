require 'pty'
require 'git'
require 'open3'
require 'faraday'
require 'faraday-cookie_jar'
require 'active_record'
require 'selenium-webdriver'

class Menou
  @@test_scripts = {}

  def self.add_test_scripts(test_name, test)
    @@test_scripts[test_name] = test
  end

  def initialize(test_name)
    @results = []
    @branch = 'master'
    @test = YAML.load_file("tests/#{test_name}.yml")
  end

  def result
    @results
  end

  def path(path)
    @path = path
  end

  def set_path(path)
    @path = "#{@path}/#{path}"
  end

  def set_branch(branch)
    @branch = branch
  end

  def git_clone(repo_url)
    @path = Dir.mktmpdir
    g = Git.clone(repo_url, @path)
    g.branch(@branch).checkout
  end

  def clean_up
    FileUtils.rm_r(@path)
  end

  def callback(&cb)
    @callback = cb
  end

  def start
    prepare_env
    main_test
    kill
  end

  def prepare_env
    Bundler.with_original_env do
      prepare_tb = MenouTaskBlock.new "環境準備", @callback
      FileUtils.rm_f("#{@path}/Gemfile.lock")
      prepare_tb.task('$ bundle install') { Open3.capture2e('bundle install', :chdir => @path) }
      prepare_tb.task('$ rake db:create') { Open3.capture2e('rake db:create', :chdir => @path) }
      prepare_tb.task('$ rake db:migrate:reset') { Open3.capture2e('rake db:migrate:reset', :chdir => @path) }
      prepare_tb.task('$ rake db:seed') { Open3.capture2e('rake db:seed', :chdir => @path) }

      prepare_tb.task('DB接続') {
        next unless Dir["#{@path}/config/database.yml"].any?
        ActiveRecord::Base.configurations = YAML.load_file("#{@path}/config/database.yml")
        require "#{@path}/models"
      }

      prepare_tb.task('Ruby起動') {
        stdout, stdin, @pid = PTY.spawn('RACK_ENV=development ruby app.rb -o 0.0.0.0 -p 4567', :chdir => @path)
        stdout.any? { |l|
          l.include?("HTTPServer#start")
        }
        Thread.start do stdout.each do end end
      }
      @results.push prepare_tb.results
    end
  end

  def kill
    Process.kill("KILL", @pid)
  end

  def main_test
    @test['tests'].each do |test|
      test_tb = MenouTaskBlock.new test['name'], @callback
      test['tasks'].each do |task|
        script = @@test_scripts[task['type']]
        next if script.nil?
        script.call task, test_tb, @path
      end

      @results.push test_tb.results
    end
  end
end

class MenouTaskBlock
  @@count = 0
  def initialize(block_title, cb)
    @block_title = block_title
    @callback = cb
    @tasks = []
  end
  def new_task(task_title)
    @@count += 1
    @tasks.push MenouTask.new @@count, task_title, @block_title, @callback
  end
  def task(task_title, &block)
    @@count += 1
    errors = []
    done = false
    task = MenouTask.new @@count, task_title, @block_title, @callback
    @tasks.push task
    error = Proc.new do |message, result, expect|
      errors.push({ message: message, result: result, expect: expect })
    end
    block.call error

    return if done
    return task.error errors if errors.length > 0
    task.success
  end
  def results
    {
      task_group_name: @block_title,
      result: @tasks.map { |task| task.result }
    }
  end
end

class MenouTask
  def initialize(id ,title, block_title, cb)
    @id = id
    @title = title
    @block_title = block_title
    @callback = cb
    @success = false

    @callback.call(@id, @title, @block_title, 0) if !@callback.nil?
  end
  def success
    @success = true
    @callback.call(@id, @title, @block_title, 1) if !@callback.nil?
  end
  def error(messages)
    @success = false
    @messages = messages
    return @callback.call(@id, @title, @block_title, 2, messages) if messages.nil? and messages.instance_of?(Array) and !@callback.nil?
    @callback.call(@id, @title, @block_title, 2, [messages]) if !@callback.nil?
  end
  def result
    {
      task: @title,
      success: @success,
      messages: @messages
    }
  end
end

def register_test(test_name, &test)
  Menou.add_test_scripts test_name, test
end

Dir[File.expand_path('../tests', __FILE__) << '/*.rb'].each do |file|
  require file
end
