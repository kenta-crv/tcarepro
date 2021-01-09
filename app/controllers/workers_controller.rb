class WorkersController < ApplicationController
  def show
    @worker = Worker.find(params[:id])
    @customers = Customer&.where(worker_id: current_worker.id)
    @count_day = @customers.where('updated_at > ?', Time.current.beginning_of_day).where('updated_at < ?',Time.current.end_of_day).count
    @count_week = @customers.where('updated_at > ?', Time.current.beginning_of_week).where('updated_at < ?',Time.current.end_of_week).count
  end
end
