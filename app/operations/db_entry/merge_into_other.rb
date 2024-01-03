class DbEntry::MergeIntoOther # rubocop:disable ClassLength
  method_object %i[entry! other!]

  RELATIONS = %i[
    user_rates
    topics
    comments
    reviews
    critiques
    collection_links
    versions
    club_links
    cosplay_gallery_links
    recommendation_ignores
    contest_links
    anime_links
    favourites
    external_links
    posters
  ]

  ASSIGN_FIELDS = %i[
    description_en
    description_ru
    english
    genre_ids
    imageboard_tag
    license_name_ru
    licensors
    name
    japanese
    popularity
    publisher_ids
    ranked
    rating
    russian
    score
    score_2
    source
    stuio_ids

    birth_on
    deceased_on
    website
  ]

  MERGE_FIELDS = %i[
    synonyms
    coub_tags
    fansubbers
    fandubbers
  ]

  def call
    @other.class.transaction do
      UserRate.wo_logging do
        assign_fields
        merge_fields
        @other.save! if @other.changed?

        self.class::RELATIONS.each do |relation|
          send :"merge_#{relation}"
        end

        DbEntry::Destroy.call @entry.class.find(@entry.id)
      end
    end

    true
  end

private

  def assign_fields
    self.class::ASSIGN_FIELDS.each do |field|
      next unless @entry.respond_to?(field) && @other.respond_to?(field)
      next unless @other.send(field).blank? && @entry.send(field).present?

      @other.assign_attributes field => @entry.send(field)
    end
  end

  def merge_fields
    self.class::MERGE_FIELDS.each do |field|
      next unless @entry.respond_to?(field) && @other.respond_to?(field)

      @other.assign_attributes field => (@other.send(field) + @entry.send(field)).sort.uniq
    end
  end

  def merge_user_rates # rubocop:disable all
    return unless @entry.respond_to? :rates

    other_rates = @other.rates.to_a

    @entry.rates.each do |entry_rate|
      user_id = entry_rate.user_id

      if entry_rate.completed?
        other_rate = other_rates.find { |v| v.user_id == user_id }

        if other_rate
          next if other_rate.completed?

          cleanup_user_rate other_rate
        end
      end

      entry_rate.update! target: @other

      update_user_rate_logs user_id
      update_user_history user_id
    rescue ActiveRecord::RecordInvalid
    end
  end

  def update_user_rate_logs user_id
    UserRateLog
      .where(user_id: user_id)
      .where(target: @entry)
      .update_all target_id: @other.id, target_type: @other.class.base_class.name
  end

  def update_user_history user_id
    UserHistory
      .where(user_id: user_id)
      .where(user_history_key => @entry.id)
      .update_all user_history_key => @other.id
  end

  def cleanup_user_rate user_rate
    user_rate.destroy!

    UserRateLog
      .where(user_id: user_rate.user_id)
      .where(target: @other)
      .destroy_all

    UserHistory
      .where(user_id: user_rate.user_id)
      .where(user_history_key => @other.id)
      .destroy_all
  end

  def merge_topics
    @entry.all_topics
      .where(generated: false)
      .each { |v| v.update linked: @other }
  end

  def merge_comments
    @entry_topic = @entry.maybe_topic
    @other_topic = @other.maybe_topic

    unless @other_topic.persisted?
      @other_topic = @other.generate_topic
    end

    @entry_topic
      .comments
      .includes(:commentable)
      .find_each do |comment|
        comment.update commentable: @other_topic
      end

    if @entry_topic.commented_at && @entry_topic.commented_at < @other_topic.commented_at
      @entry_topic.update! commented_at: @other_topic.commented_at
    end
  end

  def merge_reviews
    return unless @entry.respond_to? :reviews

    @entry.reviews.each do |review|
      review.update(
        "#{@other.anime? ? :anime : :manga}": @other
      )
    end
  end

  def merge_critiques
    return unless @entry.respond_to? :critiques

    @entry.critiques.each { |v| v.update target: @other }
  end

  def merge_collection_links
    @entry.collection_links.each { |v| v.update linked: @other }
  end

  def merge_versions
    @entry.versions.each { |v| v.update item: @other }
  end

  def merge_club_links
    @entry.club_links.each { |v| v.update linked: @other }
  end

  def merge_cosplay_gallery_links
    return unless @entry.respond_to? :cosplay_gallery_links

    @entry.cosplay_gallery_links.each { |v| v.update linked: @other }
  end

  def merge_recommendation_ignores
    return unless @entry.respond_to? :recommendation_ignores

    @entry.recommendation_ignores.each { |v| v.update target: @other }
  end

  def merge_contest_links # rubocop:disable AbcSize
    @entry.contest_links.each { |v| v.update! linked: @other }
    @entry.contest_winners.each { |v| v.update! item: @other }

    ContestMatch
      .where(left: @entry)
      .or(ContestMatch.where(right: @entry))
      .each do |contest_match|
        contest_match.left_id = @other.id if contest_match.left_id == @entry.id
        contest_match.right_id = @other.id if contest_match.right_id == @entry.id
        contest_match.winner_id = @other.id if contest_match.winner_id == @entry.id
        contest_match.save!
      end
  end

  def merge_anime_links
    return unless @entry.respond_to?(:anime_links) && @other.respond_to?(:anime_links)

    @entry.anime_links.each { |v| v.update anime: @other }
  end

  def merge_favourites
    @entry.favourites.each do |v|
      v.update linked_id: @other.id, linked_type: @other.class.name
    end
  end

  def merge_external_links
    return unless @entry.respond_to? :external_links

    @entry.external_links.each { |v| v.update entry: @other }
  end

  def merge_posters
    return if @entry.poster.nil? || @other.poster.present?

    @entry.poster.update! @entry.poster.target_key => @other.id
    Versions::PosterVersion.where(item: @entry.poster).update_all associated_id: @other.id
  end

  def user_history_key
    @entry.anime? ? :anime_id : :manga_id
  end

  def poster_key
    @entry.anime? ? :anime_id : :manga_id
  end
end
