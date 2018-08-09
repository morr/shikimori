class UserDataFetcherBase
  KLASS_HISTORIES = {
    Anime => [
      UserHistoryAction::MalAnimeImport,
      UserHistoryAction::ApAnimeImport,
      UserHistoryAction::AnimeHistoryClear
    ],
    Manga => [
      UserHistoryAction::MalMangaImport,
      UserHistoryAction::ApMangaImport,
      UserHistoryAction::MangaHistoryClear
    ]
  }

  MINIMUM_SCORES = 20

  # REALTIME_LOAD_IN_DEVELOPMENT = Rails.env.development?
  REALTIME_LOAD_IN_DEVELOPMENT = false

  method_object

  def call
    return [] unless should_fetch?
    return postprocess(load_data) if load_data

    if REALTIME_LOAD_IN_DEVELOPMENT
      postprocess(job.new.perform *job_args)
    else
      job.perform_async *job_args
      nil
    end
  end

private

  def postprocess data
    data
  end

  def list_cache_key
    [
      :userlist,
      @klass,
      @user.id,
      latest_import[:id],
      (histories_count / 10).to_i,
      rates_count >= MINIMUM_SCORES
    ].join('_')
  end

  def cache_key
    "#{self.class}_#{list_cache_key}"
  end

  def histories_count
    @histories_count ||= @user.history.count
  end

  def rates_count
    @rates_count ||= @user.send("#{@klass.name.downcase}_rates").count
  end

  def latest_import
    @latest_import ||= UserHistory
      .where(user_id: @user.id, action: KLASS_HISTORIES[@klass])
      .order(id: :desc)
      .first || {}
  end

  def should_fetch?
    @user.present? && rates_count >= MINIMUM_SCORES
      # (
      #   histories_count >= Recommendations::RatesFetcher::MINIMUM_SCORES ||
      #   latest_import.present?
      # ) &&
  end

  def load_data
    @load_data ||=
      begin
        data = Rails.cache.read cache_key

        if data.nil?
          false
        else
          data
        end
      end
  end
end
