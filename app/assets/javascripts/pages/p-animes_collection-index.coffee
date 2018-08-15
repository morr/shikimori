import PaginatedCatalog from 'views/animes/paginated_catalog'

paginated_catalog = null

page_restore(
  'animes_collection_index',
  'recommendations_index',
  'userlist_comparer_show',
  ->
    # восстановление плюсика у фильтра в актуальное состояние
    $block_filer = $('.block-filter.item-add')
    $block_list = $block_filer.siblings('.b-block_list')

    if $block_list.find('.filter').length ==
        $block_list.find('.item-minus').length
      $block_filer
        .removeClass('item-add')
        .addClass('item-minus')

    #paginated_catalog.bind_history()
)

page_load(
  'animes_collection_index',
  'recommendations_index',
  'userlist_comparer_show',
  ->
    if $('.l-menu .ajax-loading').exists()
      $('.l-menu').one 'postloaded:success', init_catalog
    else
      init_catalog()

    $(document).trigger('page:restore')

  init_catalog = ->
    type = if $('.anime-params-controls').exists() then 'anime' else 'manga'
    base_catalog_path = $('.b-collection-filters').data('base_path')

    if location.pathname.match(/\/recommendations\//)
      base_catalog_path = location.pathname.split("/").first(5).join("/")
    else if location.pathname.match(/\/comparer\//)
      base_catalog_path = location.pathname.split("/").first(6).join("/")

    paginated_catalog = new PaginatedCatalog(base_catalog_path)
)
