module DemoHelper
  # One-line "what can this persona do" hint on the demo persona picker.
  def demo_persona_hint(role)
    case role
    when "admin"      then "Manage user roles and API tokens"
    when "compliance" then "Approve submissions and compliance-gated fields"
    else "Submit vendors/systems, propose edits, own assets"
    end
  end
end
