class WorkersController < ApplicationController
  def show
   #リスト制作
    @worker = Worker.find(params[:id])
    @contact = @worker.contacts.new
    #リストカウント
    @lists = @worker.customers
    # 1日のnumber数
    @daily_number = @worker.lists.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day).sum(:number)
    # 今週のnumber数
    @weekly_number = @worker.lists.where(created_at: Time.zone.now.beginning_of_week..Time.zone.now.end_of_week).sum(:number)
    # 今月のnumber数
    @monthly_number = @worker.lists.where(created_at: Time.zone.now.beginning_of_month..Time.zone.now.end_of_month).sum(:number)
    # 先月のnumber数
    @last_month_number = @worker.lists.where(created_at: Time.zone.now.last_month.beginning_of_month..Time.zone.now.last_month.end_of_month).sum(:number)
    # トータルのnumber数
    @total_number = @worker.lists.sum(:number)
    @assigned_crowdworks = @worker.crowdworks

   #リスト制作
    @customers = Customer&.where(worker_id: current_worker.id)
    @count_day = @customers.where('updated_at > ?', Time.current.beginning_of_day).where('updated_at < ?',Time.current.end_of_day).count
    @count_week = @customers.where('updated_at > ?', Time.current.beginning_of_week).where('updated_at < ?',Time.current.end_of_week).count
    @count_month = @customers.where('updated_at > ?', Time.current.beginning_of_month).where('updated_at < ?',Time.current.end_of_month).count
    @count_month = @customers.count

    @contact_trackings_month = @worker.contact_trackings.where(created_at: Time.current.beginning_of_month..Time.current.end_of_month)
    @contact_trackings_before_month = @worker.contact_trackings.where(created_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month)
    @contact_trackings_day = @worker.contact_trackings.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
    @contact_trackings_week = @worker.contact_trackings.where(created_at: Time.current.beginning_of_week..Time.current.end_of_week)

    @send_success_count_day = @contact_trackings_day.where(status: '送信済').count.to_i
    @send_success_count_week = @contact_trackings_week.where(status: '送信済').count.to_i
    @send_success_count_month = @contact_trackings_month.where(status: '送信済').count.to_i
    @send_success_count_before_month = @contact_trackings_before_month.where(status: '送信済').count.to_i

    @send_error_count_month = @contact_trackings_month.where(status: '送信不可').count.to_i
    @send_ng_count_month = @contact_trackings_month.where(status: '営業NG').count.to_i
    @send_count_month = @send_success_count_month + @send_error_count_month + @send_ng_count_month
    if @send_count_month > 0
      @send_rate = @send_success_count_month / @send_count_month.to_f * 100
    end

    @send_count_day = @contact_trackings_day.count

    @send_count_week = @contact_trackings_week.count
    set_worker_registration_count
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
