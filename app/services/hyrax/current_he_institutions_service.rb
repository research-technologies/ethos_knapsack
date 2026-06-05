# frozen_string_literal: true
module Hyrax
  module CurrentHeInstitutionsService
    mattr_accessor :authority
    self.authority = Qa::Authorities::Local.subauthority_for('current_he_institutions')

    def self.select_all_options
      authority.all.map do |element|
        [element[:label], element[:id]]
      end
    end

    def self.select_active_options
      all_options_hash.map { |e| [e[:label], e[:id]] }
    end

    def self.select_active_options_isni
      all_options_hash.map { |e| e[:isni] }
    end

    def self.select_active_options_ror
      all_options_hash.map { |e| e[:ror] }
    end

    def self.select_active_options_id
      all_options_hash.map { |e| e[:id] }
    end

    def self.label(id)
      id = Array(id).first
      authority.find(id).fetch('term', '')
    end

    ##
    # @param [String, nil] id identifier of the resource type
    #
    # @return [String] a schema.org type. Gives the default type if `id` is nil.
    def self.microdata_type(id)
      return Hyrax.config.microdata_default_type if id.nil?
      Microdata.fetch("type.#{id}", default: Hyrax.config.microdata_default_type)
    end

    def self.all_options_hash
      authority.all.map do |res|
        { id: res[:id], label: res[:term], isni: res[:isni], ror: res[:ror], active: res.fetch(:active, true) }.with_indifferent_access
      end
    end
  end
end
