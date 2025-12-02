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
  #has_many :customers, foreign_key: 'updated_by_worker_id', inverse_of: :updated_by_worker
  has_many :first_edited_customers, class_name: 'Customer', foreign_key: 'updated_by_worker_id'
  
    def self.import_customers(file)
      save_count = 0
      CSV.foreach(file.path, headers: true) do |row|
        # Crowdworksのtitleと一致するか確認
        crowdwork = ::Crowdworks.find_by(title: row["title"])
        next unless crowdwork
  
        # Customerへのデータ保存処理
        customer = Customer.find_by(id: row["id"]) || Customer.new
        customer.attributes = row.to_hash.slice(*Customer.updatable_attributes)
        if customer.valid?
          customer.save!
          save_count += 1
        end
      end
      save_count
    end

  def self.updatable_attributes
    # 更新可能な属性のリスト
    # 例: ["name", "email", "phone", ...]
  end

   # ここにメール送信ロジックを追加します
  def send_warning_email(subject, body)
    WorkerMailer.with(worker: self, subject: subject, body: body).warning_email.deliver_now
  end

def customers_updated(period: :week)
  range = case period
          when :day
            Time.current.beginning_of_day..Time.current.end_of_day
          when :week
            Time.current.beginning_of_week..Time.current.end_of_week
          when :month
            Time.current.beginning_of_month..Time.current.end_of_month
          else
            nil
          end

  return 0 unless range

  # updated_by_worker_id がセットされている初回更新のみ
  first_edited_customers.where(first_edited_at: range).count
end
end
