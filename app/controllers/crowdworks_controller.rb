class CrowdworksController < ApplicationController
      def index
        @crowdworks = Crowdwork.order(created_at: "DESC").page(params[:page])
      end
    
      def show
        @crowdwork = Crowdwork.find(params[:id])
      end
    
      def new
        @crowdwork = Crowdwork.new
      end
    
      def create
        @crowdwork = Crowdwork.new(crowdwork_params)
        if @crowdwork.save
          assign_workers(params[:worker_ids])
          @crowdwork.workers.each do |worker|
            WorkerMailer.assignment_email(worker).deliver_later
          end
          redirect_to crowdworks_path, notice: 'Crowdwork was successfully created.'
        else
          render :new
        end
      end
    
      def edit
        @crowdwork = Crowdwork.find(params[:id])
        render :layout => "froala"
      end
    
      def destroy
        @crowdwork = Crowdwork.find(params[:id])
        @crowdwork.destroy
         redirect_to crowdworks_path
      end
    
      def update
        @crowdwork = Crowdwork.find(params[:id])
        if @crowdwork.update(crowdwork_params)
          @crowdwork.assignments.destroy_all
          assign_workers(params[:worker_ids])
          redirect_to @crowdwork, notice: 'Crowdwork was successfully updated.'
        else
          render :edit
        end
      end
    
      private
      def crowdwork_params
        params.require(:crowdwork).permit(
          :title,
          :sheet,
          :tab,
          :business,
          :genre,
          :bad,
          :attention,
          area: [],
        )
      end

      def assign_workers(worker_ids)
        return if worker_ids.nil?
        worker_ids.each do |worker_id|
          @crowdwork.assignments.create(worker_id: worker_id) unless worker_id.blank?
        end
      end
end

