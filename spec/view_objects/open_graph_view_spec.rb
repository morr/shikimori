describe OpenGraphView do
  include_context :view_object_warden_stub

  let(:view) { described_class.new }

  describe '#site_name' do
    before { allow(view.h).to receive(:ru_host?).and_return is_ru_host }
    subject { view.site_name }

    context 'ru_host' do
      let(:is_ru_host) { true }
      it { is_expected.to eq 'Шикимори' }
    end

    context 'not ru_host' do
      let(:is_ru_host) { false }
      it { is_expected.to eq 'Shikimori' }
    end
  end

  describe '#canonical_url' do
    subject { view.canonical_url }

    context 'no page param' do
      before { allow(view.h.request).to receive(:url).and_return url }
      let(:url) { 'http://zzz.com?123#45' }

      it { is_expected.to eq 'http://zzz.com' }
    end

    context 'page param' do
      before do
        allow(view.h).to receive(:params).and_return params
        allow(view.h).to receive(:current_url) { |hash| view.h.url_for(params.merge(hash)) }
      end

      let(:params) do
        {
          controller: 'animes_collection',
          action: 'index',
          page: 2,
          klass: 'anime'
        }
      end

      it { is_expected.to eq '/animes' }
    end
  end

  describe '#page_title, #meta_title, #headline' do
    context 'has title' do
      before do
        view.page_title = 'test'
        view.page_title = '123'
      end

      it { expect(view.meta_title).to eq '123 / test' }
      it { expect(view.headline).to eq '123' }
    end

    context 'no title' do
      before { allow(view.h).to receive(:ru_host?).and_return is_ru_host }
      let(:is_ru_host) { true }

      context 'ru_host' do
        it { expect(view.meta_title).to eq 'Шикимори' }
      end

      context 'not ru_host' do
        let(:is_ru_host) { false }
        it { expect(view.meta_title).to eq 'Shikimori' }
      end

      it { expect { view.headline }.to raise_error 'open_graph.page_title is not set' }
      it { expect { view.headline false }.to raise_error 'open_graph.page_title is not set' }
      it { expect(view.headline true).to eq view.site_name }
    end

    context 'development' do
      before do
        view.page_title = 'test'
        view.page_title = '123'
        allow(Rails.env).to receive(:development?).and_return true
      end

      it { expect(view.meta_title).to eq '[DEV] 123 / test' }
    end
  end

  describe '#notice, #description' do
    before do
      view.notice = notice
      view.description = description
    end
    let(:notice) { '123' }
    let(:description) { '456' }

    it { expect(view.notice).to eq notice }
    it { expect(view.description).to eq description }

    context 'no notice' do
      let(:notice) { nil }
      it { expect(view.notice).to be_nil }
      it { expect(view.description).to eq description }
    end

    context 'no description' do
      let(:description) { nil }
      it { expect(view.notice).to eq notice }
      it { expect(view.description).to eq notice }
    end

    context 'no notice, no description' do
      let(:notice) { nil }
      let(:description) { nil }

      it { expect(view.notice).to be_nil }
      it { expect(view.description).to be_nil }
    end
  end

  describe '#meta_robots' do
    before do
      view.noindex = noindex
      view.nofollow = nofollow
    end
    subject { view.meta_robots }

    context 'no noindex, no nofollow' do
      let(:noindex) { false }
      let(:nofollow) { false }

      it { is_expected.to be_nil }
    end

    context 'has noindex, no nofollow' do
      let(:noindex) { true }
      let(:nofollow) { false }

      it { is_expected.to eq 'noindex' }
    end

    context 'no noindex, has nofollow' do
      let(:noindex) { false }
      let(:nofollow) { true }

      it { is_expected.to eq 'nofollow' }
    end

    context 'has noindex, has nofollow' do
      let(:noindex) { true }
      let(:nofollow) { true }

      it { is_expected.to eq 'noindex,nofollow' }

      context 'has another canonical url' do
        before do
          allow(view).to receive(:canonical_url).and_return 'zzz'
          allow(view.h.request).to receive(:url).and_return 'zxc'
        end
        it { is_expected.to be_nil }
      end
    end
  end
end
