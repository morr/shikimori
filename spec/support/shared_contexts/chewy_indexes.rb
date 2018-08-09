# frozen_string_literal: true

shared_context :chewy_indexes do |indexes|
  include_context :timecop, 'Thu, 10 May 2018 09:00:00 PDT -07:00'

  before do
    Array(indexes).each do |index|
      ActiveRecord::Base.connection.reset_pk_sequence! index
      "#{index.to_s.camelize}Index".constantize.purge!
    end
  end

  # if (%i[collections] & Array(indexes)).any?
  #   before do
  #     ActiveRecord::Base.connection.reset_pk_sequence! :collections
  #     CollectionsIndex.purge!
  #   end
  # end
end
