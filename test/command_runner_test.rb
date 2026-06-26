# frozen_string_literal: true

require_relative "test_helper"

class CommandRunnerTest < Minitest::Test
  class FakeRunner < Ddbj::Get::CommandRunner
    attr_reader :commands

    def initialize
      super(preferred: "curl")
      @commands = []
    end

    def available
      "curl"
    end

    private

    def run(command)
      @commands << command
      true
    end
  end

  def test_probe_uses_curl_range_and_timeout
    runner = FakeRunner.new

    assert runner.probe("https://example.test/run.sra", timeout: 3)
    command = runner.commands.first
    assert_includes command, "--range"
    assert_includes command, "0-0"
    assert_includes command, "--max-time"
    assert_includes command, "3"
  end
end
