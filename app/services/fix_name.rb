class FixName < ServiceObjectBase
  method_object :name, :full_cleanup

  BAD_SYMBOLS = %r{[%&#/\\?+><\]\[:,@"'`]+} # \p{C} - http://ruby-doc.org/core-2.5.0/Regexp.html
  # https://unicode-table.com/en/034F/
  # .ord.to_s(16) to get unicode code
  SPACES = /(?:[[:space:]]|[\u2060-\u2069\u2000-\u200f\u202a-\u202f\u034f ឵⠀ᅠ­ ]|\p{C})+/
  ALL_EXTENSIONS = %w[
      css js json xml jpg jpeg png gif webp css js ttf eot otf svg woff php woff2 bmp html
      rar zip gz tar rss slim jbuilder txt os log ini conf bak swp tmp yml yaml md rb py sh
      cgi pl exe dll bin so dat db lock sql sqlite csv tsv xls xlsx doc docx ppt pptx pdf
      php3 php4 php5 php7 php8 asp aspx cgi jsp jspa do action pdf
  ]
  EXTENSIONS = /
    \.(#{ALL_EXTENSIONS.join('|')})$
  /mix
  SPAM_WORDS = Users::CheckHacked::SPAM_DOMAINS

  def call
    remove_spam censor(cleanup(fix(@name)))
  end

private

  def censor name
    Moderations::Banhammer.instance.censor name, 'x'
  end

  def remove_spam name
    name.gsub BbCodes::Text::BANNED_DOMAINS, BbCodes::Text::BANNED_TEXT
  end

  def cleanup name
    return name unless @full_cleanup

    name
      .gsub(BAD_SYMBOLS, '')
      .strip
      .gsub(/^\.$/, 'точка')
      .gsub(EXTENSIONS, '_\1')
  end

  def fix name
    (name.is_a?(String) ? name : name.to_s)
      .fix_encoding
      .gsub(SPACES, ' ')
      .gsub(/./) { |v| v.ord.between?(917_760, 917_999) ? ' ' : v }
      .strip
  end
end
