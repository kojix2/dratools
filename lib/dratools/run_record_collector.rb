# frozen_string_literal: true

require 'set'

require_relative 'config'
require_relative 'ddbj_record_fields'
require_relative 'errors'
require_relative 'traversal_node'

module Dratools
  # BioProject などの上位レコードから DDBJ sra-run レコードを集める。
  class RunRecordCollector
    TRAVERSABLE_XREF_TYPES = [
      DdbjRecordFields::SRA_RUN_RESOURCE_TYPE,
      DdbjRecordFields::SRA_EXPERIMENT_RESOURCE_TYPE,
      DdbjRecordFields::SRA_SAMPLE_RESOURCE_TYPE,
      DdbjRecordFields::SRA_STUDY_RESOURCE_TYPE,
      DdbjRecordFields::SRA_SUBMISSION_RESOURCE_TYPE,
      DdbjRecordFields::BIOPROJECT_RESOURCE_TYPE,
      DdbjRecordFields::BIOSAMPLE_RESOURCE_TYPE
    ].freeze
    def initialize(client:)
      @client = client
    end

    def collect_run_records(ddbj_record, seen_keys = Set.new)
      explore(ddbj_record, seen_keys: seen_keys).run_records
    end

    def explore(ddbj_record, seen_keys: Set.new, relation: TraversalNode::ROOT_RELATION,
                tolerant: false, direct_run_fetch_limit: nil)
      node = node_from_record(ddbj_record, relation: relation)
      return node if run_record?(ddbj_record)

      xrefs = ddbj_record.fetch(DdbjRecordFields::DB_XREFS_KEY, [])
      run_xrefs = xrefs.select { |xref| sra_run_xref?(xref) }
      if (lightweight_children = lightweight_direct_run_nodes(run_xrefs, direct_run_fetch_limit))
        node.children.concat(lightweight_children)
        return node
      end

      direct_children = explore_run_xrefs(
        run_xrefs,
        seen_keys,
        tolerant: tolerant,
        direct_run_fetch_limit: direct_run_fetch_limit
      )
      if direct_children.any? { |child| child.run? || child.run_records.any? }
        node.children.concat(direct_children)
        return node
      end

      node.children.concat(
        recursive_children(ddbj_record, xrefs, seen_keys, tolerant, direct_run_fetch_limit)
      )
      node
    end

    private

    def recursive_children(ddbj_record, xrefs, seen_keys, tolerant, direct_run_fetch_limit)
      recursive_xrefs = xrefs.select { |xref| traversable_xref?(xref) }
      validate_recursive_non_run_xref_count!(ddbj_record, recursive_xrefs)
      db_xref_edges = explore_edges(
        recursive_xrefs,
        TraversalNode::DB_XREF_RELATION,
        seen_keys,
        tolerant: tolerant,
        direct_run_fetch_limit: direct_run_fetch_limit
      )
      child_edges = explore_edges(
        child_bioprojects(ddbj_record),
        TraversalNode::CHILD_BIOPROJECT_RELATION,
        seen_keys,
        tolerant: tolerant,
        direct_run_fetch_limit: direct_run_fetch_limit
      )
      db_xref_edges + child_edges
    end

    def lightweight_direct_run_nodes(run_xrefs, direct_run_fetch_limit)
      return nil unless direct_run_fetch_limit && run_xrefs.length > direct_run_fetch_limit

      run_xrefs.map { |xref| node_from_xref(xref, relation: TraversalNode::DB_XREF_RELATION) }
    end

    def validate_recursive_non_run_xref_count!(ddbj_record, xrefs)
      max_xrefs = Config.max_recursive_non_run_xrefs
      return unless max_xrefs

      non_run_xrefs = xrefs.reject { |xref| sra_run_xref?(xref) }
      return if non_run_xrefs.length <= max_xrefs

      accession = record_accession(ddbj_record) || 'record'
      raise InvalidRecordError,
            "#{accession} has #{non_run_xrefs.length} linked non-run records; " \
            'refine to an experiment/sample accession before run expansion, ' \
            "or set #{Config::MAX_RECURSIVE_NON_RUN_XREFS_ENV}=unlimited"
    end

    def child_bioprojects(ddbj_record)
      ddbj_record.fetch(DdbjRecordFields::CHILD_BIOPROJECTS_KEY, [])
    end

    def explore_edges(xrefs, relation, seen_keys, tolerant:, direct_run_fetch_limit:)
      xrefs.each_with_object([]) do |xref, children|
        next unless traversable_xref?(xref)

        reference_key = xref_key(xref)
        next if reference_key.empty? || seen_keys.include?(reference_key)

        seen_keys.add(reference_key)
        children << explore_xref(
          xref,
          relation,
          seen_keys,
          tolerant: tolerant,
          direct_run_fetch_limit: direct_run_fetch_limit
        )
      end
    end

    def explore_run_xrefs(run_xrefs, seen_keys, tolerant:, direct_run_fetch_limit:)
      fetchable_xrefs = unseen_fetchable_xrefs(run_xrefs, seen_keys)
      return [] if fetchable_xrefs.empty?

      accessions = fetchable_xrefs.map { |xref| xref_accession(xref) }
      records = @client.fetch_resource_records_bulk(
        DdbjRecordFields::SRA_RUN_RESOURCE_TYPE,
        accessions,
        include_db_xrefs: false
      )
      fetchable_xrefs.map do |xref|
        accession = xref_accession(xref)
        if (record = records[accession])
          explore(
            record,
            seen_keys: seen_keys,
            relation: TraversalNode::DB_XREF_RELATION,
            tolerant: tolerant,
            direct_run_fetch_limit: direct_run_fetch_limit
          )
        elsif tolerant
          node_from_xref(
            xref,
            relation: TraversalNode::DB_XREF_RELATION,
            error: "not found: #{accession}"
          )
        else
          raise NotFoundError, "not found: sra-run/#{accession}"
        end
      end
    end

    def unseen_fetchable_xrefs(xrefs, seen_keys)
      xrefs.each_with_object([]) do |xref, selected|
        next unless traversable_xref?(xref)

        accession = xref_accession(xref)
        next if accession.empty?

        reference_key = xref_key(xref)
        next if reference_key.empty? || seen_keys.include?(reference_key)

        seen_keys.add(reference_key)
        selected << xref
      end
    end

    def explore_xref(xref, relation, seen_keys, tolerant:, direct_run_fetch_limit:)
      linked_record = fetch_xref_record(xref)
      explore(
        linked_record,
        seen_keys: seen_keys,
        relation: relation,
        tolerant: tolerant,
        direct_run_fetch_limit: direct_run_fetch_limit
      )
    rescue Error => error
      raise unless tolerant

      node_from_xref(xref, relation: relation, error: error.message)
    end

    def xref_key(xref)
      xref_accession(xref)
    end

    def xref_accession(xref)
      (xref[DdbjRecordFields::ID_KEY] || xref[DdbjRecordFields::IDENTIFIER_KEY]).to_s
    end

    def fetch_xref_record(xref)
      raise InvalidRecordError, 'xref has no identifier' if xref_accession(xref).empty?

      fetch_xref_by_identifier(xref)
    end

    def fetch_xref_by_identifier(xref)
      @client.fetch_resource_record(
        xref[DdbjRecordFields::TYPE_KEY],
        xref[DdbjRecordFields::ID_KEY] || xref[DdbjRecordFields::IDENTIFIER_KEY]
      )
    end

    def sra_run_xref?(xref)
      xref[DdbjRecordFields::TYPE_KEY] == DdbjRecordFields::SRA_RUN_RESOURCE_TYPE
    end

    def traversable_xref?(xref)
      TRAVERSABLE_XREF_TYPES.include?(xref[DdbjRecordFields::TYPE_KEY])
    end

    def run_record?(ddbj_record)
      record_type = ddbj_record[DdbjRecordFields::TYPE_KEY]
      record_type == DdbjRecordFields::SRA_RUN_RESOURCE_TYPE
    end

    def node_from_record(ddbj_record, relation:)
      TraversalNode.new(
        relation: relation,
        type: ddbj_record[DdbjRecordFields::TYPE_KEY],
        accession: record_accession(ddbj_record),
        object_type: ddbj_record['objectType'],
        record: run_record?(ddbj_record) ? ddbj_record : nil
      )
    end

    def node_from_xref(xref, relation:, error: nil)
      TraversalNode.new(
        relation: relation,
        type: xref[DdbjRecordFields::TYPE_KEY],
        accession: xref[DdbjRecordFields::ID_KEY] || xref[DdbjRecordFields::IDENTIFIER_KEY],
        error: error
      )
    end

    def record_accession(ddbj_record)
      ddbj_record[DdbjRecordFields::ACCESSION_KEY] ||
        ddbj_record[DdbjRecordFields::IDENTIFIER_KEY] ||
        ddbj_record[DdbjRecordFields::ID_KEY] ||
        ddbj_record[DdbjRecordFields::PRIMARY_ID_KEY]
    end
  end
end
