class ContactsController < ApplicationController
    before_action :set_worker, only: [:new, :create]
    before_action :set_contact, only: [:edit, :update, :destroy]
  
    def index
      @contacts = Contact.all
    end
  
    def new
      @contact = @worker.contacts.new
    end
  
    def create
      @contact = @worker.contacts.new(contact_params)
      if @contact.save
        redirect_to worker_path(@worker), notice: '送信完了しました'
      else
        redirect_to worker_path(@worker), alert: '送信に失敗しました'
      end
    end

    def show
     @contact = Contact.find(params[:id])
    end

    def edit
    end
  
    def update
      if @contact.update(contact_params)
        redirect_to contacts_path, notice: '更新完了しました'
      else
        render :edit
      end
    end
  
    def destroy
      @contact.destroy
      redirect_to contacts_path, notice: '削除完了しました'
    end  
    private

    def set_worker
        @worker = Worker.find(params[:worker_id])
    end
    
    def set_contact
        @contact = Contact.find(params[:id])
    end
    
  
    def contact_params
      params.require(:contact).permit(
        :question,
        :body
      )
    end
end
