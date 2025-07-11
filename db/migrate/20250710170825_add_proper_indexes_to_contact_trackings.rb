class AddProperIndexesToContactTrackings < ActiveRecord::Migration[5.1]
  def change
    # sender_idとstatusの複合インデックス（既に追加済み）
    add_index :contact_trackings, [:sender_id, :status]
    
    # sender_idとcustomer_idの複合インデックス（ユニーク制約なし）
    add_index :contact_trackings, [:sender_id, :customer_id]
    
    # 送信日時のインデックス
    add_index :contact_trackings, :sended_at
    
    # 送信開始時刻のインデックス
    add_index :contact_trackings, :sending_started_at
  end
end
