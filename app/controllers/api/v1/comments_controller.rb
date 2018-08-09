class Api::V1::CommentsController < Api::V1Controller
  before_action :check_post_permission, only: %i[create update destroy]
  load_and_authorize_resource only: %i[create update destroy]
  before_action :authenticate_user!, only: %i[create update destroy]

  LIMIT = 30

  # AUTO GENERATED LINE: REMOVE THIS TO PREVENT REGENARATING
  api :GET, '/comments/:id', 'Show a comment'
  def show
    @resource = Comment.find(params[:id]).decorate
    respond_with @resource
  end

  api :GET, '/comments', 'List comments'
  param :commentable_id, :number, required: true
  param :commentable_type, String,
    required: true,
    desc: <<~DOC.strip
      Must be one of: `#{Types::Comment::CommentableType.values.join('`, `')}`
    DOC
  param :page, :pagination, required: false
  param :limit, :pagination, required: false, desc: "#{LIMIT} maximum"
  param :desc, %w[1 0], required: false
  # rubocop:disable AbcSize
  def index
    @limit = [[params[:limit].to_i, 1].max, LIMIT].min
    @page = [params[:page].to_i, 1].max
    @desc = params[:desc].nil? || params[:desc] == '1'

    commentable_type = params[:commentable_type].gsub('Entry', Topic.name)
    commentable_id = params[:commentable_id]

    @collection = CommentsQuery
      .new(commentable_type, commentable_id)
      .fetch(@page, @limit, @desc)
      .decorate

    respond_with @collection
  end
  # rubocop:enable AbcSize

  api :POST, '/comments', 'Create a comment'
  param :comment, Hash do
    param :body, String, required: true
    param :commentable_id, :number, required: true
    param :commentable_type, String,
      required: true,
      desc: <<~DOC.squish
        <p>
          Must be one of:
          <code>#{Types::Comment::CommentableType.values.join('</code>, <code>')}</code>,
          <code>#{Anime.name}</code>,
          <code>#{Manga.name}</code>,
          <code>#{Character.name}</code>,
          <code>#{Person.name}</code>
        </p>
        <p>
          When set to
          <code>#{Anime.name}</code>,
          <code>#{Manga.name}</code>,
          <code>#{Character.name}</code>,
          <code>#{Person.name}</code>
          comment is attached to <code>commentable</code> main topic
        </p>
      DOC
    param :is_offtopic, :bool, required: false
    param :is_summary, :bool, required: false
  end
  param :frontend, :bool
  param :broadcast, :bool
  def create
    @resource = Comment::Create.call faye, create_params, locale_from_host

    if params[:broadcast] && @resource.persisted? && can?(:broadcast, @resource)
      Comment::Broadcast.call @resource
    end

    if @resource.persisted? && frontent_request?
      render :comment
    else
      respond_with @resource
    end
  end

  api :PATCH, '/comments/:id', 'Update a comment'
  api :PUT, '/comments/:id', 'Update a comment'
  param :comment, Hash do
    param :body, String, required: true
  end
  param :frontend, :bool
  def update
    if faye.update(@resource, update_params) && frontent_request?
      render :comment
    else
      respond_with @resource
    end
  end

  # AUTO GENERATED LINE: REMOVE THIS TO PREVENT REGENARATING
  api :DELETE, '/comments/:id', 'Destroy a comment'
  def destroy
    faye.destroy @resource

    render json: { notice: i18n_t('comment.removed') }
  end

private

  # TODO: remove 'offtopic' and 'review' after 01.09.2016
  # rubocop:disable MethodLength
  def comment_params
    comment_params = params
      .require(:comment)
      .permit(
        :body, :review, :offtopic, :is_summary, :is_offtopic,
        :commentable_id, :commentable_type, :user_id
      )

    comment_params[:is_summary] ||= comment_params[:review]
    comment_params[:is_offtopic] ||= comment_params[:offtopic]

    if comment_params[:commentable_type].present?
      comment_params[:commentable_type] =
        comment_params[:commentable_type].gsub('Entry', Topic.name)
    end

    comment_params.except(:review, :offtopic)
  end
  # rubocop:enable MethodLength

  def create_params
    comment_params.merge(user: current_user)
  end

  def update_params
    comment_params.except(:is_summary, :is_offtopic)
  end

  def faye
    FayeService.new current_user, faye_token
  end
end
