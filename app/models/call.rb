class Call < ApplicationRecord
  belongs_to :customer#, foreign_key: 'tel', class_name: 'Customer'
  belongs_to :admin, optional: true
  belongs_to :user, optional: true

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


  #call_import
    def  self.call_import(call_file)
      save_cnt = 0
      CSV.foreach(call_file.path, headers: true) do |row|
        call = Call.find_by(id: row["id"]) || new
        customer = Customer.find_by(tel: row["tel"])
        call.attributes = row.to_hash.slice(*call_attributes)
        call.customer_id = customer&.id
        #next if Call.where('created_at > ?', "1.month.ago.all_day")
        #next if Call.where(statu: "APP")
        call.save!
        save_cnt += 1
      end
      save_cnt
    end

    def self.call_attributes
      ["tel" ,"statu", "time", "comment", "created_at","updated_at"]
    end

  @@StatuItems = [
    "着信留守",
    "担当者不在",
    "フロントNG",
    "見込",
    "APP",
    "コロナ見込",
    "キャンセル",
    "クロージングNG",
    "根本的NG",
    "永久NG"
  ]
  def self.StatuItems
    @@StatuItems
  end

  def call_count_today
    Call
      .where.not(admin_id: 1)
      .where('created_at > ?', Time.current.beginning_of_day)
      .where('created_at < ?', Time.current.end_of_day).count
  end

  def protect_count_today #本日獲得見込数
    Call
      .where.not(admin_id: 1)
      .where(statu: "見込")
      .where('created_at > ?', Time.current.beginning_of_day)
      .where('created_at < ?', Time.current.end_of_day)
      .count
  end

  def protect_convertion
    (self.protect_count_today.to_f / self.call_count_today.to_f) * 100
  end

  def app_count_today
    Call
      .where.not(admin_id: 1)
      .where(statu: "APP")
      .where('created_at > ?', Time.current.beginning_of_day)
      .where('created_at < ?', Time.current.end_of_day)
      .count
  end

  def app_convertion
    (self.app_count_today.to_f / self.call_count_today.to_f) * 100
  end

  def date_count
    Call.where.not(admin_id: 1).group("DATE_FORMAT(created_at, '%Y-%m-%d')").count
  end

  def week_count
    Call.where.not(admin_id: 1).group("WEEK(created_at)").count
  end

  def month_count
    Call.where.not(admin_id: 1).group("MONTH(created_at)").count
  end

  def user_time_count #時間単位のカウント
    Call.where.not(admin_id: 1).where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
  end

  #def user_app
  #  U
  #end


end
