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
