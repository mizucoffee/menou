require 'fileutils'
require 'pty'
require 'git'
require 'yaml'
require 'open3'
require 'faraday'
require 'active_record'

class Menou
  def initialize(test_name)
    @results = {
      start: false
    }
    @path = 'repo'
    @test = YAML.load_file("tests/#{test_name}.yml")
  end

  def git_clone
    Git.clone(repo_url, 'repo')
  end

  def clean_up
    FileUtils.rm_r('repo')
  end

  # title, type= 0=doing, 1=done, 2=failed
  def set_callback(&cb)
    @callback = cb
  end

  def start
    prepare_env
    startup
    routes_test
    schema_test
    kill
  end

  def prepare_env
    Bundler.with_original_env do
      prepare_command('bundle install')
      prepare_command('rake db:drop')
      prepare_command('rake db:create')
      prepare_command('rake db:migrate')
    end
  end

  def prepare_command(command)
    @callback.call(command, 'Preparing environment', 0) if !@callback.nil?
    Open3.capture2e(command, :chdir => @path)
    @callback.call(command, 'Preparing environment', 1) if !@callback.nil?
  end

  def startup
    Bundler.with_original_env do
      @callback.call('Running ruby...', 'Preparing environment', 0) if !@callback.nil?
      stdout, stdin, pid = PTY.spawn('ruby app.rb -o 0.0.0.0', :chdir => @path)
      @pid = pid
      @results[:start] = stdout.any? { |l| l.include?("HTTPServer#start") } 
      Thread.start {
        stdout.each do |t|
          # puts t
        end
      }
      @callback.call('Running ruby...', 'Preparing environment', 1) if !@callback.nil?
    end
  end

  def kill
    Process.kill("KILL", @pid)
  end

  # ==========================================
  # Test
  # ==========================================

  def routes_test
    @test['tests'].each do |test|
      route_test 'get', test['path'], test['expect'] if test['type'] == 'get'
    end
  end

  def route_test(method, route, expect)
    u_method = method.upcase
    @callback.call("#{u_method} #{route}", "Routing test: #{u_method}", 0) if !@callback.nil?
    
    response = case u_method
    when 'GET'
      Faraday.get "http://localhost:4567#{route}"
    when 'POST'
      Faraday.post "http://localhost:4567#{route}"
    end
    @callback.call("#{u_method} #{route}", "Routing test: #{u_method}", response.status == expect ? 1 : 2) if !@callback.nil?
  end

  def schema_test
    ActiveRecord::Base.establish_connection **YAML.load_file("#{@path}/config/database.yml")['default_env']

    @test['tables'].each do |table_name, schema|
      @callback.call("Does the table exist?", "Table: #{table_name}", 0) if !@callback.nil?
      next @callback.call("Table: #{table_name}", "Table: #{table_name}", 2) if !ActiveRecord::Base.connection.tables.include? table_name and !@callback.nil?

      columns = ActiveRecord::Base.connection.columns(table_name)

      schema.each do |col|
        @callback.call("Schema: #{col['name']}", "Table: #{table_name}", 0) if !@callback.nil?
        res = columns.find { |c| c.name == col['name'] }
        next @callback.call("Schema: #{col['name']}", "Table: #{table_name}", 2) if res.nil? && !@callback.nil? # 存在しない
        next @callback.call("Schema: #{col['name']}", "Table: #{table_name}", 2) if col['type'] != res.type.to_s && !@callback.nil? # 型が違う
        next @callback.call("Schema: #{col['name']}", "Table: #{table_name}", 2) if col['options'] && !col['options'].all? { |key, value| res.public_send(key).to_s == value.to_s } and !@callback.nil? # オプションが違う
        @callback.call("Schema: #{col['name']}", "Table: #{table_name}", 1) if !@callback.nil?
      end

      @callback.call("Does the table exist?", "Table: #{table_name}", 1) if !@callback.nil?
    end
  end
end
