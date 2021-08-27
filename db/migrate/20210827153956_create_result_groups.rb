class CreateResultGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :result_groups do |t|
      t.string :title
      t.integer :report_id
    end
  end
end
