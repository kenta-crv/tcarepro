class TestsController < ApplicationController 
    def index
      @tests = Test.all
    end

    def new
      @worker = Worker.find(params[:worker_id])
      @test = Test.new
    end

    def create
      @worker = Worker.find(params[:worker_id])
      @test = @worker.tests.new(test_params)
      if @test.save
        redirect_to "/workers/#{current_worker.id}"
       else
        render 'new'
      end
    end
  
    def edit
      @worker = Worker.find(params[:worker_id])
      @test = Test.find(params[:id])
    end
  
    def destroy
      @test = Test.find(params[:id])
      @test.destroy
      redirect_to "/workers/#{current_worker.id}"
    end
  
    def update
      @test = Test.find(params[:id])
      if @test.update(test_params)
        redirect_to "/workers/#{current_worker.id}"
      else
        render 'edit'
      end
    end
  
    private
    def test_params
      params.require(:test).permit(
        :company,
        :tel,
        :address,
        :title,
        :business,
        :genre,
        :url,
        :contact_url,
        :url_2,
        :store
      )
    end
end
