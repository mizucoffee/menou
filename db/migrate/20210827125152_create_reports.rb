class CreateReports < ActiveRecord::Migration[6.1]
  def change
    create_table :reports do |t|
      t.string :name
      t.string :target
      t.string :repository
      t.timestamps null: false
    end
  end
end
