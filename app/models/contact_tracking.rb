class ContactTracking < ApplicationRecord
  belongs_to :sender
  belongs_to :customer
  belongs_to :inquiry
  belongs_to :worker, optional: true  # ← optional: true を維持

  validates :code, uniqueness: true, presence: true
  validates :status, presence: true, inclusion: { 
    in: %w(自動送信送信済 自動送信不可 送信済 送信不可 営業NG 自動送信予定 自動送信エラー メールAPP 送信NG 送信中 処理中) 
  } 
  # sender_idによる適切な分離
  scope :for_sender, ->(sender_id) { where(sender_id: sender_id) }
  
  # 重複防止のユニーク制約
  validates :customer_id, uniqueness: { scope: :sender_id }
  
  scope :latest, ->(sender_id){
    where(id: ContactTracking.select('max(id) as id').where(sender_id: sender_id).group(:customer_id))
  }

  scope :before_sended_at, ->(sended_at){
    where("sended_at <= ?", sended_at).where.not(sended_at: nil)
  }

  def self.search_for_sender(sender_id, params = {})
    base_scope = for_sender(sender_id)
    base_scope = base_scope.where(status: params[:status]) if params[:status].present?
    base_scope = base_scope.where('created_at >= ?', params[:date_from]) if params[:date_from].present?
    base_scope
  end
  
  # sender毎の検索機能
  def success?
    status == '送信済'
  end
end

