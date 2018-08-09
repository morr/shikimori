describe Forums::Menu do
  include_context :view_object_warden_stub

  let(:view) { Forums::Menu.new double(id: 1), nil }

  describe '#club_topics' do
    let!(:club_topic) { create :club_topic, linked: create(:club) }
    let!(:club_topic_en) { create :club_topic, linked: create(:club), locale: :en }

    it { expect(view.club_topics).to eq [club_topic] }
  end

  describe '#changeable_forums?' do
    it { expect(view.changeable_forums?).to eq false }
  end

  describe '#forums' do
    it { expect(view.forums).to be_kind_of Forums::List }
  end

  describe '#reviews' do
    let(:user_en) { build_stubbed :user }

    let!(:review) { create :review }
    let!(:review_en) { create :review, user: user_en, locale: :en }

    it { expect(view.reviews).to eq [review] }
  end

  describe '#sticky_topics' do
    it { expect(view.sticky_topics).to have(6).items }
  end

  describe '#new_topic_url' do
    it { expect(view.new_topic_url).to be_present }
  end
end
