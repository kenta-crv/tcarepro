class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :calls
  has_many :attendances

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
end
