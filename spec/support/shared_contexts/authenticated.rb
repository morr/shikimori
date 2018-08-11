shared_context :authenticated do |role, register_trait|
  if role
    if !role || (role == :user && !register_trait)
      let(:user) { seed :user }
      let(:user_1) { seed :user_admin }

    elsif role == :admin && !register_trait
      let(:user) { seed :user_admin }

    elsif role == :user && register_trait == :day_registered
      let(:user) { user_day_registered }
      let(:user_2) { seed :user_admin }

    elsif role == :user && register_trait == :week_registered
      let(:user) { user_week_registered }
      let(:user_3) { seed :user_admin }

    else
      let(:user) { create :user, role, register_trait || :day_registered }
    end
  end

  before { sign_in user }
end
