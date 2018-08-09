describe CharactersController do
  let!(:character) { create :character }
  include_examples :db_entry_controller, :character

  describe '#index' do
    let(:phrase) { 'qqq' }

    before do
      allow(Search::Character)
        .to receive(:call)
        .and_return Character.where(id: character.id)
    end
    before { get :index, params: { search: 'Fff' } }

    it do
      expect(collection).to eq [character]
      expect(response).to have_http_status :success
    end
  end

  describe '#show' do
    let!(:character) { create :character, :with_topics }
    before { get :show, params: { id: character.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#seyu' do
    context 'without_seyu' do
      before { get :seyu, params: { id: character.to_param } }
      it { expect(response).to redirect_to character }
    end

    context 'with_seyu' do
      let!(:role) { create :person_role, :seyu_role, character: character }
      before { get :seyu, params: { id: character.to_param } }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#animes' do
    context 'without_anime' do
      before { get :animes, params: { id: character.to_param } }
      it { expect(response).to redirect_to character }
    end

    context 'with_animes' do
      let!(:role) { create :person_role, :anime_role, character: character }
      before { get :animes, params: { id: character.to_param } }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#mangas' do
    context 'without_manga' do
      before { get :mangas, params: { id: character.to_param } }
      it { expect(response).to redirect_to character }
    end

    context 'with_mangas' do
      let!(:role) { create :person_role, :manga_role, character: character }
      before { get :mangas, params: { id: character.to_param } }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#cosplay' do
    let(:cosplay_gallery) { create :cosplay_gallery }
    let!(:cosplay_link) do
      create :cosplay_gallery_link,
        cosplay_gallery: cosplay_gallery, linked: character
    end
    before { get :cosplay, params: { id: character.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#art' do
    before { get :art, params: { id: character.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#images' do
    before { get :images, params: { id: character.to_param } }
    it { expect(response).to redirect_to art_character_url(character) }
  end

  describe '#favoured' do
    let!(:favoured) { create :favourite, linked: character }
    before { get :favoured, params: { id: character.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#collections' do
    let!(:collection) { create :collection, :published, :with_topics, :character }
    let!(:collection_link) do
      create :collection_link, collection: collection, linked: character
    end
    before { get :collections, params: { id: character.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#clubs' do
    let(:club) { create :club, :with_topics, :with_member }
    let!(:club_link) { create :club_link, linked: character, club: club }
    before { get :clubs, params: { id: character.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#autocomplete' do
    let(:character) { build_stubbed :character }
    let(:phrase) { 'qqq' }

    before { allow(Autocomplete::Character).to receive(:call).and_return [character] }
    before { get :autocomplete, params: { search: 'Fff' } }

    it do
      expect(collection).to eq [character]
      expect(response.content_type).to eq 'application/json'
      expect(response).to have_http_status :success
    end
  end
end
