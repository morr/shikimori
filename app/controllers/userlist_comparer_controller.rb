class UserlistComparerController < ShikimoriController
  before_action :fetch_users
  before_action :authorize_lists_access

  def show
    og noindex: true, nofollow: true
    @klass = params[:list_type].downcase.capitalize.constantize
    params[:klass] = @klass

    @entries = Rails.cache.fetch(@cache_key, expires_in: 10.minutes) do
      ListCompareService.fetch(@user_1, @user_2, params)
    end

    og page_title: i18n_t(
      "page_title.#{@klass.name.downcase}",
      user_1: @user_1.nickname,
      user_2: @user_2.nickname
    )

    @menu = Menus::CollectionMenu.new @klass
  end

private

  def fetch_users
    @user_1 = User.find_by nickname: User.param_to(params[:user_1])
    @user_2 = User.find_by nickname: User.param_to(params[:user_2])

    if @user_1.blank? || @user_2.blank?
      blank_user = @user_1.blank? ? params[:user_1] : params[:user_2]
      alert = i18n_t(
        'fetch_users_alert',
        user: ERB::Util.html_escape(blank_user)
      )

      redirect_to :root, alert: alert
    end
  end

  def authorize_lists_access
    authorize! :access_list, @user_1
    authorize! :access_list, @user_2
  end

  def cache_key
    [
      :list_comparer,
      @user_1.cache_key,
      @user_2.cache_key,
      Digest::MD5.hexdigest(params.to_yaml)
    ]
  end
end
