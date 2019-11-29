class Api::V1::SmartphoneLogsController < ApiController

  def create
    smartphone_log = SmartphoneLog.new(smartphone_log_params)
    if smartphone_log.save
      render json: { status: 'SUCCESS', data: smartphone_log }
    else
      render json: { status: 'ERROR', data: smartphone_log.errors }
    end
  end

  private

  def smartphone_log_params
    params.require(:smartphone_log).permit(:token, :log_data)
  end

end
