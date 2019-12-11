class CreateAcquisitions < ActiveRecord::Migration[5.1]
  def change
    create_table :acquisitions do |t|
      t.references :crm, foreign_key: true
      t.string :company #会社名
      t.string :day #獲得日
      t.string :name #獲得者
      t.string :statu #ステータス
      t.timestamps
    end
  end
end
