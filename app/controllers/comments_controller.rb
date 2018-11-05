class CommentsController < ApplicationController

 def create
    @company = Company.find(params[:company_id])
    @company.comments.create(comment_params)
    redirect_to company_path(@company)
  end
  
  def destroy
    @company = Company.find(params[:company_id])
    @comment = @company.comments.find(params[:id])
    @comment.destroy
    redirect_to company_path(@company)
  end

  def destroy
    @company = Company.find(params[:company_id])
    @comment = @company.comments.find(params[:id])
    @comment.destroy
    redirect_to company_path(@company)
  end

  def update
      @company = Company.find(params[:company_id])
      @comment = @company.comments.find(params[:id])
     if @comment.update(comment_params)
       redirect_to company_path(@company)
     else
        render 'edit'
     end
  end

  def download
      @comment = Comment.find(params[:id].to_i)
      filepath = @comment.picture.current_path
      stat = File::stat(filepath)
      send_file(filepath, :filename => @comment.picture.url.gsub(/.*\//,''), :length => stat.size)
  end

  def view
    @comment = Comment.find(params[:id].to_i)
    filepath = @comment.picture.current_path
    stat = File::stat(filepath)
    send_file(filepath, :filename => @comment.picture.url.gsub(/.*\//,''), :length => stat.size, :disposition => 'inline')
  end

  def bulk_edit
    @ids = params[:ids]
  end

  def bulk_update
    @ids = params[:ids].split(" ")
    @ids.each do |id|
      c = Comment.find(id.to_i)
      c.update_attributes(
        carriaup_progress: params[:carriaup_progress]
      )
    end
    redirect_to request.referer
  end

  def bulk_destroy
    return unless params[:ids]
    companies = Comment.where(id: params[:ids])
    companies.each do |o|
      o.destroy
    end
    redirect_to request.referer
  end


  private
    def comment_params
      params.require(:comment).permit(
      #コメント
      :body,
      #添付
     :picture, #その他
     :approval_data, #認定書控え
     :ahead_data, #提出控え
     :term_data, #有期雇用契約書
     :regular_data, #正規雇用契約書
     :attendance_data, #出勤簿
     :wage_data, #賃金台帳
     :labor_data, #就業規則

#有期実習型訓練
      :limited_progress, #進捗
      :limited_start,  #制度開始日
      :limited_each_name, #申込者
      :limited_each_start,  #開始日
      :limited_each_curriculum, #カリキュラム
      :limited_offjt_time, #OFF-JT
      :limited_ojt_time, #OJT
      :limited_supply, #支給申請開始日
      :limited_comment, #コメント

# キャリアアップ助成金　正社員化コース
      :carriaup_progress, #進捗
      :carriaup_start, #制度開始日
      :carriaup_each_name, #申込者
      :carriaup_each_limited_start, #入社日
      :carriaup_each_regular, #転換日
      :carriaup_each_supply, #支給申請開始日
      :carriaup_comment, #コメント


      :system_progress, #進捗
      :system_start, #制度開始日
      :system_subsidyname, #助成金
      :system_each_name, #制度
      :system_implementation, #実施日
      :system_supply,  #支給申請開始日
      :system_comment, #コメント

      :status


      )
    end

end
