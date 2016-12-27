class AnimesCollection::View < ViewObjectBase
  vattr_initialize :klass, :user

  instance_cache :collection, :results, :filtered_params
  delegate :page, :pages_count, to: :results

  OVA_KEY = 'OVA/ONA'
  LIMIT = 20

  def collection
    if season_page?
      results.collection
        .map(&:decorate)
        .group_by { |v| anime_ova_ona?(v) ? OVA_KEY : v.kind.to_s }
    else
      results.collection&.map(&:decorate)
    end
  end

  def season_page?
    !recommendations? &&
      h.params[:season].present? &&
      !!h.params[:season].match(/^([a-z]+_\d+,?)+$/)
  end

  def recommendations?
    h.params[:controller] == 'recommendations'
  end

  def cache?
    !recommendations?
  end

  def cache_key
    user_key = user if h.params[:mylist]
    reindex = Elasticsearch::Reindex.time if h.params[:search] || h.params[:q]
    initial_key = ['v2', klass.name, user_key, reindex]

    h.params
      .except(:format, :controller, :action)
      .sort_by(&:first)
      .inject(initial_key) { |memo, (k, v)| memo.push "#{k}:#{v}" }
      .compact
  end

  def cache_expires_in
    if h.params[:search] || h.params[:q]
      1.hour
    elsif h.params[:season] || h.params[:status]
      1.day
    else
      3.days
    end
  end

  def url changed_params
    params = filtered_params.merge(changed_params).symbolize_keys

    if recommendations?
      h.recommendations_url params
    else
      h.send "#{klass.name.downcase.pluralize}_url", params
    end
  end

  def prev_page_url
    url(page: page - 1) if page > 1
  end

  def next_page_url
    url(page: page + 1) if page < pages_count
  end

  def filtered_params
    h.params.except(
      :format, :template, :is_adult, :controller, :action, :klass,
      AnimesCollection::RecommendationsQuery::IDS_KEY,
      AnimesCollection::RecommendationsQuery::EXCLUDE_IDS_KEY
    )
  end

private

  def anime_ova_ona? db_entry
    db_entry.anime? && (db_entry.kind_ova? || db_entry.kind_ona?)
  end

  def results
    if cache?
      Rails.cache.fetch(*cache_params) { fetch }
    else
      fetch
    end
  end

  def fetch
    if recommendations?
      recommendations_query
    elsif season_page?
      season_query
    else
      page_query
    end
  end

  def cache_params
    [cache_key, expires_in: cache_expires_in]
  end

  def recommendations_query
    AnimesCollection::RecommendationsQuery.call(
      klass: klass,
      params: h.params,
      user: user,
      limit: LIMIT
    )
  end

  def season_query
    AnimesCollection::SeasonQuery.call(
      klass: klass,
      params: h.params,
      user: user,
      limit: LIMIT
    )
  end

  def page_query
    AnimesCollection::PageQuery.call(
      klass: klass,
      params: h.params,
      user: user,
      limit: LIMIT
    )
  end
end
