class Call < ApplicationRecord
  belongs_to :customer
  belongs_to :admin
  scope :times_last_call, -> {
    last_time = "SELECT sub_call.customer_id, MAX(sub_call.time) as last_time FROM calls as sub_call GROUP BY sub_call.customer_id";
    joins(
      "INNER JOIN (#{last_time}) AS sub ON sub.customer_id = calls.customer_id AND sub.last_time = calls.time"
    ).group(:customer_id)
  }

  scope :joins_last_call, -> {
    last_created_at = "SELECT sub_call.customer_id, MAX(sub_call.created_at) as last_created_at FROM calls as sub_call GROUP BY sub_call.customer_id";
    joins(
      "INNER JOIN (#{last_created_at}) AS sub ON sub.customer_id = calls.customer_id AND sub.last_created_at = calls.created_at"
    ).group(:customer_id)
  }

  @@StatuItems = [
    "",
    "着信のみ",
    "オーナー不在",
    "再コール",
    "見込み客",
    "FAX APP",
    "Mail APP",
    "APP",
    "フロントNG",
    "クロージングNG",
    "従業員なしNG",
    "入社年月日NG",
    "永久NG",
    "他社導入済"
  ]
  def self.StatuItems
    @@StatuItems
  end

  def count
    @call = Call.all.count(params[:id])
  end
end
