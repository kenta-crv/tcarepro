class OkuriteCallbacksController < ApplicationController
  def update_status
    contact_tracking = ContactTracking.find(params[:id])
    contact_tracking.update(status: "送信済")

    # 任意のリダイレクト先に遷移する場合は以下のように記述します
    redirect_to root_path, notice: "Contact tracking status updated successfully"
  end
end
