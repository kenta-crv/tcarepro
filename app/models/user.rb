class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :calls

  def calls_in_period(start_date, end_date)
    calls.where('created_at > ?', start_date).where('created_at < ?', end_date)
  end
  
  def calls_count_in_period(start_date, end_date)
    calls.where('created_at >= ?', start_date).where('created_at <= ?', end_date).count
  end

  def count_calls_by_status(status, start_date, end_date)
    calls_in_period(start_date, end_date).where(statu: status).count
  end

  def percentage_of_calls_by_status(status, start_date, end_date)
    total_calls = calls_in_period(start_date, end_date).count
    return 0 if total_calls.zero?

    (count_calls_by_status(status, start_date, end_date).to_f / total_calls * 100).round(1)
  end
  # =================================================================
  # 【緊急修正】
  # interview_request_text が private method エラーを起こすため、
  # 一時的にオーバーライドして public 化し、画面クラッシュを回避します。
  # 本来の定義場所が判明次第、適切な修正に置き換えてください。
  # =================================================================
  def interview_request_text
    # 一旦空文字、または安全なデフォルト値を返します
    "（システムにより自動生成されたプレースホルダー）"
  end
end
