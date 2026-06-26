# frozen_string_literal: true

require_relative 'test_helper'

class ConfigTest < Minitest::Test
  def test_uses_defaults_when_environment_is_empty
    with_env(
      'DRATOOLS_MAX_RECURSIVE_NON_RUN_XREFS' => nil,
      'DRATOOLS_TREE_MAX_DIRECT_RUNS' => nil,
      'DRATOOLS_URL_MAX_DIRECT_RUNS' => nil,
      'DRATOOLS_SIZE_MAX_DIRECT_RUNS' => nil
    ) do
      assert_equal 100, Dratools::Config.max_recursive_non_run_xrefs
      assert_equal 50, Dratools::Config.tree_max_direct_runs
      assert_equal 50, Dratools::Config.url_max_direct_runs
      assert_equal 50, Dratools::Config.size_max_direct_runs
    end
  end

  def test_accepts_positive_integer_overrides
    with_env(
      'DRATOOLS_MAX_RECURSIVE_NON_RUN_XREFS' => '12',
      'DRATOOLS_TREE_MAX_DIRECT_RUNS' => '34',
      'DRATOOLS_URL_MAX_DIRECT_RUNS' => '56',
      'DRATOOLS_SIZE_MAX_DIRECT_RUNS' => '78',
      'DRATOOLS_DOWNLOAD_CONNECT_TIMEOUT' => '7',
      'DRATOOLS_DOWNLOAD_STALL_TIMEOUT' => '8',
      'DRATOOLS_DOWNLOAD_STALL_SPEED' => '9',
      'DRATOOLS_DOWNLOAD_RETRY_WAIT' => '10'
    ) do
      assert_equal 12, Dratools::Config.max_recursive_non_run_xrefs
      assert_equal 34, Dratools::Config.tree_max_direct_runs
      assert_equal 56, Dratools::Config.url_max_direct_runs
      assert_equal 78, Dratools::Config.size_max_direct_runs
      assert_equal 7, Dratools::Config.download_connect_timeout_seconds
      assert_equal 8, Dratools::Config.download_stall_timeout_seconds
      assert_equal 9, Dratools::Config.download_stall_speed_bytes_per_second
      assert_equal 10, Dratools::Config.download_retry_wait_seconds
    end
  end

  def test_accepts_zero_retry_count
    with_env('DRATOOLS_DOWNLOAD_RETRY_COUNT' => '0') do
      assert_equal 0, Dratools::Config.download_retry_count
    end
  end

  def test_accepts_unlimited
    with_env('DRATOOLS_SIZE_MAX_DIRECT_RUNS' => 'unlimited') do
      assert_nil Dratools::Config.size_max_direct_runs
    end
  end

  def test_rejects_invalid_values
    with_env('DRATOOLS_SIZE_MAX_DIRECT_RUNS' => '0') do
      error = assert_raises(Dratools::InvalidOptionError) do
        Dratools::Config.size_max_direct_runs
      end

      assert_includes error.message, "invalid DRATOOLS_SIZE_MAX_DIRECT_RUNS '0'"
    end
  end
end
