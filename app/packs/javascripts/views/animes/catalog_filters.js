// TODO: refactor to normal classes
import inNewTab from '@/utils/in_new_tab';
import urlParse from 'url-parse';
import TinyUri from 'tiny-uri';

const DEFAULT_ORDER = 'ranked';
const DEFAULT_DATA = {
  kind: [],
  status: [],
  season: [],
  franchise: [],
  achievement: [],
  genre: [],
  studio: [],
  publisher: [],
  duration: [],
  rating: [],
  score: [],
  options: [],
  mylist: [],
  'order-by': [],
  licensor: []
};

const GET_FILTERS = ['duration', 'rating', 'score', 'options', 'mylist', 'order-by', 'licensor'];

export default function(basePath, currentUrl, changeCallback) {
  const $root = $('.b-collection-filters');

  // вытаскивание из класса элемента типа и значения
  const extractLiInfo = function($li) {
    const field = $li.data('field');
    const value = $li.data('value');
    if (!field || !value) { return null; }

    return {
      field,
      value: String(value)
    };
  };

  // удаление ! из начала и мусора из конца параметра
  const removeBang = value => value.replace(/^!/, '').replace(/\?.*/, '');

  // добавляет нужный параметр в меню с навигацией
  const addOption = function(field, rawValue) {
    // добавляем всегда без !
    let value = removeBang(rawValue);
    let text = value.replace(/^\d+-/, '');
    let targetYear = null;

    if (((field === 'publisher') || (field === 'studio')) && text.match(/-/)) {
      text = text.replace(/-/g, ' ');
    } else if ((field === 'season') && value.match(/^\d+$/)) {
      targetYear = parseInt(value, 10);
      text = value + ' год';
    } else if (field === 'licensor') {
      text = value;
    }

    value = value.replace(/\./g, '');
    const $li = $(`<li data-field='${field}' data-value='${value}'><input type='checkbox'/>${text}</li>`);

    // для сезонов вставляем не в начало, а после предыдущего года
    if (targetYear) {
      const $placeholders = $('ul.seasons li', $root).filter(function(index) {
        const match = this.className.match(/season-(\d+)/);
        if (!match) { return false; }
        let year = parseInt(match[1], 10);
        if (year < 1000) { year = year * 10; }
        return year < targetYear;
      });
      if ($placeholders.length) {
        $li.insertBefore($placeholders.first());
      } else {
        $(`.anime-params.${field}s`, $root).append($li);
      }
    } else {
      $(`.anime-params.${field}s`, $root).prepend($li).parent().removeClass('hidden');
    }
    return $li;
  };

  // клики по меню
  $('.anime-params', $root).on('click', 'li', function(e) {
    if (inNewTab(e)) { return; } // игнор средней кнопки мыши
    if (e.target.classList.contains('b-question')) { return; } // игнор при клике на инфо блок
    // return if $(e.target).hasClass('filter') # игнор при клике на фильтр

    const isAlreadySelected = this.classList.contains('selected');

    const liInfo = extractLiInfo($(this));
    if (!liInfo) { return; }

    if (!isAlreadySelected) {
      if ('type' in e.target && (e.target.type === 'checkbox')) {
        filters.add(liInfo.field, liInfo.value);
      } else {
        filters.set(liInfo.field, liInfo.value);
      }
    } else {
      filters.remove(liInfo.field, liInfo.value);
    }

    changeCallback(filters.compile());
    if (!('type' in e.target) || (e.target.type !== 'checkbox')) {
      e.preventDefault();
    }
  });

  // клики по фильтру группы - плюсику или минусику
  $('.anime-params-block .block-filter', $root).on('click', function() {
    const $paramsBlock = $(this).closest('.anime-params-block');

    $paramsBlock.find('.b-spoiler').first().trigger('spoiler:open');

    const toExclude =
      $(this).hasClass('item-sign') ?
        $paramsBlock.find('li').length === $paramsBlock.find('.item-add:visible').length :
        $(this).hasClass('item-add');

    const toDisable = $(this).hasClass('item-sign') &&
      ($paramsBlock.find('li').length === $paramsBlock.find('.item-minus:visible').length);

    $paramsBlock
      .find('li')
      .map(function() { return extractLiInfo($(this)); })
      .each(function(index, liInfo) {
        if (toDisable) {
          filters.params[liInfo.field] = [];
        } else {
          filters.params[liInfo.field][index] = (
            toExclude ? `!${liInfo.value}` : liInfo.value
          );
        }
      });

    changeCallback(filters.compile());
    filters.parse(filters.compile());
  });

  // клики по фильтру элемента - плюсику или минусику
  $('.anime-params li', $root).on('click', '.filter', function(e) {
    e.preventDefault();

    const toExclude = $(this).hasClass('item-add');

    $(this)
      .removeClass((toExclude ? 'item-add' : 'item-minus'))
      .addClass((!toExclude ? 'item-add' : 'item-minus'));

    const liInfo = extractLiInfo($(this).parent());
    const valueKey = filters.params[liInfo.field].indexOf(
      toExclude ? liInfo.value : `!${liInfo.value}`
    );
    filters.params[liInfo.field][valueKey] =
      (toExclude ? `!${liInfo.value}` : liInfo.value);

    changeCallback(filters.compile());
    return false;
  });

  const filters = {
    params: null,

    // установка значения параметра
    set(field, value) {
      const self = this;
      this.params[field].forEach(value2 => self.remove(field, value2));

      return this.add(field, value);
    },

    // выбор элемента
    add(field, value) {
      if ((field === Object.keys(this.params).last()) && (this.params[field].length > 0)) {
        this.set(field, value);
      } else {
        this.params[field].push(value);
      }

      let $li = $(`li[data-field='${field}'][data-value='${removeBang(value)}']`, $root);

      // если такого элемента нет, то создаем его
      if (!$li.length) { $li = addOption(field, value); }

      // если элемент есть, но скрыт, то показываем его
      if ($li.css('display') === 'none') { $li.css({ display: 'block' }); }
      $li.addClass('selected');

      // если элемент с чекбоксом, то ставим галочку на чекбокс
      const $input = $li.children('input');
      if ($input.length) {
        $input.prop({ checked: true });

        // добавляем или показываем плюсик
        const $filter = $li.children('.filter');
        if ($filter.length) {
          return $filter
            .removeClass('item-add')
            .removeClass('item-minus')
            .addClass((value[0] === '!' ? 'item-minus' : 'item-add')).show();
        } else {
          return $li.prepend(
            '<span class="filter ' +
              ((value[0] === '!' ? 'item-minus' : 'item-add')) +
              '"></span>'
          );
        }
      }
    },

    // отмена выбора элемента
    remove(field, rawValue) {
      // т.к. сюда значение приходит как с !, так и без, то удалять надо оба варианта
      const value = removeBang(rawValue);
      this.params[field] = this.params[field].subtract([value, `!${value}`]);

      try { // because there can bad order, and it will break jQuery selector
        const $li = $(`li[data-field='${field}'][data-value='${value}']`, $root);
        $li.removeClass('selected');

        // снятие галочки с чекбокса
        $li.children('input').prop({ checked: false });

        // скрытие плюсика/минусика
        return $li.children('.filter').hide();
      } catch (error) {} // eslint-disable-line no-empty
    },

    // формирование строки урла по выбранным элементам
    compile(page) {
      let pathFilters = '';
      const locationFilters = urlParse(window.location.href, true).query;

      Object.forEach(this.params, function(values, field) {
        delete locationFilters[field];

        if ((field === 'order-by') && (values[0] === DEFAULT_ORDER) &&
            !location.href.match(/\/list\/(anime|manga)/)) {
          return;
        }

        if (GET_FILTERS.includes(field)) {
          if ((values != null ? values.length : undefined)) {
            locationFilters[field] = values.join(',');
          }
        } else if (values != null ? values.length : undefined) {
          pathFilters += `/${field}/${values.join(',')}`;
        }
      });

      if (page && (page !== 1)) {
        pathFilters += `/page/${page}`;
      }

      return this.lastCompiled = new TinyUri(basePath + pathFilters)
        .query.set(locationFilters)
        .toString();
    },

    lastCompiled: null,

    // парсинг строки урла и выбор
    parse(url) {
      $('.anime-params .selected', $root).toggleClass('selected');
      $('.anime-params input[type=checkbox]:checked', $root).prop({ checked: false });
      $('.anime-params .filter', $root).hide();

      this.params = JSON.parse(JSON.stringify(DEFAULT_DATA));
      let parts = url
        .replace(`${location.protocol}//${location.hostname}`, '')
        .replace(`:${location.port}`, '')
        .replace(basePath, '')
        .replace(/\?.*/, '')
        .match(/[\w-]+\/[^/]+/g);

      const uriQuery = urlParse(window.location.href, true).query;
      Object.forEach(uriQuery, function(values, field) {
        if (!GET_FILTERS.includes(field)) { return; }
        parts = (parts || []).concat([`${field}/${values}`]);
      });

      (parts || []).forEach(match => {
        const field = match.split('/')[0];
        if ((field === 'page') || (!(field in DEFAULT_DATA))) { return; }

        return match
          .split('/')[1]
          .split(',')
          .forEach(value => {
            try {
              return this.add(field, value);
            } catch (error) { // becase there can bad order, and it will break jQuery selector
              if (field === 'order-by') {
                return this.add('order-by', DEFAULT_ORDER);
              }
            }
          });
      });

      if (Object.isEmpty(this.params['order-by'])) {
        return this.add('order-by', DEFAULT_ORDER);
      }
    }
  };

  filters.parse(currentUrl);

  // раскрываем фильтры, если какой-то из них выбран
  if (filters.params.genre.length) {
    $root.find('.genres .b-spoiler').spoiler().trigger('spoiler:open');
  }

  if (filters.params.licensor.length) {
    $root.find('.licensors .b-spoiler').spoiler().trigger('spoiler:open');
  }

  if (filters.params.duration.length) {
    $root.find('.durations').closest('.b-spoiler').spoiler().trigger('spoiler:open');
  }

  if (filters.params.rating.length) {
    $root.find('.ratings').closest('.b-spoiler').spoiler().trigger('spoiler:open');
  }

  if (filters.params.score.length) {
    $root.find('.scores').closest('.b-spoiler').spoiler().trigger('spoiler:open');
  }

  if (filters.params.season.length) {
    $root.find('.seasons').closest('.b-spoiler').spoiler().trigger('spoiler:open');
  }

  if (filters.params.mylist.length) {
    $root.find('.mylist-block .b-spoiler').spoiler().trigger('spoiler:open');
  }

  let orders = filters.params['order-by']

  if (orders.length && !((orders.length == 1) && (orders[0] == DEFAULT_ORDER))) {
    $root.find('.orders').closest('.b-spoiler').spoiler().trigger('spoiler:open');
  }

  return filters;
}
