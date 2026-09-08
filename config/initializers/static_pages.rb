# frozen_string_literal: true

# OVERRIDE HYKU and add a static contact page (used by BL instead of form)

Rails.application.config.after_initialize do
  # rubocop:disable Metrics/BlockLength
  ContentBlock.class_eval do
    NAME_REGISTRY = {
      marketing: :marketing_text,
      researcher: :featured_researcher,
      announcement: :announcement_text,
      about: :about_page,
      help: :help_page,
      FAQs: :help_page,
      terms: :terms_page,
      agreement: :agreement_page,
      home_text: :home_text,
      homepage_about_section_heading: :homepage_about_section_heading,
      homepage_about_section_content: :homepage_about_section_content,
      contact_us: :contact_us_page
    }.freeze
  
    # NOTE: method defined outside the metaclass wrapper below because
    # `for` is a reserved word in Ruby.
    def self.for(key)
      key = key.respond_to?(:to_sym) ? key.to_sym : key
      raise ArgumentError, "#{key} is not a ContentBlock name" unless registered?(key)
      ContentBlock.public_send(NAME_REGISTRY[key])
    end
  
    class << self
      def registered?(key)
        NAME_REGISTRY.include?(key)
      end
  
      def contact_us_page
        find_or_create_by(name: 'contact_us_page')
      end
  
      def contact_us_page=(value)
        contact_us_page.update(value:)
      end
    end
  end
  # rubocop:enable Metrics/BlockLength
end  
