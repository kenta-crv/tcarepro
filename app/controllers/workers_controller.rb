class WorkersController < ApplicationController
  def show
    # Retrieve worker and initialize a new contact
    @worker = Worker.find(params[:id])
    #@contact = @worker.contacts.new
    
    # Retrieve customers related to the worker
    @customers = @worker.customers
  
    # Calculate daily, weekly, monthly, and total customer counts
    @daily_number = @customers.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).count
    @weekly_number = @customers.where(created_at: Time.zone.now.beginning_of_week..Time.zone.now.end_of_week).count
    @monthly_number = @customers.where(created_at: Time.zone.now.beginning_of_month..Time.zone.now.end_of_month).count
    @last_month_number = @customers.where(created_at: Time.zone.now.last_month.beginning_of_month..Time.zone.now.last_month.end_of_month).count
    @total_number = @customers.count
    
    # Retrieve assigned crowdworks for the worker
    @assigned_crowdworks = @worker.crowdworks
  
    # Calculate counts of customers updated today, this week, and this month
# 今日、今週、今月、先月のカウント（削除された顧客は除外）
    @count_day = @customers.where(deleted_at: nil).where(status: nil).or(@customers.where(status: "draft")).where.not(tel: nil).where('customers.updated_at >= ?', Time.current.beginning_of_day).where('customers.updated_at <= ?', Time.current.end_of_day).count
    @count_week = @customers.where(deleted_at: nil).where(status: nil).or(@customers.where(status: "draft")).where.not(tel: nil).where('customers.updated_at >= ?', Time.current.beginning_of_week).where('customers.updated_at <= ?', Time.current.end_of_week).count
    @count_month = @customers.where(deleted_at: nil).where(status: nil).or(@customers.where(status: "draft")).where.not(tel: nil).where('customers.updated_at >= ?', Time.current.beginning_of_month).where('customers.updated_at <= ?', Time.current.end_of_month).count
    @count_before_month = @customers.where(deleted_at: nil).where(status: nil).or(@customers.where(status: "draft")).where.not(tel: nil).where('customers.updated_at >= ?', Time.current.prev_month.beginning_of_month).where('customers.updated_at <= ?', Time.current.prev_month.end_of_month).count
    @total_count = @customers.count
    
    # Retrieve contact trackings for the current and previous month, day, and week
    @contact_trackings_month = @worker.contact_trackings.where(created_at: Time.current.beginning_of_month..Time.current.end_of_month)
    @contact_trackings_before_month = @worker.contact_trackings.where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month)
    @contact_trackings_day = @worker.contact_trackings.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
    @contact_trackings_week = @worker.contact_trackings.where(created_at: Time.current.beginning_of_week..Time.current.end_of_week)
    
    # Calculate counts of successful, error, and NG contact trackings for the current month
    @send_success_count_day = @contact_trackings_day.where(status: '送信済').count
    @send_success_count_week = @contact_trackings_week.where(status: '送信済').count
    @send_success_count_month = @contact_trackings_month.where(status: '送信済').count
    @send_success_count_before_month = @contact_trackings_before_month.where(status: '送信済').count
    
    @send_error_count_month = @contact_trackings_month.where(status: '送信不可').count
    @send_ng_count_month = @contact_trackings_month.where(status: '営業NG').count
    @send_count_month = @send_success_count_month + @send_error_count_month + @send_ng_count_month
  
    # Calculate send success rate for the current month
    @send_rate = if @send_count_month > 0
                   (@send_success_count_month / @send_count_month.to_f) * 100
                 else
                   0
                 end
    
    # Calculate total send counts for the day and week
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
    @worker.destroy
    redirect_to admin_path(current_admin), notice: 'ワーカーを削除しました'
  end

  def confirm
    @worker = Worker.find(params[:id])
    @upload_results = session[:upload_results] || "結果がありません"
    # セッションをクリアする
    session.delete(:upload_results)
  end

  def import_customers
    cnt = Worker.import_customers(params[:file])
    redirect_to some_path, notice: "#{cnt}件のデータをCustomerにインポートしました。"
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
