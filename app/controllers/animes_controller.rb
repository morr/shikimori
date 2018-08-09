class AnimesController < DbEntriesController
  # caches_action :page, :characters, :show, :related, :cosplay, :tooltip,
  #   cache_path: proc {
  #     id = params[:anime_id] || params[:manga_id] || params[:id]
  #     @resource ||= klass.find(id.to_i)
  #     "#{klass.name}|#{Digest::MD5.hexdigest params.to_json}|#{@resource.updated_at.to_i}|#{@resource.topic(locale_from_host).updated_at.to_i}|#{json?}|v3|#{request.xhr?}"
  #   },
  #   unless: proc { user_signed_in? },
  #   expires_in: 2.days

  EXTERNAL_LINK_PARAMS = %i[
    entry_id entry_type created_at updated_at imported_at source kind url
  ]
  UPDATE_PARAMS = %i[
    russian
    torrents_name
    tags
    description_ru
    description_en
  ] + [
    *Anime::DESYNCABLE,
    external_links: [EXTERNAL_LINK_PARAMS],
    synonyms: []
  ]

  before_action :set_breadcrumbs, if: :resource_id
  before_action :resource_redirect, if: :resource_id
  before_action :js_export, only: %i[show]
  before_action :og_meta, if: :resource_id

  # display anime or manga
  def show
    @itemtype = @resource.itemtype
  end

  def characters
    if @resource.roles.main_characters.none? &&
        @resource.roles.supporting_characters.none?
      return redirect_to @resource.url, status: 301
    end

    og noindex: true
    og page_title: i18n_t("characters.#{@resource.object.class.name.downcase}")
  end

  def staff
    if @resource.roles.people.none?
      return redirect_to @resource.url, status: 301
    end

    og noindex: true
    og page_title: i18n_t("producers.#{@resource.object.class.name.downcase}")
  end

  def files
    unless @resource.files?
      return redirect_to @resource.url, status: 301
    end

    og noindex: true
    og page_title: i18n_t('files')
  end

  def similar
    if @resource.related.similar.none?
      return redirect_to @resource.url, status: 301
    end

    og noindex: true
    og page_title: i18n_t("similar.#{@resource.object.class.name.downcase}")
  end

  def screenshots
    unless @resource.screenshots.any? && user_signed_in? && ignore_copyright?
      return redirect_to @resource.url, status: 301
    end

    og noindex: true
    og page_title: i18n_i('screenshot', :other).capitalize
  end

  def videos
    unless @resource.videos.any? && user_signed_in? && ignore_copyright?
      return redirect_to @resource.url, status: 301
    end

    og noindex: true
    og page_title: i18n_i('video').capitalize
  end

  def related
    unless @resource.related.any?
      return redirect_to @resource.url, status: 301
    end

    og noindex: true
    og page_title: i18n_t("related.#{@resource.object.class.name.downcase}")
  end

  def chronology
    unless @resource.related.chronology?
      return redirect_to @resource.url, status: 301
    end

    og noindex: true
    og page_title: t('animes.page.chronology')
  end

  def franchise
    unless @resource.related.chronology?
      return redirect_to @resource.url, status: 301
    end

    og noindex: true
    og page_title: t('animes.page.franchise')
    @blank_layout = true
  end

  def summaries
    maybe_topic = @resource.maybe_topic(locale_from_host)
    unless Topic::CommentsPolicy.new(maybe_topic).any_summaries?
      return redirect_to @resource.url, status: 301
    end

    og page_title: i18n_t("reviews.#{@resource.object.class.name.downcase}")
  end

  def art
    unless @resource.display_sensitive?
      return redirect_to @resource.url, status: 301
    end
    og noindex: true
    og page_title: t('imageboard_art')
  end

  def images
    return redirect_to @resource.art_url, status: 301
  end

  def cosplay
    @page = [params[:page].to_i, 1].max
    @limit = 2
    @collection, @add_postloader = CosplayGalleriesQuery
      .new(@resource.object)
      .postload(@page, @limit)

    if @collection.none?
      return redirect_to @resource.url, status: 301
    end
    og page_title: t('cosplay')
  end

  def favoured
    if @resource.all_favoured.none?
      return redirect_to @resource.url, status: 301
    end

    og noindex: true
    og page_title: t('in_favorites')
  end

  def clubs
    if @resource.all_clubs.none?
      return redirect_to @resource.url, status: 301
    end
    og noindex: true
    og page_title: t('in_clubs')
  end

  def resources
    render partial: 'resources'
  end

  def other_names
    og noindex: true
  end

  # торренты к эпизодам аниме
  def episode_torrents
    render json: @resource.files.episodes_data
  end

  def autocomplete
    scope = Anime.all
    scope.where! censored: false if params[:censored] == 'false'

    @collection = Autocomplete::Anime.call(
      scope: scope,
      phrase: params[:search] || params[:q]
    )
  end

  def rollback_episode
    authorize! :rollback_episode, @resource

    Anime::RollbackEpisode.call @resource, @resource.episodes_aired
    redirect_back fallback_location: @resource.edit_url
  end

private

  def og_meta
    video_type =
      if @resource.kind_tv? || @resource.kind_ona?
        'video.tv_show'
      elsif @resource.kind_movie?
        'video.movie'
      else
        'video.other'
      end
    video_tags = @resource.genres.map do |genre|
      UsersHelper.localized_name genre, current_user
    end

    og type: video_type
    og video_duration: @resource.duration * 60 if @resource.duration.positive?
    og video_release_date: @resource.released_on if @resource.released_on
    og video_tags: video_tags
  end

  def update_params
    params
      .require(:anime)
      .permit(UPDATE_PARAMS)
  rescue ActionController::ParameterMissing
    {}
  end

  def set_breadcrumbs
    if @resource.anime?
      breadcrumb i18n_t('breadcrumbs.anime.list'), animes_collection_url

      if @resource.kind_tv?
        breadcrumb i18n_t('breadcrumbs.anime.tv'),
          animes_collection_url(type: @resource.kind)
      end

      if @resource.kind_movie?
        breadcrumb i18n_t('breadcrumbs.anime.movie'),
          animes_collection_url(type: @resource.kind)
      end
    elsif @resource.ranobe?
      breadcrumb i18n_t('breadcrumbs.ranobe.list'), ranobe_collection_url
    else
      breadcrumb i18n_t('breadcrumbs.manga.list'), mangas_collection_url
    end

    if @resource.aired_on &&
        [Time.zone.now.year + 1, Time.zone.now.year, Time.zone.now.year - 1].include?(@resource.aired_on.year)

      season_text = Titles::LocalizedSeasonText.new(
        @resource.object.class,
        @resource.aired_on.year.to_s
      ).title
      breadcrumb(
        season_text,
        @resource.collection_url(season: @resource.aired_on.year)
      )
    end

    if @resource.genres.any?
      breadcrumb UsersHelper.localized_name(@resource.main_genre, current_user),
        @resource.collection_url(genre: @resource.main_genre.to_param)
    end

    if @resource
      # все страницы, кроме animes#show
      if (params[:action] != 'show' || params[:controller] == 'reviews')
        breadcrumb(
          UsersHelper.localized_name(@resource, current_user),
          @resource.url(false)
        )
      end

      if params[:action] == 'edit_field' && params[:field].present?
        @back_url = @resource.edit_url
        breadcrumb i18n_t('edit'), @resource.edit_url
      end
    end
  end

  def js_export
    gon.push is_favoured: @resource.favoured?

    if @resource.anime?
      gon.push watch_online: {
        is_allowed: ignore_copyright?,
        is_licensed: @resource.licensed?,
        is_censored: @resource.censored? || @resource.forbidden?,
        has_videos: @resource.anime_videos?,
        watch_url: @resource.video_online_url,
        upload_url: @resource.upload_first_video_online_url
      }
    else
      gon.push watch_online: { is_allowed: false }
    end
  end
end
