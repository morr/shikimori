# TODO: refactor to bunch of simplier query objects
# TODO: remove type param after 2018-06-01
class AniMangaQuery
  IDS_KEY = :ids
  EXCLUDE_IDS_KEY = :exclude_ids
  EXCLUDE_AI_GENRES_KEY = :exclude_ai_genres

  DURATION_SQL = {
    S: '(duration >= 0 and duration <= 10)',
    D: '(duration > 10 and duration <= 30)',
    F: '(duration > 30)'
  }
  DEFAULT_ORDER = 'ranked'
  GENRES_EXCLUDED_BY_SEX = {
    'male' => Genre::YAOI_IDS + Genre::SHOUNEN_AI_IDS,
    'female' => Genre::HENTAI_IDS + Genre::SHOUJO_AI_IDS + Genre::YURI_IDS,
    '' => Genre::CENSORED_IDS + Genre::SHOUNEN_AI_IDS + Genre::SHOUJO_AI_IDS
  }

  SEARCH_IDS_LIMIT = 250

  def initialize klass, params, user=nil
    @params = params

    @klass = klass
    @query = @klass.all

    @kind = params[:kind] || params[:type] || ''

    @genre = params[:genre]
    @studio = params[:studio]
    @publisher = params[:publisher]

    @rating = params[:rating]
    @score = params[:score]
    @duration = params[:duration]
    @season = params[:season]
    @status = params[:status]
    @franchise = params[:franchise]
    @achievement = params[:achievement]

    @mylist = params[:mylist].to_s.gsub(/\b\d\b/) do |status_id|
      UserRate.statuses.find { |name, id| id == status_id.to_i }.first
    end

    @search_phrase = params[:search] || params[:q]

    @exclude_ai_genres = params[EXCLUDE_AI_GENRES_KEY]

    @ids = params[IDS_KEY]
    @ids = @ids.split(',') if @ids.is_a? String

    @exclude_ids = params[EXCLUDE_IDS_KEY]
    @exclude_ids = @exclude_ids.split(',') if @exclude_ids.is_a? String

    @user = user

    # TODO: remove all after ||
    @order = params[:order] || (@search_phrase.blank? ? DEFAULT_ORDER : nil)
  end

  # выборка аниме или манги по заданным параметрам
  def fetch # page = nil, limit = nil
    kind!
    censored!
    disable_music!

    exclude_ai_genres!
    associations!

    rating!
    score!
    duration!
    season!
    status!
    franchise!
    achievement!

    mylist!

    ids!
    exclude_ids!
    search!
    video!

    order @query
  end

  def complete
    search!
    @query.limit(AUTOCOMPLETE_LIMIT).reverse
  end

  # сортировка по параметрам
  def order query
    if @search_phrase.blank?
      params_order query
    else
      query
    end
  end

private

  def mylist?
    @mylist.present? && @mylist !~ /^(!\w+,?)+$/
  end

  def userlist?
    !!@params[:userlist]
  end

  def search?
    @search_phrase.present?
  end

  def franchise?
    !!@franchise
  end

  def achievement?
    !!@achievement
  end

  # фильтр по типам
  def kind!
    return if @kind.blank?

    kinds = @kind
      .split(',')
      .each_with_object(complex: [], simple: []) do |kind, memo|
        memo[kind =~ /tv_\d+/ ? :complex : :simple] << kind
      end

    simple_kinds = bang_split kinds[:simple]

    simple_queries = {
      include: simple_kinds[:include]
        .delete_if { |v| v == 'tv' && kinds[:complex].any? { |q| q =~ /^tv_/ } }
        .map { |v| "#{table_name}.kind = #{ApplicationRecord.sanitize v}" },
      exclude: simple_kinds[:exclude]
        .map { |v| "#{table_name}.kind = #{ApplicationRecord.sanitize v}" }
    }
    complex_queries = { include: [], exclude: [] }

    kinds[:complex].each do |kind|
      with_bang = kind.starts_with? '!'

      query = case kind
        when 'tv_13', '!tv_13'
          "(#{table_name}.kind = 'tv' and episodes != 0 and episodes <= 16) or (#{table_name}.kind = 'tv' and episodes = 0 and episodes_aired <= 16)"

        when 'tv_24', '!tv_24'
          "(#{table_name}.kind = 'tv' and episodes != 0 and episodes >= 17 and episodes <= 28) or (#{table_name}.kind = 'tv' and episodes = 0 and episodes_aired >= 17 and episodes_aired <= 28)"

        when 'tv_48', '!tv_48'
          "(#{table_name}.kind = 'tv' and episodes != 0 and episodes >= 29) or (#{table_name}.kind = 'tv' and episodes = 0 and episodes_aired >= 29)"
      end

      complex_queries[with_bang ? :exclude : :include] << query
    end

    includes = (simple_queries[:include] + complex_queries[:include]).compact
    excludes = (simple_queries[:exclude] + complex_queries[:exclude]).compact

    if includes.any?
      @query = @query.where includes.join(' or ')
    end
    if excludes.any?
      @query = @query.where 'not(' + excludes.join(' or ') + ')'
    end
  end

  # включение цензуры
  def censored!
    if @genre
      genres = bang_split(@genre.split(','), true).each { |k,v| v.flatten! }
    end
    ratings = bang_split @rating.split(',') if @rating

    rx = ratings && ratings[:include].include?(Anime::ADULT_RATING)
    hentai = genres && (genres[:include] & Genre::HENTAI_IDS).any?
    yaoi = genres && (genres[:include] & Genre::YAOI_IDS).any?
    yuri = genres && (genres[:include] & Genre::YURI_IDS).any?

    return if [false, 'false'].include? @params[:censored]
    return if rx || hentai || yaoi || yuri || mylist? || search? || userlist?
    return if @publisher || @studio
    return if franchise? || achievement?

    if @params[:censored] == true || @params[:censored] == 'true'
      @query = @query.where(censored: false)
    end
  end

  # отключение выборки по музыке
  def disable_music!
    unless @kind.match?(/music/) ||
        mylist? || userlist? || franchise? || achievement?
      @query = @query.where("#{table_name}.kind != ?", :music)
    end
  end

  # отключение всего зацензуренной для парней/девушек
  def exclude_ai_genres!
    return unless @exclude_ai_genres && @user

    excludes = GENRES_EXCLUDED_BY_SEX[@user.sex || '']

    @genre = if @genre.present?
      "#{@genre},!#{excludes.join ',!'}"
    else
      "!#{excludes.join ',!'}"
    end
  end

  # фильтрация по жанрам, студиям и издателям
  def associations!
    [
      [Genre, @genre],
      [Studio, @studio],
      [Publisher, @publisher]
    ].each do |association_klass, values|
      association! association_klass, values if values.present?
    end
  end

  def association! association_klass, values
    ids = bang_split(values.split(','), true) do |v|
      association_klass.related(v.to_i)
    end
    field = "#{association_klass.name.downcase}_ids"

    ids[:include].each do |ids|
      @query.where! "#{field} && '{#{ids.map(&:to_i).join ','}}'"
    end
    ids[:exclude].each do |ids|
      @query.where! "not (#{field} && '{#{ids.map(&:to_i).join ','}}')"
    end
  end

  # фильтрация по рейнтингу
  def rating!
    return if @rating.blank?
    ratings = bang_split @rating.split(',')

    if ratings[:include].any?
      @query = @query.where(rating: ratings[:include])
    end
    if ratings[:exclude].any?
      @query = @query.where.not(rating: ratings[:exclude])
    end
  end

  # фильтрация по оценке
  def score!
    return if @score.blank?

    @score.split(',').each do |score|
      @query = @query.where("score >= #{score.to_i}")
    end
  end

  # фильтрация по длительности эпизода
  def duration!
    return if @duration.blank?
    durations = bang_split(@duration.split(','))

    if durations[:include].any?
      durations_sql = durations[:include]
        .map { |duration| DURATION_SQL[Types::Anime::Duration[duration]] }
        .join(' or ')
      @query = @query.where durations_sql
    end

    if durations[:exclude].any?
      durations_sql = durations[:exclude]
        .map { |duration| DURATION_SQL[Types::Anime::Duration[duration]] }
        .join(' or ')
      @query = @query.where("not (#{durations_sql})")
    end
  end

  # фильтрация по сезонам
  def season!
    return if @season.blank?
    seasons = bang_split @season.split(',')

    query = seasons[:include].map do |season|
      Animes::SeasonQuery.call(@klass.all, season).to_where_sql
    end
    @query = @query.where query.join(' OR ') unless query.empty?

    query = seasons[:exclude].map do |season|
      'NOT (' +
        Animes::SeasonQuery.call(@klass.all, season).to_where_sql +
        ')'
    end
    @query = @query.where query.join(' AND ') unless query.empty?
  end

  # фильтрация по статусам
  def status!
    return if @status.blank?
    statuses = bang_split @status.split(',')

    query = statuses[:include].map do |status|
      Animes::StatusQuery.call(@klass.all, status).to_where_sql
    end
    @query = @query.where query.join(' OR ') unless query.empty?

    query = statuses[:exclude].map do |status|
      'NOT (' +
        Animes::StatusQuery.call(@klass.all, status).to_where_sql +
        ')'
    end
    @query = @query.where query.join(' AND ') unless query.empty?
  end

  # filter by franchise
  def franchise!
    return if @franchise.blank?
    franchises = bang_split @franchise.split(',')

    if franchises[:include].any?
      @query = @query.where(franchise: franchises[:include])
    end
    if franchises[:exclude].any?
      @query = @query.where(
        'franchise not in (?) or franchise is null',
        franchises[:exclude]
      )
    end
  end

  # filter by achievement
  def achievement!
    return if @achievement.blank?

    @query = @query.merge(
      NekoRepository.instance.find(@achievement, 1).animes_scope.except(:order)
    )
  end

  # фильтрация по наличию в собственном списке
  def mylist!
    return if @mylist.blank? || @user.blank?
    statuses = bang_split(@mylist.split(','), false)

    animelist = @user
      .send("#{@klass.base_class.name.downcase}_rates")
      .includes(@klass.base_class.name.downcase.to_sym)
      .each_with_object(include: [], exclude: []) do |entry, memo|

        if statuses[:include].include?(entry.status)
          memo[:include] << entry.target_id
        end

        if statuses[:exclude].include?(entry.status)
          memo[:exclude] << entry.target_id
        end
      end

    animelist[:include] << 0 if statuses[:include].any? && animelist[:include].none?
    animelist[:exclude] << 0 if statuses[:exclude].any? && animelist[:exclude].none?

    @query = @query.where(id: animelist[:include]) if animelist[:include].any?
    @query = @query.where.not(id: animelist[:exclude]) if animelist[:exclude].any?
  end

  # фильтрация по id
  def ids!
    return if @ids.blank?

    @query = @query.where(id: @ids.map(&:to_i))
  end

  # фильтрация по id
  def exclude_ids!
    return if @exclude_ids.blank?

    @query = @query.where.not(id: @exclude_ids.map(&:to_i))
  end

  # поиск по названию
  def search!
    return if @search_phrase.blank?

    @query = "Search::#{@klass.name}".constantize.call(
      scope: @query,
      phrase: @search_phrase,
      ids_limit: SEARCH_IDS_LIMIT
    )
  end

  # фильтрация по наличию видео
  def video!
    return if @params[:with_video].blank?

    @query = @query
      .where('animes.id in (select distinct(anime_id) from anime_videos)')
      .where(@params[:is_adult] ? AnimeVideo::XPLAY_CONDITION : AnimeVideo::PLAY_CONDITION)
  end

  # сортировка по параметрам запроса
  def params_order query
    query.order self.class.order_sql(@order, @klass)
  end

  # имя таблицы аниме
  def table_name
    @klass.table_name
  end

  # разбитие на 2 группы по наличию !, плюс возможная обработка элементов
  def bang_split values, force_integer = false
    data = values.inject(:include => [], :exclude => []) do |rez,v|
      rez[v.starts_with?('!') ? :exclude : :include] << v.sub('!', '')
      rez
    end

    if force_integer
      data[:include].map!(&:to_i)
      data[:exclude].map!(&:to_i)
    end

    if block_given?
      data[:include].map! { |v| yield v }
      data[:exclude].map! { |v| yield v }
    end

    data
  end

  # sql представление сортировки датасорса
  def self.order_sql field, klass
    if klass == Manga && field == 'episodes'
      field = 'chapters'
    elsif klass == Anime && %w[chapters volumes].include?(field)
      field = 'episodes'
    end

    sql = case field
      when 'name'
        "#{klass.table_name}.name, #{klass.table_name}.id"

      when 'russian'
        <<-SQL.squish
          (case
            when #{klass.table_name}.russian is null
              or #{klass.table_name}.russian=''
            then #{klass.table_name}.name
            else #{klass.table_name}.russian
          end), #{klass.table_name}.id
        SQL

      when 'episodes'
        <<-SQL.squish
          (case
            when #{klass.table_name}.episodes = 0
            then #{klass.table_name}.episodes_aired
            else #{klass.table_name}.episodes
          end) desc, #{klass.table_name}.id
        SQL

      when 'chapters'
        "#{klass.table_name}.chapters desc, #{klass.table_name}.id"

      when 'volumes'
        "#{klass.table_name}.volumes desc, #{klass.table_name}.id"

      when 'status'
        <<-SQL.squish
          (case
            when #{klass.table_name}.status='Not yet aired'
              or #{klass.table_name}.status='Not yet published'
            then 'AAA'
            else
              (case
                when #{klass.table_name}.status='Publishing'
                then 'Currently Airing'
                else #{klass.table_name}.status
              end)
          end), #{klass.table_name}.id
        SQL

      when 'popularity'
        <<-SQL.squish
          (case
            when popularity=0
            then 999999
            else popularity
          end), #{klass.table_name}.id
        SQL

      when 'ranked'
        <<-SQL.squish
          (case
            when ranked=0
            then 999999
            else ranked
          end), #{klass.table_name}.score desc, #{klass.table_name}.id
        SQL

      when 'released_on'
        <<-SQL.squish.strip
          (case
            when released_on is null
            then aired_on
            else released_on
          end) desc, #{klass.table_name}.id
        SQL

      when 'aired_on'
        "aired_on desc, #{klass.table_name}.id"

      when 'id'
        "#{klass.table_name}.id desc"

      when 'rate_id'
        "user_rates.id, #{klass.table_name}.id"

      when 'my', 'rate'
        <<-SQL.squish
          user_rates.score desc,
          #{klass.table_name}.name,
          #{klass.table_name}.id
        SQL

      when 'site_score'
        "#{klass.table_name}.site_score desc, #{klass.table_name}.id"

      when 'kind', 'type'
        "#{klass.table_name}.kind, #{klass.table_name}.id"

      when 'user_1', 'user_2' # кастомные сортировки
        nil

      when 'random'
        'random()'

      else
        # raise ArgumentError, "unknown order '#{field}'"
        order_sql DEFAULT_ORDER, klass
    end

    Arel.sql(sql)
  end
end
