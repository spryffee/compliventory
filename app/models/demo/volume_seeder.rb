module Demo
  # Bulk inventory laid down ON TOP of the curated demo dataset, so the dynamic
  # tables have something to be dynamic about: /vendors, /systems and /audit page
  # at 25 rows, and with nine vendors a visitor never sees pagination, a filter
  # that narrows anything, or a sort that reorders anything.
  #
  # Runs only when a scale is asked for (`DEMO_VOLUME`, default 0) — Seeder.seed!
  # is unchanged otherwise, which keeps it idempotent and keeps the local
  # `db:seed` loop instant. The curated records are created first and never
  # touched here, so the docs' walkthrough still finds "Acme Cloud".
  #
  # Every filter dimension is populated, including the states that are easy to
  # forget: nil enums (a vendor with no risk tier reads "unscored"), all three
  # states of the ⚖ booleans (Unknown / Yes / No), in-house systems with no
  # vendor, and all four review-status buckets. Timestamps spread over two years
  # so the "Updated" sort has something to sort.
  #
  # Deterministic — the same SEED yields the same sandbox, so the nightly reset
  # rebuilds the same demo every night and a bug found while paging is a bug you
  # can reproduce.
  module VolumeSeeder
    module_function

    ADJECTIVES = %w[Northwind Brightline Cobalt Meridian Silverpine Ironwood Lakeside
                    Cinder Halcyon Westgate Ambergris Quickstep Fernbank Stonebridge
                    Marigold Copperfield Redwing Blackthorn Sunhollow Everline].freeze
    NOUNS = %w[Analytics Logistics Payments Identity Storage Messaging Insights Robotics
               Compliance Telemetry Ledger Archive Signal Foundry Registry Beacon].freeze
    SYSTEM_NOUNS = %w[Portal Console Tracker Workbench Gateway Directory Dashboard Hub
                      Scheduler Vault Pipeline Registry Planner Monitor Desk].freeze
    DEPARTMENTS = [ "Engineering", "People", "Finance", "Sales", "Marketing", "Legal",
                   "Security", "Operations", "Customer Support", "Data" ].freeze
    FIRST_NAMES = %w[Ada Bruno Chiara Dmitri Elena Farid Greta Hugo Iris Jonas Kira Lars
                     Mira Nadia Omar Petra Quinn Rosa Sven Tomas Ulla Viktor Wanda Yara Zane].freeze
    LAST_NAMES = %w[Almeida Berg Costa Duarte Eriksen Fontaine Grimaldi Halonen Ivanov
                    Jensen Kowalski Lindqvist Moreau Novak Olsen Pereira Rossi Silva
                    Toivonen Vasquez].freeze

    # Event types worth filtering by in /audit, weighted roughly like real traffic.
    EVENT_TYPES = ([ "vendor.updated" ] * 5 + [ "system.updated" ] * 5 + [ "auth.login" ] * 4 +
                   [ "proposal.created" ] * 3 + [ "proposal.approved" ] * 2 + [ "proposal.rejected" ] +
                   [ "vendor.submitted" ] * 2 + [ "system.submitted" ] * 2 +
                   [ "vendor.approved" ] + [ "vendor.rejected" ] +
                   [ "assessment.started" ] * 2 + [ "assessment.completed" ] * 2 +
                   [ "assessment.cancelled" ] + [ "user.role_changed" ]).freeze

    BATCH = 500
    DEFAULT_SEED = 20_260_728

    # One dial: `scale` is the number of generated vendors; everything else is
    # derived from it so the mix stays sane at any size.
    def call(scale:, seed: DEFAULT_SEED)
      return if scale <= 0

      rng = Random.new(seed)
      user_ids = seed_users!([ scale / 10, 5 ].max, rng)
      vendors = seed_vendors!(scale, user_ids, rng)
      systems = seed_systems!((scale * 2.25).round, user_ids, vendors, rng)
      seed_assessments!([ scale / 7, 3 ].max, vendors, user_ids, rng)
      seed_proposals!([ scale / 8, 4 ].max, vendors, systems, user_ids, rng)
      seed_audit_events!(scale * 5, vendors, systems, rng)
      report
    end

    # --- users ---------------------------------------------------------------

    def seed_users!(count, rng)
      offset = User.count
      rows = Array.new(count) do |i|
        n = offset + i
        first = FIRST_NAMES[n % FIRST_NAMES.size]
        last = LAST_NAMES[(n / FIRST_NAMES.size) % LAST_NAMES.size]
        {
          email: "#{first}.#{last}#{n}@example.test".downcase,
          name: "#{first} #{last}",
          # A few compliance/admin users so the actor filter has more than the
          # personas; the vast majority are plain members.
          role: (n % 25).zero? ? "compliance" : ((n % 40).zero? ? "admin" : "member"),
          active: (n % 30) != 0, # a slice of deactivated users, as in real life
          created_at: past(rng, 730), updated_at: past(rng, 200)
        }
      end
      insert_batched(User, rows, :index_users_on_email)

      # Owners come from active users only — an inactive user is dropped from the
      # owner pickers, so owning assets would be inconsistent.
      User.active.pluck(:id)
    end

    # --- vendors -------------------------------------------------------------

    def seed_vendors!(count, user_ids, rng)
      offset = Vendor.count
      rows = Array.new(count) do |i|
        n = offset + i
        name = "#{ADJECTIVES[n % ADJECTIVES.size]} #{NOUNS[(n / ADJECTIVES.size) % NOUNS.size]} #{format('%04d', n)}"
        created = past(rng, 730)
        assessed, review = review_dates(n, rng)
        {
          name: name,
          website: "https://#{name.parameterize}.example",
          description: "#{NOUNS[(n / 3) % NOUNS.size]} platform for #{DEPARTMENTS[n % DEPARTMENTS.size].downcase}.",
          category: nilable(Vendor::CATEGORIES, n, 11, rng),
          status: weighted_status(Vendor::STATUSES, n),
          owner_id: user_ids.sample(random: rng),
          contact_name: (n % 4).zero? ? nil : "#{FIRST_NAMES[n % FIRST_NAMES.size]} #{LAST_NAMES[n % LAST_NAMES.size]}",
          contact_email: (n % 5).zero? ? nil : "vendor#{n}@#{name.parameterize}.example",
          notes: (n % 3).zero? ? "Renewal handled by #{DEPARTMENTS[n % DEPARTMENTS.size]}." : nil,
          processes_personal_data: tristate(n),
          data_location: nilable(Vendor::DATA_LOCATIONS, n, 7, rng),
          risk_tier: nilable(Vendor::RISK_TIERS, n, 6, rng),
          last_assessed_on: assessed,
          next_review_on: review,
          created_at: created, updated_at: created + rng.rand(0..120).days
        }
      end
      insert_batched(Vendor, rows, :index_vendors_on_name)
      Vendor.pluck(:id, :name, :status)
    end

    # The four buckets behind the vendors table's review-status filter, so each
    # one returns a non-trivial page. "never" leaves both dates nil.
    def review_dates(n, rng)
      case n % 4
      when 0 then [ nil, nil ]                                                           # never assessed
      when 1 then [ Date.current - rng.rand(400..900), Date.current - rng.rand(1..300) ]  # overdue
      when 2 then [ Date.current - rng.rand(300..700), Date.current + rng.rand(1..30) ]   # due soon
      else        [ Date.current - rng.rand(1..200),   Date.current + rng.rand(31..900) ] # ok
      end
    end

    # --- systems -------------------------------------------------------------

    def seed_systems!(count, user_ids, vendors, rng)
      offset = System.count
      vendor_ids = vendors.map(&:first)
      rows = Array.new(count) do |i|
        n = offset + i
        name = "#{ADJECTIVES[(n / 2) % ADJECTIVES.size]} #{SYSTEM_NOUNS[n % SYSTEM_NOUNS.size]} #{format('%04d', n)}"
        created = past(rng, 730)
        {
          name: name,
          # A third are in-house (no vendor) — the blank branch of the vendor
          # filter and the left-outer-join sort both need coverage.
          vendor_id: (n % 3).zero? ? nil : vendor_ids.sample(random: rng),
          description: "Internal #{SYSTEM_NOUNS[n % SYSTEM_NOUNS.size].downcase} used by #{DEPARTMENTS[n % DEPARTMENTS.size]}.",
          status: weighted_status(System::STATUSES, n),
          owner_id: user_ids.sample(random: rng),
          technical_owner_id: (n % 3).zero? ? nil : user_ids.sample(random: rng),
          department: nilable(DEPARTMENTS, n, 9, rng),
          url: "https://#{name.parameterize}.internal.example",
          authentication_method: nilable(System::AUTHENTICATION_METHODS, n, 8, rng),
          notes: (n % 4).zero? ? "Owned jointly with #{DEPARTMENTS[(n + 3) % DEPARTMENTS.size]}." : nil,
          criticality: nilable(System::CRITICALITIES, n, 7, rng),
          data_classification: nilable(System::DATA_CLASSIFICATIONS, n, 6, rng),
          stores_personal_data: tristate(n),
          personal_data_categories: personal_data_categories(n, rng),
          created_at: created, updated_at: created + rng.rand(0..120).days
        }
      end
      insert_batched(System, rows, :index_systems_on_name)
      System.pluck(:id, :name)
    end

    def personal_data_categories(n, rng)
      return [] if (n % 3).zero?

      picked = System::PERSONAL_DATA_CATEGORIES.sample(rng.rand(1..3), random: rng)
      # special_categories is the scorer's highest system-side factor, so make
      # sure a meaningful slice carries it.
      (n % 11).zero? ? (picked | [ "special_categories" ]) : picked
    end

    # --- assessments ---------------------------------------------------------

    def seed_assessments!(count, vendors, user_ids, rng)
      assessable = vendors.reject { |(_, _, status)| status == "pending_approval" }
      return if assessable.empty?

      # At most one in-progress row per asset (partial unique index), so the
      # in-progress slice draws from DISTINCT vendors that have none already.
      busy = Assessment.in_progress.where(asset_type: "Vendor").pluck(:asset_id).to_set
      free = assessable.reject { |(id, _, _)| busy.include?(id) }
      in_progress = free.sample([ count / 3, free.size ].min, random: rng)
      completed = assessable.sample(count - in_progress.size, random: rng)

      rows = in_progress.map { |(id, _, _)| assessment_row(id, user_ids, rng, completed: false) } +
             completed.map { |(id, _, _)| assessment_row(id, user_ids, rng, completed: true) }
      insert_batched(Assessment, rows, nil)
    end

    def assessment_row(vendor_id, user_ids, rng, completed:)
      created = past(rng, 500)
      residual = Assessment::RISK_LEVELS.sample(random: rng)
      decision = Assessment::DECISIONS.sample(random: rng)
      {
        asset_id: vendor_id, asset_type: "Vendor",
        assessor_id: user_ids.sample(random: rng),
        status: completed ? "completed" : "in_progress",
        inherent_risk: Assessment::RISK_LEVELS.sample(random: rng),
        inherent_risk_factors: [],
        evidence: evidence(rng),
        summary: completed ? "Reviewed; no material findings." : nil,
        residual_risk: completed ? residual : nil,
        decision: completed ? decision : nil,
        conditions: completed && decision == "approved_with_conditions" ? "Annual DPA re-review." : nil,
        next_review_on: completed ? Assessment.suggested_next_review_on(residual, from: created.to_date) : nil,
        completed_at: completed ? created + rng.rand(1..20).days : nil,
        created_at: created, updated_at: created + rng.rand(0..20).days
      }
    end

    def evidence(rng)
      Assessment.blank_evidence.map { |item| item.merge("state" => Assessment::EVIDENCE_STATES.sample(random: rng)) }
    end

    # --- change proposals ----------------------------------------------------

    def seed_proposals!(count, vendors, systems, user_ids, rng)
      rows = Array.new(count) do |i|
        on_vendor = i.even?
        asset = on_vendor ? vendors.sample(random: rng) : systems.sample(random: rng)
        created = past(rng, 90)
        # Compliance-lane proposals carry a ⚖ field; owner-lane a regular one.
        changes = if (i % 3).zero?
          on_vendor ? { "data_location" => [ "eu", "us" ] } : { "criticality" => [ "medium", "high" ] }
        else
          { "description" => [ "Before #{i}", "Updated description #{i}" ] }
        end
        {
          asset_id: asset.first, asset_type: on_vendor ? "Vendor" : "System",
          proposer_id: user_ids.sample(random: rng),
          lane: (i % 3).zero? ? "compliance" : "owner",
          attribute_changes: changes,
          justification: (i % 2).zero? ? "Corrected after the quarterly review." : nil,
          created_at: created, updated_at: created
        }
      end
      insert_batched(ChangeProposal, rows, nil)
    end

    # --- audit events --------------------------------------------------------

    def seed_audit_events!(count, vendors, systems, rng)
      actors = User.pluck(:id, :name)
      return if actors.empty? || vendors.empty? || systems.empty?

      rows = Array.new(count) do |i|
        type = EVENT_TYPES[i % EVENT_TYPES.size]
        actor_id, actor_name = actors.sample(random: rng)
        on_vendor = type.start_with?("vendor.", "assessment.") ||
                    (!type.start_with?("system.") && rng.rand(2).zero?)
        asset = on_vendor ? vendors.sample(random: rng) : systems.sample(random: rng)
        {
          event_type: type,
          actor_type: "user", actor_id: actor_id, actor_display: actor_name,
          targets: [ { "type" => on_vendor ? "Vendor" : "System", "id" => asset[0], "display" => asset[1] } ],
          attribute_changes: audit_changes(type, i),
          metadata: audit_metadata(type, rng),
          justification: (i % 7).zero? ? "Requested by the asset owner." : nil,
          occurred_at: past(rng, 730),
          schema_version: AuditEvent::CURRENT_SCHEMA_VERSION,
          correlation_id: SecureRandom.uuid,
          ip_address: "10.#{rng.rand(0..255)}.#{rng.rand(0..255)}.#{rng.rand(1..254)}",
          user_agent: "Mozilla/5.0 (demo volume data)"
        }
      end
      insert_batched(AuditEvent, rows, nil)
    end

    def audit_changes(type, i)
      case type
      when "user.role_changed" then { "role" => [ "member", "compliance" ] }
      when "vendor.approved"   then { "status" => [ "pending_approval", "active" ] }
      when "vendor.updated", "system.updated" then { "description" => [ "Before #{i}", "After #{i}" ] }
      end
    end

    # assessment.* events render their outcome from metadata, not a field diff.
    def audit_metadata(type, rng)
      base = { "source" => "web-ui" }
      case type
      when "assessment.completed"
        residual = Assessment::RISK_LEVELS.sample(random: rng)
        base.merge(
          "decision" => Assessment::DECISIONS.sample(random: rng),
          "residual_risk" => residual,
          "previous_risk_tier" => Assessment::RISK_LEVELS.sample(random: rng),
          "inherent_risk" => Assessment::RISK_LEVELS.sample(random: rng),
          "next_review_on" => Assessment.suggested_next_review_on(residual).to_s
        )
      when "assessment.started"
        base.merge("inherent_risk" => Assessment::RISK_LEVELS.sample(random: rng))
      else
        base
      end
    end

    # --- helpers -------------------------------------------------------------

    # Every row needs the same keys (insert_all requires it). `unique_by` turns
    # the insert into ON CONFLICT DO NOTHING, so a re-run tops the sandbox up
    # instead of blowing up on a name that already exists.
    def insert_batched(klass, rows, unique_index)
      rows.each_slice(BATCH) do |slice|
        unique_index ? klass.insert_all(slice, unique_by: unique_index) : klass.insert_all(slice)
      end
    end

    def past(rng, days)
      Time.current - rng.rand(0..days).days - rng.rand(0..86_399).seconds
    end

    # Picks a value but leaves a slice nil — "not recorded" is a real state
    # (unscored risk, unknown classification) and the filters must handle it.
    #
    # The nil slice is modular so its proportion is exact; the value itself is
    # drawn from the seeded RNG rather than `n % size`. Indexing every field by
    # `n` correlates them — criticality and data classification would advance in
    # lockstep, and combining two filters would return almost nothing.
    def nilable(values, n, every, rng)
      (n % every).zero? ? nil : values.sample(random: rng)
    end

    # Unknown / Yes / No — the ⚖ booleans are three-state.
    def tristate(n)
      case n % 3
      when 0 then nil
      when 1 then true
      else false
      end
    end

    # Mostly active, with a real tail of the other lifecycle states.
    def weighted_status(statuses, n)
      (n % 10) < 6 ? "active" : statuses[n % statuses.size]
    end

    def report
      Rails.logger.info(
        "[demo] volume: vendors=#{Vendor.count} systems=#{System.count} users=#{User.count} " \
        "assessments=#{Assessment.count} proposals=#{ChangeProposal.count} audit=#{AuditEvent.count}"
      )
    end
  end
end
