# frozen_string_literal: true

module Blacklight
  module SolrDocumentDecorator
    def to_semantic_values # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      @semantic_value_hash ||= self.class.field_semantics.each_with_object(Hash.new([])) do |(key, field_names), hash|
        # Handles single string field_name or an array of field_names
        value = if field_names.is_a?(Hash)
                  field_names.map { |k, v| { k => self[v] } }
                else
                  # Special cases to manipulate values based on *source* field (hence why here)
                  # ids => work urls
                  # applysensible xsi:type attributes to DOI
                  Array.wrap(field_names).map do |field_name|
                    if (field_name == 'id') && self[field_name].present?
                      get_work_url_by_id(self[field_name])
                    #                    elsif field_name == 'doi_ssim' && self[field_name].present?
                    #                      { 'dcterms:DOI' => self[field_name].first }
                    #                    elsif field_name == 'dewey_tesim' && self[field_name].present?
                    #                      { 'dcterms:DDC' => self[field_name].first }
                    elsif field_name == 'creator_tesim' && self[field_name].present?
                      c = eval(self[field_name].first) # rubocop:disable Security/Eval
                      "#{c['creator_family_name']}, #{c['creator_given_name']}"
                    elsif field_name == 'contributor_tesim' && self[field_name].present?
                      self[field_name].map do |contributor|
                        c = eval(contributor) # rubocop:disable Security/Eval
                        c['contributor_family_name'].present? || c['contributor_given_name'].present? ? "#{c['contributor_family_name']}, #{c['contributor_given_name']}" : nil
                      end
                    elsif self[field_name].present? && self[field_name].all?(&:blank?)
                      nil
                    else
                      self[field_name]
                    end
                  end.flatten.compact
                end
        # Make single and multi-values all arrays, so clients
        # don't have to know.
        hash[key] = value unless value.empty?
      end
      @semantic_value_hash ||= {}
    end

    def get_work_url_by_id(id)
      "#{Rails.application.routes.url_helpers.hyrax_thesis_or_dissertations_url protocol: 'https'}/#{id}"
    end

    def dublin_core_field_names
      [:contributor, :coverage, :creator, :date, :format, :identifier, :language, :publisher, :relation, :rights, :source, :subject, :title, :type, :ispartof, :description]
    end

    def dc_terms_field_names
      [:abstract, :issued, :extent, :accessrights]
    end

    def dublin_core_field_name?(field)
      dublin_core_field_names.include? field.to_sym
    end

    def dc_terms_field_name?(field)
      dc_terms_field_names.include? field.to_sym
    end

    def uketd_terms_field_name?(field)
      uketd_terms_field_names.include? field.to_sym
    end

    def value_to_tag(v, xml, field, namespace = "dc")
      if v.is_a?(Hash)
        v.map { |attr, vals| ([*vals] || []).each { |val| xml.tag! "#{namespace}:#{field}", val, attr.end_with?(":Local") ? nil : { "xsi:type" => attr } } }
      #      elsif /^#{URI.regexp}$/.match?(v.to_s)
      #        xml.tag! "#{namespace}:#{field}", v, { "xsi:type" => "dcterms:URI" }
      else
        xml.tag! "#{namespace}:#{field}", v
      end
    end
  end
end

SolrDocument.prepend(Blacklight::SolrDocumentDecorator)
