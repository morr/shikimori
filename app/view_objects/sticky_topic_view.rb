# frozen_string_literal: true

# views for topics to be shown in sticky topics forum section:
# all of them belong to offtopic forum
class StickyTopicView < Dry::Struct
  extend Translation

  attribute :url, Types::Strict::String
  attribute :title, Types::Strict::String
  attribute :description, Types::Strict::String

  STICKY_TOPICS = %i[
    site_rules
    description_of_genres
    ideas_and_suggestions
    site_problems
    contests_proposals
  ]
  STICKY_TOPICS.each do |topic_name|
    define_singleton_method topic_name do |locale|
      topic_id = Topic::TOPIC_IDS[topic_name][locale.to_sym]
      next unless topic_id.present?

      instance_variable_get(:"@#{topic_name}_#{locale}") ||
        instance_variable_set(
          :"@#{topic_name}_#{locale}",
          new(
            url: url(topic_id),
            title: title(topic_id),
            description: description(topic_name, locale)
          )
        )
    end
  end

  private_class_method

  def self.url topic_id
    Rails.cache.fetch("sticky_topic_url_#{topic_id}") do
      UrlGenerator.instance.topic_url topics[topic_id]
    end
  end

  def self.title topic_id
    topics[topic_id].title
  end

  def self.description topic_name, locale
    i18n_t "#{topic_name}.description", locale: locale
  end

  def self.topics
    @topics ||= Hash.new do |cache, topic_id|
      cache[topic_id] = Topic.find topic_id
    end
  end
end
