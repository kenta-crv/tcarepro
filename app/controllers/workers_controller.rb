class WorkersController < ApplicationController
  def show
    @worker = Worker.find(params[:id])

    # 基本スコープ
    base_scope = @worker.first_edited_customers
                        .where(status: [nil, 'draft'])
                        .where.not(tel: [nil, ''])

    now = Time.current

    # 日別・週別・月別・先月の件数
    @daily_number = base_scope.where(created_at: now.beginning_of_day..now.end_of_day).count
    @weekly_number = base_scope.where(created_at: now.beginning_of_week..now.end_of_week).count
    @monthly_number = base_scope.where(created_at: now.beginning_of_month..now.end_of_month).count
    @last_month_number = base_scope.where(
      created_at: now.last_month.beginning_of_month..now.last_month.end_of_month
    ).count

    # 累計
    @total_number = base_scope.count
    @total_count = @total_number + @worker.deleted_customer_count

    # ビュー用変数を統一
    @count_day = @daily_number
    @count_week = @weekly_number
    @count_month = @monthly_number
    @count_before_month = @last_month_number

    # Crowdworks → 配列としてビューに渡す
    @assigned_crowdworks = @worker.crowdworks.to_a

    # Contact Trackings
    @contact_trackings_day = @worker.contact_trackings.where(created_at: now.beginning_of_day..now.end_of_day)
    @contact_trackings_week = @worker.contact_trackings.where(created_at: now.beginning_of_week..now.end_of_week)
    @contact_trackings_month = @worker.contact_trackings.where(created_at: now.beginning_of_month..now.end_of_month)
    @contact_trackings_before_month = @worker.contact_trackings.where(
      created_at: now.last_month.beginning_of_month..now.last_month.end_of_month
    )

    @send_success_count_day = @contact_trackings_day.where(status: '送信済').count
    @send_success_count_week = @contact_trackings_week.where(status: '送信済').count
    @send_success_count_month = @contact_trackings_month.where(status: '送信済').count
    @send_success_count_before_month = @contact_trackings_before_month.where(status: '送信済').count

    @send_error_count_month = @contact_trackings_month.where(status: '送信不可').count
    @send_ng_count_month = @contact_trackings_month.where(status: '営業NG').count

    @send_count_month =
      @send_success_count_month +
      @send_error_count_month +
      @send_ng_count_month

    @send_rate =
      if @send_count_month.positive?
        (@send_success_count_month.to_f / @send_count_month) * 100
      else
        0
      end

    @send_count_day = @contact_trackings_day.count
    @send_count_week = @contact_trackings_week.count

    @assigned_senders = @worker.senders
  end


  def upload
    @worker = Worker.find(params[:id])

    if params[:file].present?
      session[:upload_results] = process_uploaded_file(params[:file])
    else
      session[:upload_results] = nil
    end

    redirect_to confirm_worker_path(@worker)
  end

  def destroy
    @worker = Worker.find(params[:id])

    @worker.first_edited_customers.update_all(updated_by_worker_id: nil)
    @worker.contact_trackings.update_all(worker_id: nil)

    if @worker.destroy
      redirect_to admin_path(current_admin), notice: 'ワーカーを削除しました'
    else
      redirect_to admin_path(current_admin), alert: 'ワーカーの削除に失敗しました'
    end
  end

  def confirm
    @worker = Worker.find(params[:id])
    @upload_results = session[:upload_results] || '結果がありません'
    session.delete(:upload_results)
  end

  def next
    @worker = Worker.find_by(id: params[:id])
  end

  private

  def process_uploaded_file(uploaded_file)
    file_path = Rails.root.join('tmp', uploaded_file.original_filename)

    File.open(file_path, 'wb') do |file|
      file.write(uploaded_file.read)
    end

    count = 0
    CSV.foreach(file_path, headers: true) do |_row|
      count += 1
    end

    File.delete(file_path)
    count
  end
end