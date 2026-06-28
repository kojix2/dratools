# frozen_string_literal: true

require 'json'

require_relative 'base_command'

module Dratools
  module Commands
    # DDBJ Search entry JSON のメタ情報を要約表示する。
    class MetaCommand < BaseCommand
      LABEL_WIDTH = 18

      private

      def command_name
        'meta'
      end

      def default_options
        super.merge(json: false)
      end

      def configure_parser(parser)
        parser.on('--json', '生の entry JSON を整形して表示する') { @options[:json] = true }
      end

      def usage_examples
        [
          "#{Dratools::NAME} meta DRR300000",
          "#{Dratools::NAME} meta --json DRR300000"
        ]
      end

      def process(accession)
        record = @resolver.fetch_record_for(accession)
        if @options[:json]
          json_buffer << record
          return
        end

        print_summary(accession, record)
      end

      def finalize
        return unless @options[:json]

        payload = json_buffer.length == 1 ? json_buffer.first : json_buffer
        @stdout.puts JSON.pretty_generate(payload)
      end

      def json_buffer
        @json_buffer ||= []
      end

      def print_summary(accession, record)
        summary_pairs(record).each { |label, value| print_field(label, value) }
        run_count = run_count_for(accession, record)
        print_field('runs', run_count) if run_count
      end

      def summary_pairs(record)
        DdbjRecordFields::INFO_FIELD_KEYS.filter_map do |key|
          value = normalized_value(record_value(record, key))
          next if value.nil?

          [field_label(key), value]
        end
      end

      def record_value(record, key)
        return record[key] unless key == DdbjRecordFields::IDENTIFIER_KEY

        record[DdbjRecordFields::IDENTIFIER_KEY] || record[DdbjRecordFields::ACCESSION_KEY]
      end

      def normalized_value(value)
        case value
        when Array
          values = value.map { |item| normalized_value(item) }.compact
          values.empty? ? nil : values.join(', ')
        when Hash
          compact_hash = value.reject { |_key, item| blank?(item) }
          compact_hash.empty? ? nil : normalized_hash_value(compact_hash)
        else
          normalized_scalar_value(value)
        end
      end

      def normalized_scalar_value(value)
        return nil if blank?(value)

        value.to_s.gsub(/[[:space:]]+/, ' ').strip
      end

      def normalized_hash_value(value)
        name = value['name'] || value[:name]
        blank?(name) ? value.values.join(', ') : name
      end

      def run_count_for(accession, record)
        case record[DdbjRecordFields::TYPE_KEY]
        when DdbjRecordFields::SRA_RUN_RESOURCE_TYPE
          1
        when DdbjRecordFields::SRA_EXPERIMENT_RESOURCE_TYPE
          tree = @resolver.resolve_tree(accession, file_type: @options[:file_type])
          tree.run_accessions.uniq.length
        end
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      def field_label(key)
        key == DdbjRecordFields::IDENTIFIER_KEY ? 'accession' : key
      end

      def print_field(label, value)
        @stdout.puts format("%-#{LABEL_WIDTH}s %s", "#{label}:", value)
      end
    end
  end
end
