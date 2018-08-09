# комментарии должны создаваться, обновляться и удаляться через CommentsService
# TODO: refactor fat model
class Comment < ApplicationRecord
  include Moderatable
  include Antispam
  include Viewable

  MIN_SUMMARY_SIZE = 230

  # associations
  belongs_to :user
  belongs_to :commentable, polymorphic: true
  belongs_to :topic,
    optional: true,
    class_name: Topic.name,
    foreign_key: :commentable_id

  has_many :abuse_requests, -> { order :id }, dependent: :destroy
  has_many :bans, -> { order :id }

  has_many :messages, -> { where linked_type: Comment.name },
    foreign_key: :linked_id,
    dependent: :destroy

  boolean_attributes :summary, :offtopic

  # validations
  validates :user, :commentable, presence: true
  validates :commentable_type,
    inclusion: { in: Types::Comment::CommentableType.values }
  validates :body, presence: true, length: { minimum: 2, maximum: 10_000 }

  # scopes
  scope :summaries, -> { where is_summary: true }

  # callbacks
  before_validation :forbid_tag_change, if: -> { will_save_change_to_body? }

  before_create :check_access
  before_create :cancel_summary
  after_create :increment_comments
  after_create :creation_callbacks

  after_save :release_the_banhammer!
  after_save :touch_commentable
  after_save :notify_quoted, if: -> { saved_change_to_body? }

  before_destroy :decrement_comments
  after_destroy :destruction_callbacks
  after_destroy :touch_commentable
  after_destroy :remove_notifies

  # TODO: remove when review param is removed from API (after 01.09.2016)
  def review= value
    self[:is_summary] = value
  end

  def commentable
    if association(:topic).loaded? && !topic.nil? && commentable_type == 'Topic'
      topic
    else
      super
    end
  end

  # counter_cache hack
  def increment_comments
    if commentable && commentable.attributes['comments_count']
      commentable.increment!(:comments_count)
    end
  end

  def decrement_comments
    if commentable && commentable.attributes['comments_count']
      commentable.class.decrement_counter(:comments_count, commentable.id)
    end
  end

  # TODO: get rid of this method
  # проверка можно ли добавлять комментарий в комментируемый объект
  def check_access
    # http://stackoverflow.com/a/3464012
    commentable_klass = commentable_type.constantize
    commentable = commentable_klass.find(commentable_id)
    if commentable.respond_to?(:can_be_commented_by?)
      throw :abort unless commentable.can_be_commented_by?(self)
    end
  end

  # отмена метки отзыва для коротких комментариев
  def cancel_summary
    self.is_summary = false if summary? && body.size < MIN_SUMMARY_SIZE
    true
  end

  # TODO: get rid of this method
  # для комментируемого объекта вызов колбеков, если они определены
  def creation_callbacks
    commentable_klass = Object.const_get(commentable_type.to_sym)
    commentable = commentable_klass.find(commentable_id)
    self.commentable_type = commentable_klass.base_class.name

    commentable.comment_added(self) if commentable.respond_to?(:comment_added)
    # commentable.mark_as_viewed(self.user_id, self) if commentable.respond_to?(:mark_as_viewed)

    # save if saved_changes?
  end

  # TODO: get rid of this method
  # для комментируемого объекта вызов колбеков, если они определены
  def destruction_callbacks
    commentable_klass = Object.const_get(commentable_type.to_sym)
    commentable = commentable_klass.find(commentable_id)

    if commentable.respond_to?(:comment_deleted)
      commentable.comment_deleted(self)
    end
  # rescue ActiveRecord::RecordNotFound
  end

  def notify_quoted
    Comments::NotifyQuoted.call(
      old_body: saved_changes[:body].first,
      new_body: saved_changes[:body].second,
      comment: self,
      user: user
    )
  end

  def remove_notifies
    Comments::NotifyQuoted.call(
      old_body: body,
      new_body: nil,
      comment: self,
      user: user
    )
  end

  # автобан за мат
  def release_the_banhammer!
    Banhammer.instance.release! self
  end

  def touch_commentable
    if commentable.respond_to? :commented_at
      commentable.update_column :commented_at, Time.zone.now
    else
      commentable.update_column :updated_at, Time.zone.now
    end
  end

  # TODO: move to CommentDecorator
  def html_body
    fixed_body =
      if offtopic_topic?
        body
          .gsub(/\[poster=/i, '[image=')
          .gsub(/\[poster\]/i, '[img]')
          .gsub(%r{\[/poster\]}i, '[/img]')
          .gsub(/\[img.*?\]/i, '[img]')
          .gsub(/\[image=(\d+) .+?\]/i, '[image=\1]')
      else
        body
      end

    BbCodes::Text.call fixed_body
  end

  def mark_offtopic flag
    # mark comment thread as offtopic
    if flag
      ids = comment_thread.map(&:id) + [id]
      Comment.where(id: ids).update_all is_offtopic: flag
      self.is_offtopic = flag
      ids
    # mark as not offtopic current comment only
    else
      update is_offtopic: flag
      [id]
    end
  end

  def mark_summary flag
    update is_summary: flag
    [id]
  end

  # ветка с ответами на этот комментарий
  def comment_thread
    comments = Comment
      .where('id > ?', id)
      .where(commentable_type: commentable_type, commentable_id: commentable_id)
      .order(:id)

    search_ids = Set.new [id]

    comments.each do |comment|
      search_ids.clone.each do |id|
        if comment.body.include?("[comment=#{id}]") || comment.body.include?("[quote=#{id};") || comment.body.include?("[quote=c#{id};")
          search_ids << comment.id
        end
      end
    end

    comments.select { |v| search_ids.include? v.id }
  end

  # запрет на изменение информации о бане
  def forbid_tag_change
    [/(\[ban=\d+\])/, /\[broadcast\]/].each do |tag|
      prior_ban = (changes_to_save[:body].first || '').match(tag).try :[], 1
      current_ban = (changes_to_save[:body].last || '').match(tag).try :[], 1

      prior_count = (changes_to_save[:body].first || '').scan(tag).size
      current_count = (changes_to_save[:body].last || '').scan(tag).size

      if prior_ban != current_ban || prior_count != current_count
        errors[:base] << I18n.t('activerecord.errors.models.comments.not_a_moderator')
      end
    end
  end

  def allowed_summary?
    commentable.instance_of?(Topics::EntryTopics::AnimeTopic) ||
      commentable.instance_of?(Topics::EntryTopics::MangaTopic) ||
        commentable.instance_of?(Topics::EntryTopics::RanobeTopic)
  end

  private

  def offtopic_topic?
    return false unless topic.present?

    topic.id == Topic::TOPIC_IDS[:offtopic][topic.locale.to_sym]
  end
end
