# frozen_string_literal: true

module Ethos
  # Vocabulary and mappings for the DINI Certificate 2022 ruleset used by validator.dini.de.
  module Dini
    DDC_FIELD = 'dewey_sim'
    QUALIFICATION_LEVEL_FIELD = 'qualification_level_tesim'

    # Table 1. Full Dewey numbers are mapped onto these groups, not used as sets.
    DDC_GROUPS = {
      '000' => 'Generalities, science', '004' => 'Data processing, computer science',
      '010' => 'Bibliography', '020' => 'Library & information sciences',
      '030' => 'General encyclopedic works', '050' => 'General serials & their indexes',
      '060' => 'General organization & museology', '070' => 'News media, journalism, publishing',
      '080' => 'General collections', '090' => 'Manuscripts & rare books',
      '100' => 'Philosophy', '130' => 'Paranormal phenomena', '150' => 'Psychology',
      '200' => 'Religion', '220' => 'Bible', '230' => 'Christian theology',
      '290' => 'Other & comparative religions', '300' => 'Social sciences',
      '310' => 'General statistics', '320' => 'Political science', '330' => 'Economics',
      '333.7' => 'Natural resources, energy and environment', '340' => 'Law',
      '350' => 'Public administration', '355' => 'Military science',
      '360' => 'Social services, association', '370' => 'Education',
      '380' => 'Commerce, communications, transport', '390' => 'Customs, etiquette, folklore',
      '400' => 'Language, linguistics', '420' => 'English', '430' => 'Germanic',
      '439' => 'Other Germanic languages', '440' => 'Romance languages, French',
      '450' => 'Italian, Romanian, Rhaeto-Romanic', '460' => 'Spanish & Portuguese languages',
      '470' => 'Italic, Latin', '480' => 'Hellenic languages, Classical Greek',
      '490' => 'Other languages', '491.8' => 'Slavic languages',
      '500' => 'Natural sciences & mathematics', '510' => 'Mathematics',
      '520' => 'Astronomy & allied sciences', '530' => 'Physics',
      '540' => 'Chemistry & allied sciences', '550' => 'Earth sciences',
      '560' => 'Paleontology, paleozoology', '570' => 'Life sciences',
      '580' => 'Botanical sciences', '590' => 'Zoological sciences',
      '600' => 'Technology (Applied sciences)', '610' => 'Medical sciences, medicine',
      '620' => 'Engineering & allied operations', '621.3' => 'Electric engineering',
      '624' => 'Civil engineering', '630' => 'Agriculture',
      '640' => 'Home economics & family living', '650' => 'Management & auxiliary services',
      '660' => 'Chemical engineering', '670' => 'Manufacturing', '690' => 'Buildings',
      '700' => 'The arts', '710' => 'Civic & landscape art', '720' => 'Architecture',
      '730' => 'Plastic arts, sculpture', '740' => 'Drawing & decorative arts',
      '741.5' => 'Comics, cartoons', '750' => 'Painting & paintings',
      '760' => 'Graphic arts, printmaking & prints', '770' => 'Photography & photographs',
      '780' => 'Music', '790' => 'Recreational & performing arts',
      '791' => 'Public performances', '792' => 'Stage presentations',
      '793' => 'Indoor games & amusements', '796' => 'Athletic & outdoor sports & games',
      '800' => 'Literature & rhetoric', '810' => 'American literature in English',
      '820' => 'English & Old English literatures', '830' => 'Literatures of Germanic languages',
      '839' => 'Other Germanic literatures', '840' => 'Literatures of Romance languages',
      '850' => 'Italian, Romanian, Rhaeto-Romanic literatures',
      '860' => 'Spanish & Portuguese literatures', '870' => 'Italic literatures, Latin',
      '880' => 'Hellenic literatures, Classical Greek', '890' => 'Literatures of other languages',
      '891.8' => 'Slavic literatures', '900' => 'Geography & history',
      '910' => 'Geography & travel', '914.3' => 'Geography & travel, Germany',
      '920' => 'Biography, genealogy, insignia', '930' => 'History of the ancient world',
      '940' => 'General history of Europe', '943' => 'General history of Europe, Central Europe, Germany',
      '950' => 'General history of Asia, Far East', '960' => 'General history of Africa',
      '970' => 'General history of North America', '980' => 'General history of South America',
      '990' => 'General history of other areas'
    }.freeze

    # Numbers that belong to a group other than their own tens or hundreds, following
    # the DNB subject groups the table is based on.
    DDC_EXCEPTIONS = {
      '491.7' => '491.8', '891.7' => '891.8',
      '005' => '004', '006' => '004', '333.8' => '333.7', '333.9' => '333.7',
      '356' => '355', '357' => '355', '358' => '355', '359' => '355',
      '794' => '793', '795' => '793', '797' => '796', '798' => '796', '799' => '796'
    }.merge((240..289).to_h { |n| [n.to_s, '230'] })
                      .merge((680..689).to_h { |n| [n.to_s, '670'] }).freeze

    # Three-digit numbers with a decimal group need matching one decimal place deeper.
    DDC_SPLIT_NUMBERS = %w[333 491 621 741 891 914].freeze

    # Table 2, keyed by the qualification level authority id.
    DOC_TYPES = { 'Doctoral' => 'PhDThesis', 'Masters' => 'MasterThesis' }.freeze
    COAR_TYPES = {
      'Doctoral' => ['doctoral thesis', 'http://purl.org/coar/resource_type/c_db06'],
      'Masters' => ['master thesis', 'http://purl.org/coar/resource_type/c_bdcc']
    }.freeze

    # ISO 639-2/B codes that differ from ISO 639-3.
    ISO_639_3 = {
      'alb' => 'sqi', 'arm' => 'hye', 'baq' => 'eus', 'bur' => 'mya', 'chi' => 'zho',
      'cze' => 'ces', 'dut' => 'nld', 'fre' => 'fra', 'geo' => 'kat', 'ger' => 'deu',
      'gre' => 'ell', 'ice' => 'isl', 'mac' => 'mkd', 'mao' => 'mri', 'may' => 'msa',
      'per' => 'fas', 'rum' => 'ron', 'slo' => 'slk', 'tib' => 'bod', 'wel' => 'cym'
    }.freeze

    class << self
      # @return [String, nil] the Table 1 key for a Dewey number
      def ddc_group(dewey)
        match = /\A\s*(\d{3})(?:\.(\d))?/.match(dewey.to_s)
        return unless match

        number = match[1]
        decimal = "#{number}.#{match[2]}"
        [decimal, number, "#{number[0, 2]}0", "#{number[0]}00"].each do |key|
          return DDC_EXCEPTIONS[key] if DDC_EXCEPTIONS.key?(key)
          return key if DDC_GROUPS.key?(key)
        end
        nil
      end

      def ddc_groups(deweys)
        Array(deweys).map { |dewey| ddc_group(dewey) }.compact.uniq
      end

      # Uses positive terms only, so a record in two groups is returned for both.
      def ddc_filter(group)
        "#{DDC_FIELD}:(#{ddc_terms.fetch(group).join(' OR ')})"
      end

      def doc_types(levels)
        Array(levels).map { |level| DOC_TYPES[level] }.compact.uniq
      end

      def coar_types(levels)
        Array(levels).flat_map { |level| COAR_TYPES.fetch(level, []) }.uniq
      end

      def iso_639_3(code)
        ISO_639_3.fetch(code.to_s.strip.downcase, code)
      end

      private

      def ddc_terms
        @ddc_terms ||= (0..999).each_with_object(Hash.new { |h, k| h[k] = [] }) do |n, terms|
          number = format('%03d', n)
          if DDC_SPLIT_NUMBERS.include?(number)
            terms[ddc_group(number)] << number
            (0..9).each { |digit| terms[ddc_group("#{number}.#{digit}")] << "#{number}.#{digit}*" }
          else
            terms[ddc_group(number)] << "#{number}*"
          end
        end
      end
    end
  end
end
