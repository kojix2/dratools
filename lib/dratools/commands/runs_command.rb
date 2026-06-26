# frozen_string_literal: true

require_relative 'base_command'

module Dratools
  module Commands
    # accession を run accession のフラットな一覧に展開する。
    class RunsCommand < BaseCommand
      XREF_URL_PATTERN = %r{/(?:resource|search/entry)/sra-run/([^/?#.]+)}

      private

      def command_name
        'runs'
      end

      def usage_examples
        [
          "#{Dratools::NAME} runs PRJNA341783",
          "#{Dratools::NAME} runs PRJNA341783 | #{Dratools::NAME} get -O ~/Downloads"
        ]
      end

      def process(accession)
        direct_runs = direct_run_accessions_for(accession)
        if direct_runs.any?
          run_accessions.concat(direct_runs)
          return
        end

        tree = @resolver.resolve_tree(accession, file_type: @options[:file_type])
        run_accessions.concat(tree.run_accessions)
      end

      def finalize
        run_accessions.uniq.each { |run_accession| @stdout.puts run_accession }
      end

      def run_accessions
        @run_accessions ||= []
      end

      def direct_run_accessions_for(accession)
        record = @resolver.fetch_record_for(accession)
        if record[DdbjRecordFields::TYPE_KEY] == DdbjRecordFields::SRA_RUN_RESOURCE_TYPE
          return [record_accession(record)].compact
        end

        record.fetch(DdbjRecordFields::DB_XREFS_KEY, []).filter_map do |xref|
          next unless xref[DdbjRecordFields::TYPE_KEY] == DdbjRecordFields::SRA_RUN_RESOURCE_TYPE

          xref[DdbjRecordFields::IDENTIFIER_KEY] ||
            xref[DdbjRecordFields::ID_KEY] ||
            run_accession_from_url(xref[DdbjRecordFields::URL_KEY])
        end
      end

      def record_accession(record)
        record[DdbjRecordFields::ACCESSION_KEY] ||
          record[DdbjRecordFields::IDENTIFIER_KEY] ||
          record[DdbjRecordFields::ID_KEY] ||
          record[DdbjRecordFields::PRIMARY_ID_KEY]
      end

      def run_accession_from_url(url)
        url.to_s.match(XREF_URL_PATTERN)&.[](1)
      end
    end
  end
end
