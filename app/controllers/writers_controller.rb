class WritersController < ApplicationController 
  def index
    @writers = Writer.all
  end

  def new
    @worker = Worker.find(params[:worker_id])
    @writer = Writer.new
  end

  def create
    @worker = Worker.find(params[:worker_id])
    @writer = @worker.writers.new(writer_params)
    if @writer.save
      redirect_to "/workers/#{current_worker.id}"
     else
      render 'new'
    end
  end

  def edit
    @worker = Worker.find(params[:worker_id])
    @writer = Writer.find(params[:id])
  end

  def destroy
    @writer = Writer.find(params[:id])
    @writer.destroy
    redirect_to "/workers/#{current_worker.id}"
  end

  def update
    @writer = Writer.find(params[:id])
    if @writer.update(writer_params)
      redirect_to "/workers/#{current_worker.id}"
    else
      render 'edit'
    end
  end

      private
      def writer_params
        params.require(:writer).permit(
          :title_1,
          :title_2,
          :title_3,
          :title_4,
          :title_5,
          :title_6,
          :title_7,
          :title_8,
          :title_9,
          :title_10,
          :url_1,
          :url_2,
          :url_3,
          :url_4,
          :url_5,
          :url_6,
          :url_7,
          :url_8,
          :url_9,
          :url_10,
        )
      end
end
