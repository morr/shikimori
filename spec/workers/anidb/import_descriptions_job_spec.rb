describe Anidb::ImportDescriptionsJob do
  subject(:perform) { job.perform }
  let(:job) { described_class.new }

  before { Timecop.freeze }
  after { Timecop.return }

  let(:anime) { create :anime }
  let(:manga) { create :manga }

  let!(:anime_external_link) do
    create :external_link,
      entry: anime,
      url: 'https://myanimelist.net/anime/889'
  end
  let!(:manga_external_link) do
    create :external_link,
      entry: manga,
      url: 'https://myanimelist.net/manga/889'
  end

  let(:parsed_anime_description_en) { 'cool anime[source]ANN[/source]' }
  let(:parsed_manga_description_en) { 'cool manga' }

  let(:processed_anime_description_en) do
    'cool anime[source]animenewsnetwork.com[/source]'
  end
  let(:processed_manga_description_en) do
    'cool manga[source]https://myanimelist.net/manga/889[/source]'
  end

  before do
    allow(Anidb::ImportDescriptionsQuery)
      .to receive(:for_import)
      .with(Anime)
      .and_return(Anime.all)
    allow(Anidb::ImportDescriptionsQuery)
      .to receive(:for_import)
      .with(Manga)
      .and_return(Manga.all)

    allow(Anidb::ParseDescription)
      .to receive(:call)
      .with(anime_external_link.url)
      .and_return(parsed_anime_description_en)
    allow(Anidb::ParseDescription)
      .to receive(:call)
      .with(manga_external_link.url)
      .and_return(parsed_manga_description_en)

    allow(Anidb::ProcessDescription)
      .to receive(:call)
      .with(parsed_anime_description_en, anime_external_link.url)
      .and_return(processed_anime_description_en)
    allow(Anidb::ProcessDescription)
      .to receive(:call)
      .with(parsed_manga_description_en, manga_external_link.url)
      .and_return(processed_manga_description_en)
  end

  before { perform }

  it do
    expect(Anidb::ParseDescription)
      .to have_received(:call)
      .with(anime_external_link.url)
      .once
    expect(Anidb::ParseDescription)
      .to have_received(:call)
      .with(manga_external_link.url)
      .once

    expect(Anidb::ProcessDescription)
      .to have_received(:call)
      .with(parsed_anime_description_en, anime_external_link.url)
      .once
    expect(Anidb::ProcessDescription)
      .to have_received(:call)
      .with(parsed_manga_description_en, manga_external_link.url)
      .once

    expect(anime.reload.description_en).to eq processed_anime_description_en
    expect(manga.reload.description_en).to eq processed_manga_description_en

    expect(anime_external_link.reload.imported_at)
      .to be_within(0.1).of(Time.zone.now)
    expect(manga_external_link.reload.imported_at)
      .to be_within(0.1).of(Time.zone.now)
  end
end
