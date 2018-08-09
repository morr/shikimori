describe UserHistory do
  describe 'relations' do
    it { is_expected.to belong_to :user }
    it { is_expected.to belong_to :target }
    it { is_expected.to belong_to :anime }
    it { is_expected.to belong_to :manga }
  end

  describe 'class methods' do
    describe '.add' do
      let(:user) { create :user, id: 1 }
      let(:user2) { build_stubbed :user, id: 2 }

      let(:kind) { %i[anime manga ranobe].sample }
      let(:anime) { build_stubbed kind, id: 1 }
      let(:anime_2) { build_stubbed kind, id: 2 }

      it 'added anime successfully', :focus do
        expect {
          UserHistory.add user, anime, UserHistoryAction::Add
        }.to change(UserHistory, :count).by 1
        expect(UserHistory.last.action).to eq UserHistoryAction::Add
      end

      describe 'added anime and' do
        before { UserHistory.add user, anime, UserHistoryAction::Add }

        it 'again added anime' do
          expect {
            UserHistory.add user, anime, UserHistoryAction::Add
          }.to change(UserHistory, :count).by 0
        end

        it 'again added anime and then added anime_2' do
          expect {
            UserHistory.add user, anime, UserHistoryAction::Add
            UserHistory.add user, anime_2, UserHistoryAction::Add
          }.to change(UserHistory, :count).by 1
        end

        it 'another user added anime too' do
          expect {
            UserHistory.add user2, anime, UserHistoryAction::Add
          }.to change(UserHistory, :count).by 1
        end

        it 'then deleted it in UserHistory::DELETE_BACKWARD_CHECK_INTERVAL' do
          UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL - 1.minute, updated_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL - 1.minute
          expect {
            UserHistory.add user, anime, UserHistoryAction::Delete
          }.to change(UserHistory, :count).by -1
        end

        it 'added anime_2 and then deleted it after UserHistory::DELETE_BACKWARD_CHECK_INTERVAL' do
          UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL - 1.minute, updated_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL - 1.minute
          expect {
            UserHistory.add user, anime_2, UserHistoryAction::Add
            UserHistory.add user, anime, UserHistoryAction::Delete
          }.to change(UserHistory, :count).by 2
          expect(UserHistory.last.action).to eq UserHistoryAction::Delete
        end

        it 'did some actions with it and with other animes and then deleted first added anime in UserHistory::DELETE_BACKWARD_CHECK_INTERVAL' do
          UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL + 1.minutes, updated_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL + 1.minutes
          expect {
            # and did some actions with it and with other animes
            UserHistory.add user, anime, UserHistoryAction::Rate, 1
            UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL + 2.minutes, updated_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL + 2.minutes
            UserHistory.add user, anime_2, UserHistoryAction::Add
            UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL + 3.minutes, updated_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL + 3.minutes

            # and then deleted first added anime
            UserHistory.add user, anime, UserHistoryAction::Delete
          }.to change(UserHistory, :count).by 0
        end

        it 'did some actions with it and with other animes and then deleted first added anime after UserHistory::DELETE_BACKWARD_CHECK_INTERVAL' do
          UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL - 1.minute, updated_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL - 1.minute
          expect {
            # and did some actions with it and with other animes
            UserHistory.add user, anime, UserHistoryAction::Rate, 1
            UserHistory.last.update_attributes created_at: DateTime.now - 5.minutes, updated_at: DateTime.now - 5.minutes
            UserHistory.add user, anime_2, UserHistoryAction::Add
            UserHistory.last.update_attributes created_at: DateTime.now - 4.minutes, updated_at: DateTime.now - 4.minutes

            # and then deleted first added anime
            UserHistory.add user, anime, UserHistoryAction::Delete
          }.to change(UserHistory, :count).by 2
        end

        it 'added anime_2 and deleted anime and then added it again' do
          UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL + 1.minute, updated_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL + 1.minute
          UserHistory.add user, anime_2, UserHistoryAction::Delete
          expect {
            UserHistory.add user, anime, UserHistoryAction::Delete
            UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL - 1.minute, updated_at: DateTime.now - UserHistory::DELETE_BACKWARD_CHECK_INTERVAL - 1.minute
            UserHistory.add user, anime, UserHistoryAction::Add
          }.to change(UserHistory, :count).by 0
        end
      end

      it 'rated anime' do
        expect {
          UserHistory.add user, anime, UserHistoryAction::Rate, 5
        }.to change(UserHistory, :count).by 1
        expect(UserHistory.last.action).to eq UserHistoryAction::Rate
        expect(UserHistory.last.value).to eq '5'
      end

      it 'rate with score greater then 10 should be treated like 10' do
        expect {
          UserHistory.add user, anime, UserHistoryAction::Rate, 100000000000000
        }.to change(UserHistory, :count).by 1
        expect(UserHistory.last.action).to eq UserHistoryAction::Rate
        expect(UserHistory.last.value).to eq '10'
      end

      it 'rate with score less then 0 should be treated like 0' do
        UserHistory.add user, anime, UserHistoryAction::Rate, 1
        expect {
          UserHistory.add user, anime, UserHistoryAction::Rate, -1
        }.to change(UserHistory, :count).by -1
      end

      it 'rated anime with 0 and prior rate was 0' do
        expect {
          UserHistory.add user, anime, UserHistoryAction::Rate, 0, 0
        }.to change(UserHistory, :count).by 0
      end

      it 'rated anime with 0 and prior rate was not 0' do
        expect {
          UserHistory.add user, anime, UserHistoryAction::Rate, 0, 1
        }.to change(UserHistory, :count).by 1
      end

      describe 'rated anime and' do
        let(:prior_rate) { 5 }
        before do
          UserHistory.add user, anime, UserHistoryAction::Rate, prior_rate, nil
        end

        it 'after BACKWARD_CHECK_INTERVAL rated it again with prior_rate+1 and rated it again with prior_rate' do
          UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::BACKWARD_CHECK_INTERVAL - 1.minute, updated_at: DateTime.now - UserHistory::BACKWARD_CHECK_INTERVAL - 1.minute
          expect {
            UserHistory.add user, anime, UserHistoryAction::Rate, prior_rate+1, prior_rate
            UserHistory.add user, anime, UserHistoryAction::Rate, prior_rate, prior_rate+1
          }.to change(UserHistory, :count).by 0
        end

        it 'rated it again with 0' do
          expect {
            UserHistory.add user, anime, UserHistoryAction::Rate, 0, prior_rate
          }.to change(UserHistory, :count).by -1
        end

        it 'rated it again with the same value' do
          expect {
            UserHistory.add user, anime, UserHistoryAction::Rate, 5, prior_rate
          }.to change(UserHistory, :count).by 0
          expect(UserHistory.last.action).to eq UserHistoryAction::Rate
          expect(UserHistory.last.value).to eq '5'
        end

        it 'rated it again with another value' do
          expect {
            UserHistory.add user, anime, UserHistoryAction::Rate, 6, prior_rate
          }.to change(UserHistory, :count).by 0
          expect(UserHistory.last.action).to eq UserHistoryAction::Rate
          expect(UserHistory.last.value).to eq '6'
        end

        it 'rated it with two values' do
          UserHistory.add user, anime, UserHistoryAction::Rate, 6, prior_rate
          UserHistory.add user, anime, UserHistoryAction::Rate, 7, 6
          expect(UserHistory.last.prior_value).to eq '0'
        end
      end

      it 'watched episode' do
        expect {
          UserHistory.add user, anime, UserHistoryAction::Episodes, 1
        }.to change(UserHistory, :count).by 1
        expect(UserHistory.last.action).to eq UserHistoryAction::Episodes
        expect(UserHistory.last.value).to eq '1'
        expect(UserHistory.last.prior_value).to eq '0'
      end

      describe 'watched episode and' do
        let(:prior_episode) { 1 }
        before do
          UserHistory.add user, anime, UserHistoryAction::Episodes, prior_episode
        end

        it 'watched 0 episode' do
          expect {
            UserHistory.add user, anime, UserHistoryAction::Episodes, 0, prior_episode
          }.to change(UserHistory, :count).by -1
        end 

        it 'watched the same episode again' do
          expect {
            UserHistory.add user, anime, UserHistoryAction::Episodes, 1, prior_episode
          }.to change(UserHistory, :count).by 0
        end

        it 'watched next episode' do
          expect {
            UserHistory.add user, anime, UserHistoryAction::Episodes, 2, prior_episode
          }.to change(UserHistory, :count).by 0

          expect(UserHistory.last.action).to eq UserHistoryAction::Episodes
          expect(UserHistory.last.value).to eq '1,2'
        end

        it 'watched more next episodes' do
          UserHistory.add user, anime, UserHistoryAction::Episodes, 2, prior_episode
          UserHistory.last.update value: 1.upto(88).map {|v| v }.join(',')
          expect {
            UserHistory.add user, anime, UserHistoryAction::Episodes, 89, 88
          }.to change(UserHistory, :count).by 1

          expect(UserHistory.last.action).to eq UserHistoryAction::Episodes
          expect(UserHistory.last.value).to eq '89'
        end

        it 'watched episode from another anime' do
          expect {
            UserHistory.add user, anime_2, UserHistoryAction::Episodes, 1, 0
          }.to change(UserHistory, :count).by 1
        end

        it 'watched episode from another anime and watched next episode from first anime' do
          expect {
            UserHistory.add user, anime_2, UserHistoryAction::Episodes, 1, 0
            UserHistory.add user, anime, UserHistoryAction::Episodes, 2, prior_episode
          }.to change(UserHistory, :count).by 1
        end

        it 'watched next episode and watched previous episode again' do
          expect {
            UserHistory.add user, anime, UserHistoryAction::Episodes, 2, prior_episode
            UserHistory.add user, anime, UserHistoryAction::Episodes, prior_episode, 2
          }.to change(UserHistory, :count).by 0
          expect(UserHistory.last.action).to eq UserHistoryAction::Episodes
          expect(UserHistory.last.value).to eq '1'
        end

        it 'watched next 2 episodes and watched one episode back' do
          expect {
            UserHistory.add user, anime, UserHistoryAction::Episodes, 3, prior_episode
            UserHistory.add user, anime, UserHistoryAction::Episodes, 2, 3
          }.to change(UserHistory, :count).by 0
          expect(UserHistory.last.action).to eq UserHistoryAction::Episodes
          expect(UserHistory.last.value).to eq '1,2'
        end

        it 'after UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL watched 0 episode' do
          UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL - 1.minute, updated_at: DateTime.now - UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL - 1.minute
          expect {
            UserHistory.add user, anime, UserHistoryAction::Episodes, 0, prior_episode
          }.to change(UserHistory, :count).by 1
          expect(UserHistory.last.action).to eq UserHistoryAction::Episodes
          expect(UserHistory.last.value).to eq '0'
        end

        it 'after UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL watched 2 episode' do
          UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL - 1.minute, updated_at: DateTime.now - UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL - 1.minute
          expect {
            UserHistory.add(user, anime, UserHistoryAction::Episodes, 2, prior_episode)
          }.to change(UserHistory, :count).by(1)
          expect(UserHistory.last.action).to eq(UserHistoryAction::Episodes)
          expect(UserHistory.last.value).to eq('2')
        end

        it 'after UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL watched 2 episode and watched 0 episode' do
          UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL - 1.minute, updated_at: DateTime.now - UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL - 1.minute
          expect {
            UserHistory.add user, anime, UserHistoryAction::Episodes, 2, prior_episode
            UserHistory.add user, anime, UserHistoryAction::Episodes, 0, 2
          }.to change(UserHistory, :count).by 1
          expect(UserHistory.last.action).to eq UserHistoryAction::Episodes
          expect(UserHistory.last.value).to eq '0'
        end

        it 'after UserHistory::EpisodeBackwaldCheckInterval watched 0 episode and then watched 3 episode' do
          UserHistory.last.update_attributes(created_at: DateTime.now - UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL - 1.minute, updated_at: DateTime.now - UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL - 1.minute)
          expect {
            UserHistory.add user, anime, UserHistoryAction::Episodes, 0, prior_episode
            UserHistory.add user, anime, UserHistoryAction::Episodes, 3, 0
          }.to change(UserHistory, :count).by 1
          expect(UserHistory.last.action).to eq UserHistoryAction::Episodes
          expect(UserHistory.last.value).to eq '0,3'
        end
      end

      it 'watched 7 episodes and after UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL watched 6 episode and 7 episode' do
        expect {
          UserHistory.add user, anime, UserHistoryAction::Episodes, 7
          UserHistory.last.update_attributes created_at: DateTime.now - UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL - 1.minute, updated_at: DateTime.now - UserHistory::EPISODE_BACKWARD_CHECK_INTERVAL - 1.minute
          UserHistory.add user, anime, UserHistoryAction::Episodes, 6, 7
          UserHistory.add user, anime, UserHistoryAction::Episodes, 7, 6
        }.to change(UserHistory, :count).by 1
        expect(UserHistory.last.value).to eq '7'
      end

      it "merges :completed and #{UserHistoryAction::Rate} into #{UserHistoryAction::CompleteWithScore}" do
        expect {
          UserHistory.add user, anime, UserHistoryAction::Status, UserRate.statuses[:completed]
          UserHistory.add user, anime, UserHistoryAction::Rate, 5
        }.to change(UserHistory, :count).by 1

        last = UserHistory.last
        expect(last.action).to eq UserHistoryAction::CompleteWithScore
        expect(last.value).to eq '5'
      end

      it "merges :completed and #{UserHistoryAction::Rate} into #{UserHistoryAction::CompleteWithScore} only for the same anime" do
        expect {
          UserHistory.add user, anime_2, UserHistoryAction::Status, UserRate.statuses[:completed]
          UserHistory.add user, anime, UserHistoryAction::Rate, 5
        }.to change(UserHistory, :count).by 2
      end

      it "merges #{UserHistoryAction::Rate} and :completed into #{UserHistoryAction::CompleteWithScore}" do
        expect {
          UserHistory.add user, anime, UserHistoryAction::Rate, 5
          UserHistory.add user, anime, UserHistoryAction::Status, UserRate.statuses[:completed]
        }.to change(UserHistory, :count).by 1

        last = UserHistory.last
        expect(last.action).to eq UserHistoryAction::CompleteWithScore
        expect(last.value).to eq '5'
      end
    end
  end
end
