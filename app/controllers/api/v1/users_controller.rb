class Api::V1::UsersController < Api::V1::BaseController
  before_action -> { require_scope!("users:write") }

  def index
    users = User.order(:email)
    render json: Api::V1::UserSerializer.collection(users)
  end

  # Upsert by email — the whole sync contract. 201 when the user was created,
  # 200 when an existing user was updated (or already matched).
  def create
    result = Users::Syncer.call(
      email: params.require(:email),
      name: params.require(:name),
      active: params.key?(:active) ? ActiveModel::Type::Boolean.new.cast(params[:active]) : true
    )

    if result.success
      outcome = result.value
      render json: Api::V1::UserSerializer.new(outcome.user).as_json,
             status: outcome.created ? :created : :ok
    else
      record = result.context[:record]
      render_error(
        code: "validation_failed",
        status: :unprocessable_content,
        message: "Validation failed.",
        details: { "errors" => record.errors.messages.transform_keys(&:to_s) }
      )
    end
  end
end
