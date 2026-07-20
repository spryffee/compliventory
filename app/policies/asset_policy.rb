# Plain-Ruby policy (governauthzer pattern) answering who may WRITE what on an
# inventory asset. Reads need no policy: everyone authenticated sees everything.
#
# Direct-edit matrix (proposal lanes arrive with the change-control phase):
#   compliance     → every field (an approver's own edit is self-approved)
#   owner/delegate → regular (non-⚖) fields
#   admin          → ownership repair only (offboarded employees etc.)
class AssetPolicy
  # Fields admin may fix directly on assets they don't own — ownership repair,
  # not general editing. Delegate management is covered by may_manage_delegates?.
  OWNERSHIP_FIELDS = %i[owner_id].freeze

  def self.for(user, asset)
    case asset
    when Vendor then VendorPolicy.new(user, asset)
    when System then SystemPolicy.new(user, asset)
    else raise ArgumentError, "no policy for #{asset.class}"
    end
  end

  def initialize(user, asset)
    @user = user
    @asset = asset
  end

  def editable_directly?(field)
    field = field.to_sym
    return true if @user.compliance?
    # pending_approval → active happens only via compliance; nobody else touches
    # the status of an unapproved asset.
    return false if field == :status && @asset.pending_approval?
    return regular_field?(field) if owner_or_delegate?
    return OWNERSHIP_FIELDS.include?(field) if @user.admin?

    false
  end

  def editable_fields
    @asset.class::EDITABLE_FIELDS.select { |field| editable_directly?(field) }
  end

  def may_edit_anything?
    editable_fields.any?
  end

  def may_manage_delegates?
    @user.compliance? || @user.admin? || owner_or_delegate?
  end

  private

  def regular_field?(field)
    !@asset.class::COMPLIANCE_FIELDS.include?(field)
  end

  def owner_or_delegate?
    return @owner_or_delegate if defined?(@owner_or_delegate)
    @owner_or_delegate = @asset.owned_or_delegated_to?(@user)
  end
end
