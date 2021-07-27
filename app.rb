require 'bundler/setup'
Bundler.require

require './menou'
pastel = Pastel.new
spinners = {}
spins = {}

menou = Menou.new 'todo'
# menou.git_clone 'https://github.com/mizucoffee/todo_app'
menou.set_callback { |title, type, status|
  if status == 0
    if spinners[type].nil?
      spinners[type] = TTY::Spinner::Multi.new("[#{pastel.yellow(":spinner")}] #{type}", success_mark: pastel.green("✔"), error_mark: pastel.red("✖"))
    end

    spins[title] = spinners[type].register "[#{pastel.yellow(":spinner")}] #{title}", format: :classic
    spins[title].auto_spin
  end
  spins[title].success if status == 1
  spins[title].error if status == 2
}
menou.start
