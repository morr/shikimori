describe AnimeMalParser, :vcr do
  before { allow(SiteParserWithCache).to receive(:load_cache).and_return cached_list: {} }
  before { allow(parser).to receive :save_cache }
  # after { sleep 1 } # раскоментить перед генерацией новых кассет

  let(:parser) { AnimeMalParser.new }
  let(:anime_id) { 1 }

  it 'have correct type' do
    expect(parser.instance_eval { type }).to eq 'anime'
  end

  it 'fetches list page' do
    expect(parser.fetch_list_page(0, :all_catalog_url).size).to eq(BaseMalParser::ENTRIES_PER_PAGE)
    expect(parser.cached_list.size).to eq(BaseMalParser::ENTRIES_PER_PAGE)
  end

  it 'fetches updated list page' do
    expect(parser.fetch_list_page(0, :updated_catalog_url).size).to eq(BaseMalParser::ENTRIES_PER_PAGE)
    expect(parser.cached_list.size).to eq(BaseMalParser::ENTRIES_PER_PAGE)
  end

  it 'fetches 3 list pages' do
    expect(parser.fetch_list_pages(limit: 3).size).to eq(3 * BaseMalParser::ENTRIES_PER_PAGE)
    expect(parser.cached_list.size).to eq(3 * BaseMalParser::ENTRIES_PER_PAGE)
  end

  it 'stops when got 0 entries' do
    urls = [
      parser.instance_eval { all_catalog_url(0) },
      parser.instance_eval { all_catalog_url(999_99) },
      parser.instance_eval { all_catalog_url(2) }
    ]
    allow(parser).to receive(:all_catalog_url).and_return(urls[0], urls[1], urls[2])

    expect(parser.fetch_list_pages(limit: 3).size).to eq(1 * BaseMalParser::ENTRIES_PER_PAGE)
    expect(parser.cached_list.size).to eq(1 * BaseMalParser::ENTRIES_PER_PAGE)
  end

  it 'fetches anime data' do
    data = parser.fetch_model(anime_id)

    expect(data[:name]).to eq 'Cowboy Bebop'
    expect(data[:kind]).to eq 'tv'
    expect(data[:status]).to eq 'released'
    expect(data[:origin]).to eq 'original'
    expect(data[:description_en]).to be_present
    expect(data[:related]).not_to be_empty
    expect(data[:english]).to eq 'Cowboy Bebop'
    expect(data).to include(:synonyms)
    expect(data[:japanese]).to eq 'カウボーイビバップ'

    expect(data[:episodes]).to eq 26

    expect(data).to include(:released_on)
    expect(data).to include(:aired_on)

    expect(data[:genres]).to eq [
      { mal_id: 1, name: 'Action', kind: 'anime' },
      { mal_id: 2, name: 'Adventure', kind: 'anime' },
      { mal_id: 4, name: 'Comedy', kind: 'anime' },
      { mal_id: 8, name: 'Drama', kind: 'anime' },
      { mal_id: 24, name: 'Sci-Fi', kind: 'anime' },
      { mal_id: 29, name: 'Space', kind: 'anime' }
    ]

    expect(data[:studios]).to eq [
      { id: 14, name: 'Sunrise' },
      # { id: 23, name: 'Bandai Visual' },
      # { id: 102, name: 'FUNimation Entertainment' },
      # { id: 233, name: 'Bandai Entertainment' }
    ]
    expect(data).to include(:duration)
    expect(data[:broadcast]).to eq nil

    expect(data[:rating]).to eq 'r'
    expect(data[:score]).to eq 8.83
    expect(data[:ranked]).to eq 23
    expect(data).to include(:popularity)
    expect(data).to include(:members)
    expect(data).to include(:favorites)

    expect(data[:img]).to eq(
      'https://myanimelist.cdn-dena.com/images/anime/4/19644.jpg'
    )
    expect(data[:external_links]).to eq(
      [
        { source: 'official_site', url: 'http://www.cowboy-bebop.net/' },
        { source: 'anime_db', url: 'http://anidb.info/perl-bin/animedb.pl?show=anime&aid=23' },
        { source: 'anime_news_network', url: 'http://www.animenewsnetwork.com/encyclopedia/anime.php?id=13' },
        { source: 'wikipedia', url: 'http://en.wikipedia.org/wiki/Cowboy_bebop' }
      ]
    )
  end

  it 'anime broadcast' do
    recs = parser.fetch_model(31_240)
    expect(recs[:broadcast]).to eq 'Mondays at 01:05 (JST)'
  end

  it 'correct synopsis' do
    data = parser.fetch_model(21_039)
    expect(data[:description_en]).to eq "A year has passed since the \
\"Tachikawa Incident\" in summer 2015. CROWDS, the system that turns the \
mentality of humans into physical form that Berg Katze gave to Rui Ninomiya \
after extracting his NOTE, has spread among the public. Prime Minister \
Sugayama backs the plan, but not everyone agrees with his policy. A \
mysterious organization attacks Sugayama's vehicle, marking the start of a \
series of new conflicts.[br][source]animenewsnetwork.com[/source]"
  end

  it 'correct score & ranked' do
    data = parser.fetch_model(31_143)
    expect(data[:ranked]).to eq 6619
    expect(data[:score]).to eq 5.93
  end

  it 'fetches anime related' do
    data = parser.fetch_model(22_043)

    expect(data[:name]).to eq 'Fairy Tail (2014)'
    expect(data[:related]).to have(4).items
  end

  it 'fetches anime characters' do
    characters, people = parser.fetch_entry_characters(anime_id)
    expect(characters).to have_at_least(29).items
    expect(people).to have_at_least(38).items
  end

  it 'fetches anime recommendations' do
    recs = parser.fetch_entry_recommendations(anime_id)
    expect(recs.size).to be >= 55
  end

  # it 'fetches anime scores' do
    # scores = parser.fetch_entry_scores(anime_id)
    # expect(scores.size).to eq(10)
  # end

  it 'fetches the whole entry' do
    expect(parser.fetch_entry(anime_id)).to have(4).items
  end

  it 'anime wo image' do
    data = parser.fetch_model(27_375)
    expect(data[:img]).to be_nil
  end

  # describe 'import' do
    # before (:each) {
      # FactoryGirl.create :anime, id: 3234
      # FactoryGirl.create :anime, id: 298, imported_at: DateTime.now
      # parser.fetch_list_page(0)
    # }

    # it 'prepares' do
      # parser.prepare.should have(BaseMalParser::ENTRIES_PER_PAGE-1).items
    # end

    # it 'imports' do
      # expect {
        # parser.import.should have(BaseMalParser::ENTRIES_PER_PAGE-1).items
      # }.to change(Anime, :count).by(BaseMalParser::ENTRIES_PER_PAGE-2)
    # end
  # end
end
