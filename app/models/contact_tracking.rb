class ContactTracking < ApplicationRecord
  belongs_to :sender
  belongs_to :customer
  belongs_to :worker, optional: true
  belongs_to :inquiry

  # sender_idによる適切な分離
  scope :for_sender, ->(sender_id) { where(sender_id: sender_id) }

  # 重複防止のユニーク制約
  validates :customer_id, uniqueness: { scope: :sender_id }
  validates :code, uniqueness: { scope: :sender_id }, presence: true
  validates :status, presence: true, inclusion: { 
    in: %w[
      自動送信送信済 自動送信不可 送信済 送信不可 営業NG 自動送信予定 
      自動送信エラー メールAPP 送信NG 送信中 処理中 
      CAPTCHA\ detected\ -\ requires\ manual\ intervention
      Form\ data\ missing No\ mappable\ form\ found\ by\ parser\ on\ url
      一時停止 送信失敗:\ no_success_indication 送信失敗:\ submission_failed
      送信成功 自動送信システムエラー 自動送信エラー(データ無) 
      自動送信システムエラー(Py無) 自動送信エラー(タイムアウト)
      自動送信システムエラー(ワーカー例外) 自動送信エラー(スクリプト未更新)
      自動送信システムエラー(スクリプト失敗)
    ]
  }
  validates :sender_id, presence: true

  # 最新の送信履歴
  scope :latest, ->(sender_id) {
    where(id: for_sender(sender_id).select('max(id) as id').group(:customer_id))
  }

  # 送信日時による絞り込み
  scope :before_sended_at, ->(sended_at) {
    where("sended_at <= ?", sended_at).where.not(sended_at: nil)
  }

  # Ransackセキュリティ: 検索可能な属性を明示的に許可
  def self.ransackable_attributes(auth_object = nil)
    %w[
      id status created_at updated_at sended_at callbacked_at
      scheduled_date sending_started_at sending_completed_at
      contact_url code auto_job_code response_data
      customer_id worker_id inquiry_id sender_id
    ]
  end

  # 検索可能な関連を制限
  def self.ransackable_associations(auth_object = nil)
    %w[customer worker inquiry sender]
  end

  # 送信成功判定
  def success?
    status == '送信済' || status == '送信成功'
  end

  # 送信処理中判定
  def processing?
    status == '処理中' || status == '送信中'
  end

  # エラー状態判定
  def error?
    status.include?('エラー') || status.include?('失敗') || status.include?('NG')
  end

  # 送信完了判定
  def completed?
    sending_completed_at.present?
  end

  # 送信処理時間
  def processing_duration
    return nil unless sending_started_at.present? && sending_completed_at.present?
    sending_completed_at - sending_started_at
  end

  # 送信処理が異常に短いかチェック
  def abnormal_processing?
    return false unless completed?
    processing_duration.present? && processing_duration < 1.0
  end

  # sender毎の安全な検索
  def self.search_for_sender(sender_id, params = {})
    base_scope = for_sender(sender_id)
    
    # 追加の検索条件
    base_scope = base_scope.where(status: params[:status]) if params[:status].present?
    base_scope = base_scope.where('created_at >= ?', params[:date_from]) if params[:date_from].present?
    base_scope = base_scope.where('created_at <= ?', params[:date_to]) if params[:date_to].present?
    base_scope = base_scope.where('sended_at >= ?', params[:sended_from]) if params[:sended_from].present?
    base_scope = base_scope.where('sended_at <= ?', params[:sended_to]) if params[:sended_to].present?
    
    base_scope
  end

  # 処理中で停止したレコードの検出
  def self.stuck_processing_records
    where(status: '処理中')
      .where('sending_started_at < ?', 1.hour.ago)
      .where.not(sending_completed_at: nil)
  end

  # 異常に短い処理時間のレコードの検出
  def self.abnormal_processing_records
    where(status: '処理中')
      .where.not(sending_completed_at: nil)
      .where('(sending_completed_at - sending_started_at) < 1')
  end

  # 送信完了済みだが状態未更新のレコード
  def self.completed_but_not_updated_records
    where(status: '処理中')
      .where.not(sending_completed_at: nil)
      .where('(sending_completed_at - sending_started_at) >= 1')
  end

  # 自動修正メソッド
  def self.auto_fix_stuck_records
    # 完了済みだが状態未更新のレコードを修正
    completed_but_not_updated_records.find_each do |record|
      record.update!(
        status: '送信済',
        sended_at: record.sending_completed_at,
        updated_at: Time.current
      )
    end

    # 異常に短い処理時間のレコードをエラー状態に
    abnormal_processing_records.update_all(
      status: '自動送信エラー',
      updated_at: Time.current
    )
  end
  
  # 特定ステータスでの検索（sender_id制限付き）
  scope :with_status_for_sender, ->(sender_id, status) {
    for_sender(sender_id).where(status: status)
  }

  # 送信済み顧客の取得（sender_id制限付き）
  scope :sent_customers_for_sender, ->(sender_id) {
    for_sender(sender_id).where(status: '送信済').select(:customer_id)
  }

  # 未送信顧客の取得（sender_id制限付き）
  scope :unsent_customers_for_sender, ->(sender_id, all_customer_ids) {
    contacted_ids = for_sender(sender_id).select(:customer_id)
    all_customer_ids - contacted_ids
  }
end
