class WorkersController < ApplicationController
def show
  @worker = Worker.find(params[:id])
  @customers = @worker.first_edited_customers

  @registrations = @customers
                     .where.not(tel: nil)
                     .where("customers.status IS NULL OR customers.status = ?", "draft")

  current = Time.zone.now

  @daily_number =
    @registrations.where(created_at: current.beginning_of_day..current.end_of_day).count

  @weekly_number =
    @registrations.where(created_at: current.beginning_of_week..current.end_of_week).count

  @monthly_number =
    @registrations.where(created_at: current.beginning_of_month..current.end_of_month).count

  @last_month_number =
    @registrations.where(
      created_at: current.prev_month.beginning_of_month..current.prev_month.end_of_month
    ).count

  @total_number = @registrations.count

  @assigned_crowdworks = @worker.crowdworks

  @count_day =
    @customers.where(status: nil).or(@customers.where(status: "draft"))
      .where.not(tel: nil)
      .where('customers.updated_at >= ?', current.beginning_of_day)
      .where('customers.updated_at <= ?', current.end_of_day)
      .count + @worker.deleted_customer_count

  @count_week =
    @customers.where(status: nil).or(@customers.where(status: "draft"))
      .where.not(tel: nil)
      .where('customers.updated_at >= ?', current.beginning_of_week)
      .where('customers.updated_at <= ?', current.end_of_week)
      .count + @worker.deleted_customer_count

  @count_month =
    @customers.where(status: nil).or(@customers.where(status: "draft"))
      .where.not(tel: nil)
      .where('customers.updated_at >= ?', current.beginning_of_month)
      .where('customers.updated_at <= ?', current.end_of_month)
      .count + @worker.deleted_customer_count

  @count_before_month =
    @customers.where(status: nil).or(@customers.where(status: "draft"))
      .where.not(tel: nil)
      .where('customers.updated_at >= ?', current.prev_month.beginning_of_month)
      .where('customers.updated_at <= ?', current.prev_month.end_of_month)
      .count + @worker.deleted_customer_count

  @total_count = @customers.count

  @contact_trackings_month =
    @worker.contact_trackings.where(created_at: current.beginning_of_month..current.end_of_month)

  @contact_trackings_before_month =
    @worker.contact_trackings.where(
      created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month
    )

  @contact_trackings_day =
    @worker.contact_trackings.where(created_at: current.beginning_of_day..current.end_of_day)

  @contact_trackings_week =
    @worker.contact_trackings.where(created_at: current.beginning_of_week..current.end_of_week)

  @send_success_count_day =
    @contact_trackings_day.where(status: '送信済').count

  @send_success_count_week =
    @contact_trackings_week.where(status: '送信済').count

  @send_success_count_month =
    @contact_trackings_month.where(status: '送信済').count

  @send_success_count_before_month =
    @contact_trackings_before_month.where(status: '送信済').count

  @send_error_count_month =
    @contact_trackings_month.where(status: '送信不可').count

  @send_ng_count_month =
    @contact_trackings_month.where(status: '営業NG').count

  @send_count_month =
    @send_success_count_month + @send_error_count_month + @send_ng_count_month

  @send_rate =
    if @send_count_month > 0
      (@send_success_count_month / @send_count_month.to_f) * 100
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
      uploaded_file = params[:file]
      upload_count = process_uploaded_file(uploaded_file)
      session[:upload_results] = upload_count
    else
      session[:upload_results] = nil
    end
    redirect_to confirm_worker_path(@worker)
  end

def destroy
  @worker = Worker.find(params[:id])

  # 関連レコードの外部キーをNULLにする
  @worker.first_edited_customers.update_all(updated_by_worker_id: nil)
  @worker.contact_trackings.update_all(worker_id: nil)

  # Workerを削除
  if @worker.destroy
    redirect_to admin_path(current_admin), notice: 'ワーカーを削除しました'
  else
    redirect_to admin_path(current_admin), alert: 'ワーカーの削除に失敗しました'
  end
end

  def confirm
    @worker = Worker.find(params[:id])
    @upload_results = session[:upload_results] || "結果がありません"
    # セッションをクリアする
    session.delete(:upload_results)
  end
  
  def question1
    render 'workers/practices/question1'
  end

  def question2
    render 'workers/practices/question2'
  end

  def question3
    render 'workers/practices/question3'
  end

  def question4
    render 'workers/practices/question4'
  end

  def reference1
    render 'workers/practices/reference1'
  end

  def reference2
    render 'workers/practices/reference2'
  end

  def reference3
    render 'workers/practices/reference3'
  end

  def reference4
    render 'workers/practices/reference4'
  end

  def next 
    @worker = Worker.find_by(id: params[:id])
  end

  private

  def set_worker_registration_count
    session[:worker_registration_count] ||= 0
    session[:worker_registration_count] += 1
  end

  def process_uploaded_file(uploaded_file)
    # ファイルを一時的に保存する
    file_path = Rails.root.join('tmp', uploaded_file.original_filename)
    File.open(file_path, 'wb') do |file|
      file.write(uploaded_file.read)
    end
  
    # CSVファイルを解析して件数をカウント
    count = 0
    CSV.foreach(file_path, headers: true) do |row|
      # ここで各行（各データ）に対する処理を行う
      # 例: row['カラム名'] でデータにアクセスし、何かしらの処理を行う
      # ...
  
      count += 1  # 行をカウント
    end
  
    # 一時ファイルを削除
    File.delete(file_path)
  
    count  # 処理したデータの件数を返す
  end
end
