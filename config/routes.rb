Rails.application.routes.draw do
  require 'sidekiq/web'
  root to: 'customers#index'
  
  # 発信認証用ルーティング
  post 'notifications', to: 'notifications#create'
  
  #管理者アカウント
  devise_for :admins, controllers: {
    registrations: 'admins/registrations'
  }
  resources :admins do
    post 'assign_workers', on: :member
    post 'remove_worker', on: :member
    post 'assign_senders', on: :member
    post 'remove_sender', on: :member
    member do
      patch :assign_worker_crowdwork  # 各管理者に対するワーカーの割り当て
    end
  end
  authenticate :admin do
    mount Sidekiq::Web => '/sidekiq'
  end
  
  #ユーザーアカウント
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  resources :users, only: [:show, :destroy] 
  
  #ワーカーアカウント
  devise_for :workers, controllers: {
    registrations: 'workers/registrations',
    sessions: 'workers/sessions',
    confirmations: 'workers/confirmations',
    passwords: 'workers/passwords',
  }
  resources :workers, only: [:show, :destroy] do 
    member do
      get 'next', to: 'workers#next'
      post 'upload', to: 'workers#upload'
      get 'confirm', to: 'workers#confirm'
    end
    collection do
      get 'practices/question1', to: 'workers#question1'
      get 'practices/question2', to: 'workers#question2'
      get 'practices/question3', to: 'workers#question3'
      get 'practices/question4', to: 'workers#question4'
      get 'practices/reference1', to: 'workers#reference1'
      get 'practices/reference2', to: 'workers#reference2'
      get 'practices/reference3', to: 'workers#reference3'
      get 'practices/reference4', to: 'workers#reference4'
    end
    resources :tests
    resources :sends
  end
  resources :crowdworks

<<<<<<< HEAD
  resource :sender, only: [:show]
  
=======
  #resource :sender, only: [:show]
>>>>>>> 08d1dbaf9e2c6e1c34e88f01cf1c3930bb3b6e9f
  #センダーアカウント
  devise_for :senders, controllers: {
    registrations: 'senders/registrations'
  }

  get 'jwork' => 'customers#jwork' #J Work

  resources :inquiries, only: [:index, :show, :edit, :update, :destroy] 
  
  # Senders with okurite routes - FIXED ROUTE HELPERS
  resources :senders, only: [:index, :show, :edit, :update] do
    resources :inquiries, only: [:new, :create, :edit, :update, :default] do
      put :default, to: 'inquiries#default'
    end
    
    # Okurite routes - FIXED structure with proper collection routes
    resources :okurite, only: [:index, :show], controller: 'okurite' do
      collection do
        get 'stats', to: 'okurite#stats'
        post 'autosettings', to: 'okurite#autosettings'
        delete 'bulk_delete', to: 'okurite#bulk_delete'
      end
      member do
        get 'preview', to: 'okurite#preview'
        post 'contact', to: 'okurite#create'
      end
    end
  end
  
  get 'callback' => 'okurite#callback', as: :callback
  get 'direct_mail_callback' => 'okurite#direct_mail_callback', as: :direct_mail_callback

  resources :customers do
    post 'exclude', on: :member
    resources :calls
    collection do
      post :bulk_action # bulk_actionへのルートを追加
      put 'update_all_status'
      get 'search', to: 'customers#search', as: 'search'
      get :industry_code_total
      get :complete
      post :all_import
      post :import
      post :send_emails #info
      get :message
    end
  end
  
  get 'customers/print', to: 'customers#print', as: :customers_pdf #thinresports
  get 'draft' => 'customers#draft' #締め
  get 'draft/filter_by_industry', to: 'customers#filter_by_industry', as: 'filter_by_industry'
  post 'draft/extract_company_info', to: 'customers#extract_company_info', as: 'extract_company_info'
<<<<<<< HEAD
  
=======
  get 'draft/progress', to: 'customers#extract_progress', as: 'extract_progress'
>>>>>>> 08d1dbaf9e2c6e1c34e88f01cf1c3930bb3b6e9f
  #showからのメール送信
  match 'customers/:id/send_email', to: 'customers#send_email', via: [:get, :post], as: 'send_email_customer'

  get 'customers/:id/:is_auto_call' => 'customers#show'
  get 'direct_mail_send/:id' => 'customers#direct_mail_send' #SFA
  get '/customers/analytics/generate_pdf', to: 'customers#generate_pdf', as: 'customers_analytics_generate_pdf'
  get '/customers/analytics/thinreports_email', to: 'customers#thinreports_email', as: 'customers_thinreports_email'
  
  scope :information do
    get '' => 'customers#information', as: :information #分析
  end

  get 'news' => 'customers#news' #インポート情報
  delete :customers, to: 'customers#destroy_all' #Mailer

  resources :contracts  do
    resources :scripts, except: [:index, :show]
  end

  # エラー情報
  get 'pybot' => 'pybot_e_notify#index'
  get 'pybot/destroy' => 'pybot_e_notify#destroyer'

  #資料
  get 'documents', to: 'customers#documents'
  resources :access_logs, only: [:index]

  # API - FIXED AND ENHANCED PYTHON INTEGRATION ROUTES
  namespace :api do
    namespace :v1 do
      resources :smartphones
      namespace :smartphone_logs do
        post '/' , :action => 'create'
      end
      
      # Pybotcenter routes - FIXED for proper Python integration
      resources :pybotcenter do
        collection do
          get 'success', to: 'pybotcenter#success'
          get 'failed', to: 'pybotcenter#failed'
          post 'notify_post', to: 'pybotcenter#notify_post'
          post 'graph_register', to: 'pybotcenter#graph_register'
          get 'get_inquiry', to: 'pybotcenter#get_inquiry'
          
          # New enhanced routes for Python autoform system
          get 'pybotcenter_success', to: 'pybotcenter#pybotcenter_success'
          get 'pybotcenter_failed', to: 'pybotcenter#pybotcenter_failed'
          post 'autoform_data_register', to: 'pybotcenter#autoform_data_register'
        end
      end
      
      # Direct routes for Python system (maintain backward compatibility)
      get "pybotcenter_success" => "pybotcenter#pybotcenter_success"
      get "pybotcenter_failed" => "pybotcenter#pybotcenter_failed"
      post "autoform_data_register" => "pybotcenter#autoform_data_register"
      post "pycall" => "pybotcenter#notify_post"
      get "inquiry" => "pybotcenter#get_inquiry"
      
      # Additional API endpoint for Python rocketbumb
      post "rocketbumb" => "pybotcenter#rocketbumb"
    end
  end

  #ユーザー案内
  get 'recruits/info' => 'recruits#info'  #ユーザー研修案内

  resources :scripts, only: [:index, :show]
  resources :knowledges 

  resources :recruits do 
    collection do
      get 'thanks'
      get 'second_thanks'
    end
    member do
      post 'offer_email', to: 'recruits#offer_email', as: 'offer_email'
      post 'reject_email', to: 'recruits#reject_email', as: 'reject_email'
    end
  end

  resources :imports, only: [:create]
  
  get '*path', controller: 'application', action: 'render_404'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end

