class ApplicationMailer < ActionMailer::Base
  helper :audit # change_value for the change diffs in mail bodies
  default from: ENV.fetch("MAIL_FROM", "compliventory@localhost")
  layout "mailer"
end
