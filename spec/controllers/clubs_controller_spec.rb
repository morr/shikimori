# frozen_string_literal: true

describe ClubsController do
  describe '#index' do
    let!(:club) { create :club, :with_topics, id: 999_999 }
    let!(:club_role) { create :club_role, club: club, user: user, role: 'admin' }

    describe 'no_pagination' do
      before { get :index }

      it do
        expect(collection).to eq [club]
        expect(response).to have_http_status :success
      end
    end

    describe 'pagination' do
      before { get :index, params: { page: 1 } }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#show' do
    let(:club) { create :club, :with_topics }
    let(:make_request) { get :show, params: { id: club.to_param } }

    context 'club locale == locale from domain' do
      before { make_request }
      it { expect(response).to have_http_status :success }
    end

    context 'club locale != locale from domain' do
      before { allow(controller).to receive(:ru_host?).and_return false }
      it { expect { make_request }.to raise_error ActiveRecord::RecordNotFound }
    end
  end

  describe '#new' do
    include_context :authenticated, :user, :week_registered
    before { get :new, params: { club: { owner_id: user.id } } }
    it { expect(response).to have_http_status :success }
  end

  describe '#edit' do
    include_context :authenticated, :user, :week_registered
    let(:club) { create :club, owner: user }
    before { get :edit, params: { id: club.to_param, page: 'main' } }

    it { expect(response).to have_http_status :success }
  end

  describe '#create' do
    include_context :authenticated, :user, :week_registered

    context 'valid params' do
      before { post :create, params: { club: params } }
      let(:params) { { name: 'test', owner_id: user.id } }

      it do
        expect(resource).to be_persisted
        expect(response).to redirect_to edit_club_url(resource, page: 'main')
      end
    end

    context 'invalid params' do
      before { post :create, params: { club: params } }
      let(:params) { { owner_id: user.id } }

      it do
        expect(resource).to be_new_record
        expect(response).to have_http_status :success
      end
    end
  end

  describe '#update' do
    include_context :authenticated, :user, :week_registered
    let(:club) { create :club, :with_topics, owner: user }

    context 'valid params' do
      before do
        patch :update,
          params: {
            id: club.id,
            club: params,
            page: 'description'
          }
      end
      let(:params) { { name: 'test club' } }

      it do
        expect(resource.errors).to be_empty
        expect(resource).to_not be_changed
        expect(resource).to have_attributes params
        expect(response).to redirect_to edit_club_url(resource, page: :description)
      end
    end

    context 'invalid params' do
      before do
        patch 'update',
          params: {
            id: club.id,
            club: params,
            page: 'description'
          }
      end
      let(:params) { { name: '' } }

      it do
        expect(resource.errors).to be_present
        expect(response).to have_http_status :success
      end
    end
  end

  describe '#members' do
    before { get :members, params: { id: club.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#images' do
    before { get :images, params: { id: club.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#animes' do
    context 'without_animes' do
      before { get :animes, params: { id: club.to_param } }
      it { expect(response).to redirect_to club_url(club) }
    end

    context 'with_animes' do
      let(:club) { create :club, :with_topics, :linked_anime }
      before { get :animes, params: { id: club.to_param } }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#mangas' do
    context 'without_mangas' do
      before { get :mangas, params: { id: club.to_param } }
      it { expect(response).to redirect_to club_url(club) }
    end

    context 'with_mangas' do
      let(:club) { create :club, :with_topics, :linked_manga }
      before { get :mangas, params: { id: club.to_param } }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#ranobe' do
    context 'without_ranobe' do
      before { get :ranobe, params: { id: club.to_param } }
      it { expect(response).to redirect_to club_url(club) }
    end

    context 'with_ranobe' do
      let(:club) { create :club, :with_topics, :linked_ranobe }
      before { get :ranobe, params: { id: club.to_param } }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#characters' do
    context 'without_characters' do
      before { get :characters, params: { id: club.to_param } }
      it { expect(response).to redirect_to club_url(club) }
    end

    context 'with_characters' do
      let(:club) { create :club, :with_topics, :linked_character }
      before { get :characters, params: { id: club.to_param } }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#autocomplete' do
    let(:phrase) { 'Fff' }
    let(:club_1) { create :club, :with_topics }
    let(:club_2) { create :club, :with_topics }

    before do
      allow(Elasticsearch::Query::Club).to receive(:call).with(
        locale: :ru,
        phrase: phrase,
        limit: Collections::Query::SEARCH_LIMIT
      ).and_return(
        club_1.id => 987,
        club_2.id => 654
      )
    end
    subject! { get :autocomplete, params: { search: phrase } }

    it do
      expect(collection).to eq [club_2, club_1]
      expect(response).to have_http_status :success
      expect(response.content_type).to eq 'application/json'
    end
  end
end
