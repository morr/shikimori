# cached_votes_up - votes for left
# cached_votes_down - votes for right
# cached_votes_total - votes_for_right + votes_for_left + refrained_votes
class ContestMatch < ApplicationRecord
  UNDEFINED = 'undefined variant'
  VOTABLE = {
    true => 'left',
    false => 'right',
    nil => 'abstain'
  }

  acts_as_votable cacheable_strategy: :update_columns

  belongs_to :round, class_name: ContestRound.name, touch: true
  belongs_to :left, polymorphic: true, optional: true
  belongs_to :right, polymorphic: true, optional: true

  delegate :contest, :strategy, to: :round

  # rubocop:disable Style/HashSyntax
  state_machine :state, initial: :created do
    state :created
    state :started
    state :finished

    event :start do
      transition :created => :started, if: ->(match) {
        match.started_on && match.started_on <= Time.zone.today
      }
    end
    event :finish do
      transition :started => :finished, if: ->(match) {
        match.finished_on && match.finished_on < Time.zone.today
      }
    end
  end
  # rubocop:enable Style/HashSyntax

  alias can_vote? started?

  def left_votes
    cached_votes_up
  end

  def right_votes
    cached_votes_down
  end

  # победитель
  def winner
    if winner_id == left_id
      left
    else
      right
    end
  end

  # проигравший
  def loser
    if winner_id == left_id
      right
    else
      left
    end
  end
end
