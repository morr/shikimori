describe Profiles::StatsBar do
  let(:struct) { Profiles::StatsBar.new type: Anime.name, lists_stats: stats }
  let(:stats) { [completed_list, dropped_list, planned_list] }

  let(:completed_list) do
    Profiles::ListStats.new id: 2, name: 'completed', size: 10
  end
  let(:dropped_list) do
    Profiles::ListStats.new id: 4, name: 'dropped', size: 5
  end
  let(:planned_list) do
    Profiles::ListStats.new id: 0, name: 'planned', size: 2
  end

  it do
    expect(struct.any?).to eq true

    expect(struct.total).to eq 17
    expect(struct.completed).to eq 10
    expect(struct.dropped).to eq 5
    expect(struct.incompleted).to eq 2

    expect(struct.completed_percent).to eq 58.82
    expect(struct.dropped_percent).to eq 29.42
    expect(struct.incompleted_percent).to eq 11.76
  end
end
