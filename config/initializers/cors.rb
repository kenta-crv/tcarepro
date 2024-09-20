Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
    origins 'http://localhost:3000','https://tcare.pro/' # ここに許可するオリジンを指定
    resource '*',
    headers: :any,
    methods: [:get, :post, :options, :put, :delete]
    end
end