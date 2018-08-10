class AnimeVideosService
  pattr_initialize :params

  def create user
    video = AnimeVideo.create @params

    create_report(video, user) if video.persisted? && video.uploaded?
    video
  end

  def update video, current_user, reason
    return if no_changes? video

    create_version video, current_user, reason
    video
  end

private

  def create_version video, current_user, reason
    Versioneers::FieldsVersioneer
      .new(video)
      .postmoderate(@params, current_user, reason)
  rescue StateMachine::InvalidTransition
  end

  def create_report video, user
    video.reports.create!(
      user_id: user.try(:id) || User::GUEST_ID,
      state: 'pending',
      kind: :uploaded
    )
  end

  def no_changes? video # rubocop:disable AbcSize
    video.author_name == @params[:author_name] &&
      video.episode == @params[:episode] &&
      video[:kind] == @params[:kind] &&
      video[:language] == @params[:language] &&
      video[:quality] == @params[:quality]
  end
end
