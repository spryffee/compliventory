class ApplicationMailer < ActionMailer::Base
  helper :audit # change_value for the change diffs in mail bodies
  default from: ENV.fetch("MAIL_FROM", "compliventory@localhost")
  layout "mailer"

  # Notifications can outlive their record: deciding a proposal destroys it, and
  # rejecting a pending asset destroys the asset. Belongs here rather than in
  # ApplicationJob — mail runs as ActionMailer::MailDeliveryJob, which does not
  # inherit it and delegates its rescues to the mailer class instead.
  rescue_from ActiveJob::DeserializationError do |error|
    Rails.logger.info("Dropping a notification whose record is gone: #{error.message}")
  end
end
