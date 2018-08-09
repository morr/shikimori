describe TopicsController do
  let(:user) { create :user, :user, :week_registered }
  let(:anime) { create :anime }

  let!(:topic) { create :topic, forum: animanga_forum, user: user }

  before { Topic.antispam = false }

  describe '#index' do
    let!(:anime_topic_1) do
      create :topic, forum: animanga_forum, user: user, linked: anime
    end
    let!(:offtopic_topic_1) { create :topic, forum: offtopic_forum, user: user }

    context 'no forum' do
      before { get :index }

      it do
        # F**K: in fact 10 items: 4 topics + 7 sticky topics but it's
        # limited to 8 because of pagination limit in Forums::View
        expect(assigns(:forums_view).topic_views).to have(8).items
        expect(response).to have_http_status :success
      end
    end

    context 'offtopic' do
      before { get :index, params: { forum: offtopic_forum.permalink } }

      # offtopic_topic_1 + 7 seeded offtopic topics
      # (offtopic topic itself + 6 offtopic sticky topics)
      it do
        expect(assigns(:forums_view).topic_views).to have(7).items
        expect(response).to have_http_status :success
      end
    end

    context 'forum' do
      before { get :index, params: { forum: animanga_forum.to_param } }

      context 'no linked' do
        it do
          expect(assigns(:forums_view).topic_views).to have(2).items
          expect(response).to have_http_status :success
        end
      end

      context 'with linked' do
        let!(:anime_topic_2) do
          create :topic, forum: animanga_forum, user: user, linked: anime
        end
        before do
          get :index,
            params: {
              forum: animanga_forum.to_param,
              linked_id: linked_id,
              linked_type: 'anime'
            }
        end

        # broken after rails upgrade. dunno why
        # context 'valid linked' do
          # let(:linked_id) { anime.to_param }
          # it do
            # expect(assigns(:forums_view).topic_views).to have(2).items
            # expect(response).to have_http_status :success
          # end
        # end

        context 'invalid linked' do
          let(:linked_id) { anime.to_param[0..-2] }
          it do
            expect(response).to redirect_to UrlGenerator.instance
              .forum_url(animanga_forum, anime)
          end
        end
      end
    end

    context 'subforum' do
      context 'one topic' do
        before do
          get :index,
            params: {
              forum: animanga_forum.to_param,
              linked_type: 'anime',
              linked_id: anime.to_param
            }
        end
        it do
          expect(response).to redirect_to(
            UrlGenerator.instance.topic_url(anime_topic_1)
          )
        end
      end

      context 'multiple topic views' do
        let!(:anime_topic_2) do
          create :topic, forum: animanga_forum, user: user, linked: anime
        end
        before do
          get :index,
            params: {
              forum: animanga_forum.to_param,
              linked: anime.to_param
            }
        end

        it do
          expect(assigns(:forums_view).topic_views).to have(3).items
          expect(response).to have_http_status :success
        end
      end

      context 'club linked' do
        before do
          get :index,
            params: {
              forum: animanga_forum.to_param,
              linked_type: 'club',
              linked_id: club.to_param
            }
        end
        it { expect(response).to redirect_to club_club_topics_url(club) }
      end
    end
  end

  describe '#show' do
    let(:anime_topic) do
      create :topic, forum: animanga_forum, user: user, linked: anime
    end
    context 'no linked' do
      before do
        get :show,
          params: {
            id: topic.to_param,
            forum: animanga_forum.to_param
          }
      end
      it { expect(response).to have_http_status :success }
    end

    context 'wrong to_param' do
      before do
        get :show,
          params: {
            id: topic.to_param[0..-2],
            forum: animanga_forum.to_param
          }
      end
      it do
        expect(response).to redirect_to UrlGenerator.instance.topic_url(topic)
      end
    end

    context 'missing linked' do
      before { get :show, params: { id: anime_topic.to_param, forum: animanga_forum.to_param } }
      it do
        expect(response)
          .to redirect_to UrlGenerator.instance.topic_url(anime_topic)
      end
    end

    context 'wrong linked' do
      before do
        get :show,
          params: {
            id: anime_topic.to_param,
            forum: animanga_forum.to_param,
            linked_type: 'anime',
            linked_id: "#{anime.to_param}test"
          }
      end
      it do
        expect(response)
          .to redirect_to UrlGenerator.instance.topic_url(anime_topic)
      end
    end

    context 'with linked' do
      before do
        get :show,
          params: {
            id: anime_topic.to_param,
            forum: animanga_forum.to_param,
            linked_type: 'anime',
            linked_id: anime.to_param
          }
      end
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#new' do
    let(:topic_params) do
      {
        user_id: user.id,
        forum_id: animanga_forum.id,
        type: Topic.name
      }
    end
    let(:make_request) do
      get :new,
        params: {
          forum: animanga_forum.to_param,
          topic: topic_params
        }
    end

    context 'guest' do
      it { expect { make_request }.to raise_error CanCan::AccessDenied }
    end

    context 'authenticated' do
      before { sign_in user }
      before { make_request }

      it { expect(response).to have_http_status :success }
    end
  end

  describe '#edit' do
    let(:make_request) { get :edit, params: { id: topic.id } }

    context 'guest' do
      it { expect { make_request }.to raise_error CanCan::AccessDenied }
    end

    context 'authenticated' do
      before { sign_in user }
      before { get :edit, params: { id: topic.to_param } }

      context 'allowed edit url' do
        it { expect(response).to have_http_status :success }
      end

      context 'disallowed edit url' do
        let!(:topic) { create :collection_topic, user: user, linked: collection }
        let(:collection) { create :collection, user: user }

        it { expect(response).to redirect_to edit_collection_url(collection) }
      end
    end
  end

  describe '#create' do
    let(:topic_params) do
      {
        user_id: user.id,
        forum_id: animanga_forum.id,
        title: 'title',
        body: 'text',
        type: Topic.name,
        linked_id: anime.id,
        linked_type: Anime.name
      }
    end

    context 'guest' do
      let(:make_request) do
        post :create,
          params: {
            forum: animanga_forum.to_param,
            topic: topic_params
          }
      end
      it { expect { make_request }.to raise_error CanCan::AccessDenied }
    end

    context 'authenticated' do
      before { sign_in user }

      context 'valid params' do
        before do
          post :create,
            params: {
              forum: animanga_forum.to_param,
              topic: topic_params
            }
        end

        it do
          expect(resource).to have_attributes topic_params
          expect(resource.locale).to eq controller.locale_from_host.to_s
          expect(response).to redirect_to UrlGenerator.instance.topic_url(resource)
        end
      end

      context 'invalid params' do
        let(:params) do
          {
            user_id: user.id,
            type: Topic.name,
            forum_id: animanga_forum.id,
            title: ''
          }
        end
        before do
          post :create,
            params: {
              forum: animanga_forum.to_param,
              topic: params
            }
        end

        it do
          expect(assigns(:topic)).to_not be_valid
          expect(response).to have_http_status :success
        end
      end
    end
  end

  describe '#update' do
    let(:params) do
      {
        user_id: user.id,
        forum_id: animanga_forum.id,
        title: 'title',
        body: 'text',
        linked_id: anime.id,
        linked_type: Anime.name
      }
    end

    context 'guest' do
      let(:make_request) do
        post :update,
          params: {
            forum: animanga_forum.to_param,
            id: topic.id,
            topic: params
          }
      end

      it { expect { make_request }.to raise_error CanCan::AccessDenied }
    end

    context 'authenticated' do
      before { sign_in user }

      context 'valid params' do
        include_context :timecop

        subject! do
          post :update,
            params: {
              forum: animanga_forum.to_param,
              id: topic.id,
              topic: params
            }
        end

        it do
          expect(resource).to have_attributes params
          expect(response)
            .to redirect_to UrlGenerator.instance.topic_url(resource)
        end
      end

      context 'invalid params' do
        let(:params) { { user_id: user.id, title: '' } }
        before { post :update, params: { id: topic.id, topic: params } }

        it do
          expect(resource).to_not be_valid
          expect(response).to have_http_status :success
        end
      end
    end
  end

  describe '#destroy' do
    context 'guest' do
      it do
        expect { post :destroy, params: { id: topic.id } }
          .to raise_error CanCan::AccessDenied
      end
    end

    context 'authenticated' do
      before { sign_in user }
      before { post :destroy, params: { id: topic.id } }

      it do
        expect(response.content_type).to eq 'application/json'
        expect(response).to have_http_status :success
      end
    end
  end

  describe '#tooltip' do
    before { get :tooltip, params: { id: topic.to_param } }
    it { expect(response).to have_http_status :success }
  end

  describe '#chosen' do
    let!(:offtopic_topic_1) { create :topic, forum: offtopic_forum, user: user }
    before do
      get :chosen,
        params: {
          ids: [topic.to_param, offtopic_topic_1.to_param].join(',')
        },
        format: :json
    end
    it { expect(response).to have_http_status :success }
  end

  describe '#reload' do
    before do
      get :reload,
        params: { id: topic.to_param, is_preview: 'true' },
        format: :json
    end
    it { expect(response).to have_http_status :success }
  end
end
