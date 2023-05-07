class KnowledgesController < ApplicationController
    before_action :load_contract
    before_action :load_knowledge, only: [:edit,:update,:show,:destroy]
  
    def load_contract
      @contract = Contract.find(params[:contract_id])
      @knowledge = Knowledge.new
    end
  
    def load_knowledge
      @knowledge = Knowledge.find(params[:id])
    end
  
    def edit
    end
  
    def create
      @knowledge = @contract.build_knowledge(knowledge_params)
      if @knowledge.save
       redirect_to contract_path(@contract)
      end
    end
  
    def destroy
      @contract = Contract.find(params[:contract_id])
      @knowledge = @contract.knowledge
      @knowledge.destroy
      redirect_to contract_path(@contract)
    end
  
    def update
      @knowledge = @contract.knowledge
      if @knowledge.update(knowledge_params)
         redirect_to contract_path(@contract)
      else
          render 'edit'
      end
    end
  
    private
    def knowledge_params
        params.require(:knowledge).permit(
        :question,
        :genre,
        :answer
       )
    end
end
  