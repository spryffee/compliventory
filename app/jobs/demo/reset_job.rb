module Demo
  # Nightly wipe-and-reseed of the public demo sandbox (scheduled in
  # config/recurring.yml). Guarded by Demo.enabled? so the recurring entry is a
  # harmless no-op on any non-demo instance that happens to load it.
  class ResetJob < ApplicationJob
    queue_as :default

    def perform
      return unless Demo.enabled?

      Demo::Seeder.reset!
      Rails.logger.info("[demo] sandbox reset — reseeded pristine demo data")
    end
  end
end
