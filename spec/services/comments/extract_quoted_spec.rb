describe Comments::ExtractQuoted do
  let(:service) { Comments::ExtractQuoted.new }

  describe '#extract' do
    subject { service.call text }

    describe 'no text' do
      let(:text) { nil }
      it do
        is_expected.to eq OpenStruct.new(
          comments: [],
          users: []
        )
      end
    end

    describe 'just quote' do
      let(:topic) { create :topic, user: user }
      let(:text) { "[quote=200778;#{user.id};test2]test[/quote]" }
      it do
        is_expected.to eq OpenStruct.new(
          comments: [],
          users: [user]
        )
      end
    end

    describe 'comment reply' do
      let(:comment) { create :comment, user: user }
      let(:text) { "[comment=#{comment.id}]test[/comment]" }

      it do
        is_expected.to eq OpenStruct.new(
          comments: [comment],
          users: [user]
        )
      end
    end

    describe 'comment quote' do
      let(:comment) { create :comment, user: user }
      let(:text) { "[quote=c#{comment.id};#{user.id};test2]test[/quote]" }

      it do
        is_expected.to eq OpenStruct.new(
          comments: [comment],
          users: [user]
        )
      end
    end

    describe 'multiple entries' do
      let(:comment_1) { create :comment, user: user }
      let(:comment_2) { create :comment, user: user }
      let(:text) do
        <<-TEXT
          [comment=#{comment_1.id}]test[/comment]
          [comment=#{comment_1.id}]test[/comment]
          [comment=#{comment_2.id}]test[/comment]
        TEXT
      end

      it do
        is_expected.to eq OpenStruct.new(
          comments: [comment_1, comment_2],
          users: [user]
        )
      end
    end
  end
end
