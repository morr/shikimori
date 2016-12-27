# парсер аккаунта anime-planet
# klass: Anime или Manga
# wont_watch_strategy - nil или :dropped
class UserListParsers::AnimePlanetListParser
  def initialize klass, wont_watch_strategy = nil
    @klass = klass
    @wont_watch_strategy = UserRate.statuses[wont_watch_strategy]
  end

  def parse login
    1.upto(pages_count(login)).flat_map do |page|
      find_matches parse_page login, page
    end
  end

private

  # заполнение id для собранного списка
  def find_matches entries
    entries.each do |entry|
      entry[:id] = find_match entry
    end
  end

  # получение id для найденного элемента
  def find_match entry
    matches = NameMatches::FindMatches.call(
      entry[:name],
      @klass,
      year: entry[:year],
      episodes: entry[:episodes]
    )

    matches.first.id if matches.one? && entry[:status]
  end

  # получение списка того, что будем импортировать
  def parse_page login, page
    content = get("http://www.anime-planet.com/users/#{login}/#{@klass.name.downcase}/all?page=#{page}")
    doc = Nokogiri::HTML(content)

    doc.css('.pure-table tbody tr').map do |tr|
      {
        name: tr.css('.tableTitle').first.text.gsub(/^(.*), The$/, 'The \1'),
        status: convert_status(tr.css('.tableStatus').first.text.strip),
        score: tr.css('.tableRating .rateme').first.attr('name').to_f*2,
        year: tr.css('.tableYear').first.text.to_i,
      }.merge(@klass == Anime ? {
        episodes: tr.css('.tableEps').first.text.to_i
      } : {
        volumes: tr.css('.tableVols').first.text.to_i,
        chapters: tr.css('.tableCh').first.text.to_i
      })
    end
  end

  # получение общего числа страниц списка
  def pages_count login
    content = get("http://www.anime-planet.com/users/#{login}/#{@klass.name.downcase}/all?page=1")
    doc = Nokogiri::HTML(content)

    doc
      .css('.pagination li')
      .map {|link| link.text.to_i }
      .select {|v| !v.zero? }
      .max || 1
  end

  # переведение статус из анимепланетного в локальный
  def convert_status planet_status
    case planet_status
      when 'Watched', 'Read'
        UserRate.statuses[:completed]

      when 'Watching', 'Reading'
        UserRate.statuses[:watching]

      when 'Want to Watch', 'Want to Read'
        UserRate.statuses[:planned]

      when 'Stalled'
        UserRate.statuses[:on_hold]

      when 'Dropped'
        UserRate.statuses[:dropped]

      when "Won't Watch", "Won't Read"
        @wont_watch_strategy

      else
        raise ArgumentError.new(planet_status)
    end
  end

  # загрузка страницы через прокси
  def get url
    #content = Proxy.get url, timeout: 30, required_text: 'Anime-Planet</title>'
    content = open(url).read
    raise EmptyContentError, url unless content
    raise InvalidIdError, url if content.include?("You searched for")
    content
  end
end
