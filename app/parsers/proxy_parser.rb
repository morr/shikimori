# rubocop:disable all

# http://pastebin.com/r2Xz6i0M
# https://www.google.com/search?q=free+proxy+blogspot&rlz=1C5CHFA_enRU910RU910&sxsrf=APq-WBvtLh2iPJ7rqyTXESAfXnHGffsZ0Q%3A1648065445172&ei=pXs7Yo6FCsmEwPAPx4uM0A4&ved=0ahUKEwjO67Obgt32AhVJAhAIHccFA-oQ4dUDCA4&uact=5&oq=free+proxy+blogspot&gs_lcp=Cgdnd3Mtd2l6EAMyBggAEAcQHjIGCAAQCBAeOgcIABBHELADOgcIIxCwAhAnOggIABAHEB4QEzoKCAAQCBAHEB4QEzoICAAQDRAeEBM6CggAEA0QBRAeEBM6CggAEAgQDRAeEBM6DAgAEAgQDRAKEB4QEzoICAAQCBAHEB5KBAhBGABKBAhGGABQoQVYrApgmgtoAXABeACAAWOIAa0DkgEBNZgBAKABAcgBCMABAQ&sclient=gws-wiz
class ProxyParser
  IS_DB_SOURCES = true
  IS_URL_SOURCES = true
  IS_OTHER_SOURCES = true
  IS_CUSTOM_SOURCES = true

  CACHE_VERSION = :v10

  CUSTOM_SOURCES = %i[hidemyname proxyshare_com] # proxylist_geonode_com

  def import(
    is_db_sources: IS_DB_SOURCES,
    is_url_sources: IS_URL_SOURCES,
    is_other_sources: IS_OTHER_SOURCES,
    is_custom_sources: IS_CUSTOM_SOURCES,
    additional_url_sources: {},
    additional_text: ''
  )
    proxies = fetch(
      is_url_sources: is_url_sources,
      is_other_sources: is_other_sources,
      is_custom_sources: is_custom_sources,
      additional_url_sources: additional_url_sources,
      additional_text: additional_text
    )
    sync_db proxies
    Proxy.alive
  end

  def fetch(
    is_db_sources: IS_DB_SOURCES,
    is_url_sources: IS_URL_SOURCES,
    is_other_sources: IS_OTHER_SOURCES,
    is_custom_sources: IS_CUSTOM_SOURCES,
    additional_url_sources: {},
    additional_text: ''
  )
    parsed_proxies = parse_proxies(
      is_url_sources: is_url_sources,
      is_other_sources: is_other_sources,
      is_custom_sources: is_custom_sources,
      additional_url_sources: additional_url_sources,
      additional_text: additional_text
    )
    db_proxies = is_db_sources ?
      Proxy.all.to_a :
      []

    print format("found %<size>i proxies\n", size: parsed_proxies.size)
    print format("fetched %<size>i proxies\n", size: db_proxies.size)

    proxies = (db_proxies + parsed_proxies).uniq(&:to_s)
    print format("%<size>i after uniq & merge with previously parsed\n", size: proxies.size)

    verified_proxies = test_concurrently proxies, Proxies::WhatIsMyIps.call

    print(
      format(
        "%<verified_size>i of %<total_size>i proxies were tested for anonymity\n",
        verified_size: verified_proxies.size,
        total_size: proxies.size
      )
    )

    verified_proxies
  end

private

  def sync_db proxies
    Proxy.update_all('dead = dead +1')
    Proxy.where(id: proxies.select(&:persisted?).map(&:id)).update_all dead: 0
    Proxy.import proxies.select(&:new_record?)
  end

  def parse url, protocol
    sleep 1 # задержка, чтобы не банили

    content =
      if url.in? SELENIUM_URLS
        Network::FirefoxGet.call url
      else
        OpenURI.open_uri(url, Proxy.prepaid_proxy_open_uri).read
      end
      .gsub(%r{<br ?/?>}, "\n")

    content = Nokogiri::HTML(content).text if content.starts_with?('<!')

    proxies = parse_text content, protocol
    if proxies.none? && content.starts_with?('<!')
      proxies = parse_text Nokogiri::HTML(content).text, protocol
    end
    print "#{url} - #{proxies.size} proxies\n"

    proxies
  rescue StandardError => e
    print "#{url}: #{e.message}\n"
    []
  end

  def parse_text text, protocol
    text
      .gsub(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}[:\t\n\s]+\d+/)
      .map do |v|
        data = v.split(/[:\t\n\s]+/)
        build_proxy ip: data[0], port: data[1], protocol: protocol
      end
  end

  def test_concurrently proxies, ips
    proxies = proxies
    verified_proxies = Concurrent::Array.new
    proxies_count = proxies.size

    print "testing #{proxies.size} proxies\n"

    pool = Concurrent::FixedThreadPool.new(Concurrent.processor_count * 8)
    # pool = Concurrent::FixedThreadPool.new(5)
    # pool = Concurrent::CachedThreadPool.new
    index = Concurrent::AtomicFixnum.new(-1)

    proxies.each do |proxy|
      pool.post do
        current_index = index.increment
        is_verified = Proxies::Check.call proxy: proxy, ips: ips

        print "tested #{current_index + 1}/#{proxies_count} proxy #{is_verified  ? '✅' : '❌'} #{proxy}\n"

        verified_proxies << proxy if is_verified
      end
    end

    loop do
      sleep 2
      break if pool.queue_length.zero?
    end
    pool.kill

    print "testing complete\n"

    verified_proxies
  end

  def other_sources
    Rails.cache.fetch([:proxy, :other_sources, CACHE_VERSION], expires_in: 6.hours) do
      getfreeproxylists + webanetlabs
    end
  end

  def webanetlabs
    Nokogiri::HTML(
      OpenURI.open_uri(
        'https://webanetlabs.net/publ/24',
        ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE,
        **Proxy.prepaid_proxy_open_uri
      ).read
    )
      .css('.uSpoilerText a.link')
      .map { |v| 'https://webanetlabs.net' + v.attr(:href) }
  rescue StandardError => e
    print "webanetlabs: #{e.message}\n"
    []
  end

  def getfreeproxylists url = 'https://getfreeproxylists.blogspot.com/'
    return []

    html = Nokogiri::HTML(OpenURI.open_uri(url, Proxy.prepaid_proxy_open_uri).read)
    links = html.css('ul.posts a').map { |v| v.attr :href }

    [url] + links
  end

  def parse_proxies(
    is_url_sources:,
    is_other_sources:,
    is_custom_sources:,
    additional_url_sources:,
    additional_text: ''
  )
    other_sourced_proxies = is_other_sources ? (
      other_sources.flat_map do |url|
        Rails.cache.fetch([url, :proxies, CACHE_VERSION], expires_in: 6.hours) { parse url, :http }
      end 
    ) : []

    (
      (is_url_sources ? url_sourced_proxies(URL_SOURCES) : []) +
        url_sourced_proxies(additional_url_sources) +
        other_sourced_proxies +
        (is_custom_sources ? custom_sourced_proxies : []) +
        parse_text(additional_text, :http)
    ).uniq
  end

  def url_sourced_proxies url_sources
    url_sources.flat_map do |(protocol, urls)|
      urls.flat_map do |url|
        Rails.cache.fetch([url, :proxies, CACHE_VERSION], expires_in: 6.hours) do
          parse url, protocol
        end
      end
    end
  end

  def custom_sourced_proxies
    CUSTOM_SOURCES.flat_map { |method| send method }
  end

  def hidemyname
    # purchased at 25-09-2024 until 25-09-2025
    url = 'https://hidemy.name/api/proxylist.php?out=js&lang=en&utf&code=138782283104956'

    data =
      Rails.cache.fetch([url, :proxies, CACHE_VERSION], expires_in: 6.hours) do
        OpenURI.open_uri(url, Proxy.prepaid_proxy_open_uri).read
      end

    JSON.parse(data, symbolize_names: true).map do |entry|
      build_proxy(
        ip: entry[:ip],
        port: entry[:port],
        protocol: (
          if entry[:http] == '1'
            :http
          elsif entry[:ssl] == '1'
            :https
          elsif entry[:socks4] == '1'
            :socks4
          elsif entry[:socks5] == '1'
            :socks5
          else
            raise "unknown protocol: #{entry.to_json}"
          end
        )
      )
    end
  end

  # it is the same as proxyshare_com
  # def proxylist_geonode_com
  #   url = 'https://proxylist.geonode.com/api/proxy-list?limit=500&page=1&sort_by=lastChecked&sort_type=desc&protocols=http%2Chttps%2Csocks4%2Csocks5'
  #   data =
  #     Rails.cache.fetch([url, :proxies, CACHE_VERSION], expires_in: 6.hours) do
  #       OpenURI.open_uri(url, Proxy.prepaid_proxy_open_uri).read
  #     rescue *Network::FaradayGet::NET_ERRORS
  #       '{"data":[]}'
  #     end
  #  
  #   JSON.parse(data, symbolize_names: true)[:data].map do |entry|
  #     build_proxy(
  #       ip: entry[:ip],
  #       port: entry[:port],
  #       protocol: entry[:protocols][0]
  #     )
  #   end
  # end

  def proxyshare_com page = 1
    url = "https://proxylist.geonode.com/api/proxy-list?limit=500&page=#{page}&sort_by=lastChecked&sort_type=desc&protocols=http%2Chttps%2Csocks4%2Csocks5"
    data =
      Rails.cache.fetch([url, :proxies, CACHE_VERSION], expires_in: 6.hours) do
        OpenURI.open_uri(url, Proxy.prepaid_proxy_open_uri).read
      rescue *Network::FaradayGet::NET_ERRORS
        '{"data":[]}'
      end

    data = JSON.parse(data, symbolize_names: true)

    proxies = data[:data].map do |entry|
      build_proxy(
        ip: entry[:ip],
        port: entry[:port],
        protocol: entry[:protocols][0]
      )
    end

    sleep 1

    if data[:page] && data[:page] * data[:limit] < data[:total]
      proxies + proxyshare_com(page + 1)
    else
      proxies
    end
  end

  def build_proxy ip:, port:, protocol:
    raise port.to_s if port.to_s.size > 5
    Proxy.new ip: ip, port: port.to_i, protocol: protocol
  end

  URL_SOURCES = {
    http: %w[
      https://raw.githubusercontent.com/TheSpeedX/SOCKS-List/master/http.txt
      https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/http/data.txt
      https://free-proxy-list.net/
      https://rootjazz.com/proxies/proxies.txt
      http://my-proxy.com/free-proxy-list-10.html
      http://my-proxy.com/free-proxy-list-2.html
      http://my-proxy.com/free-proxy-list-3.html
      http://my-proxy.com/free-proxy-list-4.html
      http://my-proxy.com/free-proxy-list-5.html
      http://my-proxy.com/free-proxy-list-6.html
      http://my-proxy.com/free-proxy-list-7.html
      http://my-proxy.com/free-proxy-list-8.html
      http://my-proxy.com/free-proxy-list-9.html
      http://my-proxy.com/free-proxy-list.html
      https://www.newproxys.com/free-proxy-lists/
      https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=10000&country=all&ssl=all&anonymity=elite&simplified=true&limit=300
      http://multiproxy.org/txt_all/proxy.txt
      https://www.cybersyndrome.net/pla6.html
      https://cyber-gateway.net/get-proxy/free-proxy/24-free-http-proxy
      https://spys.me/proxy.txt
      https://www.proxyshare.com/detection/proxyList?limit=500&page=1&sort_by=lastChecked&sort_type=desc
    ],
    https: %w[
    ],
    socks4: %w[
      https://raw.githubusercontent.com/TheSpeedX/SOCKS-List/master/socks4.txt
      https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/socks4/data.txt
      https://www.my-proxy.com/free-socks-4-proxy.html
    ]
  }
  URL_SOURCES[:socks5] = %w[
    https://raw.githubusercontent.com/TheSpeedX/SOCKS-List/master/socks5.txt
    https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/protocols/socks5/data.txt
    https://www.my-proxy.com/free-socks-5-proxy.html
    https://list.proxylistplus.com/Socks-List-1
    https://list.proxylistplus.com/Socks-List-2
    https://cyber-gateway.net/get-proxy/free-proxy/56-free-socks-proxy
    https://cyber-gateway.net/get-proxy/free-proxy/57-free-proxy-google
  ] + URL_SOURCES[:socks4]

  SELENIUM_URLS = %w[
    https://www.cybersyndrome.net/pla6.html
  ]
end
