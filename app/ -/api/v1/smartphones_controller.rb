class Api::V1::SmartphonesController < ApiController

  before_action :set_smartphone, only: [:show, :update, :destroy]

  def index
    smartphones = Smartphone.where(delete_flag: false).order(created_at: :desc)
    render json: { status: 'SUCCESS', message: 'OK', data: smartphones }
  end

  def show
    render json: { status: 'SUCCESS', message: 'OK', data: @smartphone }
  end

  def create
    # 既に登録されているトークンは登録しない
    if Smartphone.find_by(token: smartphone_params[:token], delete_flag: false) != nil
      render json: { status: 'ERROR', data: 'has already been registered.' }
    else
      smartphone = Smartphone.new(smartphone_params)
      if smartphone.save
        render json: { status: 'SUCCESS', data: smartphone }
      else
        render json: { status: 'ERROR', data: smartphone.errors }
      end
    end
  end

  def update
    if @smartphone.update(smartphone_params)
      render json: { status: 'SUCCESS', message: 'OK', data: @smartphone }
    else
      render json: { status: 'SUCCESS', message: 'OK', data: @smartphone.errors }
    end
  end

  def destroy
    # @smartphone.destroy
    # render json: { status: 'SUCCESS', message: 'OK', data: @smartphone }
    @smartphone.delete_flag = true
    if @smartphone.save
      render json: { status: 'SUCCESS', message: 'OK', data: @smartphone }
    else
      render json: { status: 'SUCCESS', message: 'OK', data: @smartphone.errors }
    end
  end

  private

  def set_smartphone
    @smartphone = Smartphone.find_by(id: params[:id], delete_flag: false)
  end

  def smartphone_params
    params.require(:smartphone).permit(:device_name, :token)
  end

end
