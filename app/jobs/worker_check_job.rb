class WorkerCheckJob < ApplicationJob
  queue_as :default

  def perform
    Worker.where(select: "リスト制作").or(Worker.where(writers: "AIライター")).each do |worker|
      check_and_notify(worker)
    end
  end

  private

  def check_and_notify(worker)
    if worker.crowdworks.where('created_at >= ?', 14.days.ago).empty?
      worker.destroy
    elsif worker.crowdworks.where('created_at >= ?', 7.days.ago).empty?
      WorkerMailer.reminder_email(worker).deliver_later
    end
  end
end
