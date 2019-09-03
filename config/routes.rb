Rails.application.routes.draw do

  root to: 'customers#index'
  #ログイン切り替え
  devise_for :admins       #使用者ログイン

  resources :customers do
        resources :calls
    collection do
      post :import
      get :message
    end
  end


                                                #アップロード
  resources :uploader, only: [:edit, :update, :destroy]

  get 'uploader/index'
  get 'uploader/form'
  post 'uploader/upload'
  get 'uploader/view'
  get 'uploader/download/:id' => 'uploader#download' ,as: :donwload_pdf

  get 'contact' => 'contact#index'
  post 'contact/confirm' => 'contact#confirm'
  post 'contact/thanks' => 'contact#thanks'


    #労働局情報
    resources :prefectures do
        resources :details
    end

    #請求書
    resources :invoices do
      member do
      #PDF生成
        get :report
      end
    end


  #TODO
  resources :todos

  #FAQ
  resources :faqs


  get '*path', controller: 'application', action: 'render_404'


  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
