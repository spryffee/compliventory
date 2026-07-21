class ApplicationMailer < ActionMailer::Base
  helper :application # audit_value for change diffs in mail bodies
  default from: ENV.fetch("MAIL_FROM", "compliventory@localhost")
  layout "mailer"
end
