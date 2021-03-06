Rails.application.routes.draw do
  authenticate :user, lambda {|u| u.admin?} do
    require 'sidekiq/web'
    require 'sidekiq/cron/web'
    mount Sidekiq::Web => '/jobs', as: 'sidekiq'
  end
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  devise_for :users


  resources :projects, shallow: true do
    member do
      post 'master'
      post 'sync'
    end

    resources :apps do
      member do
        post 'promote'
      end
    end
    resources :branches
    resources :merge_requests do
      member do
        post 'approve'
      end
    end
    resources :builds do
      member do
        post 'stop'
      end
    end
    resources :tests do
      member do
        post 'stop'
      end
    end
    resources :issues
    resources :releases do
      member do
        post 'bump'
        post 'publish'
        post 'rebuild'
        post 'close'
      end
    end
  end

  root to: 'home#index'
end
