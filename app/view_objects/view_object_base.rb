class ViewObjectBase
  include Draper::ViewHelpers
  include Translation

  prepend ActiveCacher.instance

  def page
    # do not use h.page because of conflicts with sidekiq module (fails on /about and /ongoings)
    if Rails.env.test?
      h.page
    elsif Rails.env.development?
      h.controller.instance_variable_get(:@page) || 1
    else
      h.controller.instance_variable_get(:@page)
    end
  end

  def studio_page?
    h.params[:studio].present?
  end

  def read_attribute_for_serialization attribute
    send attribute
  end
end
