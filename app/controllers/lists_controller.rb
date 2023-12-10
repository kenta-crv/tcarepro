class ListsController < ApplicationController 
      def index
        @lists = List.all
      end

      def new
        @worker = Worker.find(params[:worker_id])
        @list = List.new
      end
  
      def create
        @worker = Worker.find(params[:worker_id])
        @list = @worker.lists.new(list_params)
        if @list.save
          redirect_to "/workers/#{current_worker.id}"
         else
          render 'new'
        end
      end
    
      def edit
        @worker = Worker.find(params[:worker_id])
        @list = List.find(params[:id])
      end
    
      def destroy
        @list = List.find(params[:id])
        @list.destroy
        redirect_to "/workers/#{current_worker.id}"
      end
    
      def update
        @list = List.find(params[:id])
        if @list.update(list_params)
          redirect_to "/workers/#{current_worker.id}"
        else
          render 'edit'
        end
      end
    
      private
      def list_params
        params.require(:list).permit(
          :number,
          :url,
          :check_1,
          :check_2,
          :check_3,
          :check_4,
          :check_5,
          :check_6,
          :check_7,
          :check_8,
          :check_9,
          :check_10,
        )
      end
end
