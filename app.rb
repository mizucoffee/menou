require 'bundler/setup'
Bundler.require
require_relative 'lib/menou'
require 'sinatra/reloader' if development?

set :port, 8080

get '/' do
  erb :index
end

post '/test' do
  menou = Menou.new params[:type]
  menou.git_clone params[:repo]
  menou.set_path params[:path] unless params[:path].empty?
  menou.checkout_branch params[:branch] unless params[:branch].empty?
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
  @result[:test_name] = menou.test_name
  @result[:repo] = params[:repo]

  erb :result
end
