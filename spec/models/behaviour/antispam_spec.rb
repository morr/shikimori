class NoAntispam < ApplicationRecord; include Antispam; end
NoAntispam.antispam = false
class WithAntispam < ApplicationRecord; include Antispam; end

describe Antispam do
  it 'antispam?' do
    expect(WithAntispam).to be_with_antispam
    expect(NoAntispam).to_not be_with_antispam
  end

  describe Comment do
    let(:user) { build_stubbed :user, :user }
    let(:topic) { build_stubbed :topic }

    it 'works' do
      create :comment, :with_antispam, user: user, commentable: topic

      expect(-> {
        expect(-> {
          create :comment, :with_antispam, user: user, commentable: topic
        }).to raise_error ActiveRecord::RecordNotSaved
      }).to_not change Comment, :count
    end

    it 'can be disabled' do
      create :comment, :with_antispam, user: user, commentable: topic

      expect(-> {
        Comment.wo_antispam do
          create :comment, :with_antispam, user: user, commentable: topic
        end
      }).to change(Comment, :count).by 1
    end
  end
end
