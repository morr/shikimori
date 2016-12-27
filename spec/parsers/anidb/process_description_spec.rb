describe Anidb::ProcessDescription do
  subject { described_class.new.call value, anidb_url }
  let(:anidb_url) { 'http://anidb.net/perl-bin/animedb.pl?show=anime&aid=3395' }

  context 'without source' do
    let(:value) { 'foo' }
    it { is_expected.to eq("foo[source]#{anidb_url}[/source]") }
  end

  context 'with empty source' do
    let(:value) { 'foo[source][/source]' }
    it { is_expected.to eq("foo[source]#{anidb_url}[/source]") }
  end

  context 'with source' do
    let(:value) { 'foo[source]bar[/source]' }
    it do
      is_expected.to eq('foo[source]bar[/source]')
    end
  end

  context 'with source ANN' do
    let(:value) { 'foo[source]ANN[/source]' }
    it do
      is_expected.to eq('foo[source]animenewsnetwork.com[/source]')
    end
  end
end
