describe AbuseRequest do
  describe 'relations' do
    it { should belong_to :comment }
    it { should belong_to :user }
    it { should belong_to :approver }
  end

  describe 'validations' do
    it { should validate_presence_of :user }
    it { should validate_presence_of :comment }

    context 'accepted' do
      subject { build :abuse_request, state: 'accepted' }
      it { should validate_presence_of :approver }
    end

    context 'rejected' do
      subject { build :abuse_request, state: 'rejected' }
      it { should validate_presence_of :approver }
    end
  end

  context 'scopes' do
    let(:comment) { create :comment, user: user }

    describe 'pending' do
      let!(:offtop) { create :abuse_request, kind: :offtopic, comment: comment }
      let!(:abuse) { create :abuse_request, kind: :abuse, comment: comment }
      let!(:accepted) { create :accepted_abuse_request, kind: :offtopic, approver: user }

      it { expect(AbuseRequest.pending).to eq [offtop] }
    end

    describe 'abuses' do
      let!(:offtop) { create :abuse_request, kind: :offtopic, comment: comment }
      let!(:abuse) { create :abuse_request, kind: :abuse, comment: comment }

      it { expect(AbuseRequest.abuses).to eq [abuse] }
    end
  end

  describe 'state_machine' do
    subject(:abuse_request) { create :abuse_request, user: user }

    describe '#take' do
      before { abuse_request.take user }
      its(:approver) { should eq user }

      context 'comment' do
        subject { abuse_request.comment }
        its(:is_offtopic) { should eq true }
      end
    end

    describe '#reject' do
      before { abuse_request.reject user }
      its(:approver) { should eq user }

      context 'comment' do
        subject { abuse_request.comment }
        its(:is_offtopic) { should eq false }
      end
    end
  end

  describe 'instance methods' do
    describe '#reason=' do
      let(:abuse_request) { build :abuse_request, reason: 'a' * 3000 }
      it { expect(abuse_request.reason).to have(AbuseRequest::MAXIMUM_REASON_SIZE).items }
    end

    describe '#punishable?' do
      let(:abuse_request) { build :abuse_request, kind: kind }
      subject { abuse_request.punishable? }

      describe true do
        context 'abuse' do
          let(:kind) { 'abuse' }
          it { should eq true }
        end

        context 'spoiler' do
          let(:kind) { 'spoiler' }
          it { should eq true }
        end
      end

      describe false do
        context 'offtopic' do
          let(:kind) { 'offtopic' }
          it { should eq false }
        end

        context 'summary' do
          let(:kind) { 'summary' }
          it { should eq false }
        end
      end
    end
  end
end
