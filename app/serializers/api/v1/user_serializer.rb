class Api::V1::UserSerializer < Api::V1::BaseSerializer
  def as_json
    {
      "id" => object.id,
      "email" => object.email,
      "name" => object.name,
      "role" => object.role,
      "active" => object.active,
      "created_at" => object.created_at.iso8601,
      "updated_at" => object.updated_at.iso8601
    }
  end
end
