# frozen_string_literal: true

# Needs to stay in #after_initialize
# @see https://github.com/notch8/palni_palci_knapsack/commit/e17e7e56
Rails.application.config.after_initialize do
  Hyrax.config do |config|
    # Injected via `rails g hyrax:work_resource ThesisOrDissertation`
    config.register_curation_concern :thesis_or_dissertation
    config.enable_noids = false
  end

  # Register authorities
  Qa::Authorities::Local.register_subauthority('qualification_names', 'Qa::Authorities::Local::FileBasedAuthority')
  Qa::Authorities::Local.register_subauthority('qualification_levels', 'Qa::Authorities::Local::FileBasedAuthority')
  Qa::Authorities::Local.register_subauthority('languages', 'Qa::Authorities::Local::FileBasedAuthority')
  Qa::Authorities::Local.register_subauthority('current_he_institutions', 'Qa::Authorities::Local::FileBasedAuthority')
  Qa::Authorities::Local.register_subauthority('contributor_roles', 'Qa::Authorities::Local::FileBasedAuthority')
end

