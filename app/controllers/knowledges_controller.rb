class KnowledgesController < ApplicationController
    #before_action :authenticate_admin! or :authenticate_user!
    def index
      @q = Knowledge.ransack(params[:q])
      @knowledges = @q.result
  		@knowledges = @knowledges.all.order(created_at: 'desc')
  	end

  	def show
    	@knowledge = Knowledge.find(params[:id])
    end

    def new
      @knowledge = Knowledge.new
    end

  	def create
      @knowledge = Knowledge.new(knowledge_params)
      if @knowledge.save
          redirect_to knowledges_path
      else
          render 'new'
      end
    end

    def edit
      @knowledge = Knowledge.find(params[:id])
    end

   def update
      @knowledge = Knowledge.find(params[:id])
       if @knowledge.update(knowledge_params)
          redirect_to knowledges_path
      else
          render 'edit'
      end
   end

   def destroy
      @knowledge = Knowledge.find(params[:id])
      @knowledge.destroy
      redirect_to knowledges_path
   end

   def import
     Knowledge.import(params[:file])
     redirect_to knowledges_url, notice:"リストを追加しました"
   end

  private
   def knowledge_params
    params.require(:knowledge).permit(
      :title,
      :select,
      :name,
      :answer
      )
    end
end
