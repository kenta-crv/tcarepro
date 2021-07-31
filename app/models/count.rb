class Count < ApplicationRecord
  belongs_to :customer#, foreign_key: :tel, primary_key: :tel
  belongs_to :admin, optional: true
  belongs_to :sender, optional: true

  scope :times_last_count, -> {
    last_time = "SELECT sub_count.customer_id, MAX(sub_count.time) as last_time FROM counts as sub_count GROUP BY sub_count.customer_id";
    joins(
      "INNER JOIN (#{last_time}) AS sub ON sub.customer_id = counts.customer_id AND sub.last_time = counts.time"
    ).group(:customer_id)
  }

  scope :joins_last_count, -> {
    last_created_at = "SELECT sub_count.customer_id, MAX(sub_count.created_at) as last_created_at FROM counts as sub_count GROUP BY sub_count.customer_id";
    joins(
      "INNER JOIN (#{last_created_at}) AS sub ON sub.customer_id = counts.customer_id AND sub.last_created_at = counts.created_at"
    ).group(:customer_id)
  }


  @@StatuItems = [
    "送信成功",
    "送信エラー",
    "HP無し",
    "フォーム不明",
    "送信停止",
    "APP"
  ]
  def self.StatuItems
    @@StatuItems
  end


end
