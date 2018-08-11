describe UsersController do
  describe '#index' do
    subject! { get :index }
    it do
      expect(collection).to have(4).items # 4 from seeds
      expect(response).to have_http_status :success
    end
  end

  describe '#similar' do
    subject! do
      get :similar,
        params: {
          klass: 'anime',
          threshold: UsersController::THRESHOLDS[2]
        }
    end
    it do
      expect(collection).to be_empty
      expect(response).to have_http_status :success
    end
  end

  describe '#autocomplete' do
    let(:phrase) { 'Fff' }
    before do
      allow(Elasticsearch::Query::User).to receive(:call).with(
        phrase: phrase,
        limit: Collections::Query::SEARCH_LIMIT
      ).and_return(
        user_1.id => 123,
        user_2.id => 111
      )
    end
    subject! { get :autocomplete, params: { search: phrase } }

    it do
      expect(collection).to eq [user_2, user_1]
      expect(response).to have_http_status :success
      expect(response.content_type).to eq 'application/json'
    end
  end
end
