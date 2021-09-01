describe Summary do
  describe 'associations' do
    it { is_expected.to belong_to :user }
    # it { is_expected.to belong_to(:anime).optional }
    # it { is_expected.to belong_to(:manga).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of :body }
    it { is_expected.to validate_presence_of :anime }
    it { is_expected.to validate_presence_of :manga }
    it { is_expected.to validate_length_of(:body).is_at_least(described_class::MIN_BODY_SIZE) }
    # it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:anime_id) }
    # it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:manga_id) }
  end

  describe 'enumerize' do
    it do
      is_expected
        .to enumerize(:opinion)
        .in(*Types::Summary::Opinion.values)
    end
  end

  describe 'scopes' do
    let(:anime) { create :anime }
    let!(:positive) { create :summary, :positive, anime: anime }
    let!(:neutral) { create :summary, :neutral, anime: anime, user: user_admin }
    let!(:negative) { create :summary, :negative, anime: anime, user: user_day_registered }

    describe 'positive' do
      it { expect(Summary.positive).to eq [positive] }
      it { expect(Summary.neutral).to eq [neutral] }
      it { expect(Summary.negative).to eq [negative] }
    end
  end

  describe 'callbacks' do
    describe '#fill_is_written_before_release' do
      subject { summary.is_written_before_release }

      let(:summary) do
        Summary.create(
          anime: anime,
          body: 'a' * described_class::MIN_BODY_SIZE,
          user: user,
          opinion: 'positive',
          is_written_before_release: is_written_before_release
        )
      end
      let(:anime) { create :anime, status, released_on: released_on }

      let(:status) { :released }
      let(:released_on) { nil }

      context 'is set' do
        context 'true' do
          let(:is_written_before_release) { true }
          it { is_expected.to eq true }
        end

        context 'false' do
          let(:is_written_before_release) { false }
          it { is_expected.to eq false }
        end
      end

      context 'not set' do
        let(:is_written_before_release) { nil }

        context 'released' do
          let(:status) { :released }

          context 'released_on is set' do
            context 'released_on > now()' do
              let(:released_on) { Time.zone.tomorrow }
              it { is_expected.to eq true }
            end

            context 'released_on <= now()' do
              let(:released_on) { Time.zone.today }
              it { is_expected.to eq false }
            end
          end
        end

        context 'not released' do
          let(:status) { %i[anons ongoing].sample }
          it { is_expected.to eq true }
        end
      end
    end
  end

  describe 'instance methods' do
    describe '#anime? & #manga?, #db_entry' do
      subject { build :summary, anime: anime, manga: manga }
      let(:anime) { nil }
      let(:manga) { nil }

      its(:anime?) { is_expected.to eq false }
      its(:manga?) { is_expected.to eq false }
      its(:db_entry) { is_expected.to eq nil }

      context 'is anime' do
        let(:anime) { build_stubbed :anime }

        its(:anime?) { is_expected.to eq true }
        its(:manga?) { is_expected.to eq false }
        its(:db_entry) { is_expected.to eq anime }
      end

      context 'is anime' do
        let(:manga) { build_stubbed :manga }

        its(:anime?) { is_expected.to eq false }
        its(:manga?) { is_expected.to eq true }
        its(:db_entry) { is_expected.to eq manga }
      end
    end

    describe '#html_body' do
      subject { build :summary, body: body }
      let(:body) { '[b]zxc[/b]' }
      its(:html_body) { is_expected.to eq '<strong>zxc</strong>' }
    end

    describe '#db_entry_released_before?' do
      let(:anime) { build_stubbed :anime, status, released_on: released_on }
      subject { build :summary, anime: anime }

      context 'released' do
        let(:status) { :released }

        context 'released_on is set' do
          context 'released_on > now()' do
            let(:released_on) { Time.zone.tomorrow }
            its(:db_entry_released_before?) { is_expected.to eq false }
          end

          context 'released_on <= now()' do
            let(:released_on) { Time.zone.today }
            its(:db_entry_released_before?) { is_expected.to eq true }
          end
        end
      end

      context 'not released' do
        let(:status) { %i[anons ongoing].sample }
        let(:released_on) { nil }
        its(:db_entry_released_before?) { is_expected.to eq false }
      end
    end

    describe '#cache_key_with_version' do
      include_context :timecop, '2021-08-01 15:44:03 +0300'

      let(:summary) { build_stubbed :summary, id: 1, user: user }
      let(:user) { build_stubbed :user, id: 2, rate_at: Time.zone.now }

      it do
        expect(summary.cache_key_with_version).to eq(
          'summaries/1-20210801124403000000/user/2/1627821843'
        )
      end
    end

    describe '#user_rate' do
      let(:summary) { build_stubbed :summary, anime: anime, manga: manga }
      let(:anime) { nil }
      let(:manga) { nil }

      subject { summary.user_rate }

      context 'no rate' do
        it { is_expected.to be_nil }
      end

      context 'anime rate' do
        let(:anime) { create :anime }
        let!(:user_rate) { create :user_rate, target: anime, user: user }

        it { is_expected.to eq user_rate }
      end

      context 'manga rate' do
        let(:manga) { create :manga }
        let!(:user_rate) { create :user_rate, target: manga, user: user }

        it { is_expected.to eq user_rate }
      end
    end
  end

  describe 'permissions' do
    subject { Ability.new user }

    context 'guest' do
      let(:user) { nil }
      let(:summary) { build_stubbed :summary }

      it { is_expected.to_not be_able_to :new, summary }
      it { is_expected.to_not be_able_to :create, summary }
      it { is_expected.to_not be_able_to :update, summary }
      it { is_expected.to_not be_able_to :destroy, summary }
    end

    context 'not summary owner' do
      let(:user) { build_stubbed :user, :user, :day_registered }
      let(:user_2) { build_stubbed :user, :user, :day_registered }
      let(:summary) { build_stubbed :summary, user: user_2 }

      it { is_expected.to_not be_able_to :new, summary }
      it { is_expected.to_not be_able_to :create, summary }
      it { is_expected.to_not be_able_to :update, summary }
      it { is_expected.to_not be_able_to :destroy, summary }
    end

    context 'summary owner' do
      let(:user) { build_stubbed :user, :user, :day_registered }
      let(:summary) { build_stubbed :summary, user: user }

      it { is_expected.to be_able_to :new, summary }
      it { is_expected.to be_able_to :create, summary }
      it { is_expected.to be_able_to :update, summary }

      context 'user is registered < 1 day ago' do
        let(:user) { build_stubbed :user, :user }

        it { is_expected.to_not be_able_to :new, summary }
        it { is_expected.to_not be_able_to :create, summary }
        it { is_expected.to_not be_able_to :update, summary }
      end

      context 'banned user' do
        let(:user) { build_stubbed :user, :banned, :day_registered }

        it { is_expected.to_not be_able_to :new, summary }
        it { is_expected.to_not be_able_to :create, summary }
        it { is_expected.to_not be_able_to :update, summary }
      end
    end

    context 'forum moderator' do
      let(:user) { build_stubbed :user, :forum_moderator }
      let(:summary) { build_stubbed :summary, user: build_stubbed(:user) }
      it { is_expected.to be_able_to :manage, summary }
    end
  end

  it_behaves_like :antispam_concern, :summary
end