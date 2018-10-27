Rails.application.routes.draw do


                                              #アップロード
  resources :uploaders
  
  get 'uploader/index'
  get 'uploader/form'
post 'uploader/upload'
  get 'uploader/view'
  get 'uploader/download/:id' => 'uploader#download' ,as: :donwload_pdf



                                            #ログイン切り替え
                                                                                 
  devise_for :admins      #管理者ログイン 
  devise_for :reads
  devise_for :users


                                         #問い合わせフォーム

  get 'contact' => 'contact#index'  
  post 'contact/confirm' => 'contact#confirm'
  post 'contact/thanks' => 'contact#thanks'


                                       #会社情報・就業規則情報
                   
      
                                        
  resources :companies do

        #CSVインポート
    collection do
        post :import
        get :message
    end
        
        #コメント、アップデート、進捗情報
    resources :comments, only: [:create, :destroy, :update, :download]
    member do
        #顧客側管理進捗
            get :progress
        #ファイルビュー・ダウンロード
      get 'comments/view'
      get 'comments/download/:id' => 'comments#download' ,as: :comments_pdf
    end
 end

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
   get '/manual' => 'faqs#manual'


                                            #表側ページ
                                            
  get '/' => 'tops#subsidy'
  get '/company' => 'tops#company'



  get '*path', controller: 'application', action: 'render_404'


  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end