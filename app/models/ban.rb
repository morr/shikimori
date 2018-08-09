class Ban < ApplicationRecord
  include Translation

  belongs_to :user
  belongs_to :moderator, class_name: User.name
  belongs_to :comment, touch: true
  belongs_to :abuse_request, touch: true, optional: true

  validates :user, :moderator, presence: true
  validates :duration, :reason, presence: true
  # validates :comment, :abuse_request, presence: true

  before_validation :set_user
  after_create :ban_user
  after_create :notify_user
  after_create :mention_in_comment
  after_create :accept_abuse_request

  ACTIVE_DURATION = 60.days

  def duration= value
    self[:duration] = BanDuration.new(value).to_i unless value.nil?
  end

  def duration
    BanDuration.new self[:duration] unless self[:duration].nil?
  end

  def suggest_duration
    bans_count = Users::BansCount.call user_id

    duration =
      if bans_count > 15
        '1w 3d 12h'
      elsif bans_count <= 5
        (30 + 30 * ((bans_count ** 3) / 2.0 - 1)).to_i
      else
        60 * bans_count ** 2
      end

    BanDuration.new(duration).to_s
  end

  def warning?
    duration.zero?
  end

  def set_user
    self.user_id = comment.user_id unless user_id || !comment
  end

  def message
    i18n_key = warning? ? 'warn_message' : 'ban_message'

    i18n_t(i18n_key,
      duration: duration.humanize,
      reason: BbCodes::Text.call(reason)
    ).sub /\.+\Z/, '.'
  end

  # callbacks
  def ban_user
    return if warning?
    start_at = [user.read_only_at || Time.zone.now, Time.zone.now].max
    user.update_column :read_only_at, start_at + duration.minutes
  end

  def notify_user
    Message.create_wo_antispam!(
      from_id: moderator.id,
      to_id: user.id,
      kind: warning? ? MessageType::Warned : MessageType::Banned,
      linked: self
    )
  end

  def mention_in_comment
    return if comment.nil?
    comment.body = (comment.body.strip + "\n\n[ban=#{id}]")
      .gsub(/(\[ban=\d+\])\s+(\[ban=\d+\])/, '\1\2')

    comment.save validate: false
  end

  def accept_abuse_request
    abuse_request.take! moderator if abuse_request_id.present?
  end
end
