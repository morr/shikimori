class UserHistory < ApplicationRecord
  belongs_to :user, touch: true
  belongs_to :target, polymorphic: true, optional: true

  belongs_to :anime, foreign_key: :target_id, optional: true
  belongs_to :manga, foreign_key: :target_id, optional: true

  BACKWARD_CHECK_INTERVAL = 30.minutes
  DELETE_BACKWARD_CHECK_INTERVAL = 60.minutes
  EPISODE_BACKWARD_CHECK_INTERVAL = 6.hours

  # TODO: refactor >.<
  # look at spec for additional info
  def self.add(
    user,
    item,
    action,
    value = nil,
    prior_value = nil
  )
    # при изменении на тоже самое значение ничего не делаем
    return if value && value == prior_value
    last_entry = UserHistory
      .where(user_id: user.is_a?(Integer) ? user : user.id)
      .where(target_type: item.class.base_class.name)
      .order(id: :desc)
      .first

    unless last_entry&.target_type == item.class.base_class.name &&
        last_entry&.target_id == item.id
      last_entry = nil
    end

    # аниме просмотрено и сразу же поставлена оценка
    if last_entry && (
      (
        action == UserHistoryAction::Status &&
        value == UserRate.statuses[:completed] &&
        last_entry.action == UserHistoryAction::Rate
      ) || (
        action == UserHistoryAction::Rate &&
        last_entry.action == UserHistoryAction::Status &&
        last_entry.value.to_i == UserRate.statuses[:completed]
      )
    )
      return last_entry.update(
        action: UserHistoryAction::CompleteWithScore,
        value: action == UserHistoryAction::Status ? last_entry.value : value
      )
    end

    no_last_this_entry_search = false
    case action
      when UserHistoryAction::Status

      when UserHistoryAction::Add
        last_delete = UserHistory
          .where(user_id: user.is_a?(Integer) ? user : user.id)
          .where(target: item)
          .where(action: UserHistoryAction::Delete)
          .where('updated_at > ?', DELETE_BACKWARD_CHECK_INTERVAL.ago)
          .order(:id)
          .first

        return last_delete.destroy if last_delete

      when UserHistoryAction::Delete
        prior_entries = UserHistory
          .where(user_id: user.is_a?(Integer) ? user : user.id)
          .where(target: item)
          .where('updated_at > ?', DELETE_BACKWARD_CHECK_INTERVAL.ago)
          .order(:id)
          .to_a

        if last_entry && last_entry.action == UserHistoryAction::Add
          last_entry.destroy
          return
        end
        if !prior_entries.empty? && prior_entries.first.action == UserHistoryAction::Add
          prior_entries.each(&:destroy)
          return
        else
          prior_entries.each(&:destroy)
        end

      when UserHistoryAction::Rate
        # если prior_value=nil, то считаем, что это ноль
        prior_value = 0 unless prior_value

        unless prior_value.is_a? Integer
          raise "Got prior_value #{prior_value.class.name}, but expected Int"
        end
        unless value.is_a? Integer
          raise "Got value #{prior_value.class.name}, but expected Int"
        end

        value = 10 if value > 10
        value = 0 if value.negative?

        # если сняли оценку(поставили 0), а недавно её поставили, то удаляем обе записи
        if value.zero? && last_entry && last_entry.action == UserHistoryAction::Rate
          last_entry.destroy
          return
        end
        # если поставили поставили 0, и раньше был ноль, то ничего не делаем
        return if value.zero? && prior_value.zero?

      when UserHistoryAction::Episodes, UserHistoryAction::Volumes, UserHistoryAction::Chapters
        counter =
          case action
            when UserHistoryAction::Episodes
              'episodes'
            when UserHistoryAction::Volumes
              'volumes'
            when UserHistoryAction::Chapters
              'chapters'
          end

        no_last_this_entry_search = true
        unless value.is_a? Integer
          raise "Got value #{value.class.name}, but expected Int"
        end

        # если prior_value=nil, то считаем, что это ноль
        prior_value ||= 0
        unless prior_value.is_a?(Integer)
          raise "Got prior_value #{prior_value.class.name}, but expected Int"
        end

        prior_entries = UserHistory
          .where(user_id: user.is_a?(Integer) ? user : user.id)
          .where(target: item)
          .where(action: action)
          .where('updated_at > ?', EPISODE_BACKWARD_CHECK_INTERVAL.ago)
          .order(:id)
          .to_a

        if prior_entries.any? && prior_entries.last.value.size < 250
          # если предыдущее событие было с эпизодом этого же аниме,
          # то откидываем более поздние эпизоды из списка и добавляем текущий эпизод в конец списка
          unless value.zero?
            last_this_entry = prior_entries.last
            episode = value.to_i
            new_episodes = last_this_entry.send(counter).clone
            last_this_entry.send(counter).reverse_each do |v|
              if v < episode
                new_episodes << episode
                # ситуация, когда посмотрели новые эпизоды, а отмечаем более старые
                if new_episodes.last == last_this_entry.prior_value.to_i
                  last_this_entry.destroy
                  return
                end
                last_this_entry.send "#{counter}=", new_episodes
                last_this_entry.save
                return
              elsif v == episode
                last_this_entry.send "#{counter}=", new_episodes
                last_this_entry.save
                return
              else
                new_episodes.pop
              end
            end
          end

          # если поставили 0 эпизодов, а до этого были другие эпизоды, и начинали с нуля, то удаляем все записи
          if value.zero? && prior_entries.first.prior_value == '0'
            prior_entries.each(&:destroy)
            return
          end
          # если поставили 0 эпизодов, а до этого были другие эпизоды, но начинали не с нуля, то удаляем сколько сможем и пишем записть о добавлении 0 эпизодов
          if value.zero? && prior_entries.first.prior_value != '0'
            prior_entries.each(&:destroy)
          end
        end
    end

    unless no_last_this_entry_search
      entry = UserHistory
        .where('updated_at > ?', BACKWARD_CHECK_INTERVAL.ago)
        .where(user_id: user.is_a?(Integer) ? user : user.id)
        .where(target: item)
        .where(action: action)
        .first

      if entry && action == UserHistoryAction::Rate
        # для оценок изначальную оценку не меняем
        prior_value = entry.prior_value

        # если меняли несколько раз оценку и в конце-концов поставили старую назад,
        # то нам запись в истории совсем не нужна - удаляем её
        if prior_value.to_i == value
          entry.destroy
          return
        end
      end
    end

    entry ||= UserHistory.new(
      user_id: user.is_a?(Integer) ? user : user.id,
      target: item,
      action: action
    )

    entry.value = value
    entry.prior_value = prior_value
    entry.save
    entry
  end

  %w[episodes volumes chapters].each do |counter| # rubocop:disable BlockLength
    define_method(counter) do
      return @parsed_episodes if @parsed_episodes
      if action != UserHistoryAction.const_get(counter.capitalize)
        raise <<-TEXT.squish
          Got action:#{action}, but
          expected action:#{UserHistoryAction.const_get counter.capitalize}
        TEXT
      end

      @parsed_episodes = value.split(',').map(&:to_i)
    end

    define_method("#{counter}=") do |value|
      if action != UserHistoryAction.const_get(counter.capitalize)
        raise <<-TEXT.squish
          Got action:#{action}, but
          expected action:#{UserHistoryAction.const_get counter.capitalize}
        TEXT
      end

      @parsed_episodes = value
      self.value = @parsed_episodes.join(',')
    end

    # полный список всех эпизодов с учетом прошлых эпизодов в prior_value
    define_method("watched_#{counter}") do # rubocop:disable MethodLength
      if action != UserHistoryAction.const_get(counter.capitalize)
        raise <<-TEXT.squish
          Got action:#{action}, but
          expected action:#{UserHistoryAction.const_get counter.capitalize}
        TEXT
      end

      if send(counter).last && send(counter).last < prior_value.to_i
        [send(counter).last]
      else
        e_start = prior_value ? prior_value.to_i + 1 : episodes.first
        e_end = send(counter).last
        # бывает и такое. ушлые пользователи
        e_end = send(counter)[-2] || 0 if e_end > UserRate::MAXIMUM_EPISODES

        e_start.upto(e_end).inject([]) { |all, v| all << v }
      end
    end
  end
end
