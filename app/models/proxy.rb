# sudo apt-get install libjpeg-progs
class Proxy < ActiveRecord::Base
  SAFE_ERRORS = /queue empty|execution expired|banned|connection refused|connection reset by peer|no route to host|end of file reached/i
  cattr_accessor :use_proxy, :use_cache, :show_log

  # список проксей
  @@proxies = nil
  # изначальное число проксей
  @@proxies_initial_size = 0

  # использовать ли кеш
  @@use_cache = false #Rails.env == 'test'

  # показывать ли логи
  @@show_log = false

  # использовать ли прокси
  @@use_proxy = true

  class << self
    # загрузка проксей из базы
    def preload
      queue = Queue.new
      Proxy.all.shuffle.each { |v| queue.push v }

      @@proxies_initial_size = queue.size
      @@proxies = queue
    end

    # гет запрос через прокси
    def get url, options = {}
      process url, options, :get
    end

    # пост запрос через прокси
    def post url, options = {}
      process url, options, :post
    end

    # выполнение запроса через прокси или из кеша
    def process url, options, method
      if @@use_cache && File.exists?(cache_path(url, options)) && (1.month.ago < File.ctime(cache_path(url, options)))
        NamedLogger.proxy.info "CACHE #{url} (#{cache_path(url, options)})"
        return File.open(cache_path(url, options), "r") { |h| h.read }
      end

      # получаем контент
      content = if options[:no_proxy] || @@use_cache || !@@use_proxy
        if method == :get
          no_proxy_get url, options
        else
          no_proxy_post url, options
        end
      else
        do_request url, options.merge(method: method)
      end

      # фиксим кодировки
      content = content.fix_encoding(options[:encoding]) if content && url !~ /\.(jpg|gif|png|jpeg)/i

      # кешируем
      if content && content.present? && (options[:test] || @@use_cache)
        File.open(cache_path(url, options), "w") { |h| h.write(content) }
      end

      content
    end

    # выполнение запроса
    def do_request url, options
      preload if (options[:proxy].nil? && @@proxies.nil?) || (@@proxies && @@proxies.size < @@proxies_initial_size / 7)
      raise NoProxies.new(url) if options[:proxy].nil? && @@proxies.empty?

      content = nil
      proxy = options[:proxy] # прокси может быть передана в параметрах, тогда использоваться будет лишь она

      max_attempts = options[:attempts] || 8
      options[:timeout] ||= 15

      attempts = 0 # число попыток
      freeze_count = 50 # число переборов проксей

      until content || attempts == max_attempts || freeze_count <= 0 do
        freeze_count -= 1

        begin
          proxy ||= @@proxies.pop(true) # кидает "ThreadError: queue empty" при пустой очереди
          log "#{options[:method].to_s.upcase} #{url}#{ options[:data] ? " "+options[:data].map { |k,v| "#{k}=#{v}" }.join('&') : ''} via #{proxy.to_s}", options

          Timeout::timeout(options[:timeout]) do
            content = if options[:method] == :get
              #Net::HTTP::Proxy(proxy.ip, proxy.port).get(uri) # Net::HTTP не следует редиректам, в топку его
              get_open_uri(url, proxy: proxy.to_s(true)).read
            else
              Net::HTTP::Proxy(proxy.ip, proxy.port).post_form(URI.parse(url), options[:data]).body
            end
          end
          raise "#{proxy.to_s} banned" if content.nil?

          # фикс кодировок перед проверкой текста
          content = content.fix_encoding(options[:encoding]) if content && url !~ /\.(jpg|gif|png|jpeg)/i
          raise "#{proxy.to_s} banned" if content.blank?

          # проверка валидности jpg
          if options[:validate_jpg]
            tmpfile = Tempfile.new 'jpg'
            File.open(tmpfile.path, 'wb') {|f| f.write content }
            tmpfile.instance_variable_set :@original_filename, url.split('/').last
            def tmpfile.original_filename; @original_filename; end

            unless ImageChecker.valid? tmpfile.path
              content = nil
              # тут можно бы обнулять tmpfile, но если мы 8 раз не смогли загрузить файл, то наверное его и правда нет, падать не будем
              log "bad image", options
            end
          end

          # проверка на наличие запрошенного текста
          if options[:required_text]
            requires = if options[:required_text].kind_of?(Array)
              options[:required_text]
            else
              [options[:required_text]]
            end

            stripped_content = content.gsub(/[ \n\r]+/, '').downcase
            raise "#{proxy.to_s} banned" unless requires.all? { |text| stripped_content.include?(text.gsub(/[ \n\r]+/, '').downcase) }
          end

          # проверка на забаненны тексты
          if options[:ban_texts]
            options[:ban_texts].each do |text|
              raise "#{proxy.to_s} banned" if text.class == Regexp ? content.match(text) : content.include?(text)
            end
          end

          # и надо не забыть вернуть проксю назад
          @@proxies.push(proxy) unless options[:proxy]

          attempts += 1

        rescue Exception => e
          raise if defined?(VCR) && e.kind_of?(VCR::Errors::UnhandledHTTPRequestError)
          if e.message =~ SAFE_ERRORS
            log "#{e.message}", options
          else
            log "#{e.message}\n#{e.backtrace.join("\n")}", options
          end

          proxy = nil
          content = nil

          exit if e.class == Interrupt
          break if options[:proxy] # при указании прокси делаем лишь одну попытку
        end
      end

      log "can't get page #{url}", options if content.nil?

      if options[:return_file]
        tmpfile
      else
        content
      end
    end

    # выполнение get запроса без прокси
    def no_proxy_get url, options
      NamedLogger.proxy.info "GET #{url}"

      resp = get_open_uri URI.encode(url)
      file = if resp.meta["content-encoding"] == "gzip"
        Zlib::GzipReader.new(StringIO.new(resp.read))
      else
        resp
      end

      options[:return_file] ? file : file.read

    rescue Exception => e
      raise if defined?(VCR) && e.kind_of?(VCR::Errors::UnhandledHTTPRequestError)
      if e.message =~ SAFE_ERRORS
        log "#{e.message}", options
      else
        log "#{e.message}\n#{e.backtrace.join("\n")}", options
      end

      exit if e.class == Interrupt
      nil
    end

    # выполнение post запроса без прокси
    def no_proxy_post(url, options)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      path = uri.path
      #cookie = resp.response['set-cookie']

      # POST request -> getting data
      data = options[:data].map { |k,v| "#{k}=#{v}" }.join('&')
      headers = {
        #'Cookie' => cookie,
        'Referer' => url,
        'Content-Type' => 'application/x-www-form-urlencoded'
      }

      NamedLogger.proxy.info "POST #{url} #{data}"
      resp = http.post(path, data, headers)
      resp.body
    rescue Exception => e
      raise if defined?(VCR) && e.kind_of?(VCR::Errors::UnhandledHTTPRequestError)
      if e.message =~ SAFE_ERRORS
        log "#{e.message}", options
      else
        log "#{e.message}\n#{e.backtrace.join("\n")}", options
      end

      exit if e.class == Interrupt
      nil
    end

    # адрес страницы в кеше
    def cache_path url, options
      Dir.mkdir('tmp/cache/pages') unless Rails.env.test? || File.exists?('tmp/cache/pages')
      (Rails.env == 'test' ? 'spec/pages/%s' : 'tmp/cache/pages/%s') % Digest::MD5.hexdigest(options[:data] ? "#{url}_data:#{options[:data].map { |k,v| "#{k}=#{v}" }.join('&')}" : url)
    end

    # логирование
    def log message, options
      print "[Proxy]: #{message}\n" if options[:log] || @@show_log
    end

    def off!
      @@use_proxy = false
    end

    def on!
      @@use_proxy = true
    end

    def get_open_uri url, params = {}
      if url =~ /\.(jpe?g|png)$/
        open_image url, open_params(url, params)
      else
        open url, open_params(url, params)
      end
    end

    def open_params url, params
      params.merge(
        'User-Agent' => user_agent(url),
        'Cookie' => cookie(url),
        allow_redirections: :all
      )
    end

    def user_agent _url
      'Mozilla/5.0 (Windows NT 6.3; rv:36.0) Gecko/20100101 Firefox/36.0'

      #if url =~ /myanimelist.net/
      #  'api-malupdater-989B0AD8068FA18E49825724D2B8E68B'
      #else
      #  'Mozilla/5.0 (Windows NT 6.3; rv:36.0) Gecko/20100101 Firefox/36.0'
      #end
    end

    def cookie url
      if url =~ %r{myanimelist.net/(?:anime|manga)/\d+/?\w*$}
        %w(
          MALHLOGSESSID=94988ef1f0cc270c6541e35258eb08f9;
          MALSESSIONID=9tp6dm89d1up518icv73hjelm0;
          is_logged_in=1;
        ).join
      else
        ''
      end
    end

  end

  def to_s with_http = false
    with_http ? "http://#{ip}:#{port}" : "#{ip}:#{port}"
  end
end
