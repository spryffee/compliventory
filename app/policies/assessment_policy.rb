# Who may run vendor risk assessments. Assessments are a compliance activity, so
# every write is gated on the compliance role; reads are open to everyone
# (transparency, like the rest of the app). State guards (in-progress vs
# completed) live in the services, so callers get precise error codes.
class AssessmentPolicy
  def initialize(user, assessment = nil)
    @user = user
    @assessment = assessment
  end

  # May the user start an assessment on a vendor (no record exists yet)?
  def may_assess?
    @user.compliance?
  end

  def may_edit?
    @user.compliance?
  end

  def may_complete?
    @user.compliance?
  end

  def may_cancel?
    @user.compliance?
  end
end
