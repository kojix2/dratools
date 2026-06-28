# frozen_string_literal: true

require 'stringio'

require_relative 'test_helper'

class ProgressReporterTest < Minitest::Test
  def test_reports_nothing_when_disabled
    io = StringIO.new
    reporter = Dratools::ProgressReporter.new(io: io, enabled: false)

    reporter.report('fetching sra-run DRR000001')
    reporter.finish

    assert_empty io.string
  end

  def test_writes_and_counts_when_enabled
    io = StringIO.new
    reporter = Dratools::ProgressReporter.new(io: io, enabled: true)

    reporter.report('fetching sra-run DRR000001')
    reporter.report('linking bioproject PRJDB12740')

    assert_includes io.string, 'fetching sra-run DRR000001 (1)'
    assert_includes io.string, 'linking bioproject PRJDB12740 (2)'
  end

  def test_finish_clears_the_active_line
    io = StringIO.new
    reporter = Dratools::ProgressReporter.new(io: io, enabled: true)

    reporter.report('fetching sra-run DRR000001')
    reporter.finish

    assert io.string.end_with?(Dratools::ProgressReporter::CLEAR_LINE)
  end

  def test_finish_without_report_writes_nothing
    io = StringIO.new
    reporter = Dratools::ProgressReporter.new(io: io, enabled: true)

    reporter.finish

    assert_empty io.string
  end

  def test_clearing_io_clears_active_progress_before_writing
    io = StringIO.new
    reporter = Dratools::ProgressReporter.new(io: io, enabled: true)

    reporter.report('fetching sra-run DRR000001')
    reporter.clearing_io.puts('dratools url: error')

    assert_includes io.string, "#{Dratools::ProgressReporter::CLEAR_LINE}dratools url: error\n"
  end

  def test_clearing_io_can_write_to_a_different_output
    progress_io = StringIO.new
    output_io = StringIO.new
    reporter = Dratools::ProgressReporter.new(io: progress_io, enabled: true)

    reporter.report('fetching sra-run DRR000001')
    reporter.clearing_io(output_io).puts('https://example.test/DRR000001.sra')

    assert_equal "https://example.test/DRR000001.sra\n", output_io.string
    assert progress_io.string.end_with?(Dratools::ProgressReporter::CLEAR_LINE)
  end

  def test_defaults_to_disabled_for_non_tty
    io = StringIO.new

    reporter = Dratools::ProgressReporter.new(io: io)

    reporter.report('fetching sra-run DRR000001')
    assert_empty io.string
  end
end
