class CreateUploadData < ActiveRecord::Migration[5.1]
  def change
    create_table :upload_data do |t|
      t.string :name
      t.string :file
      t.references :company, foreign_key: true

      t.timestamps
    end
  end
end
