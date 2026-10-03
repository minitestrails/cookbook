Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "recipes#index"

  resources :recipes do
    resources :ingredients, only: :destroy
    resources :steps, only: :destroy

    collection do
      post :export
      get :download
    end

    member { post :share }
  end

  namespace :api do
    namespace :v1 do
      resources :sessions, only: :create
      resource :session, only: :destroy

      resources :recipes do
        post :share, on: :member
        post :export, on: :collection
        get :download, on: :collection
      end
    end
  end
end
