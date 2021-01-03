Rails.application.routes.draw do

  root to: 'top#index'
  get 'usp' => 'top#usp'
  get 'question' => 'top#question'
  get 'co' => 'top#co'

  get 'manuals' => 'manuals#index'
  get 'manuals/format' => 'manuals#format' #アポフォーマット
  get 'manuals/faq' => 'manuals#faq' #よくある質問
  get 'manuals/outsourcing' => 'manuals#outsourcing'

  get 'manuals/homework' => 'manuals#homework' #２回目の出勤について
  get 'manuals/second' => 'manuals#second' #２回目の出勤について
  get 'manuals/first' => 'manuals#first' #１回目の出勤について
  get 'manuals/script' => 'manuals#script' #トークスクリプト
  get 'manuals/tool' => 'manuals#tool' #各種ツール紹介
  get 'manuals/document' => 'manuals#document' #各種ツール紹介

  #管理者アカウント
  devise_for :admins, controllers: {
    registrations: 'admins/registrations'
  }
  resources :admins, only: [:show]
  #ユーザーアカウント
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  resources :users, only: [:show]
  #ワーカーアカウント
  devise_for :workers, controllers: {
    registrations: 'workers/registrations',
    sessions: 'workers/sessions',
    confirmations: 'workers/confirmations',
    passwords: 'workers/passwords',
  }
  resources :workers, only: [:show]

  resources :matters
  resources :posts
  resources :estimates, only: [:index, :show] do
    member do
      get :report
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
    resources :estimates, except: [:index, :show]
  end

  get 'list' => 'customers#list'
  get 'customers/:id/:is_auto_call' => 'customers#show'
  get 'analytics' => 'customers#analytics' #分析
  get 'sfa' => 'customers#sfa' #SFA
  #TCARE
  get 'extraction' => 'customers#extraction'
  #Mailer
  get 'mail' => 'customers#mail'
  delete :customers, to: 'customers#destroy_all'

  #ファイルアップロード
  resources :uploader, only: [:edit, :update, :destroy]
  get 'uploader/index'
  post 'uploader/upload'
  get 'uploader/view'
  get 'uploader/download/:id' => 'uploader#download' ,as: :donwload_pdf

  #お問い合わせフォーム
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

  #削除予定
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

  get '*path', controller: 'application', action: 'render_404'


  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
