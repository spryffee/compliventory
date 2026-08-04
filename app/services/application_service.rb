class ApplicationService
  Result = Data.define(:success, :value, :code, :context)

  # Sentinel for kwargs distinguishing "not provided" from "explicitly nil".
  # Use as default for optional kwargs whose nil value has meaning (e.g., "clear this field").
  NOT_PROVIDED = Object.new.freeze

  def self.call(...)
    new(...).call
  end

  def call
    raise NotImplementedError, "#{self.class.name} must implement #call"
  end

  private

  def success(value = nil)
    Result.new(success: true, value: value, code: nil, context: {})
  end

  def failure(code, **context)
    Result.new(success: false, value: nil, code: code, context: context)
  end

  # Nobody is mailed about their own decision, and a deactivated user is mailed
  # nothing at all.
  def notify?(recipient, actor)
    recipient != actor && recipient.active?
  end
end
