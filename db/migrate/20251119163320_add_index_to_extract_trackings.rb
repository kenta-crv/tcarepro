class AddIndexToExtractTrackings < ActiveRecord::Migration[5.1]
  def change
    # industryとidの複合インデックスを追加（最新のtrackingを取得するクエリを高速化）
    add_index :extract_trackings, [:industry, :id], order: { id: :desc }
    # industryのみのインデックスも追加（where句の高速化）
    add_index :extract_trackings, :industry
  end
end
