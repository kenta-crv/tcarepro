class Worker < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :customers
  has_many :contact_trackings
  has_many :lists
  has_many :writers
  has_many :assignments
  has_many :crowdworks, through: :assignments

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
end
