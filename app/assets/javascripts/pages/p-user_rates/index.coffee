import { COMMON_TOOLTIP_OPTIONS } from 'helpers/tooltip_options'
import ShikiModal from 'views/application/shiki_modal'

# TODO: этот гигантский файл нуждается в рефакторинге
list_cache = []
filter_timer = null

page_load 'user_rates_index', ->
  apply_list_handlers $('.l-content')
  update_list_cache()

  # графики
  $("#scores, #types, #ratings").bar
    no_data: ($chart) ->
      text = I18n.t('frontend.pages.p_user_rates.insufficient_data')
      $chart.html("<p class='b-nothing_here'>#{text}</p>")

  # фокус по инпуту фильтра по тайтлу
  $('.b-collection_search input').on 'focus', ->
    update_list_cache() unless list_cache.length

  # разворачивание свёрнутых блоков при фокусе на инпут
  $('.b-collection_search input').on 'focus', ->
    $('.collapsed').each ->
      $(@).trigger 'click' if @style.display == 'block'

  # пишут в инпуте фильтра по тайтлу
  $('.b-collection_search input').on 'keyup', (e) ->
    if e.keyCode == 91 || e.keyCode == 18 || e.keyCode == 16 || e.keyCode == 17
      return

    if filter_timer
      clearInterval filter_timer
      filter_timer = null

    filter_timer = setInterval filter, 350

  # сортировка по клику на колонку
  $('.order-control').on 'click', (e) ->
    type = $(@).data('order')
    $(".orders.anime-params li.order-by-#{type}").trigger 'click'

  # редактирование user_rate posters
  $('.list-groups').on 'ajax:before', '.edit-user_rate', ->
    $(@).closest('.user_rate').addClass 'b-ajax'

  $('.list-groups').on 'ajax:success', '.edit-user_rate', (e, form_html) ->
    $poster = $(@).closest('.user_rate')

    $poster.removeClass('b-ajax')
    $form = $(form_html).process()
    modal = new ShikiModal $form

    $('.remove', $form).on 'ajax:success', ->
      $poster.remove()
    $form.on 'ajax:success', (e, data) ->
      $poster.children('.text')
        .html(data.text_html || '')
        .toggleClass('hidden', Object.isEmpty(data.text_html))
      update_text_in_cache data
      modal.close()

  # фильтры каталога
  base_catalog_path = location.pathname.replace(/(\/list\/(?:anime|manga))(\/.+)?/, '$1')
  new Animes.CatalogFilters base_catalog_path, location.href, (url) ->
    Turbolinks.visit url, true
    if $('.l-page.menu-expanded').exists()
      $(document).one 'page:change', -> $('.l-page').addClass('menu-expanded')

# фильтрация списка пользователя
filter = ->
  clearInterval filter_timer
  filter_timer = null

  # разворачивание свёрнутых элементов
  filter_value = $('.b-collection_search input').val().toLowerCase()
  $entries = $('tr.selectable')
  list_cache.forEach (block) ->
    visible = false
    num = 0

    while num < block.entries.length
      entry = block.entries[num]
      if entry.title.indexOf(filter_value) != -1 ||
          entry.text.indexOf(filter_value) != -1
        visible = true

        if entry.display != ''
          entry.display = ''
          entry.node.style.display = ''

      else if entry.display != 'none'
        entry.display = 'none'
        entry.node.style.display = 'none'
      num++

    block.$container.toggle visible  if block.toggable

  $.force_appear()

# кеширование всех строк списка для производительности
update_list_cache = ->
  list_cache = $('.list-lines, .list-posters')
    .map ->
      $container = $(@)
      entries = $container.find('.user_rate').map(->
        node: @
        target_id: $(@).data('target_id')
        title: String($(@).data('title')).toLowerCase()
        text: String($(@).data('text') || '').toLowerCase()
        display: @style.display
      ).toArray()

      $container: $container
      entries: entries
      toggable: !$container.next('.b-postloader').length
    .toArray()

# обработчики для списка
apply_list_handlers = ($root) ->
  # хендлер подгрузки очередной страницы
  $('.b-postloader', $root).on 'postloader:before', insert_next_page
  $('.l-content').on 'postloader:success', process_next_page

  # открытие блока с редактирование записи по клику на строку с аниме
  $('tr.editable', $root).on 'click', (e) ->
    if $(@).next().hasClass 'edit-form'
      $(@).next().find('.cancel').click()
      e.stopImmediatePropagation()

  $('tr.editable', $root).on 'ajax:success', (e, html) ->
    # прочие блоки редактирования скроем
    $another_tr_edit = $('tr.edit-form')

    $tr = $(@)
    $tr_edit = $("<tr class='edit-form'><td colspan='#{$(@).children('td').length}'>#{html}</td></tr>")
      .insertAfter(@)
    $form = $tr_edit.find('form')
    # original_height = $form.height()

    if $another_tr_edit.exists()
      $another_tr_edit.remove()
    else
      $form.animated_expand()
      # $form.css height: 0
      # delay().then -> $form.css height: original_height

    # отмена редактирования
    $('.cancel', $tr_edit).on 'click', ->
      $form.hide()
      $tr_edit.remove()

    $form.on 'ajax:before', (e, data) ->
      $form.addClass 'b-ajax'

    # применение изменений в редактировании
    $form.on 'ajax:success', (e, data) ->
      $.flash notice: I18n.t('frontend.pages.p_user_rates.changes_saved')
      $('.cancel', $tr_edit).click()

      $('.current-value[data-field=score]', $tr).html(
        String(data.score || '0').replace(/^0$/, '–')
      )
      $('.current-value[data-field=chapters]', $tr).html data.chapters
      $('.current-value[data-field=volumes]', $tr).html data.volumes
      $('.current-value[data-field=episodes]', $tr).html data.episodes

      rate_text = "<div>#{data.text_html}</div>" if data.text_html

      $('.rate-text', $tr).html rate_text || ''

      if data.rewatches > 0
        count = data.rewatches
        word = if data.target_type == 'Anime'
          p count,
            I18n.t('frontend.pages.p_user_rates.rewatch.one'),
            I18n.t('frontend.pages.p_user_rates.rewatch.few'),
            I18n.t('frontend.pages.p_user_rates.rewatch.many')
        else
          p count,
            I18n.t('frontend.pages.p_user_rates.reread.one'),
            I18n.t('frontend.pages.p_user_rates.reread.few'),
            I18n.t('frontend.pages.p_user_rates.reread.many')

        $('.rewatches', $tr).html "#{count} #{word}"
      else
        $('.rewatches', $tr).html ''

      # обновляем текст в кеше
      update_text_in_cache data

    # удаление из списка
    $('.remove', $form).on 'ajax:success', (e, data) ->
      $('.cancel', $tr_edit).click()
      delay(250).then -> $tr.remove()
      e.stopPropagation()

  $('tr.unprocessed', $root)
    .removeClass('unprocessed')
    .find('a.tooltipped')
    .tooltip Object.add(COMMON_TOOLTIP_OPTIONS,
      offset: [
        -95
        10
      ]
      position: 'bottom right'
      opacity: 1
    )

  # изменения оценки/числа просмотренных эпизодов у user_rate lines
  $trs = $('.list-lines .hoverable').off()
  $trs.off()
    .hover ->
        return if is_mobile()
        $current_value = $('.current-value', @)
        $new_value = $('.new-value', @)

        # если нет элемента, то создаём его
        if $new_value.length is 0
          val = parseInt $current_value.text(), 10
          val = 0 if !val && val != 0

          new_value_html = if $current_value.data('field') != 'score'
            "<span class=\"new-value\"><input type=\"text\" class=\"input\"/><span class=\"item-add\"></span></span>"
          else
            "<span class=\"new-value\"><input type=\"text\" class=\"input\"/></span>"

          $new_value = $(new_value_html)
            .children('input')
            .val(val)
            .data(counter: val, max: $current_value.data('max') || 999, min: $current_value.data('min'))
            .data(field: $current_value.data('field'), action: $current_value.closest('tr').data('rate_url'))
              .parent()
              .insertAfter($current_value)

          apply_new_value_handlers $new_value

        $new_value.show()
        $current_value.hide()
        $('.misc-value', @).hide()

      , ->
        return if is_mobile()
        return if $('.new-value input', @).is(":focus")
        $('.new-value', @).hide()
        $('.current-value', @).show()
        $('.misc-value', @).show()

    .on 'click', (e) ->
      return if is_mobile()
      # клик на плюсик обрабатываем по дефолтному
      return if e.target && e.target.className == 'item-add'
      $this = $(@)
      $this.trigger 'mouseenter'
      $('input', $this).trigger('focus').select()
      e.stopPropagation()
      false

apply_new_value_handlers = ($new_value) ->
  # обработчики для инпутов листа
  $('input', $new_value).off()
    .on 'blur', ->
      $this = $(@)
      $this.parent().parent().trigger 'mouseleave'
      @value = 0 if @value < 0
      return if (parseInt(@value, 10) or 0) is (parseInt($this.data('counter'), 10) or 0)

      $value = $this.parent().parent().find('.current-value')
      prior_value = $value.html()
      $this.data 'counter', @value
      $value.html (if $this.data('counter') == '0' then '&ndash;' else $this.data('counter'))

      $.post($this.data('action'), "_method=patch&user_rate[#{$this.data 'field'}]=#{$this.attr 'value'}")
        .error ->
          $value.html prior_value
          $.flash alert: I18n.t('frontend.pages.p_user_rates.error_occurred')

    .on 'mousewheel', (e) ->
      return true unless $(@).is(':focus')

      if e.originalEvent.wheelDelta && e.originalEvent.wheelDelta > 0
        @value = Math.min (parseInt(@value, 10) + 1 or 0), parseInt($(@).data('max'), 10)

      else if e.originalEvent.wheelDelta
        @value = Math.max (parseInt(@value, 10) - 1 or 0), parseInt($(@).data('min'), 10)

      false

    .on 'keydown', (e) ->
      if e.keyCode is 38
        @value = Math.min (parseInt(@value, 10) + 1 or 0), parseInt($(@).data('max'), 10)

      else if e.keyCode is 40
        @value = Math.max (parseInt(@value, 10) - 1 or 0), parseInt($(@).data('min'), 10)

      else if e.keyCode is 27
        @value = $(@).data('counter')
        $(@).trigger 'blur'

    .on 'keypress', (e) ->
      if e.keyCode is 13
        $(@).trigger 'blur'
        e.stopPropagation()
        false

  # обработчик для плюсика у числа эпизодов/глав
  $('.item-add', $new_value).on 'click', (e) ->
    $input = $(@).prev()
    $input
      .val(parseInt($input.val(), 10) + 1)
      .trigger_with_return('blur')
      .success(-> $input.closest('td').trigger 'mouseover')

    e.stopPropagation()
    false

# подгрузка очередной страницы списка
insert_next_page = (e, $data) ->
  $header = $data.find('header:first')
  $present_header = $("header.#{$header.attr 'class'}")

  # при подгрузке могут быть 2 случая:
  # 1. подгружается совершенно новый блок, и тогда $header будет пустым
  # 2. погружается дальнейший контент уже существующего блока, и тогда...

  if $present_header.exists()
    # # присоединяем к уже существующим сущностям новые
    $entries = $header.next().children()

    $entries
      .detach()
      .process() # very improtant. or else tooltips wont be displayed
      .appendTo($present_header.next())
    apply_list_handlers $entries

    $header.next().remove()
    $header.remove()

  apply_list_handlers $data

process_next_page = ->
  update_list_cache()
  filter() unless Object.isEmpty($('.b-collection_search input').val())
  $.force_appear()

update_text_in_cache = (data) ->
  list_cache.forEach (cache_block) ->
    cache_entry = cache_block.entries.find (row) ->
      row.target_id == data.target_id

    cache_entry.text = data.text if cache_entry
