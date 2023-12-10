class Writer < ApplicationRecord
  belongs_to :worker

  # このメソッドは、特定の期間で非空のtitle_列の数をカウントします
  def self.count_non_empty_titles_for_period(start_date, end_date)
    where(created_at: start_date..end_date).select(
      'SUM(CASE WHEN title_1 IS NOT NULL AND title_1 != "" THEN 1 ELSE 0 END) +
       SUM(CASE WHEN title_2 IS NOT NULL AND title_2 != "" THEN 1 ELSE 0 END) +
       SUM(CASE WHEN title_3 IS NOT NULL AND title_3 != "" THEN 1 ELSE 0 END) +
       SUM(CASE WHEN title_4 IS NOT NULL AND title_4 != "" THEN 1 ELSE 0 END) +
       SUM(CASE WHEN title_5 IS NOT NULL AND title_5 != "" THEN 1 ELSE 0 END) +
       SUM(CASE WHEN title_6 IS NOT NULL AND title_6 != "" THEN 1 ELSE 0 END) +
       SUM(CASE WHEN title_7 IS NOT NULL AND title_7 != "" THEN 1 ELSE 0 END) +
       SUM(CASE WHEN title_8 IS NOT NULL AND title_8 != "" THEN 1 ELSE 0 END) +
       SUM(CASE WHEN title_9 IS NOT NULL AND title_9 != "" THEN 1 ELSE 0 END) +
       SUM(CASE WHEN title_10 IS NOT NULL AND title_10 != "" THEN 1 ELSE 0 END) AS total_titles'
    ).take.total_titles
  end
end
