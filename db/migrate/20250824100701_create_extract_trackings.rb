class CreateExtractTrackings < ActiveRecord::Migration[5.1]
  def change
    create_table :extract_trackings do |t|
      t.string  :industry,       null: false
      t.integer :total_count,    default: 0, null: false
      t.integer :success_count,  default: 0, null: false
      t.integer :failure_count,  default: 0, null: false
      t.string  :status,         null: false

      t.timestamps
    end
  end
end
