source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'rails'
gem 'bootsnap', require: false

# database & cache
gem 'dalli'
gem 'pg'
gem 'redis', '4.8.1'
gem 'redis-mutex'
gem 'msgpack'

# frontend
group :beta, :production do
  gem 'autoprefixer-rails'
end
gem 'non-stupid-digest-assets', github: 'afdev82/non-stupid-digest-assets', branch: 'patch-1' # ruby 3.2 fix https://github.com/alexspeller/non-stupid-digest-assets/pull/51
gem 'sassc-rails'
gem 'gon'
gem 'turbolinks'
gem 'uglifier'
gem 'webpacker'
# gem 'execjs', '2.7' # do no upgrade until upgrade to ruby 2.7 https://github.com/rails/execjs/issues/99
gem 'sprockets-rails'

# templates
gem 'jbuilder' # для рендеринга json
gem 'slim-rails'

# engines
gem 'pg_query' # for suggested indexes in pghero
gem 'pghero'

gem 'graphql'
gem 'graphiql-rails', group: :development
gem 'graphql-rails_logger', group: :development
gem 'ar_lazy_preload'

# background jobs
gem 'sidekiq', '~> 7.1.3' # sidekiq 7 and redis 5 do not work properly https://stackoverflow.com/questions/74314906/heartbeat-unsupported-command-argument-type-falseclass-redis
gem 'sidekiq-limit_fetch'
# gem 'sidekiq-limit_fetch', github: 'brainopia/sidekiq-limit_fetch', branch: 'master' # <- for sidekiq 6
gem 'sidekiq-unique-jobs'
gem 'sidekiq-delay_extensions'

# auth
gem 'devise'
gem 'omniauth'
gem 'omniauth-facebook'
gem 'omniauth-twitter'
gem 'omniauth-vkontakte'
gem 'omniauth-rails_csrf_protection' # provides a mitigation against CVE-2015-9284
gem 'doorkeeper'
gem 'devise-doorkeeper', github: 'morr/devise-doorkeeper', branch: 'master'
gem 'recaptcha'

# application
gem 'mal_parser', github: 'shikimori/mal_parser'
gem 'chewy', github: 'morr/chewy', branch: 'v6.0.0-i18n-fix'
gem 'rack-attack'
gem 'rack-cors'
gem 'rack-utf8_sanitizer'
gem 'mail', '2.7.1' # mail 2.8 depends on net-protocol gem which conflicts with ruby 2.6

# images processing
gem 'mini_magick' # dependence: sudo apt-get install libmagickwand-dev
gem 'mimemagic' # deploy broken w/o the dependency updated
gem 'shrine'
gem 'image_processing'

gem 'actionpack-action_caching'
gem 'attr_extras'

gem 'kt-paperclip'
gem 'paperclip-i18n'
gem 'rs_russian', github: 'morr/rs_russian', branch: 'master'
gem 'translit'
gem 'sixarm_ruby_unaccent' # adds method `unaccent`. it is used in Tags::GenerateNames
gem 'simple_form'
gem 'simple_form-magic_submit', github: 'morr/simple_form-magic_submit', branch: 'master'
gem 'active_model_serializers'
gem 'concurrent-ruby-edge'

gem 'aasm'
# [DEPRECATION] :after_commit AASM callback is not safe in terms of race conditions and redundant calls.
# Please add `gem 'after_commit_everywhere', '~> 1.0'` to your Gemfile in order to fix that.
# gem 'after_commit_everywhere'

gem 'nokogiri'
# gem 'sanitize'

# gem 'mobylette' # для is_mobile_request в application_controller#show_social?. гем добавляет :mobyle mime type. с ним в ипаде сайт падает сразу после регистрации
gem 'browser' # для детекта internet explorer в рендере shiki_editor

gem 'htmlentities' # для конвертации &#29190; -> 爆 у ворлдарта, мала и прочих
# gem 'exception_notification', github: 'smartinez87/exception_notification'
# gem 'slack-notifier'
gem 'htmldiff-lcs', github: 'nbudin/htmldiff-lcs', require: 'htmldiff'

gem 'acts_as_list'
gem 'retryable'
gem 'truncate_html'
gem 'acts_as_votable'
gem 'cancancan', github: 'morr/cancancan', branch: 'master'
gem 'draper'
gem 'draper-cancancan' # because https://github.com/CanCanCommunity/cancancan/issues/255
gem 'enumerize' # , '2.0.1' # в 2.1.0 Sidekiq::Extensions::DelayedMailer падает с "NoMethodError: undefined method `include?' for nil:NilClass"

gem 'activerecord-import' # для быстрого импорта тегов
gem 'amatch', github: 'flori/amatch' # для поиска русских имён из википедии
gem 'icalendar' # for anime calendar
gem 'ruby-esvidi', github: 'shikimori/ruby-esvidi'
gem 'matrix' # ruby 3.2 dependency of ruby-esvidi

gem 'unicode' # to downcase russian words
gem 'xxhash' # очень быстрый несекьюрный алгоритм хеширования (для comments_helper)

gem 'faraday'
gem 'faraday-cookie_jar'
gem 'faraday_middleware'
# gem 'curb' # curl client with socks proxy support

gem 'responders' # для json responder'а, который нужен для рендеринга контента на patch и put запросы

gem 'apipie-rails'
gem 'gcm'
gem 'maruku'
gem 'open_uri_redirections' # for http->https redirects. for example for loading videos fom vimeo (http://vimeo.com/113998423)
gem 'cgi', '0.3.6' # fixes capybara errors with .example.com domain in ruby >= 2.7. details in https://discuss.rubyonrails.org/t/invalid-domain-example-com-in-rspec-after-changing-session-store-to-domain-all/81922

gem 'i18n' # update only with chewy - otherwise get error of missing module
gem 'i18n-inflector', github: 'morr/i18n-inflector', branch: :master # fork fixes regular expression for parsing @ inflections
gem 'i18n-js'
gem 'rails-i18n'

gem 'shallow_attributes', github: 'morr/shallow_attributes', branch: :master
gem 'dry-types'

group :beta, :production do
  gem 'unicorn'
  # gem 'airbrake'
  # gem 'sentry-raven'
  gem 'honeybadger'
  # gem 'honeybadger', '~> 5.0'
  # gem 'appsignal'
  # gem 'sentry-ruby'
  # gem 'sentry-rails'
  # gem 'bugsnag'
  gem 'lograge'
  # gem 'newrelic_rpm'
end

group :development do
  # gem 'meta_request'
  # gem 'rails_panel'

  gem 'spring'
  gem 'spring-watcher-listen'

  gem 'letter_opener'
  gem 'mactag'

  gem 'better_errors'
  gem 'binding_of_caller'
  # gem 'bullet'

  # gem 'web-console'
  # gem 'listen'

  gem 'airbrussh', require: false
  gem 'capistrano'
  gem 'capistrano-bundler', require: false
  gem 'capistrano-copy-files', require: false
  gem 'capistrano-rails', require: false
  gem 'capistrano-rbenv', require: false

  gem 'active_record_query_trace'
end

gem 'amazing_print'
# gem 'awesome_print', github: 'edipofederle/awesome_print', branch: 'fix-marshal-dump' # https://github.com/awesome-print/awesome_print/pull/415 https://github.com/awesome-print/awesome_print/issues/413
gem 'colorize'
gem 'pry-byebug'
gem 'pry-rails'

group :development, :test do
  gem 'dotenv-rails'
  gem 'puma'

  gem 'rb-fchange', require: false
  gem 'rb-fsevent', require: false
  gem 'rb-inotify', require: false

  gem 'rspec'
  gem 'spring-commands-rspec'

  # gem 'rack-mini-profiler', require: false
  # gem 'flamegraph', require: false # for flame graph in rack-mini-profiler
  gem 'stackprof', require: false # for flamegraph

  gem 'guard', require: false
  gem 'guard-bundler', require: false
  gem 'guard-i18n-js', require: false, github: 'morr/guard-i18n-js'
  gem 'guard-pow', require: false
  gem 'guard-rspec', require: false
  gem 'guard-rubocop', require: false
  gem 'guard-spring', require: false
  gem 'guard-brakeman', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false

  gem 'parallel_tests'
end

group :test do
  gem 'capybara', '3.36.0' # request specs failing with 3.39.2 version
  gem 'database_cleaner'
  gem 'factory_girl-seeds',
    require: false,
    github: 'morr/factory_girl-seeds',
    branch: 'use-factory-bot'
  gem 'factory_bot_rails', require: false
  gem 'rails-controller-testing' # it allows use `assigns` method in specs
  gem 'rspec-collection_matchers'
  gem 'rspec-core'
  gem 'rspec-expectations'
  gem 'rspec-its'
  gem 'rspec-mocks'
  gem 'rspec-rails'
  gem 'rspec_junit_formatter'
  gem 'fuubar'

  gem 'shoulda-matchers'
  gem 'timecop'
  gem 'vcr'
  gem 'webmock', require: false
end

gem 'clockwork', require: false

gem 'faye'
gem 'thin'

gem 'rexml', '~> 3.2' # added to fix ruby 3 on production
