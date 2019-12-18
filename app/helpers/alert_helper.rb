module AlertHelper
  def bootstrap_alert_type(type)
    {
      error: :danger,
      alert: :warning,
      notice: :info
    }[type.to_sym] || type
  end
end
