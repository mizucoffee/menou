require 'fileutils'
require 'pty'
require 'git'
require 'yaml'
require 'open3'
require 'faraday'
require 'faraday-cookie_jar'
require 'active_record'

class Menou
  def initialize(test_name)
    @results = {
      start: false
    }
    @path = 'repo'
    @test = YAML.load_file("tests/#{test_name}.yml")

    @client = Faraday.new 'http://localhost:4567' do |b|
      b.use :cookie_jar
      b.adapter Faraday.default_adapter
    end
  end

  def post_form(path, body)
    @client.post(path) do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = URI.encode_www_form body
    end
  end

  def git_clone
    Git.clone(repo_url, 'repo')
  end

  def clean_up
    FileUtils.rm_r('repo')
  end

  def set_callback(&cb)
    @callback = cb
  end

  def start
    prepare_env
    schema_test
    main_test
    kill
  end

  def prepare_env
    Bundler.with_original_env do
      prepare_tb = MenouTaskBlock.new "Preparing environment", @callback
      prepare_tb.task('Command: bundle install') { Open3.capture2e('bundle install', :chdir => @path) }
      prepare_tb.task('Command: rake db:drop') { Open3.capture2e('rake db:drop', :chdir => @path) }
      prepare_tb.task('Command: rake db:create') { Open3.capture2e('rake db:create', :chdir => @path) }
      prepare_tb.task('Command: rake db:migrate') { Open3.capture2e('rake db:migrate', :chdir => @path) }
      prepare_tb.task('Command: rake db:seed') { Open3.capture2e('rake db:seed', :chdir => @path) }

      prepare_tb.task('Connecting database') {
        # ActiveRecord::Base.establish_connection **YAML.load_file("#{@path}/config/database.yml")['default_env']
        ActiveRecord::Base.configurations = YAML.load_file("#{@path}/config/database.yml")
        require "./#{@path}/models"
      }

      prepare_tb.task('Running ruby') {
        stdout, stdin, @pid = PTY.spawn('RACK_ENV=development ruby app.rb -o 0.0.0.0', :chdir => @path)
        @results[:start] = stdout.any? { |l| l.include?("HTTPServer#start") } 
        Thread.start do stdout.each do end end
      }
    end
  end

  def kill
    Process.kill("KILL", @pid)
  end

  # ==========================================
  # Test
  # ==========================================

  def main_test
    test_tb = MenouTaskBlock.new "Test", @callback
    @test['tests'].each do |test|
      case test['type']
      when 'get'
        test_tb.task("GET #{test['path']} == #{test['expect']}") do |success, error|
          res = @client.get test['path']
          next error.call "Unexpected status code: #{res.status}" if res.status != test['expect']
        end
      when 'post'
        test_tb.task("POST #{test['path']} == #{test['expect']}") do |success, error|
          res = post_form test['path'], test['body']

          next error.call "Unexpected status code: #{res.status}" if res.status != test['expect']
        end
      when 'database'
        test_tb.task("Database #{test['table'].classify} #{test['where']}") do |success, error|
          result = test['table'].classify.constantize.find_by(test['where'])
          next success.call if test['expect'].nil? and result.nil?
          next error.call "Not found" if result.nil?

          test['expect'].each do |k, v|
            next error.call "Unexpected value: #{test['table'].classify}.#{k}=\"#{result[k]}\", expected: \"#{v}\"" if result[k].to_s != v.to_s
          end
        end
      end
    end
  end

  def schema_test
    @test['tables'].each do |table_name, schema|
      table_tb = MenouTaskBlock.new "Table: #{table_name}", @callback

      table_tb.task("Table exist") do |success, error|
        if !ActiveRecord::Base.connection.tables.include? table_name
          next error.call 'Table not found'
        end
      end

      columns = ActiveRecord::Base.connection.columns(table_name)

      schema.each do |col|
        table_tb.task("Schema: #{col['name']}") do |success, error|
          res = columns.find { |c| c.name == col['name'] }
          next error.call 'Schema does not exist' if res.nil?
          next error.call 'Invalid type' if col['type'] != res.type.to_s
          next error.call 'Invalid option(s)' if col['options'] and !col['options'].all? { |key, value| res.public_send(key).to_s == value.to_s }
        end
      end
    end
  end

end

class MenouTaskBlock
  @@count = 0
  def initialize(block_title, cb)
    @block_title = block_title
    @callback = cb
  end
  def new_task(task_title)
    return if !@callback
    task = MenouTask.new @@count, task_title, @block_title, @callback
    @@count += 1
    task
  end
  def task(task_title, &block)
    return if !@callback
    @@count += 1
    done = false
    task = MenouTask.new @@count, task_title, @block_title, @callback
    success = Proc.new do |message|
      task.success(message) if !done
      done = true
    end
    error = Proc.new do |message|
      task.error message if !done
      done = true
    end
    block.call success, error
    task.success if !done
  end
end

class MenouTask
  def initialize(id ,title, block_title, cb)
    @id = id
    @title = title
    @block_title = block_title
    @callback = cb
    @callback.call(@id, @title, @block_title, 0)
  end
  def success(*message)
    @callback.call(@id, @title, @block_title, 1, message[0])
  end
  def error(*message)
    @callback.call(@id, @title, @block_title, 2, message[0])
  end
end