# frozen_string_literal: true

require_relative 'test_helper'

class AccessionResourceTypeClassifierTest < Minitest::Test
  def setup
    @classifier = Dratools::AccessionResourceTypeClassifier.new
  end

  def test_classifies_supported_sra_accession_prefixes
    {
      'DRR000001' => 'sra-run',
      'ERR000001' => 'sra-run',
      'SRR000001' => 'sra-run',
      'DRX000001' => 'sra-experiment',
      'ERX000001' => 'sra-experiment',
      'SRX000001' => 'sra-experiment',
      'DRS000001' => 'sra-sample',
      'ERS000001' => 'sra-sample',
      'SRS000001' => 'sra-sample',
      'DRP000001' => 'sra-study',
      'ERP000001' => 'sra-study',
      'SRP000001' => 'sra-study',
      'DRA000001' => 'sra-submission',
      'ERA000001' => 'sra-submission',
      'SRA000001' => 'sra-submission'
    }.each do |accession, resource_type|
      assert_equal resource_type, @classifier.resource_type_for(accession), accession
    end
  end

  def test_classifies_supported_bioproject_and_biosample_prefixes
    {
      'PRJDA000001' => 'bioproject',
      'PRJDB000001' => 'bioproject',
      'PRJEB000001' => 'bioproject',
      'PRJNA000001' => 'bioproject',
      'SAMD000001' => 'biosample',
      'SAMN000001' => 'biosample',
      'SAMEA000001' => 'biosample',
      'SAMEG000001' => 'biosample'
    }.each do |accession, resource_type|
      assert_equal resource_type, @classifier.resource_type_for(accession), accession
    end
  end

  def test_rejects_unsupported_accession_prefixes
    assert_raises(Dratools::UnsupportedAccessionError) do
      @classifier.resource_type_for('XYZ000001')
    end
  end
end
