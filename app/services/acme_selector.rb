# typed: false
# frozen_string_literal: true

module AcmeSelector
  def self.config_for(surface)
    AcmeSelectorSurfaceConfig::CONFIGS.fetch(surface.to_sym)
  end
  public_class_method :config_for
end
