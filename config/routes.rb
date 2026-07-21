Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get    "/login"  => "logins#show",       as: :login
  delete "/logout" => "sessions#destroy",  as: :logout

  # The OIDC request phase (POST /auth/oidc) is handled by the OmniAuth middleware.
  get "/auth/oidc/callback" => "omniauth_sessions#callback", as: :oidc_callback
  get "/auth/failure"       => "omniauth_sessions#failure",  as: :oidc_failure

  resources :vendors, except: :destroy do
    member do
      post :approve
      post :reject
    end
    resources :delegations, only: %i[create destroy], defaults: { asset_type: "Vendor" }
  end
  resources :systems, except: :destroy do
    member do
      post :approve
      post :reject
    end
    resources :delegations, only: %i[create destroy], defaults: { asset_type: "System" }
  end

  resources :proposals, only: [], controller: "proposals" do
    member do
      post :approve
      post :reject
    end
  end

  patch "/table_preferences/:table" => "table_preferences#update", as: :table_preference

  get "/inbox"      => "inbox#show",      as: :inbox
  get "/compliance" => "compliance#show", as: :compliance
  get "/audit"      => "audit_events#index", as: :audit_events

  namespace :admin do
    resources :users, only: %i[index update]
    resources :api_tokens, only: %i[index new create destroy]
    root to: "users#index"
  end

  namespace :api do
    namespace :v1 do
      resources :users, only: %i[index create]
    end
  end

  root "dashboard#index"

  # Public-demo persona-picker sign-in. Always declared; the controller 404s
  # unless DEMO_MODE is on (Demo.enabled?). See Demo::SessionsController.
  get  "/demo/sign-in" => "demo/sessions#new",    as: :demo_sign_in
  post "/demo/sign-in" => "demo/sessions#create"

  # Development-only one-click sign-in. Declared only in development, so these
  # routes simply do not exist in production (404), independent of the controller
  # guard. See Dev::SessionsController.
  if Rails.env.development?
    get  "/dev/sign-in" => "dev/sessions#new", as: :dev_sign_in
    post "/dev/sign-in" => "dev/sessions#create"

    # Browse captured outgoing mail.
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
