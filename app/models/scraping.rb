# app/models/scraping.rb
class Scraping < ApplicationRecord
    belongs_to :customer
  
    enum status: { waiting: 0, running: 1, done: 2, failed: 3 }
  
    validates :scraping_type, presence: true
  
    # ステータス更新用
    def mark_running!
      update(status: :running, started_at: Time.current)
    end
  
    def mark_done!(result_json = nil)
      update(status: :done, finished_at: Time.current, scraped_data: result_json)
    end
  
    def mark_failed!(error_message)
      update(status: :failed, finished_at: Time.current, log: error_message)
    end
  end
  