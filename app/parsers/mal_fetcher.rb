module MalFetcher
  @@empty_end_regex = /(<br(?: \/|)>|\r|\n|\t)+$/

  @@ban_texts = [
    "This proxy needs to find out if you are human",
    "</TITLE></HEAD><BODY><H2>",
    "require '../application/bootstrap.php';",
    "Apache Server at myanimelist.net Port 80",
    "<title>200 OK</title>",
    "CoDeeN",
    "Please identify yourself as a human",
    "</title></head><body><table",
    "Unhandled Exception",
    "Start of StatCounter Code",
    "<!--Yahoo results-->",
    "evaluation version",
    "CAPTCHA",
    "Страница заблокирована",
    "<HTML>",
    "Denied Access",
    "YOU HAVE BEEN AUTO-BANNED",
    "Your IP was temporary blocked",
    "<html><head><title>Forbidden",
    "Access to Proxy requires some authentication",
    "teikyo-u.ac.jp",
    "Unable to establish connection with",
    "<title>Login</title>",
    "<title>404: Not Found</title>",
    "<title>Document moved</title>",
    "ERROR: Forbidden",
    "was not found on this server.",
    "Das System kann die angegebene Datei nicht finden.",
    "404 Not Found",
    "object not found",
    "The requested URL could not be retrieved",
    "ERROR: Not Found",
    "Cannot connect to the configuration database",
    "Document Error: Unauthorized",
    "Error 404: Not Found",
    'Сервер на техосмотре, пожалуйста, зайдите через полчасика.'
  ]

  NO_SYNOPSYS = [
    'No synopsis has been added for this',
    'No biography written.',
    'No summary yet.'
  ]

  def self.ban_texts
    @@ban_texts
  end

  # загрузка элемента
  def fetch_entry(id)
    entry = fetch_model(id)
    characters, people = fetch_entry_characters(id)
    recommendations = fetch_entry_recommendations(id)
    #scores = fetch_entry_scores(id)

    {
      :entry => entry,
      :characters => characters,
      :people => people,
      :recommendations => recommendations,
      #:scores => scores
    }
  end

  # загрузка привязанных персонажей/людей
  def fetch_entry_characters(id)
    content = get(entry_url(id) + '/1/characters')

    characters = {}
    people = {}

    doc = Nokogiri::HTML(content)
    characters_doc = doc.css("div#content > table tr > td > div > table")
    staff_doc = characters_doc.pop unless content.include?('Add staff</a> for this anime') || content.include?('Edit Manga Information')

    characters_doc.each do |character_doc|
      node = character_doc.css("td")[1]

      character = {}
      url = node.css("a")[0]
      if url
        character[:url] = url['href']
      else
        next
      end
      if character[:url].match(/\/character\/(\d+)\//)
        character[:id] = $1.to_i
      else
        next
      end
      character[:role] = node.css('small').text

      if characters.include?(character[:id])
        characters[character[:id]].merge!(character)
      else
        characters[character[:id]] = character
      end
    end

    if staff_doc
      staff_doc.css('tr').map {|tr| tr.css('td').last }.each do |staff_doc|
        staff = {}
        url = staff_doc.css("a")[0]
        if url
          staff[:url] = url['href']
        else
          next
        end
        if staff[:url].match(/\/people\/(\d+)\//)
          staff[:id] = $1.to_i
        else
          next
        end
        staff[:role] = staff_doc.css('small').text

        if people.include?(staff[:id])
          people[staff[:id]].merge!(staff)
        else
          people[staff[:id]] = staff
        end
      end
    end
    [characters, people]
  end

  # загрузка похожих элементов
  def fetch_entry_recommendations(id)
    content = get(entry_url(id) + '/1/userrecs')

    recs = []

    doc = Nokogiri::HTML(content).css('div.borderClass > table .picSurround a')
    doc.each do |link_node|
      rec = {}
      next unless link_node['href'].match(/\/(anime|manga)\/(\d+)\//)
      key = "#{$1}_id".to_sym
      rec[key] = $2.to_i

      unless recs.any? {|v| v[key] == rec[key] }
        recs << rec
      end
    end
    recs
  end

  # загрузка оценок элемента
  #def fetch_entry_scores(id)
    #content = get(entry_url(id) + '/1/stats')

    #scores_regexp = /<td width="20">(\d+)<\/td>[\s\S]+?<td><div.*?<small>\((\d+) votes\)/
    #scores = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    #content.gsub(scores_regexp).each { |v|
      #if v.match(scores_regexp)
        #next if $1.to_i > 10
        #scores[$1.to_i - 1] = $2.to_i
      #end
    #}
    #scores
  #end

private

  def parse_block(entry, key, regexp, content)
    entry[key] = {}
    if content.match(regexp)
      related =  $1.strip.gsub(@@empty_end_regex, '').split(/<br(?: \/|)>/)
      related.each do |line|
        splits = line.split(":", 2)
        entry[key][splits[0]] = splits[1].split(",").map {|v| v.match(/\/(\d+)\//) ? $1 : nil }.compact
      end
    end
  end

  def parse_h1(content)
    content.match(/<span itemprop=\"name\">(.*?)<\/span>/) ? cleanup($1.gsub(/<(\w+).*?>.*?<\/\1>/, '')) : ""
  end

  def parse_synopsis(content)
    return if NO_SYNOPSYS.any? { |phrase| content.include? phrase }

    match_result = content.match /
      Synopsis<\/h2>
        (?:
          <span\sitemprop="description">
            (?<text> [\s\S]*? )
          <\/span>
          |
          (?<text> [\s\S]*? )
        )
      (?: <\/td>|<h2 )
    /mix

    if match_result.present?
      synopsis = Regexp.last_match[:text]
      Mal::TextSanitizer.new(synopsis).()
    else
      ''
    end
  end

  def parse_line(line_name, content, multiple_results)
    regexp = Regexp.new("<span class=\"dark_text\">%s:</span>([\\s\\S]*?)(?:</div>|<div class=)" % line_name)
    if content.match(regexp)
      match =  $1.strip.gsub(@@empty_end_regex, '');
      multiple_results ? match.split(",").map {|v| v.strip } || [] : match
    else
      multiple_results ? [] : ""
    end
  end

  def parse_score(content)
    line = parse_line('Score', content, false).gsub(/\<(.+?)\>.+<\/\1>/, '').strip
    if line =~ /^n\/a/i
      0
    else
      score = line.match(/([\d.]+)/) ? $1.to_f : 0
      score >= 10 ? 9.99 : score
    end
  end

  def parse_ranked(content)
    line = parse_line('Ranked', content, false).gsub(/\<(.+?)\>.+<\/\1>/, '').strip
    if line =~ /^n\/a/i
      0
    else
      line.match(/([\d.]+)/) ? $1.to_f : 0
    end
  end

  def parse_date(date)
    begin
      if date.match(/^\w+\s+\d+,$/)
        nil
      elsif date.match(/^\d+$/)
        Date.new(date.to_i)
      else
        Date.parse(date)
      end
    rescue Exception => e
      nil
    end
  end

  def parse_related doc
    doc.css('table.anime_detail_related_anime tr').each_with_object({}) do |tr, memo|
      tds = tr.css('td')
      memo[tds.first.text.sub(/:$/, '')] = tds.last.css('a')
        .map { |link| $1.to_i if link.attr('href') =~ /(\d+)/ }
        .compact
    end
  end

  def parse_poster doc
    doc.css('img.ac[itemprop=image]').first&.attr(:src) || begin
      img_doc = doc.css('td.borderClass > div:first-child > img')

      if img_doc.empty? || img_doc.first.attr(:src) !~ %r{cdn.myanimelist.net}
        doc.css('td.borderClass').first()
          .css('> div:first-child > a > img').first.try(:attr, :src)
      else
        img_doc.first.attr(:src)
      end
    end
  end

  def parse_external_links doc
    external_links_h2 = doc.at_css('table td h2:contains("External Links")')
    return [] unless external_links_h2.present?

    external_links_h2
      .next_element
      .css('a')
      .map { |v| { source: v.text.delete(' ').underscore, url: v['href'] } }
  end

  def cleanup text
    (text || '')
      .gsub('&amp;#039;', "'")
      .gsub(/<br>/, '<br />')
      .gsub(/\r\n/, '<br />')
      .gsub(/[\n\r]/, '<br />')
      .gsub(/<br \/>(<br \/>)?(\(|\[)?source[\s\S]*/i, '')
      .gsub(/<br \/>(<br \/>)?\[written[\s\S]*/i, '')
      .gsub(/<br \/>(<br \/>)?(\(|- ?)?from[\s\S]*/i, '')
      .gsub(/<br \/>(<br \/>)?Taken from[\s\S]*/i, '')
      .gsub(/<br \/>(<br \/>)?\(description from[\s\S]*/i, '')
      .gsub(/<br \/>(<br \/>)?\(adapted from[\s\S]*/i, '')
      .gsub(/<br \/>(<br \/>)<strong>Note:<\/strong><br \/>[\s\S]*/i, '')
      .gsub(/=Tricks=[\s\S]*/i, '')
      .strip
      .gsub(/(<br \/>)+$/m, '')
      .gsub(/(<br \/?>){2}+/m, '<br />')
      .gsub(/<div class="spoiler[\s\S]*?(<br? \/?>|value="Hide spoiler">)/, '[spoiler]')
      .gsub(/(?:<!--spoiler[\s\S]*?|<\/span>)<\/div>(?:<br \/>)?/, '[/spoiler]')
      .gsub(/<div class=\"border_top\"[\s\S]*<\/div>/, '') # Naruto: Shippuuden (id: 1735)
      .gsub(/<!--.*?-->/mix, '') # <!-- comment -->
      .gsub(%r{<span style=\"font-size: 90%;\"><b>Note:</b>.*</span>}, '')
      .strip
  end
end
