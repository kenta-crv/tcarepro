class AttendancesController < ApplicationController
  def index
    @attendances = Attendance.all
  end

  def show
    @attendance = Attendance.find(params[:id])
  end

  def new
    @user = User.find(params[:user_id])
    @attendance = @user.attendances.new
  end

  def create
    @user = User.find(params[:user_id])
    @attendance = @user.attendances.new(attendance_params)
    if @attendance.save
      redirect_to attendances_path
    else
      render 'new'
    end
  end
  
    def edit
      @user = User.find(params[:user_id])
      @attendance = Attendance.find(params[:id])
    end
  
    def destroy
      @attendance = Attendance.find(params[:id])
      @attendance.destroy
      redirect_to "/users/#{current_user.id}"
    end
  
    def update
      @attendance = Attendance.find(params[:id])
      if @attendance.update(attendance_params)
        redirect_to "/users/#{current_user.id}"
      else
        render 'edit'
      end
    end
  
    private
    def attendance_params
      params.require(:attendance).permit(
        :month,
        :year,
        :hours_worked,
        :user_id
      )
    end
end
