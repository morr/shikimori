source 'https://rubygems.org'

gem 'rake'
gem 'rails', '4.2.7.1'

gem 'pg'
gem 'dalli' # NOTE: в конфиге мемкеша должна быть опция -I 16M
gem 'redis'
gem 'redis-namespace'

gem 'slim-rails'
gem 'coffee-rails'

gem 'sass-rails'
gem 'compass-rails'
gem 'turbolinks', github: 'morr/turbolinks', branch: 'master'
gem 'jade-rails', github: 'GBH/jade-rails'
gem 'd3_rails'

gem 'uglifier'
gem 'non-stupid-digest-assets'
gem 'activerecord-collection_cache_key' # NOTE: remove after upgrading to rails 5

gem 'mal_parser', github: 'shikimori/mal_parser'

gem 'rmagick' # dependence: sudo apt-get install libmagickwand-dev
gem 'unicorn'
gem 'rack-cors'
gem 'rack-utf8_sanitizer'
gem 'rack-attack'

gem 'multi_fetch_fragments', github: 'watg/multi_fetch_fragments'
gem 'actionpack-action_caching'
gem 'attribute-defaults'
gem 'attr_extras'
gem 'state_machine'
gem 'nokogiri'
gem 'paperclip', '5.1.0'
gem 'rs_russian'
gem 'metrika'
gem 'simple_form'
gem 'simple_form-magic_submit', github: 'morr/simple_form-magic_submit'
#gem 'simple_form-magic_submit', path: '/Users/morr/Develop/simple_form-magic_submit/'
gem 'active_model_serializers', github: 'rails-api/active_model_serializers', branch: '0-8-stable' # https://github.com/rails-api/active_model_serializers/issues/641

#gem 'mobylette' # для is_mobile_request в application_controller#show_social?. гем добавляет :mobyle mime type. с ним в ипаде сайт падает сразу после регистрации
gem 'browser' # для детекта internet explorer в рендере shiki_editor
gem 'devise'
gem 'devise-async' # асинхронная отсылка писем для devise

gem 'omniauth'
gem 'omniauth-facebook'
gem 'omniauth-vkontakte'
gem 'omniauth-twitter'

gem 'pghero'
gem 'sidekiq'
gem 'sidekiq-unique-jobs'
gem 'sidekiq-limit_fetch'
gem 'redis-mutex'

gem 'htmlentities' # для конвертации &#29190; -> 爆 у ворлдарта, мала и прочих
#gem 'exception_notification', github: 'smartinez87/exception_notification'
#gem 'slack-notifier'
gem 'awesome_print'
gem 'htmldiff', github: 'myobie/htmldiff'

gem 'retryable'
gem 'truncate_html'
gem 'acts-as-taggable-on'
gem 'meta-tags'
gem 'enumerize'
gem 'draper'
gem 'cancancan', github: 'morr/cancancan', branch: 'master'
gem 'draper-cancancan' # because https://github.com/CanCanCommunity/cancancan/issues/255

gem 'unicode' # для downcase русских слов
gem 'icalendar' # для аниме календраря
gem 'activerecord-import' # для быстрого импорта тегов
gem 'amatch', github: 'flori/amatch' # для поиска русских имён из википедии
gem 'ruby-svd', github: 'morr/Ruby-SVD' # для SVD рекомендаций. ruby 2.0
gem 'xxhash' # очень быстрый несекьюрный алгоритм хеширования (для comments_helper)
gem 'faraday'
gem 'faraday_middleware'

gem 'jbuilder' # для рендеринга json
gem 'rack-contrib' # для поддержки jsonp в api
# TODO: выпилить отовсюду rabl, заменив его на jbuilder
gem 'rabl' # для рендеринга json
gem 'responders' # для json responder'а, который нужен для рендеринга контента на patch и put запросы
gem 'zaru'

gem 'apipie-rails', '0.3.3' # 0.3.4 сломан
gem 'gcm'
gem 'open_uri_redirections' # для работы http->https редиректов. например, при загрузке видео с vimeo (http://vimeo.com/113998423)

gem 'i18n-js', '3.0.0.rc14'
gem 'rails-i18n'
gem 'i18n-inflector-rails'

gem 'dry-struct'
gem 'chainable_methods'

group :beta, :production do
  gem 'honeybadger'
  gem 'appsignal'
  gem 'newrelic_rpm'
  gem 'lograge'
end

group :development do
  gem 'spring'
  gem 'letter_opener'
  gem 'quiet_assets'
  gem 'mactag'
  #gem 'web-console'
  gem 'better_errors'
  gem 'binding_of_caller'

  # gem 'rack-mini-profiler'
  # gem 'flamegraph' # for flame graph in rack-mini-profiler
  # gem 'stackprof', require: false # for flamegraph

  gem 'capistrano'
  gem 'capistrano-rails', require: false
  gem 'capistrano-bundler', require: false
  #gem 'slackistrano', require: false
  gem 'rvm1-capistrano3', require: false
  gem 'airbrussh', require: false
  # gem 'rails-flog', require: 'flog'
  gem 'active_record_query_trace'

  # gem 'foreman', github: 'morr/foreman' # для управления бекграунд процессами
end

gem 'byebug'
gem 'colorize'
gem 'marco-polo'
gem 'pry-byebug'
gem 'pry-rails'
gem 'pry-stack_explorer'

group :test, :development do
  gem 'rb-inotify', require: false
  gem 'rb-fsevent', require: false
  gem 'rb-fchange', require: false

  gem 'rspec'
  gem 'rspec-core'
  gem 'rspec-expectations'
  gem 'rspec-mocks'
  gem 'rspec-rails'
  gem 'rspec-collection_matchers'
  gem 'rspec-its'

  gem 'spring-commands-rspec'

  gem 'guard', require: false
  gem 'guard-rspec', require: false
  gem 'guard-bundler', require: false
  gem 'guard-spring', require: false
  gem 'guard-pow', require: false
  gem 'guard-rubocop', require: false
  gem 'guard-i18n-js', require: false, github: 'fauxparse/guard-i18n-js'
end

group :test do
  gem 'capybara'
  gem 'database_cleaner'
  gem 'factory_girl_rails', require: false
  gem 'factory_girl-seeds', require: false
  gem 'shoulda-matchers'
  gem 'timecop'
  gem 'vcr'
  gem 'webmock', require: false
end

gem 'acts_as_voteable', github: 'morr/acts_as_voteable', branch: 'master'

gem 'whenever', require: false
gem 'clockwork', require: false

gem 'faye'
gem 'faye-redis'
gem 'faye-websocket', '0.10.0' # не обновлять до 0.10.1 - ломается faye
gem 'thin'

# assets
source 'https://rails-assets.org' do
  # gem 'rails-assets-moment'
  gem 'rails-assets-pikaday'
  gem 'rails-assets-urijs'

  # dependencies for rails-assets-packery'
  gem 'rails-assets-fizzy-ui-utils', '2.0.2'
  gem 'rails-assets-get-size', '2.0.2'
  gem 'rails-assets-matches-selector', '2.0.1'
  gem 'rails-assets-outlayer', '2.1.0'

  gem 'rails-assets-sugar'
  gem 'rails-assets-jquery', '2.2.4'
  gem 'rails-assets-jquery-bridget', '2.0.0' # packery dependency
  gem 'rails-assets-packery'
  gem 'rails-assets-jQuery-Storage-API'
  gem 'rails-assets-imagesloaded'
  gem 'rails-assets-magnific-popup'
  gem 'rails-assets-nouislider'
  gem 'rails-assets-js-md5'
  gem 'rails-assets-uevent'

  # it's time to experiment with a new tool
  # gem 'rails-assets-vue'
end
