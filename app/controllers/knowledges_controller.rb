class KnowledgesController < ApplicationController
        def index
          @knowledges = Knowledge.order(created_at: "DESC").page(params[:page])
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
      
        def destroy
          @knowledge = Knowledge.find(params[:id])
          @knowledge.destroy
           redirect_to knowledges_path
        end
      
        def update
          @knowledge = Knowledge.find(params[:id])
          if @knowledge.update(knowledge_params)
            redirect_to knowledges_path
          else
            render 'edit'
          end
        end
      
        private
        def knowledge_params
          params.require(:knowledge).permit(
            :title,
            :category,
            :genre,
            :file,
            :file_2,
            :url_1,
            :url_2,
            :url_3,
            :name_1,
            :name_2,
            :name_3,
            :priority,
            :body,
          )
        end
end
