require 'spec_helper'

describe AnimeVideo do
  it { should belong_to :anime }
  it { should belong_to :author }

  it { should validate_presence_of :anime }
  it { should validate_presence_of :url }
  it { should validate_presence_of :source }
  it { should validate_numericality_of :episode }

  describe :scopes do
    describe :worked do
      subject { AnimeVideo.worked }

      context :filter_by_video_status do
        before do
          states.each do |s|
            create :anime_video, state: s, anime: create(:anime)
          end
        end

        context :good_states do
          let(:states) { ['working', 'uploaded' ] }
          it { should have(states.size).items }
        end

        context :bad_states do
          let(:states) { ['broken', 'wrong', 'banned', 'copyrighted' ] }
          it { should have(0).items }
        end
      end
    end

    describe :allowed_play do
      subject { AnimeVideo.allowed_play }

      context :true do
        context :by_censored do
          before { create :anime_video, anime: create(:anime, censored: false) }
          it { should have(1).items }
        end

        context :by_reting do
          before { create :anime_video, anime: create(:anime, rating: 'None') }
          it { should have(1).items }
        end
      end

      context :false do
        context :by_censored do
          before { create :anime_video, anime: create(:anime, censored: true) }
          it { should be_blank }
        end

        context :by_rating do
          before do
            Anime::ADULT_RATINGS.each { |rating|
              create :anime_video, anime: create(:anime, rating: rating)
            }
          end

          it { should be_blank }
        end
      end
    end

    describe :allowed_xplay do
      subject { AnimeVideo.allowed_xplay }

      context :false do
        context :by_censored do
          before { create :anime_video, anime: create(:anime, censored: false) }
          it { should be_blank }
        end

        context :by_reting do
          before { create :anime_video, anime: create(:anime, rating: 'None') }
          it { should be_blank }
        end
      end

      context :true do
        context :by_censored do
          before { create :anime_video, anime: create(:anime, censored: true) }
          it { should have(1).items }
        end

        context :by_rating do
          before { create :anime_video, anime: create(:anime, rating: Anime::ADULT_RATINGS.first) }
          it { should have(1).items }
        end
      end
    end
  end

  describe :before_save do
    before { anime_video.save }

    describe :check_ban do
      subject { anime_video.banned? }
      let(:anime_video) { build :anime_video, url: url }

      context :in_ban do
        let(:url) { 'http://v.kiwi.kz/v2/9l7tsj8n3has/' }
        it { should be_true }
      end

      context :no_ban do
        let(:url) { 'http://vk.com/j8n3/' }
        it { should be_false }
      end
    end

    describe :copyrighted do
      let(:anime_video) { build :anime_video, anime: create(:anime, id: anime_id) }
      subject { anime_video.copyrighted? }

      context :ban do
        let(:anime_id) { AnimeVideo::CopyrightBanAnimeIDs.first }
        it { should be_true }
      end

      context :not_ban do
        let(:anime_id) { 1 }
        it { should be_false }
      end
    end
  end

  describe :hosting do
    subject { build(:anime_video, url: url).hosting }

    context :valid_url do
      let(:url) { 'http://vk.com/video_ext.php?oid=1' }
      it { should eq 'vk.com' }
    end

    context :remove_www do
      let(:url) { 'http://www.vk.com?id=1' }
      it { should eq 'vk.com' }
    end

    context :second_level_domain do
      let(:url) { 'http://www.foo.bar.com/video?id=1' }
      it { should eq 'bar.com' }
    end

    context :alias_vk_com do
      let(:url) { 'http://vkontakte.ru/video?id=1' }
      it { should eq 'vk.com' }
    end
  end

  describe '#vk?' do
    subject { video.vk? }
    let(:video) { build :anime_video, url: url }

    context :true do
      let(:url) { 'http://www.vk.com?id=1' }
      it { should be_true }
    end

    context :false do
      let(:url) { 'http://www.foo.bar.com/video?id=1' }
      it { should be_false }
    end
  end

  describe '#player_url' do
    subject { video.player_url }
    let(:video) { create :anime_video, url: url }

    context :vk do
      context :with_rejected_broken_report do
        let!(:rejected_report) { create :anime_video_report, kind: 'broken', state: 'rejected', anime_video: video }

        context :with_? do
          let(:url) { 'http://www.vk.com?id=1' }
          it { should eq "#{url}&quality=480" }
        end

        context :without_? do
          let(:url) { 'http://www.vk.com' }
          it { should eq "#{url}?quality=480" }
        end
      end

      context :with_rejected_wrong_report do
        let!(:rejected_report) { create :anime_video_report, kind: 'wrong', state: 'rejected', anime_video: video }
        let(:url) { 'http://www.vk.com?id=1' }

        it { should eq url }
      end

      context :without_reports do
        let(:url) { 'http://www.vk.com?id=1' }
        it { should eq url }
      end
    end

    context :sibnet do
      let(:url) { "http://video.sibnet.ru/shell.swf?videoid=621188" }
      context :with_rejected_broken_report do
        let!(:rejected_report) { create :anime_video_report, kind: 'broken', state: 'rejected', anime_video: video }
        it { should eq url }
      end

      context :without_reports do
        it { should eq url }
      end
    end
  end

  describe :state_machine do
    subject { video.state }
    let(:video) { create :anime_video }

    context :initial do
      it { should eq 'working' }
    end

    context :broken do
      before { video.broken }
      it { should eq 'broken' }
    end

    context :wrong do
      before { video.wrong }
      it { should eq 'wrong' }
    end

    context :ban do
      before { video.ban }
      it { should eq 'banned' }
    end
  end

  describe :allowed? do
    context :true do
      ['working', 'uploaded'].each do |state|
        specify { build(:anime_video, state: state).allowed?.should be_true }
      end
    end

    context :false do
      ['broken', 'wrong', 'banned'].each do |state|
        specify { build(:anime_video, state: state).allowed?.should be_false }
      end
    end
  end

  describe :copyright_ban do
    let(:anime_video) { build :anime_video, anime_id: anime_id }
    subject { anime_video.copyright_ban? }

    context :ban do
      let(:anime_id) { AnimeVideo::CopyrightBanAnimeIDs.first }
      it { should be_true }
    end

    context :not_ban do
      let(:anime_id) { 1 }
      it { should be_false }
    end
  end

  describe :mobile_compatible? do
    let(:anime_video) { build :anime_video, url: url }
    subject { anime_video.mobile_compatible? }

    context :true do
      context :vk_com do
        let(:url) { 'http://vk.com?video=1' }
        it { should be_true }
      end

      context :vkontakte_com do
        let(:url) { 'http://vkontakte.ru?video=1' }
        it { should be_true }
      end
    end
    context :false do
      let(:url) { 'http://rutube.ru?video=1' }
      it { should be_false }
    end
  end

  describe :uploader do
    let(:anime_video) { build_stubbed :anime_video, state: state }
    let(:user) { create :user, nickname: 'foo' }
    subject { anime_video.uploader }

    context :with_uploader do
      let(:state) { 'uploaded' }
      let(:kind) { state }
      let!(:anime_video_report) { create :anime_video_report, anime_video: anime_video, kind: kind, user: user }
      it { should eq user }
    end

    context :without_uploader do
      context :working do
        let(:state) { 'working' }
        it { should be_nil }
      end

      context :uploaded_without_report do
        let(:state) { 'uploaded' }
        it { should be_nil }
      end
    end
  end

  describe '#moderated_update' do
    let(:video) { create :anime_video, episode: 1 }
    let(:params) { {episode: 2} }

    context :without_current_user do
      let(:moderated_update) { video.moderated_update params }
      specify { moderated_update.should eq true }
      specify { moderated_update; video.reload.episode.should eq 2 }

      context :check_versions do
        before { moderated_update }
        subject { Version.last }
        let(:diff_hash) { {episode: [1,2]} }

        it { should_not be_nil }
        its(:item_id) { should eq video.id }
        its(:item_diff) { should eq diff_hash.to_s }
        its(:item_type) { should eq video.class.name }
      end
    end

    context :with_current_user do
      let(:current_user) { create :user }
      let(:moderated_update) { video.moderated_update params, current_user }
      before { moderated_update }
      subject { Version.last }

      its(:user_id) { should eq current_user.id }
    end
  end

  describe '#versions' do
    let(:video) { create :anime_video, episode: 1 }
    let(:update_params_1) { {episode: 2} }
    let(:update_params_2) { {episode: 3} }
    let(:last_diff_hash) { {episode: [2,3]} }
    before do
      video.moderated_update update_params_1
      video.moderated_update update_params_2
    end

    subject { video.reload.versions }
    it { should_not be_blank }
    it { should have(2).items }
    specify { subject.last.item_diff.should eq last_diff_hash.to_s }
  end
end
