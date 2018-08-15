import {
  ANIME_TOOLTIP_OPTIONS,
  COMMON_TOOLTIP_OPTIONS
} from 'helpers/tooltip_options'

import UserRatesTracker from 'services/user_rates/tracker'
import TopicsTracker from 'services/topics/tracker'
import CommentsTracker from 'services/comments/tracker'
import PollsTracker from 'services/polls/tracker'

(($) ->
  $.fn.extend
    process: (JS_EXPORTS) ->
      @each ->
        process_current_dom @, JS_EXPORTS
) jQuery

# обработка элементов страницы (инициализация галерей, шрифтов, ссылок)
# TODO: переписать всю тут имеющееся на dynamic_element
process_current_dom = (root = document.body, JS_EXPORTS = window.JS_EXPORTS) ->
  $root = $(root)

  UserRatesTracker.track JS_EXPORTS, $root
  TopicsTracker.track JS_EXPORTS, $root
  CommentsTracker.track JS_EXPORTS, $root
  PollsTracker.track JS_EXPORTS, $root

  new DynamicElements.Parser $with('.to-process', $root)

  $with('time', $root).livetime()

  # то, что должно превратиться в ссылки
  $with('.linkeable', $root)
    .change_tag('a')
    .removeClass('linkeable')

  $with('.b-video.unprocessed', $root).shiki_video()

  # стена картинок
  $with('.b-shiki_wall.unprocessed', $root)
    .removeClass('unprocessed')
    .each ->
      new Wall.Gallery @

  # блоки, загружаемые аяксом
  $with('.postloaded[data-href]', $root).each ->
    $this = $(@)
    return unless $this.is(':visible')
    $this.load $this.data('href'), ->
      $this
        .removeClass('postloaded')
        .process()
        .trigger('postloaded:success')

    $this.attr 'data-href', null

  # чёрные мелкие тултипы
  $with('.b-tooltipped.unprocessed', $root)
    .removeClass('unprocessed')
    .each ->
      return if (is_mobile() || is_tablet()) && !@classList.contains('mobile')

      $tip = $(@)

      gravity = switch $tip.data('direction')
        when 'top' then 's'
        when 'bottom' then 'n'
        when 'right' then 'w'
        else 'e'

      $tip.tipsy
        gravity: gravity
        html: true
        prependTo: document.body

  # подгружаемые тултипы
  $with('.anime-tooltip', $root)
    .tooltip(ANIME_TOOLTIP_OPTIONS)
    .removeClass('anime-tooltip')
    .removeAttr('title')

  $with('.bubbled', $root)
    .addClass('bubbled-processed')
    .removeClass('bubbled')
    .tooltip Object.add(COMMON_TOOLTIP_OPTIONS,
      offset: [-48, 10, -10]
    )

  $with('.b-spoiler.unprocessed', $root).spoiler()

  $with('img.check-width', $root)
    .removeClass('check-width')
    .normalize_image(append_marker: true)
  $with('.b-image.unprocessed', $root)
    .removeClass('unprocessed')
    .magnific_rel_gallery()

  $with('.b-show_more.unprocessed', $root)
    .removeClass('unprocessed')
    .show_more()

  # выравнивание картинок в галерее аниме постеров
  $posters = $with('.align-posters.unprocessed', $root)
  if $posters.length
    $posters.removeClass('unprocessed').find('img').imagesLoaded ->
      $posters.align_posters()

  # с задержкой делаем потому, что collapsed блоки могут быть в контенте,
  # загруженном аяксом, а process для таких случаев вызывается ещё до вставки в
  # DOM
  delay().then ->
    # сворачиваение всех нужных блоков "свернуть"
    ($.cookie('collapses') || '')
      .replace(/;$/, '')
      .split(';')
      .forEach (id) ->
        $("#collapse-#{id}")
          .filter(':not(.triggered)')
          .trigger('click', true)
