require 'spec_helper'

describe Anime do
  context '#relations' do
    it { should have_and_belong_to_many :genres }
    it { should have_and_belong_to_many :studios }

    it { should have_many :person_roles }
    it { should have_many :characters }
    it { should have_many :people }

    it { should have_many :rates }
    it { should have_many :topics }
    it { should have_many :news }

    it { should have_many :related_animes }
    it { should have_many :related_mangas }

    it { should have_many :similar }

    it { should have_one :thread }

    it { should have_many :user_histories }

    it { should have_many :cosplay_gallery_links }
    it { should have_many :cosplay_galleries }

    it { should have_many :images }
    it { should have_attached_file :image }

    it { should have_many :screenshots }
    it { should have_many :all_screenshots }

    it { should have_many :videos }
    it { should have_many :all_videos }

    it { should have_many :anime_calendars }

    it { should have_many :reviews }

    it { should have_many :recommendation_ignores }

    it { should have_many :anime_videos }
  end

  context '#hooks' do
    it { expect{create :anime, :with_thread}.to change(AniMangaComment, :count).by 1 }
  end

  #it 'should sync episodes_aired with episodes' do
    #anime = create :anime, status: AniMangaStatus::Ongoing, episodes: 20, episodes_aired: 10
    #anime.status = AniMangaStatus::Released

    #anime.episodes_aired.should_not eq(anime.episodes)

    #anime.save

    #anime.episodes_aired.should eq(anime.episodes)
  #end

  describe AnimeNews do
    describe 'created anime' do
      it 'with Ongoing status generates new AnimeNews entry' do
        expect {
          create :anime, :with_callbacks, status: AniMangaStatus::Ongoing
        }.to change(AnimeNews.where(action: AnimeHistoryAction::Ongoing), :count).by 1
      end

      it 'with Anons status generates new AnimeNews entry' do
        expect {
          create :anime, :with_callbacks, status: AniMangaStatus::Anons
        }.to change(AnimeNews.where(action: AnimeHistoryAction::Anons), :count).by 1
      end

      it "with Released status doesn't generate new AnimeNews entry" do
        expect {
          create :anime, :with_callbacks, status: AniMangaStatus::Released
        }.to_not change(AnimeNews, :count)
      end
    end

    describe 'changed anime' do
      describe 'status' do
        it "Anons with aired_at > now() to Ongoing" do
          anime = create :anime, :with_callbacks, status: AniMangaStatus::Anons, aired_at: DateTime.now + 1.week

          expect {
            anime.update_attribute :status, AniMangaStatus::Ongoing
          }.to_not change(AnimeNews, :count)
          anime.status.should == AniMangaStatus::Anons
        end

        it 'Ongoing to Anons' do
          anime = create :anime, :with_callbacks, status: AniMangaStatus::Ongoing

          expect {
            anime.update_attribute :status, AniMangaStatus::Anons
          }.to_not change(AnimeNews, :count)
          anime.status.should == AniMangaStatus::Anons
        end

        it 'Ongoing to Release' do
          anime = create :anime, :with_callbacks, status: AniMangaStatus::Ongoing, released_at: DateTime.now

          expect {
            anime.update_attribute :status, AniMangaStatus::Released
          }.to change(AnimeNews, :count).by 1
          anime.status.should == AniMangaStatus::Released
        end

        it "should not crete news for ancient releases" do
          anime = create :anime, :with_callbacks, status: AniMangaStatus::Ongoing

          expect {
            anime.update_attributes status: AniMangaStatus::Released, released_at: DateTime.now - 33.days
          }.to_not change(AnimeNews, :count)
        end

        it 'Ongoing to Release if released_at greater than now by 1 day' do
          anime = create :anime, :with_callbacks, status: AniMangaStatus::Ongoing, released_at: DateTime.now + 2.days

          # более одного дня - не меняем статус
          expect {
            anime.update_attributes(status: AniMangaStatus::Released)
          }.to_not change(AnimeNews, :count)
          anime.status.should == AniMangaStatus::Ongoing

          # менее одного дня - меняем статус
          anime.update_attributes(released_at: DateTime.now + 1.hour)
          expect {
            anime.update_attributes(status: AniMangaStatus::Released)
          }.to change(AnimeNews, :count)
          anime.status.should == AniMangaStatus::Released
        end

        it 'Ongoing to Release with released_at more than 2.weeks.ago' do
          anime = create :anime, :with_callbacks, status: AniMangaStatus::Ongoing

          anime.update_attributes(status: AniMangaStatus::Released, released_at: DateTime.now - 15.days)
          news = AnimeNews.last

          news.processed.should be(true)
          news.created_at.should == anime.released_at
        end

        it 'Ongoing to Released to Ongoing to Released' do
          anime = create :anime, :with_callbacks, status: AniMangaStatus::Ongoing
          anime.update_attribute :status, AniMangaStatus::Released

          expect {
            anime.update_attribute :status, AniMangaStatus::Ongoing
          }.to_not change(AnimeNews, :count)
          anime.status.should == AniMangaStatus::Ongoing

          expect {
            anime.update_attribute :status, AniMangaStatus::Released
          }.to_not change(AnimeNews, :count)
          anime.status.should == AniMangaStatus::Released
        end

        it "'' to #{AniMangaStatus::Released}" do
          anime = create :anime, status: ''
          expect {
            anime.update_attributes(status: AniMangaStatus::Released, aired_at: DateTime.now - 15.months)
          }.to_not change(AnimeNews, :count)
        end
      end

      describe 'episodes' do
        it 'Anons with episodes_aired > 0 becomes Ongoing' do
          anime = create :anime, :with_callbacks, status: AniMangaStatus::Anons

          expect {
            anime.update_attribute :episodes_aired, 1
          }.to change(AnimeNews.where(action: AnimeHistoryAction::Ongoing), :count).by 1
          anime.status.should == AniMangaStatus::Ongoing
        end

        it 'Ongoing with episodes_aired == episodes becomes Released' do
          anime = create :anime, :with_callbacks, status: AniMangaStatus::Ongoing, episodes: 2, aired_at: DateTime.now - 3.month

          expect {
            anime.update_attribute :episodes_aired, 2
          }.to change(AnimeNews.where(action: AnimeHistoryAction::Release), :count).by 1
          anime.status.should == AniMangaStatus::Released
        end
      end
    end

    describe 'check_aired_episodes' do
      let (:episodes_aired) { 1 }
      before (:each) do
        @anime = create :anime, episodes_aired: episodes_aired, episodes: 24, status: AniMangaStatus::Ongoing
      end

      it 'adds AnimeNews' do
        expect {
          @anime.check_aired_episodes([
              {title: "[QTS] Mobile Suit Gundam Unicorn Vol.3 (BD H264 1280x720 24fps AAC 5.1J+5.1E).mkv"},
              {title: "[QTS] Mobile Suit Gundam Unicorn Vol.2 (BD H264 1280x720 24fps AAC 5.1J+5.1E).mkv"},
              {title: "[QTS] Mobile Suit Gundam Unicorn Vol.4 (BD H264 1280x720 24fps AAC 5.1J+5.1E).mkv"}
            ])
        }.to change(AnimeNews, :count).by(3)
      end

      it 'adds AnimeNews for intervals' do
        expect {
          @anime.check_aired_episodes([
              {title: "[QTS] Mobile Suit Gundam Unicorn Vol.5-9 (BD H264 1280x720 24fps AAC 5.1J+5.1E).mkv"}
            ])
        }.to change(AnimeNews, :count).by(5)
      end

      it 'updates episodes_aired' do
        @anime.check_aired_episodes([
            {title: "[QTS] Mobile Suit Gundam Unicorn Vol.2 (BD H264 1280x720 24fps AAC 5.1J+5.1E).mkv"}
          ])
        @anime.episodes_aired.should be(2)
      end

      it "wrong episode number shouldn't affect anime if episodes is specified" do
        expect {
          @anime.check_aired_episodes([
              {title: "[QTS] Mobile Suit Gundam Unicorn Vol.99 (BD H264 1280x720 24fps AAC 5.1J+5.1E).mkv"}
            ])
          @anime.episodes_aired.should be(episodes_aired)
        }.to_not change(AnimeNews, :count)
      end

      it "any episode number should affect anime if episodes is not specified" do
        @anime.update_attribute :episodes, 0
        expect {
          @anime.check_aired_episodes([
              {title: "[QTS] Mobile Suit Gundam Unicorn Vol.99 (BD H264 1280x720 24fps AAC 5.1J+5.1E).mkv"}
            ])
          @anime.episodes_aired.should be 99
        }.to change(AnimeNews, :count).by 1
      end
    end

    describe "reset episodes_aired" do
      let!(:anime) { create :anime, :with_callbacks, status: AniMangaStatus::Ongoing, episodes: 20, episodes_aired: 10 }

      it "shouldn't generate new AnimeNews" do
        expect {
          anime.update_attributes episodes_aired: 0
        }.to_not change(AnimeNews, :count)
      end

      it "should reset anime's AnimeNews" do
        create :anime_episode_news, linked: anime
        create :anime_episode_news, linked: anime
        expect {
          anime.update_attributes episodes_aired: 0
        }.to change(AnimeNews, :count).by -2
      end
    end
  end

  describe 'matches_for' do
    def positive_match(string, options)
      build(:anime, options).matches_for(string).should be_true
    end

    def negative_match(string, options)
      build(:anime, options).matches_for(string).should be_false
    end

    it 'works' do
      positive_match('test 123', name: 'test')
      negative_match('ttest', name: 'test')
      positive_match('test zxcv', name: 'test zxcv')
      positive_match('test zxcv bnc', name: 'test zxcv')
      negative_match('ttest zxcv bnc', name: 'test zxcv')
      negative_match('[OWA Raws] Kodomo no Jikan ~ Kodomo no Natsu Jikan ~ (DVD 1280x720 h264 AC3 soft-upcon).mp4 ', name: 'Kodomo no Jikan OVA 5')
      negative_match('[ReinForce] To Aru Majutsu no Index II - 16 (TVS 1280x720 x264 AAC).mkv', name: 'Toaru Majutsu no Index II Specials')
      positive_match('[ReinForce] To Aru Majutsu no Index II - 16 (TVS 1280x720 x264 AAC).mkv', name: 'Toaru Majutsu no Index II')
      #positive_match('[HQR] Umi monogatari TV [DVDRip 1024x576 h264 aac]', name: 'Umi Monogatari: Anata ga Ite Kureta Koto', kind: 'TV')
      negative_match('[Leopard-Raws] Maria Holic - 11 (DVD 704x480 H264 AAC).mp4', name: 'Maria Holic 2', kind: 'TV')
      negative_match('[Leopard-Raws] Maria Holic - 11 (DVD 704x480 H264 AAC).mp4', name: 'Maria†Holic Alive', synonyms: ['Maria+Holic 2', 'Maria Holic 2', 'MariaHolic 2'], kind: 'TV')
      positive_match('[Leopard-Raws] Maria Holic 2e- 11 (DVD 704x480 H264 AAC).mp4', name: 'Maria Holic 2', kind: 'TV')
      positive_match('[Leopard-Raws] Bakuman 2 #11 (DVD 704x480 H264 AAC).mp4', name: 'Bakuman 2', kind: 'TV')
      negative_match('[Leopard-Raws] Testov Test 2e- 11 (DVD 704x480 H264 AAC).mp4', name: 'Testov Test', kind: 'TV', synonyms: ['Testov Test OVA'])
      negative_match('[Leopard-Raws] Testov Test 2e- 11 (DVD 704x480 H264 AAC).mp4', name: 'Testov Test', kind: 'TV', synonyms: ['Testov Test (OVA)'])
    end

    it 'II treated like 2' do
      positive_match('[Zero-Raws] Sekai Ichi Hatsukoi II - 08 (TVS 1280x720 x264 AAC).mp4', name: 'Sekai Ichi Hatsukoi 2', kind: 'TV')
    end

    it 'minus treated like whitespace' do
      positive_match('[Zero-Raws] Sekai Ichi Hatsukoi II - 08 (TVS 1280x720 x264 AAC).mp4', name: 'Sekaiichi Hatsukoi 2', synonyms: ['Sekai-ichi Hatsukoi 2'], kind: 'TV')
    end

    it 'matches names with underscores' do
      positive_match('[sage]_Sekaiichi_Hatsukoi_2_-_07_[720p][10bit][E5CC0581].mkv', name: 'Sekaiichi Hatsukoi 2', kind: 'TV')
    end

    it 'matches name with season w/o space' do
      positive_match('[Leopard-Raws] Bakuman2 - 11 (DVD 704x480 H264 AAC).mp4', name: 'Bakuman 2', kind: 'TV')
    end

    it 'matches name with season "S" letter' do
      positive_match('Shinryaku! Ika Musume S2 - 05v2 [94DCBFF3].mkv', name: 'Shinryaku! Ika Musume 2', kind: 'TV')
    end

    it 'matches name with season "S" letter' do
      positive_match('Shinryaku! Ika Musume S2 - 05v2 [94DCBFF3].mkv', name: 'Shinryaku! Ika Musume 2', kind: 'TV')
    end

    it 'matches name with season (TV)' do
      positive_match('[TV-J] Mirai Nikki - 11 [1440x810 h264+AAC TOKYO-MX].mp4', name: 'Mirai Nikki (TV)', kind: 'TV')
    end

    it 'works for torrents_name' do
      positive_match('[TV-J] Mirai Nikki - 11 [1440x810 h264+AAC TOKYO-MX].mp4', name: 'Mirai Nikk', torrents_name: 'Mirai Nikki', kind: 'TV')
    end

    #it 'torrents_name top priority' do
      #negative_match('[TV-J] Mirai Nikki - 11 [1440x810 h264+AAC TOKYO-MX].mp4', name: 'Mirai Nikki', torrents_name: 'Mirai Nikk', kind: 'TV')
    #end

    it 'tilda and semicolon' do
      positive_match('[Zero-Raws] Queen\'s Blade ~Rebellion~ - 01 (AT-X 1280x720 x264 AAC).mp4', name: 'Queen\'s Blade: Rebellion', kind: 'TV')
    end

    it 'special symbols' do
      positive_match('[Zero-Raws] Fate kaleid liner Prism Illya - 01 (MX 1280x720 x264 AAC).mp4', name: 'Fate/kaleid liner Prisma☆Illya', kind: 'TV')
      positive_match('[Zero-Raws] Fatekaleid liner Prism Illya - 01 (MX 1280x720 x264 AAC).mp4', name: 'Fate/kaleid liner Prisma☆Illya', kind: 'TV')
      positive_match('[Zero-Raws] Fate kaleid liner PrismIllya - 01 (MX 1280x720 x264 AAC).mp4', name: 'Fate/kaleid liner Prisma☆Illya', kind: 'TV')
    end

    describe 'torrents_name specified' do
      it 'matches only exact match' do
        negative_match('[Hien] Hayate no Gotoku! - Can\'t Take My Eyes Off You - 05-06 [BD 1080p H.264 10-bit AAC]', name: 'Hayate no Gotoku! Cuties', torrents_name: 'Hayate no Gotoku! Cuties', kind: 'TV')
      end
    end
  end
end
