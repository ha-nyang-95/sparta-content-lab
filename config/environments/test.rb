# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # 테스트는 절대 실 API(YouTube·Gemini)를 타지 않는다 — dotenv 가 .env 의 live 키/모드를 로드해도
  # stub 를 강제한다(spec-1-5 deferred 해소). 모드별 분기 테스트는 어댑터를 직접 주입하거나 이 값을
  # 테스트 안에서 일시적으로 덮어쓴다. 우발적 live 경로 → 실 API 호출·쿼터 소진·과금을 원천 차단.
  ENV["YOUTUBE_API_MODE"] = "stub"
  ENV["EMBEDDING_MODE"] = "stub"

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Show full error reports.
  config.consider_all_requests_local = true

  # Durable cache backed by the dedicated `cache` SQLite DB so SolidCache::Entry
  # resolves to the cache DB in tests (AD-12).
  config.cache_store = :solid_cache_store

  # 테스트에서 Active Job은 표준 :test 어댑터를 쓴다 — 잡 enqueue 단언(assert_enqueued_*)이
  # 동작해야 하기 때문(Rails 8 인증 제너레이터의 PasswordsController 테스트가 이를 전제한다).
  # 큐 DB 격리(AD-12)는 아래 connects_to로 유지된다 — SolidQueue::Job 연결은 어댑터와 무관하다.
  config.active_job.queue_adapter = :test
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true
end
