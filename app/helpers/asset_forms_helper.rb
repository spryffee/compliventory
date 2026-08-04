# View bits for the two asset forms (vendors/_form, systems/_form).
module AssetFormsHelper
  # One optional field. `fields` is what the policy lets this actor touch, so
  # every field on the form is conditional — this keeps the check, the wrapper
  # and the label in one place instead of six lines around each control.
  def form_field(form, fields, key, label = nil, hint: nil, &block)
    return unless fields.include?(key)

    tag.div(safe_join([
      form.label(key, label, class: "field-label"),
      capture(&block),
      (tag.p(hint, class: "field-hint") if hint)
    ].compact))
  end

  # Owner pickers. Memoized: the system form has two of them (business and
  # technical owner), and they are the same list.
  def user_options
    @user_options ||= User.active.order(:name).map { |user| [ user.name, user.id ] }
  end

  # Every vendor, not just the active ones — a system may legitimately point at
  # one that is pending approval or already offboarded.
  def vendor_options
    @vendor_options ||= Vendor.order(:name).map { |vendor| [ vendor.name, vendor.id ] }
  end
end
