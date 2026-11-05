# frozen_string_literal: true

class EthosListSet < BlacklightOaiProvider::SolrSet
  OPEN_ACCESS = 'open_access'
  ACCESS_RIGHTS_FIELD = 'ethos_access_rights_tesim'
  ACCESS_RIGHTS_SIM_FIELD = 'ethos_access_rights_sim'

  class << self
    def all
      static_sets.keys.map { |spec| new(spec) } + Array(super)
    end

    # Resumption tokens carry a dot as ! because they split on dots (ddc:333.7).
    def from_spec(spec)
      super(spec.tr('!', '.'))
    end

    def sets_for(record)
      sets = Array.wrap(@fields).flat_map do |f|
        Array.wrap(record.fetch(f[:solr_field], [])).reject(&:blank?).map do |value|
          new(build_spec(f[:label], value))
        end
      end

      static_specs_for(record).map { |spec| new(spec) } + sets
    end

    def sets_from_facets(facet_results)
      sets = Array.wrap(@fields).map do |f|
        facet_results.fetch(f[:solr_field], [])
                     .each_slice(2)
                     .select { |t| t[0] != '' } # added to avoid choking on empty values
                     .map { |t| new(build_spec(f[:label], t.first)) }
      end.flatten

      sets.empty? ? nil : sets
    end

    def build_spec(label, value)
      "#{encode(label)}:#{encode(value)}"
    end

    # OAI-PMH limits a setSpec to a small set of URL-safe characters. Spaces become
    # underscores and anything else outside A-Za-z0-9 and - becomes ~XX per UTF-8 byte.
    # That includes dots, which would break the resumption token parser.
    def encode(text)
      text.to_s.gsub(/[^A-Za-z0-9\- ]/) { |c| c.bytes.map { |b| format('~%02X', b) }.join }.tr(' ', '_')
    end

    def decode(text)
      text.tr('_', ' ').gsub(/(?:~\h\h)+/) { |m| [m.delete('~')].pack('H*').force_encoding('UTF-8') }.scrub('')
    end

    # Sets defined by DINI rather than built from facets.
    def static_sets
      @static_sets ||= { OPEN_ACCESS => open_access_set }.merge(doc_type_sets).merge(ddc_sets)
    end

    private

    def open_access_set
      field = ACCESS_RIGHTS_SIM_FIELD
      {
        name: 'Open Access',
        # The string field, as a "" value counts as present in the _tesim field.
        filter: %(((*:* -#{field}:[* TO *]) OR #{field}:"")),
        description: 'This is a set containing all the open access records (those with no access rights restrictions recorded).'
      }
    end

    def doc_type_sets
      types = Ethos::Dini::DOC_TYPES
      sets = types.each_with_object({}) do |(level, type), hash|
        hash["doc-type:#{type}"] = {
          name: type, filter: %(#{Ethos::Dini::QUALIFICATION_LEVEL_FIELD}:"#{level}"),
          description: "This is a set containing records of type #{type}."
        }
      end
      all_types = types.keys.map { |level| %("#{level}") }.join(' OR ')
      parent = { name: 'Document types', filter: "#{Ethos::Dini::QUALIFICATION_LEVEL_FIELD}:(#{all_types})",
                 description: 'This is a set containing all records with a document type.' }
      { 'doc-type' => parent }.merge(sets)
    end

    def ddc_sets
      sets = Ethos::Dini::DDC_GROUPS.each_with_object({}) do |(group, name), hash|
        hash["ddc:#{group}"] = {
          name: name, filter: Ethos::Dini.ddc_filter(group),
          description: "This is a set containing records in DDC subject group #{group}."
        }
      end
      parent = { name: 'Dewey Decimal Classification', filter: "#{Ethos::Dini::DDC_FIELD}:?*",
                 description: 'This is a set containing all records with a DDC subject group.' }
      { 'ddc' => parent }.merge(sets)
    end

    def static_specs_for(record)
      levels = record.fetch(Ethos::Dini::QUALIFICATION_LEVEL_FIELD, [])
      groups = Ethos::Dini.ddc_groups(record.fetch('dewey_tesim', []))
      doc_types = Ethos::Dini.doc_types(levels).map { |type| "doc-type:#{type}" }
      ddc = groups.map { |group| "ddc:#{group}" }

      specs = open_access?(record) ? [OPEN_ACCESS] : []
      specs += ['doc-type'] + doc_types if doc_types.any?
      specs += ['ddc'] + ddc if ddc.any?
      specs
    end

    def open_access?(record)
      Array.wrap(record.fetch(ACCESS_RIGHTS_FIELD, [])).all?(&:blank?)
    end
  end

  # Takes an encoded spec, so always build one with build_spec. Static sets have no
  # facet behind them, so they skip the parent's label:value and set_fields checks.
  def initialize(spec)
    if self.class.static_sets.key?(spec)
      @label = spec
      @static = self.class.static_sets[spec]
    else
      super(self.class.decode(spec))
    end
  end

  def spec
    @static ? label : self.class.build_spec(label, value)
  end

  def solr_filter
    @static ? @static[:filter] : super
  end

  # Override and offer translation of an authority id into a term if possible
  def name
    return @static[:name] if @static
    return "#{label.titleize}: #{Hyrax::CurrentHeInstitutionsService.label(value)}" if label == "University"

    "#{label}:#{value}".titleize.gsub(':', ': ')
  end

  def description
    @static ? @static[:description] : "This is a #{label} set containing records with the value of #{value}."
  end
end
