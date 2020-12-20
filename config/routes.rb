Rails.application.routes.draw do

  root to: 'top#index'

  get '/format' => 'top#format' #アポフォーマット
  get '/faq' => 'top#faq' #よくある質問
  get '/outsourcing' => 'top#outsourcing'

  get '/homework' => 'top#homework' #２回目の出勤について
  get '/second' => 'top#second' #２回目の出勤について
  get '/first' => 'top#first' #１回目の出勤について
  get '/script' => 'top#script' #トークスクリプト
  get '/tool' => 'top#tool' #各種ツール紹介
  get '/document' => 'top#document' #各種ツール紹介

  #ログイン切り替え
  devise_for :admins, controllers: {
    registrations: 'admins/registrations'
  }
  resources :admins, only: [:show]
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  resources :users, only: [:show]

  resources :crms do
    collection do
      post :import
      get :message
    end
    resources :comments
    resources :images
     member do
      get 'images/view'
      get 'images/download/:id' => 'images#download', as: :images_pdf
     end
  end

  resources :customers do
    resources :calls
    collection do
      get :complete
      post :import
      post :call_import
      get :message
      get :bulk_destroy
    end
    resources :estimates, except: [:index]
  end

  resources :estimates, only: [:index]

  get 'customers/:id/:is_auto_call' => 'customers#show'
  get 'analytics' => 'customers#analytics'
  get 'sfa' => 'customers#sfa'
  delete :customers, to: 'customers#destroy_all'

  resources :uploader, only: [:edit, :update, :destroy]
  get 'uploader/index'
  #get 'uploader/form'
  post 'uploader/upload'
  get 'uploader/view'
  get 'uploader/download/:id' => 'uploader#download' ,as: :donwload_pdf

  get 'contact' => 'contact#index'
  post 'contact/confirm' => 'contact#confirm'
  post 'contact/thanks' => 'contact#thanks'

  # API
  namespace :api do
    namespace :v1 do
      resources :smartphones
      namespace :smartphone_logs do
        post '/' , :action => 'create'
      end
    end
  end

  get '*path', controller: 'application', action: 'render_404'


  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
