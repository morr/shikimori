class RelatedAnime < ApplicationRecord
  belongs_to :source, class_name: Anime.name, touch: true
  belongs_to :anime, touch: true, optional: true
  belongs_to :manga, touch: true, optional: true
end
