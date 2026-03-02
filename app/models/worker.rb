class Worker < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :contact_trackings
  has_many :assignments, dependent: :destroy
  has_many :tests, dependent: :destroy
  has_many :crowdworks, through: :assignments
  has_many :sender_assignments, dependent: :destroy
  has_many :senders, through: :sender_assignments

  has_many :first_edited_customers,
           class_name: 'Customer',
           foreign_key: 'updated_by_worker_id'

  # =============================
  # CSVインポート
  # =============================
  def self.import_customers(file)
    save_count = 0

    CSV.foreach(file.path, headers: true) do |row|
      crowdwork = ::Crowdworks.find_by(title: row['title'])
      next unless crowdwork

      customer = Customer.find_by(id: row['id']) || Customer.new
      customer.attributes = row.to_hash.slice(*Customer.updatable_attributes)

      if customer.valid?
        customer.save!
        save_count += 1
      end
    end

    save_count
  end

  def self.updatable_attributes
    # 更新可能な属性のリストを定義
    # 例: %w[name email phone]
  end

  # =============================
  # メール送信
  # =============================
  def send_warning_email(subject, body)
    WorkerMailer
      .with(worker: self, subject: subject, body: body)
      .warning_email
      .deliver_now
  end

  # =============================
  # 集計共通スコープ
  # =============================
  def base_customers
    first_edited_customers
      .where(status: [nil, 'draft'])
      .where.not(tel: [nil, ''])
  end

  # =============================
  # 登録数集計（初回のみ）
  # =============================
  def daily_number
    base_customers.where(
      created_at: Time.current.beginning_of_day..Time.current.end_of_day
    ).count
  end

  def weekly_number
    base_customers.where(
      created_at: Time.current.beginning_of_week..Time.current.end_of_week
    ).count
  end

  def monthly_number
    base_customers.where(
      created_at: Time.current.beginning_of_month..Time.current.end_of_month
    ).count
  end

  def last_month_number
    base_customers.where(
      created_at: Time.current.last_month.beginning_of_month..
                  Time.current.last_month.end_of_month
    ).count
  end

  def total_number
    base_customers.count
  end

  # =============================
  # 期間指定集計（既存ロジック整理）
  # =============================
  def customers_updated(period: :week)
    range =
      case period
      when :day
        Time.current.beginning_of_day..Time.current.end_of_day
      when :week
        Time.current.beginning_of_week..Time.current.end_of_week
      when :month
        Time.current.beginning_of_month..Time.current.end_of_month
      else
        return 0
      end

    first_edited_customers.where(created_at: range).count
  end
end