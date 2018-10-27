class TodosController < ApplicationController


  def index
  	 @todos = Todo.all.order(created_at: 'desc')
  	 @todo = Todo.new
  end
  
  def show
  	@todo = Todo.find(params[:id])
  end
  
 def create
    @todo = Todo.new(todo_params)
    if @todo.save
        # redirect
        redirect_to todos_path
    else
        render 'index'
    end
  end
  
  def edit
    @todo = Todo.find(params[:id])
  end

 def update
    @todo = Todo.find(params[:id])
     if @todo.update(todo_params)
        redirect_to todos_path
    else
        render 'edit'
    end      
 end
 
 def destroy
    @todo = Todo.find(params[:id])
    @todo.destroy
    redirect_to todos_path
 end

  private
    def todo_params
      params.require(:todo).permit(
      :execution, #実行
      :title, #タイトル
      :select, #選択 
      :deadline, #期限
      :state, #ステータス
      :name, #担当者
      :contents #コンテンツ
      )
    end    


end
