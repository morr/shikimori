describe Api::V1::CharactersController, :show_in_doc do
  describe '#show' do
    let(:character) { create :character, :with_topics }

    let!(:person_role_1) { create :person_role, character: character, anime: anime }
    let!(:person_role_2) { create :person_role, character: character, person: person }

    let(:anime) { create :anime }
    let(:person) { create :person }

    before { get :show, params: { id: character.id }, format: :json }

    it do
      expect(response).to have_http_status :success
      expect(response.content_type).to eq 'application/json'
    end
  end

  describe '#search' do
    let!(:character_1) { create :character, name: 'asdf' }
    let!(:character_2) { create :character, name: 'zxcv' }

    before do
      allow(Autocomplete::Character).to receive(:call) do |params|
        params[:scope].where(id: character_1.id)
      end
    end
    before { get :search, params: { q: 'asd' }, format: :json }

    it do
      expect(collection).to have(1).item
      expect(response).to have_http_status :success
      expect(response.content_type).to eq 'application/json'
    end
  end
end
