Rails.application.routes.draw do

  root to: 'customers#index'
  get 'customers/analytics' => 'customers#analytics'

  delete :customers, to: 'customers#destroy_all'
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
    end
    resources :comments, :acquisitions
    resources :images
     member do
      get 'images/view'
      get 'images/download/:id' => 'images#download', as: :images_pdf
     end
  end

  resources :customers do
        resources :calls do
        end
    collection do
      post :import
      post :call_import
      get :message
      get :bulk_destroy
    end
  end
  get 'customers/:id/:is_auto_call' => 'customers#show'


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
