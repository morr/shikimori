describe AnimesController do
  let(:anime) { create :anime }
  include_examples :db_entry_controller, :anime

  describe '#show' do
    let(:anime) { create :anime, :with_topics }

    describe 'id' do
      subject! { get :show, params: { id: anime.id } }
      it { expect(response).to redirect_to anime_url(anime) }
    end

    describe 'to_param' do
      subject! { get :show, params: { id: anime.to_param } }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#characters' do
    let(:anime) { create :anime, :with_character }
    subject! { get :characters, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#staff' do
    let(:anime) { create :anime, :with_staff }
    subject! { get :staff, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#files' do
    let(:make_request) { get :files, params: { id: anime.to_param } }

    context 'authenticated' do
      include_context :authenticated, :user
      subject! { make_request }
      it { expect(response).to have_http_status :success }
    end

    context 'guest' do
      subject! { get :files, params: { id: anime.to_param } }
      it { expect(response).to redirect_to anime_url(anime) }
    end
  end

  describe '#similar' do
    let!(:similar_anime) { create :similar_anime, src: anime }
    subject! { get :similar, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#screenshots' do
    let!(:screenshot) { create :screenshot, anime: anime }

    context 'authenticated' do
      include_context :authenticated, :user
      subject! { get :screenshots, params: { id: anime.to_param } }
      it { expect(response).to have_http_status :success }
    end

    context 'guest' do
      subject! { get :screenshots, params: { id: anime.to_param } }
      it { expect(response).to redirect_to anime_url(anime) }
    end
  end

  describe '#videos' do
    let!(:video) { create :video, :confirmed, anime: anime }

    context 'authenticated' do
      include_context :authenticated, :user
      subject! { get :videos, params: { id: anime.to_param } }
      it { expect(response).to have_http_status :success }
    end

    context 'guest' do
      subject! { get :videos, params: { id: anime.to_param } }
      it { expect(response).to redirect_to anime_url(anime) }
    end
  end

  describe '#related' do
    let!(:related_anime) { create :related_anime, source: anime, anime: create(:anime) }
    subject! { get :related, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#chronology' do
    let!(:related_anime) { create :related_anime, source: anime, anime: create(:anime) }
    subject! { get :chronology, params: { id: anime.to_param } }
    after { Animes::BannedRelations.instance.clear_cache! }
    it { expect(response).to have_http_status :success }
  end

  describe '#franchise' do
    let!(:related_anime) { create :related_anime, source: anime, anime: create(:anime) }
    subject! { get :franchise, params: { id: anime.to_param } }
    after { Animes::BannedRelations.instance.clear_cache! }
    it { expect(response).to have_http_status :success }
  end

  describe '#art' do
    subject! { get :art, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#images' do
    subject! { get :images, params: { id: anime.to_param } }
    it { expect(response).to redirect_to art_anime_url(anime) }
  end

  describe '#cosplay' do
    let(:cosplay_gallery) { create :cosplay_gallery }
    let!(:cosplay_link) { create :cosplay_gallery_link, cosplay_gallery: cosplay_gallery, linked: anime }
    subject! { get :cosplay, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#favoured' do
    let!(:favoured) { create :favourite, linked: anime }
    subject! { get :favoured, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#clubs' do
    let(:club) { create :club, :with_topics, :with_member }
    let!(:club_link) { create :club_link, linked: anime, club: club }
    subject! { get :clubs, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#collections' do
    let!(:collection) { create :collection, :published, :with_topics, :anime }
    let!(:collection_link) do
      create :collection_link, collection: collection, linked: anime
    end
    subject! { get :collections, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#summaries' do
    let(:anime) { create :anime, :with_topics }
    let!(:comment) { create :comment, :summary, commentable: anime.topic(:ru) }
    subject! { get :summaries, params: { id: anime.to_param } }

    it { expect(response).to have_http_status :success }
  end

  describe '#resources' do
    subject! { get :resources, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#other_names' do
    subject! { get :other_names, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#episode_torrents' do
    subject! { get :episode_torrents, params: { id: anime.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#autocomplete' do
    let(:anime) { build_stubbed :anime }
    let(:phrase) { 'qqq' }

    before { allow(Autocomplete::Anime).to receive(:call).and_return [anime] }
    subject! { get :autocomplete, params: { search: 'Fff' } }

    it do
      expect(collection).to eq [anime]
      expect(response.content_type).to eq 'application/json'
      expect(response).to have_http_status :success
    end
  end

  describe '#rollback_episode' do
    let(:make_request) { post :rollback_episode, params: { id: anime.to_param } }
    let(:anime) { create :anime, episodes_aired: 10 }

    context 'admin' do
      include_context :authenticated, :admin
      subject! { make_request }
      it do
        expect(resource.episodes_aired).to eq 9
        expect(response).to redirect_to edit_anime_url(anime)
      end
    end

    context 'not admin' do
      include_context :authenticated, :version_moderator
      it do
        expect { make_request }.to raise_error CanCan::AccessDenied
      end
    end
  end
end
