Rails.application.routes.draw do
  authenticate :user, lambda {|u| u.role.admin?} do
    require 'sidekiq/web'
    require 'sidekiq/cron/web'
    mount Sidekiq::Web => '/jobs', as: 'sidekiq'
  end
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  devise_for :users

  resources :teams, shallow: true do
    resources :projects
  end

  resources :projects, shallow: true do
    resources :apps
    resources :branches
    resources :builds
    resources :issues
    resources :releases
  end

  root to: 'home#index'
end
