describe Api::V1::CommentsController do
  include_context :authenticated
  let(:user) { seed :user_day_registered }

  let(:topic) { create :topic, user: user }
  let(:comment) { create :comment, commentable: topic, user: user }

  describe '#show', :show_in_doc do
    before { sign_out user }
    subject! { get :show, params: { id: comment.id }, format: :json }

    it do
      expect(json).to have_key :user
      expect(response).to have_http_status :success
      expect(response.content_type).to eq 'application/json'
    end
  end

  describe '#index', :show_in_doc do
    before { sign_out user }

    let!(:comment_1) { create :comment, commentable: user }
    let!(:comment_2) { create :comment, commentable: user }

    subject! do
      get :index,
        params: {
          commentable_type: User.name,
          commentable_id: user.id,
          page: 1,
          limit: 10,
          desc: '1'
        },
        format: :json
    end

    it do
      expect(response).to have_http_status :success
      expect(response.content_type).to eq 'application/json'
    end
  end

  describe '#create' do
    let(:params) do
      {
        commentable_id: topic.id,
        commentable_type: Topic.name,
        body: body,
        is_offtopic: true,
        is_summary: true
      }
    end
    let(:is_broadcast) { false }
    before { allow(Comment::Broadcast).to receive :call }

    subject! do
      post :create,
        params: {
          frontend: is_frontend,
          broadcast: is_broadcast,
          comment: params
        },
        format: :json
    end

    context 'success' do
      let(:body) { 'x' * Comment::MIN_SUMMARY_SIZE }

      context 'frontend' do
        let(:is_frontend) { true }
        it_behaves_like :successful_resource_change, :frontend
      end

      context 'broadcast' do
        let(:is_frontend) { true }
        let(:is_broadcast) { true }

        context 'can broadcast' do
          let(:user) { seed :user_admin }
          it { expect(Comment::Broadcast).to have_received(:call).with resource }
        end

        context 'cannot broadcast' do
          it { expect(Comment::Broadcast).to_not have_received :call }
        end
      end

      context 'api', :show_in_doc do
        let(:is_frontend) { false }
        it_behaves_like :successful_resource_change, :api
      end
    end

    context 'failure' do
      let(:body) { '' }

      context 'frontend' do
        let(:is_frontend) { true }
        it_behaves_like :failed_resource_change
      end

      context 'api' do
        let(:is_frontend) { false }
        it_behaves_like :failed_resource_change
      end
    end
  end

  describe '#update' do
    let(:params) { { body: body } }

    subject! do
      patch :update,
        params: {
          id: comment.id,
          frontend: is_frontend,
          comment: params
        },
        format: :json
    end

    context 'success' do
      let(:body) { 'blablabla' }

      context 'frontend' do
        let(:is_frontend) { true }
        it_behaves_like :successful_resource_change, :frontend
      end

      context 'api', :show_in_doc do
        let(:is_frontend) { false }
        it_behaves_like :successful_resource_change, :api
      end
    end

    context 'failure' do
      let(:body) { '' }

      context 'frontend' do
        let(:is_frontend) { true }
        it_behaves_like :failed_resource_change
      end

      context 'api' do
        let(:is_frontend) { false }
        it_behaves_like :failed_resource_change
      end
    end
  end

  describe '#destroy' do
    let(:make_request) { delete :destroy, params: { id: comment.id }, format: :json }

    context 'success', :show_in_doc do
      subject! { make_request }
      it do
        expect(response).to have_http_status :success
        expect(response.content_type).to eq 'application/json'
        expect(json[:notice]).to eq 'Комментарий удалён'
      end
    end

    context 'forbidden' do
      let(:comment) { create :comment, commentable: topic }
      it { expect { make_request }.to raise_error CanCan::AccessDenied }
    end
  end
end
