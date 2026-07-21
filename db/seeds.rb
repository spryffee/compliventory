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
# Demo data — the personas and inventory behind /dev/sign-in locally and the
# public demo's persona picker. Seeded in development and on a DEMO_MODE
# instance's first deploy (thereafter the nightly Demo::ResetJob keeps it
# fresh). Never in a plain production install.
# ---------------------------------------------------------------------------
if Rails.env.development? || Demo.enabled?
  puts "Seeding demo data…"
  Demo::Seeder.seed!
  puts <<~OUT
    Done. Demo users (sign in at #{Demo.enabled? ? '/demo/sign-in' : '/dev/sign-in'}):
      admin@example.com       (admin — user roles, API tokens)
      compliance@example.com  (compliance — approves submissions & gated fields)
      owner@example.com       (member — owns demo assets)
      delegate@example.com    (member — acts as delegate)
      employee@example.com    (member — plain employee)
      gone@example.com        (inactive — cannot sign in)
  OUT
end
