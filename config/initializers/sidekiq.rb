require 'sidekiq'
require 'sidekiq-scheduler'
puts "Sidekiq.server? is #{Sidekiq.server?.inspect}"
puts "defined?(Rails::Server) is #{defined?(Rails::Server).inspect}"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq.yml', __FILE__))[:scheduler][:schedule]
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end
