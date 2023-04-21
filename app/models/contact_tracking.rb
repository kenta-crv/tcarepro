class ContactTracking < ApplicationRecord
  belongs_to :sender
  belongs_to :customer
  belongs_to :inquiry
  belongs_to :worker, optional: true

  validates :code, uniqueness: true, presence: true
  validates :status, presence: true, inclusion: { in: %w(自動送信送信済 自動送信不可 送信済 送信不可  営業NG 自動送信予定 自動送信エラー メールAPP 送信NG) }

  scope :latest, ->(sender_id){
    where(id: ContactTracking.select('max(id) as id').where(sender_id: sender_id).group(:customer_id))
  }

  scope :before_sended_at, ->(sended_at){
    where("sended_at <= ?", sended_at).where.not(sended_at: nil)
  }

  def success?
    status == '送信済'
  end
end
