class CreateResults < ActiveRecord::Migration[6.1]
  def change
    create_table :results do |t|
      t.string :title
      t.boolean :success
      t.integer :result_group_id
    end
  end
end
