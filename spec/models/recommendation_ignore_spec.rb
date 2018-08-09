describe RecommendationIgnore do
  describe 'relations' do
    it { should belong_to :user }
    it { should belong_to :target }
  end

  context 'class_methods' do
    let(:anime1) { create :anime, kind: :special }
    let(:anime2) { create :anime }
    let(:anime3) { create :anime }

    after { Animes::BannedRelations.instance.clear_cache! }

    describe '.block' do
      before do
        create :related_anime, source_id: anime2.id, anime_id: anime3.id
        create :related_anime, source_id: anime3.id, anime_id: anime2.id
      end

      subject { RecommendationIgnore.block anime3, user }

      it { should eq [anime3.id, anime2.id] }
      it { expect { subject }.to change(RecommendationIgnore, :count).by 2 }

      describe 'second run' do
        before { RecommendationIgnore.block anime3, user }
        it { should eq [anime3.id] }
        it { expect { subject }.to_not change(RecommendationIgnore, :count) }
      end

      describe 'block of new entry' do
        let(:anime4) { create :anime }
        before do
          RecommendationIgnore.block anime3, user

          create :related_anime, source_id: anime2.id, anime_id: anime4.id
          create :related_anime, source_id: anime4.id, anime_id: anime2.id
        end

        it { should eq [anime4.id, anime3.id] }
        it { expect { subject }.to change(RecommendationIgnore, :count).by 1 }
      end
    end
  end
end
