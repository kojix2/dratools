# frozen_string_literal: true

require_relative 'ddbj_record_fields'
require_relative 'errors'

module Dratools
  # accession の接頭辞から DDBJ resource API の type を判定する。
  class AccessionResourceTypeClassifier
    RUN_PREFIXES = /\A[DES]RR\d+\z/
    EXPERIMENT_PREFIXES = /\A[DES]RX\d+\z/
    SAMPLE_PREFIXES = /\A[DES]RS\d+\z/
    STUDY_PREFIXES = /\A[DES]RP\d+\z/
    SUBMISSION_PREFIXES = /\A[DES]RA\d+\z/
    BIOPROJECT_PREFIXES = /\APRJ[DEN][A-Z]\d+\z/
    BIOSAMPLE_PREFIXES = /\ASAM(?:D|N|EA|EG)?\d+\z/

    TYPE_BY_ACCESSION = [
      [RUN_PREFIXES, DdbjRecordFields::SRA_RUN_RESOURCE_TYPE],
      [EXPERIMENT_PREFIXES, DdbjRecordFields::SRA_EXPERIMENT_RESOURCE_TYPE],
      [SAMPLE_PREFIXES, DdbjRecordFields::SRA_SAMPLE_RESOURCE_TYPE],
      [STUDY_PREFIXES, DdbjRecordFields::SRA_STUDY_RESOURCE_TYPE],
      [SUBMISSION_PREFIXES, DdbjRecordFields::SRA_SUBMISSION_RESOURCE_TYPE],
      [BIOPROJECT_PREFIXES, DdbjRecordFields::BIOPROJECT_RESOURCE_TYPE],
      [BIOSAMPLE_PREFIXES, DdbjRecordFields::BIOSAMPLE_RESOURCE_TYPE]
    ].freeze

    def resource_type_for(accession)
      matching_rule = TYPE_BY_ACCESSION.find { |pattern, _resource_type| pattern.match?(accession) }
      raise UnsupportedAccessionError, "unsupported accession: #{accession}" unless matching_rule

      matching_rule.last
    end
  end
end
