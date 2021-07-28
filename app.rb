require 'bundler/setup'
Bundler.require

require './menou'
pastel = Pastel.new
spinners = {}
spins = {}

menou = Menou.new 'todo'
# menou.git_clone 'https://github.com/mizucoffee/todo_app'
menou.set_callback { |id ,title, type, status, message|
  if status == 0
    if spinners[type].nil?
      spinners[type] = TTY::Spinner::Multi.new("[#{pastel.yellow(":spinner")}] #{type}", success_mark: pastel.green("✔"), error_mark: pastel.red("✖"))
    end

    spins[id] = spinners[type].register "[#{pastel.yellow(":spinner")}] #{title}", format: :classic
    spins[id].auto_spin
  end
  mes = !message.nil? ? "(#{message})" : ""
  spins[id].success mes || "" if status == 1
  spins[id].error mes if status == 2
}
menou.start
