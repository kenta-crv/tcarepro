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
    {
      id: id,
      industry: industry,
      total: total_count.to_i,
      success: success_count.to_i,
      failure: failure_count.to_i,
      processed: processed_count,
      remaining: remaining_count,
      status: status,
      updated_at: updated_at
    }
  end
end
