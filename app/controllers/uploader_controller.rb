class UploaderController < ApplicationController
  #before_action :authenticate_admin!

  def index
  end

  def form
  end

  def edit
    @upload = Upload.find(params[:id])
  end

  def upload
    @upload_file = UploadFile.new( params.require(:upload_file).permit(:name, :file) )
    @upload_file.save
    redirect_to action: 'index'
  end

   def destroy
    @upload = Upload.find(params[:id])
    @upload.destroy
    redirect_to uploads_path
 end


  def download
    @upload_file = UploadFile.find(params[:id].to_i)
    filepath = @upload_file.file.current_path
    stat = File::stat(filepath)
    send_file(filepath, :filename => @upload_file.file.url.gsub(/.*\//,''), :length => stat.size)
  end

  def view
    @upload_file = UploadFile.find(params[:id].to_i)
    filepath = @upload_file.file.current_path
    stat = File::stat(filepath)
    send_file(filepath, :filename => @upload_file.file.url.gsub(/.*\//,''), :length => stat.size, :disposition => 'inline')
  end

  def edit
    @upload_file = UploadFile.find(params[:id])
  end

 def update
    @upload_file = UploadFile.find(params[:id])
     if @upload_file.update(upload_file_params)
        redirect_to uploader_index_path
    else
        render 'edit'
    end
 end


  def destroy
     @upload_file = UploadFile.find(params[:id])
     filepath = @upload_file.file.current_path
     #remove filepath?
     @upload_file.destroy
     redirect_to uploader_index_path
  end


  def upload_process
  	#アップロードファイルを取得
  	file = params[:upfile]
  	#ファイルのベース名を取得
  	name = file.original_filename
  	#許可する拡張子を定義
  	perms = [ '.jpg' , '.jpeg' , '.png' , '.pdf' , '.pages' , '.numbers' , '.key' , '.jpeg' , 'docs' , 'pptx', 'xls']
  	#配列permsにアップロードファイルの拡張子に合致するものがあるか
  	if !perms.include?(File.extname(name).downcase)
  		result = 'アップロードできません。'
  	#アップロードファイルが５MB以下であるか
  	elsif file.size > 5.megabyte
  		result = 'ファイルサイズは５MBまでです。'
  	else
  	#/public/docフォルダ配下にアップロードファイルを保存
  	File.open("public/docs/#{name}", 'wb') { |f| f.write(file.read) }
  	end
  	#成功・エラーメッセージを保存
  	render plain: result
  end

  private
    def upload_file_params
      params.require(:upload_file).permit(
        :name,
        :file
      )
    end


end
