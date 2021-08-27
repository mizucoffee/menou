require 'bundler/setup'
Bundler.require

ActiveRecord::Base.establish_connection

class Report < ActiveRecord::Base
  has_many :result_groups
  has_many :screenshots
end

class ResultGroup < ActiveRecord::Base
  belongs_to :report
  has_many :results
end

class Result < ActiveRecord::Base
  belongs_to :result_group
  has_many :messages
end

class Message < ActiveRecord::Base
  belongs_to :result
end

class Screenshot < ActiveRecord::Base
  belongs_to :report
end
    