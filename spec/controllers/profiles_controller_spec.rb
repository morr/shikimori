describe ProfilesController do
  let!(:user) { create :user }

  describe '#show' do
    before { get :show, id: user.to_param }
    it { expect(response).to have_http_status :success }
  end

  describe '#friends' do
    context 'without friends' do
      before { get :friends, id: user.to_param }
      it { expect(response).to redirect_to profile_url(user) }
    end

    context 'with friends' do
      let!(:friend_link) { create :friend_link, src: user, dst: create(:user) }
      before { get :friends, id: user.to_param }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#clubs' do
    context 'without clubs' do
      before { get :clubs, id: user.to_param }
      it { expect(response).to redirect_to profile_url(user) }
    end

    context 'with clubs' do
      let(:club) { create :club, :with_topics }
      let!(:club_role) { create :club_role, user: user, club: club }
      before { get :clubs, id: user.to_param }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#favourites' do
    context 'without favourites' do
      before { get :favourites, id: user.to_param }
      it { expect(response).to redirect_to profile_url(user) }
    end

    context 'with favourites' do
      let!(:favourite) { create :favourite, user: user, linked: create(:anime) }
      before { get :favourites, id: user.to_param }
      it { expect(response).to have_http_status :success }
    end
  end

  describe '#reviews' do
    let!(:review) { create :review, :with_topics, user: user }
    before { get :reviews, id: user.to_param }
    it { expect(response).to have_http_status :success }
  end

  describe '#feed' do
    let!(:comment) { create :comment, user: user, commentable: user }
    before { get :feed, id: user.to_param }
    it { expect(response).to have_http_status :success }
  end

  describe '#comments' do
    let!(:comment) { create :comment, user: user, commentable: user }
    before { get :comments, id: user.to_param }
    it { expect(response).to have_http_status :success }
  end

  describe '#summaries' do
    let!(:comment) { create :comment, :summary, user: user, commentable: user }
    before { get :summaries, id: user.to_param }
    it { expect(response).to have_http_status :success }
  end

  describe '#versions' do
    let(:anime) { create :anime }
    let!(:version) { create :version, user: user, item: anime, item_diff: { name: ['test', 'test2'] }, state: :accepted }
    before { get :versions, id: user.to_param }

    it do
      expect(collection).to have(1).item
      expect(response).to have_http_status :success
    end
  end

  describe '#videos' do
    let!(:video) { create :video, uploader: user, state: 'confirmed', url: 'http://youtube.com/watch?v=VdwKZ6JDENc' }
    before { get :videos, id: user.to_param }
    it { expect(response).to have_http_status :success }
  end

  describe '#ban' do
    before { get :ban, id: user.to_param }
    it { expect(response).to have_http_status :success }
  end

  #describe '#stats' do
    #before { get :stats, id: user.to_param }
    #it { expect(response).to have_http_status :success }
  #end

  describe '#edit' do
    let(:make_request) { get :edit, id: user.to_param, page: page }

    context 'when valid access' do
      before { sign_in user }
      before { make_request }

      describe 'account' do
        let(:page) { 'account' }
        it { expect(response).to have_http_status :success }
      end

      describe 'profile' do
        let(:page) { 'profile' }
        it { expect(response).to have_http_status :success }
      end

      describe 'password' do
        let(:page) { 'password' }
        it { expect(response).to have_http_status :success }
      end

      describe 'styles' do
        let!(:user) { create :user, :with_assign_style }
        let(:page) { 'styles' }
        it { expect(response).to have_http_status :success }
      end

      describe 'list' do
        let(:page) { 'list' }
        it { expect(response).to have_http_status :success }
      end

      describe 'notifications' do
        let(:page) { 'notifications' }
        it { expect(response).to have_http_status :success }
      end

      describe 'misc' do
        let(:page) { 'misc' }
        it { expect(response).to have_http_status :success }
      end
    end

    context 'when invalid access' do
      let(:page) { 'account' }
      it { expect { make_request }.to raise_error CanCan::AccessDenied }
    end
  end

  describe '#update' do
    let(:make_request) { patch :update, id: user.to_param, page: 'account', user: update_params }

    context 'when valid access' do
      before { sign_in user }

      context 'when success' do
        before { make_request }

        context 'common change' do
          let(:update_params) { { nickname: 'morr' } }

          it do
            expect(resource.nickname).to eq 'morr'
            expect(resource.errors).to be_empty
            expect(response).to redirect_to edit_profile_url(resource, page: 'account')
          end
        end

        context 'association change' do
          let(:user_2) { create :user }
          let(:update_params) { { ignored_user_ids: [user_2.id] } }

          it do
            expect(resource.ignores?(user_2)).to be true
            expect(resource.errors).to be_empty
          end
        end

        context 'password change' do
          context 'when current password is set' do
            let(:user) { create :user, password: '1234' }
            let(:update_params) { { current_password: '1234', password: 'yhn' } }

            it do
              expect(resource.valid_password?('yhn')).to be true
              expect(resource.errors).to be_empty
            end
          end

          context 'when current password is not set' do
            let(:user) { create :user, :without_password }
            let(:update_params) { { password: 'yhn' } }

            it do
              expect(resource.valid_password?('yhn')).to be true
              expect(resource.errors).to be_empty
            end
          end
        end
      end

      context 'when validation errors' do
        let!(:user_2) { create :user }
        let(:update_params) { { nickname: user_2.nickname } }
        before { make_request }

        it do
          expect(resource.errors).to_not be_empty
          expect(response).to have_http_status :success
        end
      end
    end

    context 'when invalid access' do
      let(:update_params) { { nickname: '123' } }
      it { expect { make_request }.to raise_error CanCan::AccessDenied }
    end
  end
end
