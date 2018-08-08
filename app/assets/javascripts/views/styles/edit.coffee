import { debounce } from 'throttle-debounce'

import PageBackgroundColor from './page_background_color'
import PageBorder from './page_border'
import BodyBackground from './body_background'

export default class EditStyles extends View
  initialize: ->
    @$form = @$ '.edit_style'
    @$preview = @$ '.preview'

    @_loading()

    require.ensure [], (require) =>
      CodeMirror = require 'codemirror'

      require 'codemirror/addon/hint/show-hint.js'
      require 'codemirror/addon/hint/css-hint.js'

      require 'codemirror/addon/display/fullscreen.js'
      require 'codemirror/addon/dialog/dialog.js'
      require 'codemirror/addon/search/searchcursor.js'
      require 'codemirror/addon/search/search.js'
      require 'codemirror/addon/scroll/annotatescrollbar.js'
      require 'codemirror/addon/search/matchesonscrollbar.js'
      require 'codemirror/addon/search/jump-to-line.js'

      @md5 = require('blueimp-md5')

      @editor = @_init_editor(CodeMirror)

      @css_cache = {}

      @components = [
        new PageBackgroundColor(@$('.page_background_color')),
        new PageBorder(@$('.page_border'))
        new BodyBackground(@$('.body_background'))
      ]

      @_debounced_preview = debounce(500, @preview)
      @_debounced_sync = debounce(500, @sync)

      @_sync_components()

      @$form.on 'ajax:before', @_loading
      @$form.on 'ajax:complete', @_loaded

      # @editor.on 'cut', @_debounced_sync
      # @editor.on 'paste', @_debounced_sync
      @editor.on 'change', @_debounced_sync

      @$root.on 'component:update', @_component_updated

  preview: =>
    css = @editor.getValue().trim()
    hash = @md5(css)

    if @css_cache[hash]
      @_replace_custom_css(@css_cache[hash])
    else
      @$preview.show()
      @_fetch_preview css, hash

  sync: =>
    @$('#style_css').val @editor.getValue()
    @preview()
    @_sync_components()

  _loading: =>
    @$form.find('.editor-container').addClass 'b-ajax'

  _loaded: =>
    @$form.find('.editor-container').removeClass 'b-ajax'

  _init_editor: (CodeMirror) ->
    @_loaded()

    full_screen = (editor) ->
      editor.setOption 'fullScreen', !editor.getOption('fullScreen')

    CodeMirror.fromTextArea @$('#style_css')[0],
      mode: 'css'
      theme: 'solarized light'
      lineNumbers: true
      styleActiveLine: true
      matchBrackets: true
      lineWrapping: true
      extraKeys:
        'F11': full_screen
        'Ctrl-F11': full_screen
        'Cmd-F11': full_screen
        'Esc': (editor) ->
          if editor.getOption 'fullScreen'
            editor.setOption 'fullScreen', false

  _sync_components: ->
    css = @editor.getValue()

    @components.forEach (component) ->
      component.update css
      true

  _component_updated: (e, regexp, replacement) =>
    css = @editor.getValue()

    fixed_replacement = if replacement then replacement + "\n" else ''
    if css.match(regexp)
      @editor.setValue css.replace(regexp, fixed_replacement).trim(), 1

    else if replacement
      @editor.setValue (fixed_replacement + css).trim(), 1

    @_debounced_preview()

  _fetch_preview: (css, hash) ->
    $.post(@$preview.data('url'), style: { css: css })
      .success (style) =>
        @css_cache[hash] = style.compiled_css
        @_replace_custom_css style.compiled_css
      .done =>
        @$preview.hide()

  _replace_custom_css: (compiled_css) ->
    custom_css_id = @$root.data 'custom_css_id'
    $("##{custom_css_id}").html compiled_css
