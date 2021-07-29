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
    @test = YAML.load_file("tests/#{test_name}.yml")

    @client = Faraday.new 'http://localhost:4567' do |b|
      b.use :cookie_jar
      b.adapter Faraday.default_adapter
    end
  end

  def result
    @results
  end

  def post_form(path, body)
    @client.post(path) do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form body
    end
  end

  def set_path(path)
    @path = path
  end

  def git_clone
    @path = Dir.mktmpdir
    Git.clone(repo_url, @path)
  end

  def clean_up
    FileUtils.rm_r(@path)
  end

  def set_callback(&cb)
    @callback = cb
  end

  def start
    prepare_env
    # schema_test
    main_test
    kill
  end

  def prepare_env
    Bundler.with_original_env do
      prepare_tb = MenouTaskBlock.new "環境準備", @callback
      prepare_tb.task('$ bundle install') { Open3.capture2e('bundle install', :chdir => @path) }
      prepare_tb.task('$ rake db:create') { Open3.capture2e('rake db:create', :chdir => @path) }
      prepare_tb.task('$ rake db:migrate:reset') { Open3.capture2e('rake db:migrate', :chdir => @path) }
      prepare_tb.task('$ rake db:seed') { Open3.capture2e('rake db:seed', :chdir => @path) }

      prepare_tb.task('DB接続') {
        ActiveRecord::Base.configurations = YAML.load_file("#{@path}/config/database.yml")
        require "#{@path}/models"
      }

      prepare_tb.task('Ruby起動') {
        stdout, stdin, @pid = PTY.spawn('RACK_ENV=development ruby app.rb -o 0.0.0.0', :chdir => @path)
        stdout.any? { |l| l.include?("HTTPServer#start") } 
        Thread.start do stdout.each do end end
      }
      @results.push prepare_tb.results
    end
  end

  def kill
    Process.kill("KILL", @pid)
  end

  # ==========================================
  # Test
  # ==========================================

  def main_test
    @test['tests'].each do |test|
      test_tb = MenouTaskBlock.new test['name'], @callback
      test['tasks'].each do |task|
        script = @@test_scripts[task['type']]
        next if script.nil?

        script.call task, test_tb, @path
      end

      @results.push test_tb.results
      
      # test['tasks'].each do |task|
      #   case task['type']
      #   when 'get'
      #     test_tb.task("GET #{task['path']}") do |success, error|
      #       query = (task['query'].nil?) ? "" : URI.encode_www_form(task['query'])
      #       res = @client.get task['path'] + "?" + query
      #       error.call "Unexpected status code: #{res.status}, expected: #{task['expect']}" if res.status != task['expect']
      #     end
      #   when 'post'
      #     test_tb.task("POST #{task['path']}") do |success, error|
      #       query = (task['query'].nil?) ? "" : URI.encode_www_form(task['query'])
      #       res = post_form task['path'] + "?" + query, task['body']
      #       error.call "Unexpected status code: #{res.status}, expected: #{task['expect']}" if res.status != task['expect']
      #     end
      #   when 'database'
      #     test_tb.task("Database #{task['table'].classify} where: #{task['where'].map {|k, v| "#{k}=\"#{v}\""}.join ', '}") do |success, error|
      #       table_class = task['table'].classify.constantize rescue nil
      #       next error.call "Table not found" if table_class.nil?

      #       result = table_class.find_by(task['where'])
      #       next success.call if task['expect'].nil? and result.nil?
      #       next error.call "Record not found" if result.nil?

      #       task['expect'].each do |k, v|
      #         error.call "Unexpected value: #{task['table'].classify}.#{k}=\"#{result[k]}\", expected: \"#{v}\"" if result[k].to_s != v.to_s
      #       end
      #     end
      #   when 'get_json_api'
      #     test_tb.task("GET #{task['path']} as JSON API") do |success, error|
      #       query = (task['query'].nil?) ? "" : URI.encode_www_form(task['query'])
      #       res = @client.get task['path'] + "?" + query
      #       json = JSON.parse(res.body) rescue nil
      #       next error.call "Invalid JSON" if json.nil?

      #       task['expect'].each do |k, v|
      #         error.call "Unexpected value: #{k}=\"#{json[k]}\", expected: \"#{v}\"" if v != json[k]
      #       end
      #     end
      #   end
      # end
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
    error = Proc.new do |message|
      errors.push message
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

# 何が期待しなかったものか = title
# 何だったら正しいのか Express
# 何が来たのか test
