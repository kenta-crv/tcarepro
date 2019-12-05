class Api::V1::SmartphoneLogsController < ApiController

  def create
    SmartphoneLog.transaction do
      for data in smartphone_log_params[:log_data] do
        smartphone_log = SmartphoneLog.new(token: smartphone_log_params[:token], log_data: data)
        if smartphone_log.save
          # nop
        else
          # ロールバック
          raise ActiveRecord::Rollback
          # 終了
          render json: { status: 'ERROR', data: smartphone_log.errors } and return
        end
      end
    end
    #
    render json: { status: 'SUCCESS', data: "" }
  end

  private

  def smartphone_log_params
    params.require(:smartphone_log).permit(:token, log_data: [])
  end

end
