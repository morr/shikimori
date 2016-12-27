class CharacterMalParser < BaseMalParser
  # сбор списка элементов, которые будем импортировать
  def prepare
    ids = super
    ActiveRecord::Base.connection.
        execute("select pr.#{type}_id
                    from person_roles pr
                    left join #{type.tableize} c
                      on c.id=pr.#{type}_id
                    where
                      pr.#{type}_id is not null
                      and c.id is null").
          each {|v| ids << v["#{type}_id"].to_i }
    ids
  end

  # загрузка всей информации по персонажу
  def fetch_entry id
    entry = fetch_model id

    {
      entry: entry,
    }
  end

  # загрузка информации по персонажу
  def fetch_model id
    content = get entry_url(id)

    entry = { seyu: [] }

    doc = Nokogiri::HTML(content)

    # общие данные
    title_doc = doc.css('.breadcrumb + .normal_header')

    entry[:img] = parse_poster doc

    if title_doc.text.match(/^(.*?) ?\((.*)\)$/)
      name = cleanup($1)
      entry[:name] = name if name.present?
      entry[:japanese] = cleanup($2)
    elsif title_doc.text.match(/^(.*) ?$/)
      entry[:name] = cleanup($1)
    else
      raise "name not parsed, id: %i" % id
    end

    entry[:fullname] = cleanup doc.css('h1').text.gsub('  ', ' ')

    description_doc = doc.css('#content > table > tr > td:nth-child(2)')
    # TODO: add source to character too? (just like for anime and manga)
    entry[:description_en] = if description_doc.to_html.match(/<div class="normal_header"[\s\S]*?<\/div>([\s\S]*?)<div class="(normal_header)"/)
      Mal::TextSanitizer.new($1).call
    else
      ""
    end

    # сэйю
    staff_doc = doc.css('#content table > tr > td') if content.include?('Voice Actors')
    if staff_doc
      staff_doc.css("tr").map {|tr| tr.css('td').last }.each do |staff_doc|
        staff = {}
        url = staff_doc.css("a")[0]
        next unless url

        if url['href'].match(/\/people\/(\d+)\//)
          staff[:id] = $1.to_i
        else
          next
        end
        staff[:role] = staff_doc.css('small').text

        entry[:seyu] << staff
      end
    end

    entry
  end

  # привязка персонажа к сэйю
  def deploy_seyu entry, seyu
    # сперва удаляем все старые записи, затем создаём новые привязки
    PersonRole.where("character_id = ? and person_id is not null", entry.id).delete_all
    time = DateTime.now.strftime('%Y-%m-%d %H:%M:%S')

    queries = seyu.map do |v|
      "('#{v[:role]}', #{entry.id}, #{v[:id]}, '#{time}', '#{time}')"
    end

    ActiveRecord::Base.connection.
      execute("insert into person_roles (role, character_id, person_id, created_at, updated_at)
                  values #{queries.join(',')}") unless queries.empty?
  end
end
