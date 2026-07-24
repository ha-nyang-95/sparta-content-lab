require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module YoutubePlanningHelper
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # lib/youtube 는 스텁 fixture(.json) 소재지일 뿐 오토로드 대상이 아니다(향후 .rb 네임스페이스 충돌 방지).
    config.autoload_lib(ignore: %w[assets tasks youtube])

    # errors.rb 는 여러 예외 클래스(Youtube::Error/QuotaExceeded/…)를 한 파일에 모은다.
    # 파일명이 단일 상수와 매핑되지 않아 zeitwerk 규칙에 맞지 않으므로 무시하고 직접 require 한다.
    youtube_errors = Rails.root.join("app/services/youtube/errors.rb")
    Rails.autoloaders.main.ignore(youtube_errors)
    require youtube_errors

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
