class Call < ApplicationRecord
  belongs_to :customer

  scope :joins_last_call, -> {
    last_created_at = "SELECT sub_call.customer_id, MAX(sub_call.created_at) as last_created_at FROM calls as sub_call GROUP BY sub_call.customer_id";
    joins(
      "INNER JOIN (#{last_created_at}) AS sub ON sub.customer_id = calls.customer_id AND sub.last_created_at = calls.created_at"
    ).group(:post_id)
  }

  @@StatuItems = [
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
    "士業知人",
    "他社導入済"
  ]
  def self.StatuItems
    @@StatuItems
  end

  def count
    @call = Call.all.count(params[:id])
  end
end
