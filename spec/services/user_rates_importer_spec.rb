describe UserRatesImporter do
  let(:anime_1) { create :anime, name: 'Zombie-Loan', episodes: 22 }
  let(:anime_2) { create :anime, name: 'Zombie-Loan Specials' }

  let(:anime_1_id) { anime_1.id }
  let(:anime_1_status) { UserRate.statuses[:watching] }
  let(:list) do
    [{
      status: anime_1_status,
      score: 5,
      target_id: anime_1_id,
      target_type: 'Anime',
      episodes: 1,
      rewatches: 2,
      volumes: 7,
      chapters: 8,
      text: 'test'
    }, {
      status: UserRate.statuses[:completed],
      score: 8,
      target_id: anime_2.id,
      target_type: 'Anime',
      episodes: 20
    }]
  end
  let(:importer) { UserRatesImporter.new user, Anime }
  let(:with_replace) { false }

  subject { importer.import list, with_replace }

  let(:added) { subject[0] }
  let(:updated) { subject[1] }
  let(:not_imported) { subject[2] }

  context 'new records' do
    before { subject }

    context 'everything is matched' do
      it do
        expect(added.size).to eq(2)
        expect(updated).to be_empty
        expect(not_imported).to be_empty

        rates = user.reload.anime_rates.to_a
        expect(rates.size).to eq(2)
        expect(rates.first.target_id).to eq anime_1_id
        expect(rates.first).to be_watching
        expect(rates.first.rewatches).to eq 2
        expect(rates.first.score).to eq 5
        expect(rates.first.episodes).to eq 1
        expect(rates.first.volumes).to eq 7
        expect(rates.first.chapters).to eq 8
        expect(rates.first.text).to eq 'test'
        expect(rates.first.status).to eq 'watching'
      end
    end

    context 'nil id is not matched' do
      let(:anime_1_id) { nil }

      it do
        expect(added.size).to eq(1)
        expect(updated).to be_empty
        expect(not_imported.size).to eq(1)

        expect(user.reload.anime_rates.size).to eq(1)
      end
    end

    context 'nil status is not matched' do
      let(:anime_1_status) { nil }

      it do
        expect(added.size).to eq(1)
        expect(updated).to be_empty
        expect(not_imported.size).to eq(1)

        expect(user.reload.anime_rates.size).to eq(1)
      end
    end
  end

  context 'existing records' do
    let!(:user_rate) { create :user_rate, user: user, anime: anime_1 }
    before { subject }

    describe 'replace' do
      let(:with_replace) { true }

      it do
        expect(added.size).to eq(1)
        expect(updated.size).to eq(1)
        expect(not_imported).to be_empty
        expect(user.reload.anime_rates.size).to eq(2)
      end
    end

    describe 'w/o replace' do
      let(:with_replace) { false }

      it do
        expect(added.size).to eq(1)
        expect(updated).to be_empty
        expect(not_imported).to be_empty
        expect(user.reload.anime_rates.size).to eq(2)
      end
    end
  end
end
