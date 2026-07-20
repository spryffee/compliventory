# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_20_100005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "name", null: false
    t.string "scope", default: "users:write", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "audit_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "actor_display"
    t.uuid "actor_id"
    t.string "actor_type", null: false
    t.jsonb "attribute_changes"
    t.uuid "correlation_id", null: false
    t.string "event_type", null: false
    t.inet "ip_address"
    t.text "justification"
    t.jsonb "metadata"
    t.datetime "occurred_at", null: false
    t.string "schema_version", default: "1.0", null: false
    t.jsonb "targets", default: [], null: false
    t.text "user_agent"
    t.index ["actor_id", "occurred_at"], name: "index_audit_events_on_actor_id_and_occurred_at"
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["correlation_id"], name: "index_audit_events_on_correlation_id"
    t.index ["event_type"], name: "index_audit_events_on_event_type"
    t.index ["occurred_at"], name: "index_audit_events_on_occurred_at", order: :desc
    t.index ["targets"], name: "index_audit_events_on_targets", opclass: :jsonb_path_ops, using: :gin
  end

  create_table "delegations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "asset_id", null: false
    t.string "asset_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["asset_type", "asset_id", "user_id"], name: "index_delegations_on_asset_type_and_asset_id_and_user_id", unique: true
    t.index ["asset_type", "asset_id"], name: "index_delegations_on_asset"
    t.index ["user_id"], name: "index_delegations_on_user_id"
  end

  create_table "systems", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "authentication_method"
    t.datetime "created_at", null: false
    t.string "criticality"
    t.string "data_classification"
    t.string "department"
    t.text "description"
    t.string "name", null: false
    t.text "notes"
    t.uuid "owner_id", null: false
    t.string "personal_data_categories", default: [], array: true
    t.string "status", default: "pending_approval", null: false
    t.boolean "stores_personal_data"
    t.uuid "technical_owner_id"
    t.datetime "updated_at", null: false
    t.string "url"
    t.uuid "vendor_id"
    t.index ["name"], name: "index_systems_on_name", unique: true
    t.index ["owner_id"], name: "index_systems_on_owner_id"
    t.index ["technical_owner_id"], name: "index_systems_on_technical_owner_id"
    t.index ["vendor_id"], name: "index_systems_on_vendor_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "role", default: "member", null: false
    t.jsonb "ui_preferences", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "vendors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category"
    t.string "contact_email"
    t.string "contact_name"
    t.datetime "created_at", null: false
    t.string "data_location"
    t.text "description"
    t.string "name", null: false
    t.text "notes"
    t.uuid "owner_id", null: false
    t.boolean "processes_personal_data"
    t.string "risk_tier"
    t.string "status", default: "pending_approval", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["name"], name: "index_vendors_on_name", unique: true
    t.index ["owner_id"], name: "index_vendors_on_owner_id"
  end

  add_foreign_key "audit_events", "users", column: "actor_id"
  add_foreign_key "delegations", "users"
  add_foreign_key "systems", "users", column: "owner_id"
  add_foreign_key "systems", "users", column: "technical_owner_id"
  add_foreign_key "systems", "vendors"
  add_foreign_key "vendors", "users", column: "owner_id"
end
