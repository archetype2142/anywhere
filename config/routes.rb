require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  # Dashboard routes
  mount Sidekiq::Web => '/sidekiq'
  get 'dashboard', to: 'dashboard#index'
  resources :dashboard, only: [:index] do
    collection do
      post :retry_all_failed_orders
      post :process_all_pending_charges
      post :trigger_database_purge
    end
  end
  
  # Named routes for dashboard actions
  post 'dashboard/retry_failed_order/:id', to: 'dashboard#retry_failed_order', as: :retry_failed_order
  post 'dashboard/process_pending_charge/:id', to: 'dashboard#process_pending_charge', as: :process_pending_charge
  post 'dashboard/retry_all_failed_orders', to: 'dashboard#retry_all_failed_orders', as: :retry_all_failed_orders
  post 'dashboard/process_all_pending_charges', to: 'dashboard#process_all_pending_charges', as: :process_all_pending_charges
  post "dashboard/refresh_merchant_stripe_account/:id", to: "dashboard#refresh_merchant_stripe_account", as: :refresh_merchant_stripe_account
  post "dashboard/trigger_database_purge", to: "dashboard#trigger_database_purge", as: :trigger_database_purge
  
  # Webhook routes
  post "webhooks/stripe"
  post "webhooks/anywhere_clubs"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "dashboard#index"
end
