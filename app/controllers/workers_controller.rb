class WorkersController < ApplicationController
    before_action :authenticate_user!

    def first
    end

    def second
    end

    def upload
    end

    def tool
    end

    def faq
    end

    def index
      @q = Worker.ransack(params[:q])
      @workers = @q.result
  		@workers = @workers.all.order(created_at: 'desc')
  	end

  #	def show
  #  	@worker = Worker.find(params[:id])
  #  end

    def new
    	@worker = Worker.new
    end

  	def create
      @worker = Worker.new(worker_params)
      if @worker.save
          redirect_to workers_path
      else
          render 'new'
      end
    end

    def edit
      @worker = Worker.find(params[:id])
    end

   def update
      @worker = Worker.find(params[:id])
       if @worker.update(worker_params)
          redirect_to workers_path
      else
          render 'edit'
      end
   end

   def destroy
      @worker = Worker.find(params[:id])
      @worker.destroy
      redirect_to workers_path
   end

  private
   def worker_params
    params.require(:worker).permit(
    )
    end
end
