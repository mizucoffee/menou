require 'bundler/setup'
Bundler.require
require_relative 'lib/menou'
require 'sinatra/reloader' if development?
require 'securerandom'
require './models'

set :port, ENV['PORT'] || 8080
set :sockets, []

get '/' do
  erb :index
end

post '/analyze' do
  menou = Menou.new params[:type]
  menou.git_clone params[:repo]
  menou.set_path params[:path] unless params[:path].empty?
  menou.checkout_branch params[:branch] unless params[:branch].empty?

  report = Report.create

  menou.callback do |id ,title, type, status, messages|
    next unless status == 0
    settings.sockets.filter { |s|
      s[:id] == "#{report.id}"
    }.each { |s|
      s[:ws].send(title)
    }
  end

  Thread.start do 
    menou.start

    report.update(target: menou.test_name, repository: params[:repo])

    menou.result.each do |g|
      group = report.result_groups.create(title: g[:task_group_name])
      g[:result].each do |r|
        result = group.results.create(title: r[:task], success: r[:success])
        next if r[:messages].nil?
        r[:messages].each do |m|
          result.messages.create(message: m[:message], expect: m[:expect], result: m[:result])
        end
      end
    end

    menou.screenshots.each { |sc|
      uuid = SecureRandom.uuid
      File.binwrite("./public/screenshots/#{uuid}.png", sc[:image])
      report.screenshots.create(title: sc[:title], path: "/screenshots/#{uuid}.png")
    }

    settings.sockets.filter { |s|
      s[:id] == "#{report.id}"
    }.each { |s|
      s[:ws].send("Complated")
    }
  end
  redirect "/analyze/#{report.id}"
end

get '/analyze/:id' do
  @id = params[:id]
  r = Report.find_by(id: @id)
  next redirect '/' if r.nil?
  next redirect '/' if "#{r.id}" != @id
  next redirect "/report/#{@id}" unless r.target.nil?
  erb :analyze
end

get '/report/:id' do
  @report = Report.find_by(id: params[:id])
  next redirect '/' if @report.nil?
  next redirect '/' if "#{@report.id}" != params[:id]
  next redirect "/analyze/#{@id}" if @report.target.nil?
  erb :report
end

get '/ws/:id' do
  if request.websocket?
    request.websocket do |ws|
      ws.onopen do
        settings.sockets << { id: params[:id], ws: ws }
      end
      ws.onclose do
        settings.sockets.delete({ id: params[:id], ws: ws })
      end
    end
  end
end
