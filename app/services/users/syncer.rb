module Users
  # The whole sync contract: upsert by email. Deactivation is `active: false`
  # in the payload — there is deliberately no snapshot-and-diff sync here
  # (see DESIGN.md, "Users sync API").
  class Syncer < ApplicationService
    def initialize(email:, name:, active: true)
      @email = email
      @name = name
      @active = active
    end

    def call
      user = User.find_or_initialize_by(email: @email)
      created = user.new_record?
      user.assign_attributes(name: @name, active: @active)

      changes = user.changes.except("created_at", "updated_at")
      return success(SyncOutcome.new(user: user, created: false, changed: false)) if changes.empty?

      ActiveRecord::Base.transaction do
        user.save!
        AuditEvent.record!(
          event_type: "user.synced",
          actor: :system,
          targets: user,
          attribute_changes: changes,
          metadata: { "source" => "api", "created" => created }
        )
      end

      success(SyncOutcome.new(user: user, created: created, changed: true))
    rescue ActiveRecord::RecordInvalid => e
      failure(:validation_failed, record: e.record)
    end

    SyncOutcome = Data.define(:user, :created, :changed)
  end
end
