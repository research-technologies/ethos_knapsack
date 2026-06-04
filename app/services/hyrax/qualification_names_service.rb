# frozen_string_literal: true
module Hyrax
  module QualificationNamesService
    mattr_accessor :authority
    self.authority = Qa::Authorities::Local.subauthority_for('qualification_names')

    def self.select_all_options
      authority.all.map do |element|
        [element[:label], element[:id]]
      end
    end

    def self.select_all_option_ids
      authority.all.map do |element|
        [element[:id], element[:id]]
      end
    end

    def self.select_all_option_just_ids
      authority.all.map { |e| e[:id] }
    end

    def self.label(id)
      id = Array(id).first
      authority.find(id).fetch('term')
    end

    ##
    # @param [String, nil] id identifier of the resource type
    #
    # @return [String] a schema.org type. Gives the default type if `id` is nil.
    def self.microdata_type(id)
      return Hyrax.config.microdata_default_type if id.nil?
      Microdata.fetch("type.#{id}", default: Hyrax.config.microdata_default_type)
    end
  end
end
