# frozen_string_literal: true

# Allow DiceRoll class to be serialized/deserialized with YAML
Rails.application.config.to_prepare do
  Rails.application.config.active_record.yaml_column_permitted_classes ||= []
  Rails.application.config.active_record.yaml_column_permitted_classes << DiceRoll
end
