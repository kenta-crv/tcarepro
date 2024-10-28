Rails.application.routes.draw do
  Rails.logger.debug("routes: " + DateTime.now.to_s)
  # 発信認証用ルーティング
  post 'notifications', to: 'notifications#create'
  devise_for :staffs
  root to: 'customers#index'
  #管理者アカウント
  devise_for :admins, controllers: {
    registrations: 'admins/registrations'
  }
  resources :admins do
    post 'assign_workers', on: :member
    post 'remove_worker', on: :member
    member do
      patch :assign_worker_crowdwork  # 各管理者に対するワーカーの割り当て
    end
  end
  #ユーザーアカウント
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  resources :users, only: [:show, :destroy] do
    resources :attendances, except: [:index]
  end
  resources :attendances, only: [:index]
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
      post :import_customers
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
    resources :contacts, except: [:index, :edit, :update, :destroy]
  end
  resources :crowdworks
  resources :contacts, only: [:index, :edit, :update, :destroy]

  resource :sender, only: [:show]
  post 'senders/import' => 'senders#import'
  #センダーアカウント
  devise_for :senders, controllers: {
    registrations: 'senders/registrations'
  }

  resources :inquiries, only: [:index, :show, :edit, :update, :destroy] 

  resources :senders, only: [:index, :show, :edit, :update] do
    resources :inquiries, except: [:index, :show, :edit, :update, :destroy] do
      put :default, to: 'inquiries#default'
    end
    get 'history', to: 'senders_history#index'
    get 'sended', to: 'senders_history#sended'
    get 'mail_app', to: 'senders_history#mail_app'
    get 'tele_app', to: 'senders_history#tele_app'
    get 'download_sended', to: 'senders_history#download_sended'
    get 'download_callbacked', to: 'senders_history#download_callbacked'
    get 'callbacked', to: 'senders_history#callbacked'
    get 'users_callbacked', to: 'senders_history#users_callbacked'
    get 'okurite/index01', to: 'okurite#index01'
    post 'okurite/autosettings', to: 'okurite#autosettings'
    delete 'bulk_delete', to: 'okurite#bulk_delete'
    get 'resend', to: 'okurite#resend'
    # okurite
    resources :okurite, only: [:index, :show] do
      get :preview, to: 'okurite#preview'
      post :contact, to: 'okurite#create'

    end
  end
  get 'callback' => 'okurite#callback', as: :callback
  get 'direct_mail_callback' => 'okurite#direct_mail_callback', as: :direct_mail_callback

  resources :sendlist
  resources :estimates, only: [:index, :show] do
    member do
      get :report
    end
  end

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
      #post :repost_import
      #post :update_import
      #post :call_import
      #post :tcare_import
      get :message
      put 'update_all_status'
    end
    get 'analytics', on: :collection
  end
  get '/customers/:id/copy', to: 'customers#copy', as: 'copy_customer' # コピー機能のためのルート
  get 'customers/print', to: 'customers#print', as: :customers_pdf #thinresports
  get '/customers/analytics/generate_pdf', to: 'customers#generate_pdf', as: 'customers_analytics_generate_pdf'
  get '/customers/analytics/thinreports_email', to: 'customers#thinreports_email', as: 'customers_thinreports_email'
  get 'infosends' => 'customers#infosends' #締め
  get 'draft' => 'customers#draft' #締め
  get 'draft/filter_by_industry', to: 'customers#filter_by_industry', as: 'filter_by_industry'
  #showからのメール送信
  get 'customers/:id/send_email', to: 'customers#send_email', as: 'send_email_customer'
  post 'customers/:id/send_email', to: 'customers#send_email_send'
  get 'customers/:id/:is_auto_call' => 'customers#show'
  get 'direct_mail_send/:id' => 'customers#direct_mail_send' #SFA
  #get 'sender/:id/' => 'sender#show'
  scope :information do
    get '' => 'customers#information', as: :information #分析
  end

  get 'closing' => 'customers#closing' #締め
  get 'news' => 'customers#news' #インポート情報
  get 'extraction' => 'customers#extraction' #TCARE
  delete :customers, to: 'customers#destroy_all' #Mailer

  resources :contracts  do
    resources :images, only: [:create, :destroy, :update, :download, :edit]
    member do
      get 'images/view'
      get 'images/download/:id' => 'images#download' ,as: :images_pdf
    end
    resources :scripts, except: [:index, :show]
  end

  # エラー情報
  get 'pybot' => 'pybot_e_notify#index'
  get 'pybot/destroy' => 'pybot_e_notify#destroyer'

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

  
  get '*path', controller: 'application', action: 'render_404'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
