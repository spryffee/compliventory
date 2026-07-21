# Idempotent seeds. Users normally arrive via the sync API; seeding is the
# documented bootstrap carve-out (REQUIREMENTS.md).

# ---------------------------------------------------------------------------
# Production bootstrap: the first admin, so someone can mint API tokens and
# assign roles. Set BOOTSTRAP_ADMIN_EMAIL (+ optional BOOTSTRAP_ADMIN_NAME)
# for the first deploy; subsequent runs are no-ops.
# ---------------------------------------------------------------------------
if ENV["BOOTSTRAP_ADMIN_EMAIL"].present?
  admin = User.find_or_initialize_by(email: ENV["BOOTSTRAP_ADMIN_EMAIL"])
  admin.name ||= ENV.fetch("BOOTSTRAP_ADMIN_NAME", "Admin")
  admin.role = "admin"
  admin.active = true
  admin.save!
  puts "Bootstrap admin: #{admin.email}"
end

# ---------------------------------------------------------------------------
# Development demo data — for clicking through /dev/sign-in with every role.
# ---------------------------------------------------------------------------
if Rails.env.development?
  puts "Seeding development demo data…"

  {
    "admin@example.com"      => [ "Alice Admin",      "admin" ],
    "compliance@example.com" => [ "Clara Compliance", "compliance" ],
    "owner@example.com"      => [ "Oscar Owner",      "member" ],
    "delegate@example.com"   => [ "Dana Delegate",    "member" ],
    "employee@example.com"   => [ "Eve Employee",     "member" ]
  }.each do |email, (name, role)|
    User.find_or_create_by!(email: email) { |u| u.name = name; u.role = role }
  end

  User.find_or_create_by!(email: "gone@example.com") do |u|
    u.name = "Gary Gone"
    u.active = false
  end

  owner = User.find_by!(email: "owner@example.com")
  delegate = User.find_by!(email: "delegate@example.com")
  employee = User.find_by!(email: "employee@example.com")

  acme = Vendor.find_or_create_by!(name: "Acme Cloud") do |v|
    v.website = "https://acme.example"
    v.description = "Object storage and CDN."
    v.category = "cloud_infra"
    v.status = "active"
    v.owner = owner
    v.processes_personal_data = true
    v.data_location = "eu"
    v.risk_tier = "medium"
  end

  Vendor.find_or_create_by!(name: "NewTool.io") do |v|
    v.category = "saas"
    v.status = "pending_approval"
    v.owner = employee
    v.description = "Awaiting compliance approval — activate via edit as compliance."
  end

  tracker = System.find_or_create_by!(name: "Issue Tracker") do |s|
    s.vendor = acme
    s.description = "Where work is tracked."
    s.status = "active"
    s.owner = owner
    s.department = "Engineering"
    s.authentication_method = "sso"
    s.criticality = "high"
    s.data_classification = "confidential"
    s.stores_personal_data = true
    s.personal_data_categories = %w[employees]
  end

  System.find_or_create_by!(name: "Internal Wiki") do |s|
    s.status = "active"
    s.owner = employee
    s.authentication_method = "sso"
    s.data_classification = "internal"
  end

  # A wider inventory so the dynamic tables (sort/filter/columns) have
  # something to chew on. Compact tuples, expanded below.
  [
    # name, category, status, owner, data_location, risk_tier, personal_data, description
    [ "Slacker",        "saas",        "active",     owner,    "us",  "medium",   true,  "Company chat." ],
    [ "HubForge",       "saas",        "active",     owner,    "us",  "high",     true,  "Code hosting and CI." ],
    [ "Cloudmazon",     "cloud_infra", "active",     owner,    "eu",  "critical", true,  "Primary cloud provider." ],
    [ "PeopleFirst HR", "saas",        "active",     delegate, "eu",  "high",     true,  "HRIS — payroll and absences." ],
    [ "Figmatic",       "saas",        "active",     employee, "us",  "low",      false, "Design collaboration." ],
    [ "MailChimping",   "saas",        "offboarded", employee, "us",  "medium",   true,  "Old newsletter tool, contract ended." ],
    [ "Deskside IT",    "services",    "active",     delegate, "eu",  "low",      false, "On-site hardware support." ],
    [ "LicenseWorks",   "software",    "archived",   owner,    "other", "low",    false, "Perpetual-license CAD suite." ]
  ].each do |name, category, status, o, loc, tier, pd, description|
    Vendor.find_or_create_by!(name: name) do |v|
      v.category = category
      v.status = status
      v.owner = o
      v.data_location = loc
      v.risk_tier = tier
      v.processes_personal_data = pd
      v.description = description
      v.website = "https://#{name.parameterize}.example"
    end
  end

  [
    # name, vendor name (nil = in-house), status, owner, criticality, classification, auth, department
    [ "Chat",           "Slacker",        "active",     owner,    "high",   "confidential", "sso",          "Company-wide" ],
    [ "Source Control", "HubForge",       "active",     owner,    "critical", "confidential", "sso",        "Engineering" ],
    [ "HR Portal",      "PeopleFirst HR", "active",     delegate, "high",   "restricted",   "sso",          "People" ],
    [ "Design Studio",  "Figmatic",       "active",     employee, "low",    "internal",     "sso",          "Product" ],
    [ "Legacy CRM",     nil,              "deprecated", owner,    "medium", "confidential", "password_mfa", "Sales" ],
    [ "Build Farm",     nil,              "retired",    employee, "low",    "internal",     "other",        "Engineering" ]
  ].each do |name, vendor_name, status, o, criticality, classification, auth, department|
    System.find_or_create_by!(name: name) do |s|
      s.vendor = Vendor.find_by!(name: vendor_name) if vendor_name
      s.status = status
      s.owner = o
      s.criticality = criticality
      s.data_classification = classification
      s.authentication_method = auth
      s.department = department
      s.stores_personal_data = classification == "restricted"
      s.description = "#{name} (demo)."
    end
  end

  [ acme, tracker ].each do |asset|
    Delegation.find_or_create_by!(asset: asset, user: delegate)
  end

  ChangeProposal.find_or_create_by!(asset: acme, proposer: employee, lane: "owner") do |p|
    p.attribute_changes = { "description" => [ acme.description, "Object storage, CDN and DNS." ] }
    p.justification = "They also host our DNS now."
  end

  puts <<~OUT
    Done. Demo users (sign in at /dev/sign-in):
      admin@example.com       (admin — user roles, API tokens)
      compliance@example.com  (compliance — approves submissions & gated fields)
      owner@example.com       (member — will own demo assets)
      delegate@example.com    (member — will act as delegate)
      employee@example.com    (member — plain employee)
      gone@example.com        (inactive — cannot sign in)
  OUT
end
