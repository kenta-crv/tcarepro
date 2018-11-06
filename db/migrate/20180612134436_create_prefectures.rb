class CreatePrefectures < ActiveRecord::Migration[5.1]
  def change
    create_table :prefectures do |t|
    t.string :labor #労働局名　
    t.string :method #最低賃金額

      t.timestamps
    end
  end
end
