class Api::V1::UsersController < Api::V1::BaseController
  STRING_PARAMS = %i[email name].freeze

  before_action -> { require_scope!("users:write") }
  before_action :reject_non_string_params!, only: :create

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

  private

  # A string column casts whatever it is given to its to_s before any validation
  # sees it, so an array of two addresses became one user named after both. Blank
  # values are left alone — `require` still answers those with 400.
  def reject_non_string_params!
    offenders = STRING_PARAMS.select { |key| params[key].present? && !params[key].is_a?(String) }
    return if offenders.empty?

    render_error(
      code: "validation_failed",
      status: :unprocessable_content,
      message: "Validation failed.",
      details: { "errors" => offenders.index_with { [ "must be a string" ] }.transform_keys(&:to_s) }
    )
  end
end
