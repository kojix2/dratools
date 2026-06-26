# frozen_string_literal: true

module Dratools
  # DDBJ Search resource JSON で使う resource type とキー名をまとめる。
  module DdbjRecordFields
    SRA_RUN_RESOURCE_TYPE = 'sra-run'
    SRA_EXPERIMENT_RESOURCE_TYPE = 'sra-experiment'
    SRA_SAMPLE_RESOURCE_TYPE = 'sra-sample'
    SRA_STUDY_RESOURCE_TYPE = 'sra-study'
    SRA_SUBMISSION_RESOURCE_TYPE = 'sra-submission'
    BIOPROJECT_RESOURCE_TYPE = 'bioproject'
    BIOSAMPLE_RESOURCE_TYPE = 'biosample'

    FILE_TYPE_SRA = 'sra'
    FILE_TYPE_FASTQ = 'fastq'
    FILE_TYPE_ALL = 'all'

    DB_XREFS_KEY = 'dbXrefs'
    CHILD_BIOPROJECTS_KEY = 'childBioProjects'
    TYPE_KEY = 'type'
    URL_KEY = 'url'
    FTP_URL_KEY = 'ftpUrl'
    ID_KEY = 'id'
    IDENTIFIER_KEY = 'identifier'
    ACCESSION_KEY = 'accession'
    PRIMARY_ID_KEY = 'primaryId'
    DOWNLOAD_URL_KEY = 'downloadUrl'
    DISTRIBUTION_KEY = 'distribution'
    CONTENT_URL_KEY = 'contentUrl'
    CONTENT_SIZE_KEY = 'contentSize'
    SIZE_KEY = 'size'
    FILE_SIZE_KEY = 'fileSize'
    MD5_KEY = 'md5'
    MD5_SUM_KEY = 'md5sum'
    ENCODING_FORMAT_KEY = 'encodingFormat'

    INFO_FIELD_KEYS = [
      IDENTIFIER_KEY,
      TYPE_KEY,
      'title',
      'description',
      'organism',
      'platform',
      'instrumentModel',
      'libraryStrategy',
      'librarySource',
      'librarySelection',
      'libraryLayout',
      'libraryName',
      'dateCreated',
      'dateModified',
      'datePublished',
      'status'
    ].freeze
  end
end
