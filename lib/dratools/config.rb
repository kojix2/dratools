# frozen_string_literal: true

require_relative 'errors'

module Dratools
  # Reads advanced configuration from environment variables.
  module Config
    MAX_RECURSIVE_NON_RUN_XREFS_ENV = 'DRATOOLS_MAX_RECURSIVE_NON_RUN_XREFS'
    TREE_MAX_DIRECT_RUNS_ENV = 'DRATOOLS_TREE_MAX_DIRECT_RUNS'
    URL_MAX_DIRECT_RUNS_ENV = 'DRATOOLS_URL_MAX_DIRECT_RUNS'
    SIZE_MAX_DIRECT_RUNS_ENV = 'DRATOOLS_SIZE_MAX_DIRECT_RUNS'
    DOWNLOAD_CONNECT_TIMEOUT_ENV = 'DRATOOLS_DOWNLOAD_CONNECT_TIMEOUT'
    DOWNLOAD_STALL_TIMEOUT_ENV = 'DRATOOLS_DOWNLOAD_STALL_TIMEOUT'
    DOWNLOAD_STALL_SPEED_ENV = 'DRATOOLS_DOWNLOAD_STALL_SPEED'
    DOWNLOAD_RETRY_COUNT_ENV = 'DRATOOLS_DOWNLOAD_RETRY_COUNT'
    DOWNLOAD_RETRY_WAIT_ENV = 'DRATOOLS_DOWNLOAD_RETRY_WAIT'
    DOWNLOAD_COMMAND_ENV = 'DRATOOLS_DOWNLOAD_COMMAND'

    DEFAULT_MAX_RECURSIVE_NON_RUN_XREFS = 100
    DEFAULT_TREE_MAX_DIRECT_RUNS = 50
    DEFAULT_URL_MAX_DIRECT_RUNS = 50
    DEFAULT_SIZE_MAX_DIRECT_RUNS = 50
    DEFAULT_DOWNLOAD_CONNECT_TIMEOUT_SECONDS = 30
    DEFAULT_DOWNLOAD_STALL_TIMEOUT_SECONDS = 60
    DEFAULT_DOWNLOAD_STALL_SPEED_BYTES_PER_SECOND = 1024
    DEFAULT_DOWNLOAD_RETRY_COUNT = 3
    DEFAULT_DOWNLOAD_RETRY_WAIT_SECONDS = 5
    SUPPORTED_DOWNLOAD_COMMANDS = %w[curl wget aria2c].freeze
    UNLIMITED_VALUE = 'unlimited'

    module_function

    def max_recursive_non_run_xrefs
      positive_integer_or_unlimited(
        MAX_RECURSIVE_NON_RUN_XREFS_ENV,
        DEFAULT_MAX_RECURSIVE_NON_RUN_XREFS
      )
    end

    def tree_max_direct_runs
      positive_integer_or_unlimited(
        TREE_MAX_DIRECT_RUNS_ENV,
        DEFAULT_TREE_MAX_DIRECT_RUNS
      )
    end

    def url_max_direct_runs
      positive_integer_or_unlimited(URL_MAX_DIRECT_RUNS_ENV, DEFAULT_URL_MAX_DIRECT_RUNS)
    end

    def size_max_direct_runs
      positive_integer_or_unlimited(SIZE_MAX_DIRECT_RUNS_ENV, DEFAULT_SIZE_MAX_DIRECT_RUNS)
    end

    def download_connect_timeout_seconds
      positive_integer(DOWNLOAD_CONNECT_TIMEOUT_ENV, DEFAULT_DOWNLOAD_CONNECT_TIMEOUT_SECONDS)
    end

    def download_stall_timeout_seconds
      positive_integer(DOWNLOAD_STALL_TIMEOUT_ENV, DEFAULT_DOWNLOAD_STALL_TIMEOUT_SECONDS)
    end

    def download_stall_speed_bytes_per_second
      positive_integer(DOWNLOAD_STALL_SPEED_ENV, DEFAULT_DOWNLOAD_STALL_SPEED_BYTES_PER_SECOND)
    end

    def download_retry_count
      non_negative_integer(DOWNLOAD_RETRY_COUNT_ENV, DEFAULT_DOWNLOAD_RETRY_COUNT)
    end

    def download_retry_wait_seconds
      positive_integer(DOWNLOAD_RETRY_WAIT_ENV, DEFAULT_DOWNLOAD_RETRY_WAIT_SECONDS)
    end

    def download_command
      value = ENV.fetch(DOWNLOAD_COMMAND_ENV, '').strip
      return nil if value.empty?
      return value if SUPPORTED_DOWNLOAD_COMMANDS.include?(value)

      invalid_environment_value!(
        DOWNLOAD_COMMAND_ENV,
        value,
        SUPPORTED_DOWNLOAD_COMMANDS.join(' or ')
      )
    end

    def positive_integer_or_unlimited(name, default)
      value = ENV.fetch(name, '').strip
      return default if value.empty?
      return nil if value.casecmp?(UNLIMITED_VALUE)

      integer = Integer(value, 10)
      return integer if integer.positive?

      invalid_environment_value!(name, value, "positive integer or #{UNLIMITED_VALUE}")
    rescue ArgumentError
      invalid_environment_value!(name, value, "positive integer or #{UNLIMITED_VALUE}")
    end

    def positive_integer(name, default)
      value = ENV.fetch(name, '').strip
      return default if value.empty?

      integer = Integer(value, 10)
      return integer if integer.positive?

      invalid_environment_value!(name, value, 'positive integer')
    rescue ArgumentError
      invalid_environment_value!(name, value, 'positive integer')
    end

    def non_negative_integer(name, default)
      value = ENV.fetch(name, '').strip
      return default if value.empty?

      integer = Integer(value, 10)
      return integer unless integer.negative?

      invalid_environment_value!(name, value, 'non-negative integer')
    rescue ArgumentError
      invalid_environment_value!(name, value, 'non-negative integer')
    end

    def invalid_environment_value!(name, value, expected)
      raise InvalidOptionError, "invalid #{name} '#{value}' (expected: #{expected})"
    end
  end
end
