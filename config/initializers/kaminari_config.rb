# frozen_string_literal: true

Kaminari.configure do |config|
  # config.default_per_page = 25
  config.default_per_page = 10
  # config.max_per_page = nil
  config.max_per_page = 100
  # config.window = 4
  config.window = 2
  # config.outer_window = 0
  config.outer_window = 1
  # config.left = 0
  # config.right = 0
  # config.page_method_name = :page
  # config.param_name = :page
  # config.max_pages = nil
  # config.params_on_first_page = false
end
