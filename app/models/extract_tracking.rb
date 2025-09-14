class ExtractTracking < ApplicationRecord
  # 現在までの処理件数（成功＋失敗）
  def processed_count
    success_count.to_i + failure_count.to_i
  end

  # 残件数（0未満にならない）
  def remaining_count
    [total_count.to_i - processed_count, 0].max
  end

  # 進捗用のシリアライズ
  def progress_payload
    extract_count = Customer
      .where(industry: industry)
      .where(status: ["ai_success", "ai_failed", "ai_extracting"])
      .group(:status)
      .count
    success_count_t = extract_count["ai_success"].to_i
    failure_count_t = extract_count["ai_failed"].to_i
    total_count_t   = success_count_t + failure_count_t + extract_count["ai_extracting"].to_i
    if extract_count["ai_extracting"].to_i > 0
      status_t = "抽出中"
    else
      status_t = "抽出完了"
    end

    {
      id: id,
      industry: industry,
      total: total_count_t,
      success: success_count_t,
      failure: failure_count_t,
      processed: processed_count,
      remaining: remaining_count,
      status: status_t,
      updated_at: updated_at
    }
  end
end
