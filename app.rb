require 'bundler/setup'
Bundler.require
require_relative 'lib/menou'
require 'sinatra/reloader' if development?

set :port, 8080

pastel = Pastel.new
spinners = {}
spins = {}

# menou = Menou.new 'express'
# # menou.path File.expand_path('./repob', File.dirname(__FILE__))
# menou.git_clone 'https://github.com/yuipi7272/school-06'
# menou.callback { |id ,title, type, status, messages|
#   if status == 0
#     if spinners[type].nil?
#       spinners[type] = TTY::Spinner::Multi.new("[#{pastel.yellow(":spinner")}] #{type}", success_mark: pastel.green("✔"), error_mark: pastel.red("✖"))
#     end

#     spins[id] = spinners[type].register "[#{pastel.yellow(":spinner")}] #{title}", format: :classic
#     spins[id].auto_spin
#   end
#   mes = (messages.nil? or messages.empty?) ? "" : "(#{messages.join ', '})"
#   spins[id].success mes if status == 1
#   spins[id].error mes if status == 2
# } unless ARGV[0] == "q"
# menou.start

get '/' do
  erb :index
end

post '/test' do
  menou = Menou.new params[:type]
  menou.git_clone params[:repo]
  menou.set_path params[:path] if params[:path]
  menou.set_branch params[:branch] if params[:branch]
  menou.callback do |id ,title, type, status, messages|

  end
  menou.start

  @result = {}
  @result[:screenshots] = menou.screenshots
  @result[:results] = menou.result
  @result[:results].map!{ |r|
    r[:failed] = r[:result].filter { |result| !result[:success] }
    r[:score] = r[:result].size - r[:failed].size
    r
  }
  @result[:score] = @result[:results].inject(0) { |a, b| a + b[:score] }

  erb :result
end

get '/status' do
  
end

get '/result' do
  
end

# use Faye::RackAdapter, :mount => '/status', :timeout => 25


# # App.add_websocket_extension(PermessageDeflate)

# def App.log(message)
# end

# App.on(:subscribe) do |client_id, channel|
#   puts "[  SUBSCRIBE] #{ client_id } -> #{ channel }"
# end

# App.on(:unsubscribe) do |client_id, channel|
#   puts "[UNSUBSCRIBE] #{ client_id } -> #{ channel }"
# end

# App.on(:disconnect) do |client_id|
#   puts "[ DISCONNECT] #{ client_id }"
# end