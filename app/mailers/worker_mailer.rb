class WorkerMailer < ApplicationMailer
  default from: 'notifications@example.com'

  def assignment_email(worker)
    @worker = worker
    @url  = 'http://tcare.pro/workers/sign_in'
    mail(to: @worker.email, subject: '新しいタスクが割り当てられました')
  end

  def reminder_email(worker)
    @worker = worker
    mail(to: @worker.email, subject: '至急作業を実施してください。')
  end  

  def warning_email
    @worker = params[:worker]
    @body = params[:body]
    mail(to: @worker.email, subject: params[:subject])
  end
end
