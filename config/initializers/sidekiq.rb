redis_options = {
    # namespace: "labman"
}

# redis_options[:namespace] = "labman_#{Rails.env}" unless Rails.env.production?

redis_options[:url] = ENV['REDIS_URL'] if ENV['REDIS_URL']

Sidekiq.configure_server do |config|
  config.redis = redis_options
end

Sidekiq.configure_client do |config|
  config.redis = redis_options
end

schedule_file = 'config/schedule.yml'

if File.exists?(schedule_file) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
end
