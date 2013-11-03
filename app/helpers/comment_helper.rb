require Rails.root.join('lib', 'string')

module CommentHelper
  include SiteHelper
  include AniMangaHelper

  SimpleBbCodes = [:b, :s, :u, :i, :quote, :url, :img, :list, :right, :center, :solid]
  ComplexBbCodes = [:moderator, :smileys, :youtube, :twitch, :group, :contest, :mention, :user_change, :user,
                    :comment, :entry, :review, :quote, :posters, :wall_container, :ban, :spoiler
                   ]

  @@smileys_path = '/images/smileys/'
  @@smileys_synonym = {
    ":)" => ":-)"
  }
  @smiley_first_to_replace = [':dunno:']
  @@smiley_groups = [
    [":)",":D", ":-D", ":lol:", ":ololo:", ":evil:", "+_+", ":cool:", ":thumbup:", ":yahoo:", ":tea2:", ":star:"],
    [":oh:",":shy:", ":shy2:", ":hurray:", ":-P", ":roll:", ":!:", ":watching:", ":love:", ":love2:", ":bunch:", ":perveted:"],
    [":(", ":very sad:", ":depressed:", ":depressed2:", ":hopeless:", ":very sad2:", ":-(", ":cry:", ":cry6:", ":Cry2:", ":Cry3:", ":Cry4:"],
    [":-o", ":shock:", ":shock2:", ":scream:", ":dont want:", ":noooo:", ":scared:", ":shocked2:", ":shocked3:", ":shocked4:",
     ":tea shock:", ":frozen3:"],
    [":angry4:", ":revenge:", ":evil2:", ":twisted:", ":angry:", ":angry3:", ":angry5:", ":angry6:", ":cold:", ":strange4:", ":ball:", ":evil3:"],
    [":8):", ":oh2:", ":ooph:", ":wink:", ":dunno:", ":dont listen:", ":hypno:", ":advise:", ":bored:", ":disappointment:", ":hunf:"],#, ":idea:"
    [":hot:", ":hot2:", ":hot3:", ":stress:", ":strange3:", ":strange2:", ":strange1:", ":strange:", ":hope:", ":hope3:", ":diplom:"],
    [":hi:", ":bye:", ":sleep:", ":bow:", ":Warning:", ":Ban:", ":Bath2:", ":Im dead:", ":sick:", ":s1:", ":s3:", ":s2:", ":happy_cry:"],
    [":ill:",
     ":sad2:",
     ":bullied:", ":bdl2:",
     ":Happy Birthday:", ":flute:",
     ":cry5:",
     ":gaze:", ":hope2:",
     ":sleepy:",
     ":study:", ":study2:", ":study3:", ":gamer:",
     ":animal:",
     ":caterpillar:",
     ":cold2:", ":shocked:", ":frozen:", ":frozen2:", ":kia:", ":interested:",
     ":happy:",
     ":happy3:",
     ":water:", ":dance:", ":liar:", ":prcl:",
     ":play:",
     ":s4:", ":s:",
     ":bath:",
     ":kiss:", ":whip:", ":relax:", ":smoker:", ":smoker2:", ":bdl:", ":cool2:",
     ":V:", ":V2:", ":V3:",
     ":sarcasm:", ":angry2:", ":kya:"
    ]
  ]
  @@smileys = @@smiley_groups.flatten
  @@replaceable_smileys = @smiley_first_to_replace + (@@smileys.reverse-@smiley_first_to_replace)

  def smileys
    @@smileys
  end

  def smileys_path
    @@smileys_path
  end

  def smiley_groups
    @@smiley_groups
  end

  def smileys_to_html(text, poster=nil)
    @@replaceable_smileys.each do |v|
      text.gsub!(v, '<img src="%s%s.gif" alt="%s" title="%s" class="smiley" />' % [@@smileys_path, v, v, v])
    end
    text
  end

  def moderator_to_html(text, poster=nil)
    if self.respond_to?(:user_signed_in?) && poster && user_signed_in? && (current_user.id == poster.id || current_user.moderator?)
      text.gsub(/\[moderator\]([\s\S]*?)\[\/moderator\](?:<br ?\/?>|\n)?/mi, "
<section class=\"moderation\">
  <header>
    <<< сообщение от модератора
  </header>
  <article>
    \\1
  </article>
  <footer>
    удалите тег после после исправления замечаний >>>
  </footer>
</section>")
    else
      text.gsub(/\[moderator\]([\s\S]*?)\[\/moderator\](?:<br ?\/?>|\n)?/mi, '')
    end
  end

  def mention_to_html(text, poster=nil)
    text.gsub /\[mention=\d+\]([\s\S]*?)\[\/mention\]/ do
      nickname = $1
      "<a href=\"#{user_url User.param_to(nickname)}\">@#{nickname}</a>"
    end
  end

  def wall_container_to_html(text, poster=nil)
    text.sub /(^[\s\S]*)(<div class="wall")/ , '<div class="height-unchecked inner-block">\1</div>\2'
  end

  def spoiler_to_html(text, nesting = 0)
    return text if nesting > 2

    text = spoiler_to_html text, nesting + 1

    text.gsub(/
        \[spoiler (?:= (?<label> [^\[\]\n\r]*? ) )? \]
          (?:<br ?\/?> | \n | \r )?
          (?<content>
            (?:
              (?! \[\/?spoiler\] ) (?>[\s\S])
            )+
          )
          (?: <br ?\/?> | \n | \r )?
        \[\/spoiler\]
    /xi) do |match|
      '<div class="spoiler collapse"><span class="action half-hidden" style="display: none;">развернуть</span></div><div class="collapsed spoiler">' + ($~[:label] || 'спойлер') + '</div><div class="spoiler target" style="display: none;">' + $~[:content] + '<span class="closing"></span></div>'
    end
  end

  BbCodeReplacers = ComplexBbCodes.map { |v| "#{v}_to_html".to_sym }.reverse

  def format_comment(text, poster=nil)
    safe_text = poster && poster.bot? ? text.html_safe : ERB::Util.h(text)

    result = remove_wiki_codes(remove_old_tags(safe_text))
      .gsub(/\r\n|\r|\n/, '<br />')
      .bbcode_to_html(@@custom_tags, false, :disable, :quote, :link, :image, :listitem)
      .gsub(%r{<a href="(?!http|/)}, '<a href="http://')
      .gsub('<ul><br />', '<ul>')
      .gsub('</ul><br />', '</ul>')

    BbCodeReplacers.each do |processor|
      result = send processor, result
    end

    result = db_entry_mention result
    result = anime_to_html result
    result = manga_to_html result
    result = character_to_html result
    result = person_to_html result
    #result = spoiler_to_html result

    if poster && poster.bot?
      result = result.gsub('<a href=', '<a rel="nofollow" href=')
    end
    result.html_safe
  end

  def db_entry_mention(text)
    text.gsub %r{\[(?!\/|#{(SimpleBbCodes + ComplexBbCodes).map {|v| "#{v}\b" }.join('|') })(.*?)\]} do |matched|
      name = $1.gsub('&#x27;', "'").gsub('&quot;', '"')

      splitted_name = name.split(' ')

      entry = if name.contains_russian?
        Anime.order('score desc').find_by_russian(name) ||
          Manga.order('score desc').find_by_russian(name) ||
          Character.find_by_russian(name) ||
          (splitted_name.size == 2 ? Character.find_by_russian(splitted_name.reverse.join ' ') : nil)
      elsif name != 'manga' && name != 'list' && name != 'anime'
        Anime.order('score desc').find_by_name(name) ||
          Manga.order('score desc').find_by_name(name) ||
          Character.find_by_name(name) ||
          (splitted_name.size == 2 ? Character.find_by_name(splitted_name.reverse.join ' ') : nil) ||
          Person.find_by_name(name) ||
          (splitted_name.size == 2 ? Person.find_by_name(splitted_name.reverse.join ' ') : nil)
      end

      entry ? "[#{entry.class.name.downcase}=#{entry.id}]#{name}[/#{entry.class.name.downcase}]" : matched
    end
  end

  def remove_old_tags(html)
    html.gsub(/(?:<|&lt;)p(?:>|&gt;)[\t\n\r]*([\s\S]*?)[\t\n\r]*(?:<|&lt;)\/p(?:>|&gt;)/i, '\1')
        .gsub(/(?:<|&lt;)br ?\/?(?:>|&gt;)/, "\n")
        .strip
        #.gsub(/[\n\r\t ]+$/x, '')
  end

  def youtube_html(hash)
    video = Video.new url: "http://youtube.com/watch?v=#{hash}"
    fake_view = OpenStruct.new view_context: Sendgrid.send(:new).view_context
    DummyRenderController.new(fake_view).render_to_string partial: 'videos/video', object: video, locals: { marker: true }
  end

  def youtube_to_html(text, poster=nil)
    text = text.gsub %r{<a href="(?:https?://(?:www\.)?youtube.com/watch\?(?:feature=player_embedded&(?:amp;))?v=([^&\s"<>#]+)([^\s"<>]+)?)">[^<]+</a>(?:(?:<br ?/?>)*(?=<a href="https?:\/\/(?:www\.)?youtube.com)|)}mi do |match|
      youtube_html $1
    end
    text.gsub /([^"\]]|^)(?:https?:\/\/(?:www\.)?youtube.com\/watch\?(?:feature=player_embedded&(?:amp;)?)v=([^&\s<>#]+)([^\s<>]+)?)/mi do
      $1 + youtube_html($2)
    end
  end


  def twitch_to_html(text, poster=nil)
    text
  end

  def quote_to_html(text, poster=nil)
    return text unless text.include?("[quote") && text.include?("[/quote]")

    text.gsub(/\[quote\]/, '<blockquote>').
         gsub(/\[quote=(\d+);(\d+);([^\]]+)\]/, '<blockquote><div class="quoteable">[user=\2]\3[/user]</div>').
         gsub(/\[quote=([^\]]+)\]/, '<blockquote><div class="quoteable">[user]\1[/user]</div>').
         gsub(/\[\/quote\](?:\r\n|\r|\n|<br \/>)?/, '</blockquote>')
  end

  def posters_to_html(text, poster=nil)
    return text unless text.include?("[anime_poster") || text.include?("[manga_poster")

    text.gsub(/\[(anime|manga)_poster=(\d+)\]/) do
      entry = ($1 == 'anime' ? Anime : Manga).find_by_id($2)
      if entry
        "<a href=\"#{url_for(entry)}\" title=\"#{entry.name}\"><img class=\"poster-image\" src=\"#{entry.image.url(:preview)}\" title=\"#{entry.name}\" alt=\"#{entry.name}\"/></a>"
      else
        ''
      end
    end
  end

  @@type_matchers = {
    Anime => [/(\[anime(?:=(\d+))?\]([^\[]*?)\[\/anime\])/, :tooltip_anime_url],
    Manga => [/(\[manga(?:=(\d+))?\]([^\[]*?)\[\/manga\])/, :tooltip_manga_url],
    Character => [/(\[character(?:=(\d+))?\]([^\[]*?)\[\/character\])/, :character_tooltip_url],
    Person => [/(\[person(?:=(\d+))?\]([^\[]*?)\[\/person\])/, :person_tooltip_url],
    UserChange => [/(\[user_change(?:=(\d+))?\]([^\[]*?)\[\/user_change\])/, :moderation_user_change_tooltip_url],
    Comment => [/(\[comment=(\d+)\]([^\[]*?)\[\/comment\])/, nil],
    Entry => [/(\[entry=(\d+)\]([^\[]*?)\[\/entry\])/, nil],
    User => [/(\[(user|profile)(?:=(\d+))?\]([^\[]*?)\[\/(?:user|profile)\])/, nil],
    Review => [/(\[review=(\d+)\]([^\[]*?)\[\/review\])/, nil],
    Group => [/(\[group(?:=(\d+))?\]([^\[]*?)\[\/group\])/, nil],
    Contest => [/(\[contest(?:=(\d+))?\]([^\[]*?)\[\/contest\])/, nil],
    Ban => [/(\[ban(?:=(\d+))\])/, nil]
  }
  @@type_matchers.each do |klass,data|
    matcher, preloader = data

    define_method("#{klass.name.to_underscore}_to_html") do |text|
      while text =~ matcher
        if klass == Comment || klass == Entry
          url = if klass == Comment
            comment_url id: $2, format: :html
          else
            topic_tooltip_url id: $2, format: :html
          end

          begin
            comment = klass.find($2)
            user = comment.user

            text.gsub!($1, "<a href=\"#{url_for user}\" title=\"#{user.nickname}\" class=\"bubbled\" data-remote=\"true\" data-href=\"#{url}\">#{$3}</a>")
          rescue
            text.gsub!($1, "<span class=\"bubbled\" data-remote=\"true\" data-href=\"#{url}\">#{$3}</span>")
            break
          end

        elsif klass == Review
          begin
            review = Review.find($2)
            text.gsub!($1, "<a href=\"#{url_for [review.target, review]}\" title=\"Обзор #{review.target.name} от #{review.user.nickname}\">#{$3}</a>")
          rescue
            text
            break
          end

        elsif klass == User
          is_profile = $2 == 'profile'
          begin
            user = if $3.nil?
              User.find_by_nickname $4
            else
              User.find $3
            end

            text.gsub! $1, "<a href=\"#{user_url user}\" title=\"#{$4}\"><img src=\"#{gravatar_url user, 16}\" alt=\"#{$4}\" /></a>
<a href=\"#{url_for(user)}\" title=\"#{$4}\">#{$4}</a>" + (is_profile ? '' : " #{user.sex == 'male' ? 'написал' : 'написала'}:")
          rescue
            text.gsub! $1, "#{$4}#{is_profile ? '' : ' написал:'}"
            break
          end

        elsif klass == Ban
          begin
            ban = Ban.find $2

            moderator_html = "<a href=\"#{user_url ban.moderator}\" title=\"#{ban.moderator.nickname}\"><img src=\"#{gravatar_url ban.moderator, 16}\" alt=\"#{ban.moderator.nickname}\" /></a>
<a href=\"#{user_url ban.moderator}\" title=\"#{ban.moderator.nickname}\">#{ban.moderator.nickname}</a>"
            text.gsub! $1, "<div class=\"ban-message\">#{moderator_html}: <span class=\"details\">#{ban.message}</span></div>"
          rescue ActiveRecord::RecordNotFound
            text.gsub! $1, ''
            text.strip!
            break
          end
        else # [tag=id]name[/tag]
          begin
            id = $2.nil? ? $3.to_i : $2.to_i
            entry = klass.find(id)
            title = $2.nil? ? entry.name : $3
            preload = preloader ? " class=\"bubbled\" data-remote=\"true\" data-href=\"#{send preloader, entry}\"" : nil
            url = if entry.kind_of? UserChange
              moderation_user_change_url entry
            else
              url_for entry
            end
            text.gsub! $1, "<a href=\"#{url}\" title=\"#{entry.name}\"#{preload}>#{title}</a>"
          rescue ActiveRecord::RecordNotFound
            text.gsub! $1, "<b>#{$3}</b>"
            break
          end
        end
      end
      text
    end
  end

  # больше "ката" нет
  def cut(text)
    #text.sub(/\[cut\][\s\S]*/, '')
    (text || '').gsub('[h3]', '[b]')
        .gsub('[/h3]', ":[/b]\n")
        #.gsub('<li>', '<p>')
        #.gsub('</li>', '</p>')
  end

  # удаление ббкодов википедии
  def remove_wiki_codes(html)
    html.gsub(/\[\[[^\]|]+?\|(.*?)\]\]/, '\1').gsub(/\[\[(.*?)\]\]/, '\1')
  end

private
  @@imageformats = 'png|bmp|jpg|gif|jpeg'
  @@custom_tags = {
    'List Item (alternative)' => [
      / \[\* (:[^\[]+)? \] (
          (?:(?!\[\*|\[\/list).)+
        )
      /mix,
      #/\[\*(:[^\[]+)?\]([^(\[|\<)]+)/mi,
      '<li>\2</li>',
      'List item (alternative)',
      '[*]list item',
      :listitem_alt
    ],
    'cut' => [
      /\[cut\]/i,
      '',
      'cut for cutting news',
      '[cut]',
      :cut
    ],
    'image with class' => [
      /\[img class=([\w-]+)\](.*?)\[\/img\]/mi,
      '<img class="\1" src="\2" />',
      'Image tag with class',
      '[img class=test]link_to_image[/img]',
      :image_with_class
    ],
    'Image (Alternative)' => [
      /\[img=([^\[\]].*?)\.(#{@@imageformats})\]/im,
      '<img src="\1.\2" alt="" class="check-width" />',
      'Display an image (alternative format)', 
      '[img=http://myimage.com/logo.gif]',
      :img],
    'Image' => [
      /\[img(:.+)?\]([^\[\]].*?)\.(#{@@imageformats})\[\/img\1?\]/im,
      '<img src="\2.\3" alt="" class="check-width" />',
      'Display an image',
      'Check out this crazy cat: [img]http://catsweekly.com/crazycat.jpg[/img]',
      :img],
    'poster' => [
      /\[poster\](.*?)\[\/poster\]/mi,
      '<div class="text-poster">\1</div>',
      'Poster text block',
      '[poster]some text[/poster]',
      :poster
    ],
    'right' => [
      /\[right\](.*?)\[\/right\]/mi,
      '<div class="right-text">\1</div>',
      'right text block',
      '[right]some text[/right]',
      :center
    ],
    'center' => [
      /\[center\](.*?)\[\/center\]/mi,
      '<center>\1</center>',
      'center text block',
      '[center]some text[/center]',
      :center
    ],
    'h3' => [
      /\[h3\](.*?)\[\/h3\](?:<br ?\/?>|\n)?/mi,
      '<h3>\1</h3>',
      'h3 tag',
      '[h3]some text[/h3]',
      :h3
    ],
    'strike' => [
      /\[s\]([\s\S]*?)\[\/s\]?/mi,
      '<strike>\1</strike>',
      'strike',
      '[s]some text[/s]',
      :poster
    ],
    'solid' => [
      /\[solid\]([\s\S]*?)\[\/solid\](?:<br ?\/?>|\n)?/mi,
      '<div class="solid">\1</div>',
      'solid tag',
      '[solid]some text[/solid]',
      :solid
    ],
    'collapsed' => [
      /\[collapsed\](?:<br ?\/?>|\n)?([\s\S]*?)(?:<br ?\/?>|\n)?\[\/collapsed\](?:<br ?\/?>|\n)?/mi,
      '<div class="collapse"><span class="action half-hidden" style="display: none;">развернуть</span></div><div class="collapsed tiny" style="display: block;">...</div><div style="display: none;">\1</div>',
      'collapsed tag',
      '[collapsed]some text[/collapsed]',
      :collapsed
    ],
    'Link' => [
      /\[url=(.*?)\](.*?)\[\/url\]/mi,
      '<a href="\1">\2</a>',
      'Hyperlink to somewhere else',
      'Maybe try looking on [url=http://google.com]Google[/url]?',
      :link2],
    'Link (Implied)' => [
      /\[url\](.*?)\[\/url\]/mi,
      '<a href="\1">\1</a>',
      'Hyperlink (implied)',
      "Maybe try looking on [url]http://google.com[/url]",
      :link2],
    'Link (Automatic)' => [
      /(\s|^|>)((https?:\/\/(?:www\.)?)([^\s<]+))/mi,
      '\1<a href="\2">\4</a>',
      'Hyperlink (automatic)',
      'Maybe try looking on http://www.google.com',
      :link2],
    'wall' => [
      /(?:<br \/>|\n)*\[wall\](.*?)\[\/wall\]/mi,
      '<div class="wall">\1</div>',
      'wall with images',
      "[wall]images here[/wall]",
      :wall]
  }
end
