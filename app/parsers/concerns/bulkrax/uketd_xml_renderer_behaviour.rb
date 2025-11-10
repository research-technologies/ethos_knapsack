# frozen_string_literal: true
require 'open-uri'
require 'xml'

module Bulkrax
  module UketdXmlRendererBehaviour # rubocop:disable Metrics/ModuleLength
    class << self # rubocop:disable Metrics/ClassLength
      attr_accessor :mappings, :oai_pmh

      # A method that will dump UKETD XML for a SolrDoc
      # This is outside of the context of Parsers and Entries etc
      def dump_xml_partial(metadata) # rubocop:disable Metrics/MethodLength
        @mappings = Hyku.default_bulkrax_field_mappings["Bulkrax::XmlEtdDcParser"].freeze
        @oai_pmh = true

        uketddc_node = XML::Node.new('uketddc')
        uketd_dc_namespaces.each do |ns, ns_url|
          add_namespace(uketddc_node, ns.to_s, ns_url)
        end
        uketddc_node['xsi:schemaLocation'] = "http://naca.central.cranfield.ac.uk/ethos-oai/2.0/uketd_dc.xsd"
        seen = []
        metadata.each do |key, value|
          k = unsolrize(key)
          next if seen.include?(k)
          render(uketd_tag(k), value, uketddc_node)
          seen << k
        end
        uketddc_node
      end

      def unsolrize(key)
        key.gsub(/_(tesim|ssim|ssi)$/, '')
      end

      def render(key, value, uketddc_node)
        return if key.nil?
        send("render_#{key}", key, value, uketddc_node)
      rescue NoMethodError
        # We can do this as if it weren't a single string (accidentally in an array)
        # then it would have a render_thing method defined
        value = value.first if value.is_a?(Array)
        uketddc_node << XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", value)
      end

      def render_creator(key, value, uketddc_node)
        orcids = []
        isnis = []
        value.each do |v|
          v = eval(v) if v.is_a?(String) # rubocop:disable Security/Eval
          uketddc_node << XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", "#{v['creator_family_name']}, #{v['creator_given_name']}")
          orcids << v['creator_orcid'] if v['creator_orcid']
          isnis << v['creator_isni'] if v['creator_isni']
        end
        return unless oai_pmh
        render('authoridentifier_orcid', orcids, uketddc_node)
        render('authoridentifier_isni', isnis, uketddc_node)
      end

      def render_advisor(key, value, uketddc_node)
        value.each do |v|
          v = eval(v) if v.is_a?(String) # rubocop:disable Security/Eval
          uketddc_node << XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", "#{v['contributor_family_name']}, #{v['contributor_given_name']}")
        end
      end

      def render_sponsor(key, value, uketddc_node)
        if oai_pmh
          names = []
          awards = []
          value.each do |v|
            v = eval(v) if v.is_a?(String) # rubocop:disable Security/Eval
            names << v['funder_name'] if v['funder_name']
            awards << v['funder_award'] if v['funder_award'].present?
          end
          render('grantnumber', awards, uketddc_node)
        else
          names = value
        end
        uketddc_node << XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", names.join(' ; '))
      end

      def render_grantnumber(key, value, uketddc_node)
        value.each do |v|
          v = v.first if v.is_a?(Array)
          uketddc_node << XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", v) unless v.nil?
        end
      end

      def render_language(key, value, uketddc_node)
        value = value.first if value.is_a?(Array)
        language_node = XML::Node.new("#{uketd_tags[key.to_sym]}:#{key}", value)
        XML::Attr.new(language_node, "xsi:type", "dcterms:ISO639-2")
        uketddc_node << language_node
      end

      def render_identifier_doi(_key, value, uketddc_node)
        value = value.first if value.is_a?(Array)
        identifier_node = XML::Node.new("#{uketd_tags['identifier_doi'.to_sym]}:identifier", value)
        XML::Attr.new(identifier_node, "xsi:type", "dcterms:DOI")
        uketddc_node << identifier_node
      end

      def render_identifier_other_identifier(_key, value, uketddc_node)
        value = value.first if value.is_a?(Array)
        identifier_node = XML::Node.new("#{uketd_tags['identifier_other_identifier'.to_sym]}:identifier", value)
        XML::Attr.new(identifier_node, "xsi:type", "dcterms:URI")
        uketddc_node << identifier_node
      end

      def render_authoridentifier_isni(_key, value, uketddc_node)
        value.each do |v|
          identifier_node = XML::Node.new("#{uketd_tags['authoridentifier_isni'.to_sym]}:authoridentifier", v)
          XML::Attr.new(identifier_node, "xsi:type", "uketdterms:ISNI")
          uketddc_node << identifier_node
        end
      end

      def render_authoridentifier_orcid(_key, value, uketddc_node)
        value.each do |v|
          identifier_node = XML::Node.new("#{uketd_tags['authoridentifier_orcid'.to_sym]}:authoridentifier", v)
          XML::Attr.new(identifier_node, "xsi:type", "uketdterms:ORCID")
          uketddc_node << identifier_node
        end
      end

      def render_subject_ethos_subject(_key, value, uketddc_node)
        value = value.first if value.is_a?(Array)
        uketddc_node << XML::Node.new("#{uketd_tags['subject_ethos_subject'.to_sym]}:subject", value)
      end

      def render_subject_dewey(_key, value, uketddc_node)
        value = value.first if value.is_a?(Array)
        subject_node = XML::Node.new("#{uketd_tags['subject_dewey'.to_sym]}:subject", value)
        XML::Attr.new(subject_node, "xsi:type", "dcterms:DDC")
        uketddc_node << subject_node
      end

      def uketd_tag(key)
        if hyrax_to_uketd_tags.key?(key.to_sym)
          hyrax_to_uketd_tags[key.to_sym]
        elsif uketd_tags.key?(key.to_sym)
          key
        end
      end

      # rubocop:disable Metrics/MethodLength
      def uketd_tags
        {
          relation: 'dc',
          title: 'dc',
          creator: 'dc',
          authoridentifier_isni: 'uketdterms', # xsi:type="uketdterms:ISNI"
          authoridentifier_orcid: 'uketdterms', # xsi:type="uketdterms:ORCID"
          advisor: 'uketdterms',
          institution: 'uketdterms',
          department: 'uketdterms',
          publisher: 'dc',
          issued: 'dcterms',
          abstract: 'dcterms',
          alternative: 'dcterms',
          subject_dewey: 'dc', # xsi:type="dcterms:DDC"
          subject_ethos_subject: 'dc',
          coverage: 'dc',
          type: 'dc',
          qualificationlevel: 'uketdterms',
          embargodate: 'uketdterms',
          sponsor: 'uketdterms',
          grantnumber: 'uketdterms',
          language: 'dc', # xsi:type="dcterms:ISO639-2"
          isReferencedBy: 'dcterms',
          identifier_doi: 'dc', # xsi:type="dcterms:DOI"
          identifier_other_identifier: 'dc', # xsi:type="dcterms:URI"
          provenance: 'dcterms',
          source: 'dc',
          accessRights: 'dcterms'
        }
      end

      def hyrax_to_uketd_tags
        {
          relation: 'bl_cat_identifier',
          title: 'title',
          alternative_title: 'alternative',
          creator: 'creator',
          contributor: 'advisor',
          institution: 'publisher',
          current_he_institution: 'institution',
          org_unit: 'department',
          date_issued: 'issued',
          abstract: 'abstract',
          dewey: 'subject_dewey', # xsi:type="dcterms:DDC"
          subject: 'subject_ethos_subject',
          keywords: 'coverage',
          qualification_name: 'type',
          qualification_level: 'qualificationlevel',
          embargo_date: 'embargodate',
          funder: 'sponsor',
          language: 'language', # xsi:type="dcterms:ISO639-2"
          referenced_by: 'isReferencedBy',
          doi: 'identifier_doi', # identifier xsi:type="dcterms:DOI"
          other_identifier: 'identifier_other_identifier', # xsi:type="dcterms:URI"
          oai_identifier: 'provenance',
          ethos_identifier: 'source',
          ethos_access_rights: 'accessRights'
        }
      end
      # rubocop:enable Metrics/MethodLength

      def uketd_dc_namespaces
        {
          oai_dc: "http://www.openarchives.org/OAI/2.0/oai_dc/",
          xsi: "http://www.w3.org/2001/XMLSchema-instance",
          dc: "http://purl.org/dc/elements/1.1/",
          dcterms: "http://purl.org/dc/terms/",
          uketdterms: "http://naca.central.cranfield.ac.uk/ethos-oai/terms/",
          uketd_dc: "http://naca.central.cranfield.ac.uk/ethos-oai/2.0/"
        }
      end

      def add_namespace(node, ns, ns_url)
        node.namespaces.namespace = XML::Namespace.new(node, ns, ns_url)
      end
    end
  end
end
