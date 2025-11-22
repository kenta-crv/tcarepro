Rails.application.routes.draw do
  require 'sidekiq/web'
  root to: 'customers#index'
  # 発信認証用ルーティング
  post 'notifications', to: 'notifications#create'
  root to: 'customers#index'
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

  #resource :sender, only: [:show]
  #センダーアカウント
  devise_for :senders, controllers: {
    registrations: 'senders/registrations'
  }

  get 'jwork' => 'customers#jwork' #J Work

  resources :inquiries, only: [:index, :show, :edit, :update, :destroy] 
  resources :senders, only: [:index, :show, :edit, :update] do
    resources :inquiries, only: [:new, :create, :edit, :update, :default] do
      put :default, to: 'inquiries#default'
    end
    #get 'history', to: 'senders_history#index'
    #get 'sended', to: 'senders_history#sended'
    #get 'mail_app', to: 'senders_history#mail_app'
    #get 'tele_app', to: 'senders_history#tele_app'
    #get 'download_sended', to: 'senders_history#download_sended'
    #get 'download_callbacked', to: 'senders_history#download_callbacked'
    #get 'callbacked', to: 'senders_history#callbacked'
    #get 'users_callbacked', to: 'senders_history#users_callbacked'
    #get 'okurite/index01', to: 'okurite#index01'
    post 'okurite/autosettings', to: 'okurite#autosettings'
    delete 'bulk_delete', to: 'okurite#bulk_delete'
    # okurite
    resources :okurite, only: [:index, :show] do
      get :preview, to: 'okurite#preview'
      post :contact, to: 'okurite#create'
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
  get 'draft/progress', to: 'customers#extract_progress', as: 'extract_progress'
  post 'draft/stop_extraction', to: 'customers#stop_extraction', as: 'stop_extraction'
  #showからのメール送信
  match 'customers/:id/send_email', to: 'customers#send_email', via: [:get, :post], as: 'send_email_customer'

  get 'customers/:id/:is_auto_call' => 'customers#show'
  get 'direct_mail_send/:id' => 'customers#direct_mail_send' #SFA
  get '/customers/analytics/generate_pdf', to: 'customers#generate_pdf', as: 'customers_analytics_generate_pdf'
  get '/customers/analytics/thinreports_email', to: 'customers#thinreports_email', as: 'customers_thinreports_email'
  #get 'sender/:id/' => 'sender#show'
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

  # API
  namespace :api do
    namespace :v1 do
      resources :smartphones
      namespace :smartphone_logs do
        post '/' , :action => 'create'
      end
      resources :pybotcenter 
      get "pybotcenter_success" => "pybotcenter#success"
      get "pybotcenter_failed" => "pybotcenter#failed"
      post "autoform_data_register" => "pybotcenter#graph_register"
      post "pycall" => "pybotcenter#notify_post"
      get "inquiry" => "pybotcenter#get_inquiry"
      
      # Customers API
      resources :customers, only: [:index, :show] do
        collection do
          get :search
          get :by_industry
          get :by_status
        end
      end
      
      # Calls API
      resources :calls, only: [:create]
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
