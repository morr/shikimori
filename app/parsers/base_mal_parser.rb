class BaseMalParser < SiteParserWithCache
  include MalFetcher
  include MalDeployer

  ENTRIES_PER_PAGE = 50
  THREADS = 50

  BANNED_IDS_CONFIG_PATH = "#{Rails.root}/config/app/banned_mal_ids.yml"

  def genres
    @genres ||= Genre.all
      .each_with_object({'anime' => {}, 'manga' => {}}) do |genre, memo|
        memo[genre.kind][genre.mal_id] = genre
      end
  end

  def studios
    @studios ||= Studio.all
      .each_with_object({}) do |studio, memo|
        memo[studio.id] = studio
      end
  end

  def publishers
    @publishers ||= Publisher.all
      .each_with_object({}) do |publisher, memo|
        memo[publisher.id] = publisher
      end
  end

  def cached_list
    @cache[:list] ||= {}
  end

  def mal_fixes
    @mal_fixes ||= begin
      mal_fixes_path = Rails.root.join('config/mal_fixes.yml')
      YAML::load(File.open(mal_fixes_path))[type.to_sym] || {}
    end
  end

  def apply_mal_fixes id, data
    return data unless mal_fixes[id]
    mal_fixes[id].each { |k, v| data[:entry][k] = v }
    data
  end

  def self.import ids = nil
    self.new.import(ids)
  end

  # импорт всех новых и помеченных к импорту элементов
  def import ids = nil
    Proxy.preload
    # timeout: 90, log: true debug_log: true }
    ThreadPool.defaults = { threads: THREADS }
    #@proxy_log = true
    @import_mutex = Mutex.new

    klass = type.camelize.constantize

    print "loading %s for import\n" % [type.tableize] if Rails.env != 'test'
    # если передан id, то импортировать только элемент с указанным id
    data = (ids ? Array(ids) : prepare) - banned_ids

    print "%d %s to import\n" % [data.size, type.tableize] if Rails.env != 'test'
    data.send(Rails.env == 'test' ? :each : :parallel) do |id|
      begin
        print "downloading %s %s\n" % [type, id] if Rails.env != 'test'
        fetched_data = fetch_entry id

        # применение mal_fixes
        apply_mal_fixes id, fetched_data

        entry = klass.find_by(id: id) || klass.create!(id: id, name: fetched_data[:entry][:name])
        @import_mutex.synchronize do
          print "deploying %s %s %s\n" % [type, id, entry.name] if Rails.env != 'test'
          deploy entry, fetched_data
        end
        print "successfully imported %s %s %s\n" % [type, id, entry.name] if Rails.env != 'test'
      rescue Exception => e
        print "%s\n%s\n" % [e.message, e.backtrace.join("\n")] if Rails.env == 'test' || e.class != EmptyContent
        print "failed import for %s %s\n" % [type, id] if Rails.env != 'test'
        exit if e.class == Interrupt
      end
    end
  end

  # сбор списка элементов, которые будем импортировать
  def prepare
    klass = type.camelize.constantize

    all_ids = klass.pluck(:id)
    new_ids = cached_list.keys - all_ids
    outdated_ids = klass.where(imported_at: nil).pluck(:id)

    new_ids + outdated_ids
  end

  def banned_ids
    @banned_ids ||= YAML.load_file(BANNED_IDS_CONFIG_PATH)[type.to_sym]
  end

  # загрузка полного списка с MAL
  def fetch_list_pages options = {}
    options = {
      offset: 0,
      limit: 99999,
      url_getter: :all_catalog_url
    }.merge(options)

    #total_entries_found = 0
    page = options[:offset]
    all_found_entrires = []

    begin
      entries_found = fetch_list_page(page, options[:url_getter])
      all_found_entrires += entries_found
      #total_entries_found += entries_found
      page += 1 if entries_found.any?
    rescue Exception => e
      print "%s\n%s\n" % [e.message, e.backtrace.join("\n")]
      break
    end while entries_found.any? && page < options[:limit]

    #total_entries_found
    save_cache
    all_found_entrires
  end

  # загрузка страницы списка
  def fetch_list_page(page, url_getter)
    max_attempts = 5
    entries_found = []
    attempt = 0

    url = self.send(url_getter, page)
    begin
      attempt += 1
      content = get(url, 'Search Results')
      next unless content
      doc = Nokogiri::HTML(content)

      doc.css("div.list > table tr").each do |tr|
        tds = tr.css('td')
        next if tds[0].css('img').none?

        entry = {}
        entry[:img_preview] = tds[0].css('img')[0]['src']
        entry[:url] = tds[1].css('a')[0]['href']
        entry[:id] = entry[:url].match(/\/(\d+)\//)[1].to_i
        entry[:name] = tds[1].css('a > strong')[0].inner_html

        cached_list[entry[:id]] = entry
        entries_found << entry[:id]
      end

      break if entries_found.any?
    end while attempt < max_attempts

    if entries_found.empty?
      print "page %i fetched successfully, but found 0 entries\n" % page
    else
      print "page %i fetched successfully, found %i entries\n" % [page, entries_found.size]
    end unless Rails.env == 'test'

    entries_found
  end

  private

  # получение страницы MAL
  def get(url, required_text = ['MyAnimeList.net</title>', '</html>'])
    content = super(url, required_text)
    # binding.pry unless content
    raise EmptyContent.new(url) unless content
    raise InvalidId.new(url) if content.include?("Invalid ID provided") ||
                                content.include?("No manga found, check the manga id and try again") ||
                                content.include?("No series found, check the series id and try again")
    raise ServerUnavailable.new(url) if content.include?("MyAnimeList servers are under heavy load")
    content
  end

  def updated_catalog_url(page)
    "https://myanimelist.net/#{type}.php?o=9&c[]=a&c[]=d&cv=2&w=1&show=#{page * ENTRIES_PER_PAGE}"
  end

  def all_catalog_url(page)
    "https://myanimelist.net/#{type}.php?letter=&q=&tag=&sm=0&sd=0&em=0&ed=0&c[0]=b&c[1]=c&c[2]=a&show=#{page * ENTRIES_PER_PAGE}"
  end

  def entry_url(id)
    "https://myanimelist.net/#{type}/#{id}"
  end

  # AnimeMalParser => 'anime'
  def type
    @type ||= self.class.name.match(/[A-Z][a-z]+/)[0].downcase
  end

  def processed_description_en id, content
    value = parse_synopsis(content)
    DbEntries::ProcessDescription.new.(value, type, id)
  end
end
