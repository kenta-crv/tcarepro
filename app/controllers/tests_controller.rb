class TestsController < ApplicationController 
  def index
    @tests = Test.all
  end

  def new
    @worker = Worker.find(params[:worker_id])
    @question_number = params[:question].to_i
    @test = @worker.tests.new
  end

  def create
    @worker = Worker.find(params[:worker_id])
    @question_number = params[:question].to_i
    @test = @worker.tests.new(test_params)
    if params[:commit] == '対象外リスト'
      @test.skip_validation = true
    end

    if @test.save
      if @question_number < 4
        redirect_to new_worker_test_path(@worker, question: @question_number + 1)
      else
        redirect_to worker_path(@worker)
      end
    else
      render :new
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
    def reset_registration_count_if_needed
      if session[:worker_registration_count] >= 4
        session[:worker_registration_count] = 0
        redirect_to worker_path(@worker) and return
      else
        redirect_to new_worker_test_path(@worker) and return
      end
    end

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
