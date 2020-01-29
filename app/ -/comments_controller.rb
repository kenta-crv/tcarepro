class CommentsController < ApplicationController
  def create
    @crm = Crm.find(params[:crm_id])
    @crm.comments.create(comment_params)
    redirect_to crm_path(@crm)
  end

  def destroy
    @crm = Crm.find(params[:crm_id])
    @comment = @crm.comments.find(params[:id])
    @image.destroy
    redirect_to crm_path(@crm)
  end

  private
  def comment_params
    params.require(:comment).permit(:body)
  end
end
