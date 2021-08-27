class CreateScreenshots < ActiveRecord::Migration[6.1]
  def change
    create_table :screenshots do |t|
      t.string :title
      t.string :path
      t.integer :report_id
    end
  end
end
