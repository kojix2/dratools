# frozen_string_literal: true

require_relative 'errors'

module Dratools
  # 引数・ファイル・標準入力からアクセッションを集める。
  class AccessionInputCollector
    STANDARD_INPUT_PATH = '-'
    MISSING_ACCESSION_ARGUMENT = 'ACCESSION'
    INPUT_OPTION_NAME = '--input'

    def initialize(argv:, input_path: nil, stdin: $stdin)
      @argv = argv
      @input_path = input_path
      @stdin = stdin
    end

    def collect_accessions
      accessions = (positional_accessions + streamed_accessions).uniq
      raise MissingAccessionError, "#{MISSING_ACCESSION_ARGUMENT} is required" if accessions.empty?

      accessions
    end

    private

    def positional_accessions
      @argv.map { |value| normalize_accession(value) }.reject(&:empty?)
    end

    def streamed_accessions
      return parse_accessions(@stdin.read) if @input_path == STANDARD_INPUT_PATH
      return parse_accessions(File.read(@input_path)) if @input_path
      return [] if stdin_tty?

      parse_accessions(@stdin.read)
    rescue SystemCallError => error
      raise InputFileError, "#{INPUT_OPTION_NAME}: #{error.message}"
    end

    def parse_accessions(content)
      content.each_line.map { |value| normalize_accession(value) }.reject(&:empty?)
    end

    def normalize_accession(value)
      value.to_s.strip.upcase
    end

    def stdin_tty?
      @stdin.respond_to?(:tty?) && @stdin.tty?
    end
  end
end
