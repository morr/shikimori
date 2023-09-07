json.title og.headline
json.notice og.notice

json.content JsExports::Supervisor.instance.sweep(
  current_user,
  render(
    partial: 'animes_collection/cached_collection',
    locals: {
      view: @view,
      is_studio: params[:studio].present?
    },
    formats: :html
  )
)
json.page @view.page
json.pages_count @view.pages_count

json.JS_EXPORTS JsExports::Supervisor.instance.export(current_user)
