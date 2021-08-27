class CreateMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :messages do |t|
      t.string :message
      t.string :expect
      t.string :output
      t.integer :result_id
    end
  end
end
