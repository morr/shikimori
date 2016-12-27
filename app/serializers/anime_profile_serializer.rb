class AnimeProfileSerializer < AnimeSerializer
  attributes :rating, :english, :japanese, :synonyms, :kind, :aired_on,
    :released_on, :episodes, :episodes_aired, :duration, :score, :description,
    :description_html, :description_source,
    :favoured?, :anons?, :ongoing?, :thread_id, :topic_id,
    :world_art_id, :myanimelist_id, :ani_db_id,
    :rates_scores_stats, :rates_statuses_stats, :updated_at

  has_many :genres
  has_many :studios
  has_many :videos
  has_many :screenshots

  has_one :user_rate

  def user_rate
    UserRateFullSerializer.new(object.current_rate)
  end

  # TODO: deprecated
  def thread_id
    object.maybe_topic(scope.locale_from_domain).id
  end

  def topic_id
    object.maybe_topic(scope.locale_from_domain).id
  end

  def myanimelist_id
    object.id
  end

  def english
    [object.english]
  end

  def japanese
    [object.japanese]
  end

  def description
    object.description.text
  end

  def description_html
    object.description_html.gsub(%r{(?<!:)//(?=\w)}, 'http://')
  end

  def description_source
    object.description.source
  end

  def videos
    object.videos 2
  end

  def screenshots
    object.screenshots 2
  end
end
