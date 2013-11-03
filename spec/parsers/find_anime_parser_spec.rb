require 'spec_helper'

describe FindAnimeParser do
  before { SiteParserWithCache.stub(:load_cache).and_return entries: {} }
  before { SiteParserWithCache.stub :save_cache }

  let(:parser) { FindAnimeParser.new }

  it { parser.fetch_pages_num.should eq 34 }
  it { parser.fetch_page_links(0).should have(FindAnimeParser::PageSize).items }

  describe :fetch_entry do
    it 'common entry' do
      entry = parser.fetch_entry 'attack_on_titan'
      entry[:id].should eq 'attack_on_titan'
      entry[:names].should eq ['Вторжение гигантов', 'Attack on Titan', 'Shingeki no Kyojin']
      entry[:russian].should eq 'Вторжение гигантов'
      entry[:score].should be_within(1).of 9
      entry[:description].should be_present
      entry[:source].should eq 'http://findanime.ru/attack_on_titan'
      entry[:episodes].should have(26).items

      entry[:episodes][0][:episode].should eq 26
      entry[:episodes][0][:url].should eq 'http://findanime.ru/attack_on_titan/series26?mature=1'
      entry[:episodes][0][:videos].should have(9).items

      entry[:episodes][0][:videos][3][:kind].should eq :dubbed
      entry[:episodes][0][:videos][3][:language].should eq :russian
      entry[:episodes][0][:videos][3][:author].should eq 'JazzWay Anime'
      #entry[:episodes][0][:videos][3][:author].should eq 'JazzWay Anime'
      entry[:episodes][0][:videos][3][:episode].should eq 26

      entry[:episodes][25][:episode].should eq 1
      entry[:episodes][25][:url].should eq 'http://findanime.ru/attack_on_titan/series1?mature=1'
      entry[:episodes][25][:videos].should have(14).items
    end
  end

  describe :extract_language do
    subject { parser.extract_language text }

    describe :английские_сабы do
      let(:text) { 'Английские сабы' }
      it { should eq :english }
    end

    describe :other do
      let(:text) { 'other' }
      it { should eq :russian }
    end
  end

  describe :extract_kind do
    subject { parser.extract_kind text }

    describe :озвучка do
      let(:text) { 'Озвучка+сабы' }
      it { should eq :dubbed }
    end

    describe :озвучка do
      let(:text) { 'Озвучка' }
      it { should eq :dubbed }
    end

    describe :сабы do
      let(:text) { 'Сабы' }
      it { should eq :subtitles }
    end

    describe :английские_сабы do
      let(:text) { 'Английские сабы' }
      it { should eq :subtitles }
    end

    describe :оригинал do
      let(:text) { 'Оригинал' }
      it { should eq :raw }
    end

    describe :mismatch do
      let(:text) { 'mismatch' }
      specify { expect{subject}.to raise_error }
    end
  end

  describe :extract_url do
    subject { parser.extract_url html, 'test' }

    describe :vk_1 do
      let(:html) { "<iframe src=\"http://vk.com/video_ext.php?oid=-31193397&id=165152640&hash=924605cf891257c2&hd=1\" width=\"730\" height=\"480\" frameborder=\"0\"></iframe>" }
      it { should eq 'http://vk.com/video_ext.php?oid=-31193397&id=165152640&hash=924605cf891257c2&hd=3' }
    end

    describe :vk_2 do
      let(:html) { '<iframe src="http://vkontakte.ru/video_ext.php?oid=154832837&id=161773398&hash=3c74648f3d5c6cfc&hd=3" width="730" height="480" frameborder="0"></iframe>' }
      it { should eq 'http://vkontakte.ru/video_ext.php?oid=154832837&id=161773398&hash=3c74648f3d5c6cfc&hd=3' }
    end

    describe :myvi_1 do
      let(:html) { "<object style=\"height: 390px; width: 640px\"><param name=\"movie\" value=\"http://myvi.ru/player/flash/oIxbMgoWkVjUm-HHtYw1d1Gwj5xxyVdusrAmuarGU8ycjTIaeOcNlgGbGEZGhTGLE0\"><param name=\"allowFullScreen\" value=\"true\"><param name=\"allowScriptAccess\" value=\"always\"><embed src=\"http://myvi.ru/player/flash/oIxbMgoWkVjUm-HHtYw1d1Gwj5xxyVdusrAmuarGU8ycjTIaeOcNlgGbGEZGhTGLE0\" type=\"application/x-shockwave-flash\" allowfullscreen=\"true\" allowScriptAccess=\"always\" width=\"730\" height=\"480\"></object>" }
      it { should eq 'http://myvi.ru/player/flash/oIxbMgoWkVjUm-HHtYw1d1Gwj5xxyVdusrAmuarGU8ycjTIaeOcNlgGbGEZGhTGLE0' }
    end

    describe :myvi_2 do
      let(:html) { '<object style="width: 640px; height: 390px"><param name="allowFullScreen" value="true"/><param name="allowScriptAccess" value="always" /><param name="movie" value="http://myvi.ru/ru/flash/player/pre/oCJCcZPAwDviOuI-cOd-JrhfCmNXN_Z8j1E4-AfyYvpDRsgS_SwGRg2SBXhTpEZs30" /><param name="flashVars" value="kgzp=replace" /><embed src="http://myvi.ru/ru/flash/player/pre/oCJCcZPAwDviOuI-cOd-JrhfCmNXN_Z8j1E4-AfyYvpDRsgS_SwGRg2SBXhTpEZs30" type="application/x-shockwave-flash" allowfullscreen="true" allowScriptAccess="always" width="730" height="480" flashVars="kgzp=replace"></object>' }
      it { should eq 'http://myvi.ru/ru/flash/player/pre/oCJCcZPAwDviOuI-cOd-JrhfCmNXN_Z8j1E4-AfyYvpDRsgS_SwGRg2SBXhTpEZs30' }
    end

    describe :mail_ru_1 do
      let(:html) { "<iframe src=\"http://api.video.mail.ru/videos/embed/mail/bel_comp1/14985/16397.html\" width=\"730\" height=\"480\" frameborder=\"0\"></iframe>" }
      it { should eq 'http://api.video.mail.ru/videos/embed/mail/bel_comp1/14985/16397.html' }
    end

    describe :mail_ru_2 do
      let(:html) { "<object classid=\"clsid:d27cdb6e-ae6d-11cf-96b8-444553540000\" width=\"730\" height=\"480\" id=\"movie_name\" align=\"middle\"><param name=\"movie\" value=\"http://my9.imgsmail.ru/r/video2/uvpv3.swf?3\"/><param name=\"flashvars\" value=\"movieSrc=mail/bel_comp1/14985/15939&autoplay=0\" /><param name=\"allowFullScreen\" value=\"true\" /><param name=\"AllowScriptAccess\" value=\"always\" /><!--[if !IE]>--><object type=\"application/x-shockwave-flash\" data=\"http://my9.imgsmail.ru/r/video2/uvpv3.swf?3\" width=\"730\" height=\"480\"><param name=\"movie\" value=\"http://my9.imgsmail.ru/r/video2/uvpv3.swf?3\"/><param name=\"flashvars\" value=\"movieSrc=mail/bel_comp1/14985/15939&autoplay=0\" /><param name=\"allowFullScreen\" value=\"true\" /><param name=\"AllowScriptAccess\" value=\"always\" /><!--<![endif]--><a href=\"http://www.adobe.com/go/getflash\"><img src=\"http://www.adobe.com/images/shared/download_buttons/get_flash_player.gif\" alt=\"Get Adobe Flash player\"/></a><!--[if !IE]>--></object><!--<![endif]--></object>" }
      it { should eq 'http://api.video.mail.ru/videos/embed/mail/bel_comp1/14985/15939.html' }
    end

    describe :mail_ru_3 do
      let(:html) { '<embed src="http://img.mail.ru/r/video2/player_v2.swf?par=http://video.mail.ru/mail/ol4ik87.87/1123/$3816" flashvars="orig=2" width="730" height="480" allowfullscreen="true" wmode="opaque"/>' }
      it { should eq 'http://img.mail.ru/r/video2/player_v2.swf?par=http://video.mail.ru/mail/ol4ik87.87/1123/$3816' }
    end

    describe :rutube_1 do
      let(:html) { "<iframe type=\"text/html\" width=\"730\" height=\"480\" src=\"http://rutube.ru/video/embed/6504640\" frameborder=\"0\"></iframe>" }
      it { should eq 'http://rutube.ru/video/embed/6504640' }
    end

    describe :rutube_2 do
      let(:html) { '<OBJECT width="730" height="480"><PARAM name="movie" value="http://video.rutube.ru/28c276bcec9a0619affa8e2443551b32"></PARAM><PARAM name="wmode" value="window"></PARAM><PARAM name="allowFullScreen" value="true"></PARAM><EMBED src="http://video.rutube.ru/28c276bcec9a0619affa8e2443551b32" type="application/x-shockwave-flash" wmode="window" width="730" height="480" allowFullScreen="true" ></EMBED></OBJECT>' }
      it { should eq 'http://video.rutube.ru/28c276bcec9a0619affa8e2443551b32' }
    end

    describe :rutube_3 do
      let(:html) { '<iframe width="730" height="480" src="http://rutube.ru/embed/6127963" frameborder="0" webkitAllowFullScreen mozallowfullscreen allowfullscreen scrolling="no"> </iframe>' }
      it { should eq 'http://rutube.ru/embed/6127963' }
    end

    describe :sibnet do
      let(:html) { "<iframe width=\"730\" height=\"480\" src=\"http://video.sibnet.ru/shell.php?videoid=1186077\" frameborder=\"0\" scrolling=\"no\" allowfullscreen></iframe>" }
      it { should eq 'http://video.sibnet.ru/shell.php?videoid=1186077' }
    end

    describe :kiwi_1 do
      let(:html) { '<iframe title="Kiwi player" width="730" height="480" src="http://v.kiwi.kz/v2/s3jf896ex7h9/" frameborder="0" allowfullscreen></iframe>' }
      it { should eq 'http://v.kiwi.kz/v2/s3jf896ex7h9/' }
    end

    describe :kiwi_2 do
      let(:html) { '<object id="main_player_object" width="730" height="480"> <param name="wmode" value="opaque"/><param name="movie" value="http://p.kiwi.kz/static/player2/player.swf?config=http://p.kiwi.kz/static/player2/video.txt&url=http://farm.kiwi.kz/v/yvb2eb5r6y71/%3Fsecret%3DxrUpVyacqXt8unyeBzN4%2Bw%3D%3D&poster=http://im6.asset.kwimg.kz/screenshots/normal/yv/yvb2eb5r6y71_2.jpg&title=Mawaru+Penguin+Drum+-+23+%D1%81%D0%B5%D1%80%D0%B8%D1%8F+%28%D1%80%D1%83%D1%81.+%D1%81%D1%83%D0%B1%D1%82.+Ad...&redirect=http://kiwi.kz/watch/yvb2eb5r6y71/&page=http://kiwi.kz/watch/yvb2eb5r6y71/&embed=%3Ciframe+title%3D%22Kiwi+player%22+width%3D%22640%22+height%3D%22385%22+src%3D%22http%3A%2F%2Fv.kiwi.kz%2Fv2%2Fyvb2eb5r6y71%2F%22+frameborder%3D%220%22+allowfullscreen%3E%3C%2Fiframe%3E&related=http%3A%2F%2Fkiwi.kz%2Fapi%2Fmovies%2Frelated2%3Fhash%3Dyvb2eb5r6y71&like=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Flike%2F&unlike=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Funlike%2F&fave=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Ffave%2F&unfave=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Funfave%2F"> <param name="bgcolor" value="#000000"> <param name="allowFullScreen" value="true"> <param name="allowScriptAccess" value="always"> <embed wmode="opaque" id="main_player_embed" width="730" height="480" src="http://p.kiwi.kz/static/player2/player.swf" flashvars="config=http://p.kiwi.kz/static/player2/video.txt&url=http://farm.kiwi.kz/v/yvb2eb5r6y71/%3Fsecret%3DxrUpVyacqXt8unyeBzN4%2Bw%3D%3D&poster=http://im6.asset.kwimg.kz/screenshots/normal/yv/yvb2eb5r6y71_2.jpg&title=Mawaru+Penguin+Drum+-+23+%D1%81%D0%B5%D1%80%D0%B8%D1%8F+%28%D1%80%D1%83%D1%81.+%D1%81%D1%83%D0%B1%D1%82.+Ad...&redirect=http://kiwi.kz/watch/yvb2eb5r6y71/&page=http://kiwi.kz/watch/yvb2eb5r6y71/&embed=%3Ciframe+title%3D%22Kiwi+player%22+width%3D%22640%22+height%3D%22385%22+src%3D%22http%3A%2F%2Fv.kiwi.kz%2Fv2%2Fyvb2eb5r6y71%2F%22+frameborder%3D%220%22+allowfullscreen%3E%3C%2Fiframe%3E&related=http%3A%2F%2Fkiwi.kz%2Fapi%2Fmovies%2Frelated2%3Fhash%3Dyvb2eb5r6y71&like=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Flike%2F&unlike=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Funlike%2F&fave=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Ffave%2F&unfave=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Funfave%2F" type="application/x-shockwave-flash" allowscriptaccess="always" allowfullscreen="true"> </object>' }
      it { should eq 'http://p.kiwi.kz/static/player2/player.swf?config=http://p.kiwi.kz/static/player2/video.txt&url=http://farm.kiwi.kz/v/yvb2eb5r6y71/%3Fsecret%3DxrUpVyacqXt8unyeBzN4%2Bw%3D%3D&poster=http://im6.asset.kwimg.kz/screenshots/normal/yv/yvb2eb5r6y71_2.jpg&title=Mawaru+Penguin+Drum+-+23+%D1%81%D0%B5%D1%80%D0%B8%D1%8F+%28%D1%80%D1%83%D1%81.+%D1%81%D1%83%D0%B1%D1%82.+Ad...&redirect=http://kiwi.kz/watch/yvb2eb5r6y71/&page=http://kiwi.kz/watch/yvb2eb5r6y71/&embed=%3Ciframe+title%3D%22Kiwi+player%22+width%3D%22640%22+height%3D%22385%22+src%3D%22http%3A%2F%2Fv.kiwi.kz%2Fv2%2Fyvb2eb5r6y71%2F%22+frameborder%3D%220%22+allowfullscreen%3E%3C%2Fiframe%3E&related=http%3A%2F%2Fkiwi.kz%2Fapi%2Fmovies%2Frelated2%3Fhash%3Dyvb2eb5r6y71&like=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Flike%2F&unlike=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Funlike%2F&fave=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Ffave%2F&unfave=http%3A%2F%2Fkiwi.kz%2Fwatch%2Fyvb2eb5r6y71%2Funfave%2F' }
    end

    describe :youtube_1 do
      let(:html) { '<iframe width="730" height="480" src="http://www.youtube.com/embed/pOSilkJpCUI?feature=player_detailpage" frameborder="0" allowfullscreen></iframe>' }
      it { should eq 'http://www.youtube.com/embed/pOSilkJpCUI?feature=player_detailpage' }
    end

    describe :youtube_2 do
      let(:html) { '<object ><param name="wmode" value="opaque"/><param name="movie" value="http://www.youtube.com/v/CezgoEWr6U0?version=3&feature=player_detailpage"><param name="allowFullScreen" value="true"><param name="allowScriptAccess" value="always"><embed wmode="opaque" src="http://www.youtube.com/v/CezgoEWr6U0?version=3&feature=player_detailpage" type="application/x-shockwave-flash" allowfullscreen="true" allowScriptAccess="always" width="730" height="480"></object>' }
      it { should eq 'http://www.youtube.com/v/CezgoEWr6U0?version=3&feature=player_detailpage' }
    end

    describe :youtube_3 do
      let(:html) { '<iframe width="730" height="480" src="//www.youtube.com/embed/pmLm4phNjB4" frameborder="0" allowfullscreen></iframe>' }
      it { should eq 'http://www.youtube.com/embed/pmLm4phNjB4' }
    end

    describe :i_ua do
      let(:html) { "<iframe width=\"730\" height=\"480\" frameborder=\"0\" src=\"http://video.yandex.ru/iframe/dashaset08/pwq0ljt7p4.5028/\"></iframe>" }
      it { should eq 'http://video.yandex.ru/iframe/dashaset08/pwq0ljt7p4.5028/' }
    end

    describe :i_ua do
      let(:html) { "<OBJECT width=\"730\" height=\"480\"><PARAM name=\"movie\" value=\"http://i.i.ua/video/evp.swf?V=504dd.ac6bb.59d.8e7cdf9.k29b27ead\"></PARAM><EMBED src=\"http://i.i.ua/video/evp.swf?V=504dd.ac6bb.59d.8e7cdf9.k29b27ead\" type=\"application/x-shockwave-flash\" width=\"730\" height=\"480\"></EMBED></OBJECT>" }
      it { should eq 'http://i.i.ua/video/evp.swf?V=504dd.ac6bb.59d.8e7cdf9.k29b27ead' }
    end
  end

  describe :fetch_pages do
    before { parser.stub(:fetch_entry).and_return id: true }
    let(:pages) { 3 }

    it 'fetches pages' do
      items = nil
      expect {
        items = parser.fetch_pages(0..(pages-1))
      }.to change(parser.cache[:entries], :count).by(items)

      items.should have_at_least(ReadMangaParser::PageSize * pages - 1).items
    end
  end
end
