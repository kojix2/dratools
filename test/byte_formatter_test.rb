# frozen_string_literal: true

require_relative 'test_helper'

class ByteFormatterTest < Minitest::Test
  def test_formats_bytes
    assert_equal '0 B', Dratools::ByteFormatter.format(0)
    assert_equal '1023 B', Dratools::ByteFormatter.format(1023)
  end

  def test_formats_iec_units
    assert_equal '1.0 KiB', Dratools::ByteFormatter.format(1024)
    assert_equal '1.5 KiB', Dratools::ByteFormatter.format(1536)
    assert_equal '1.0 TiB', Dratools::ByteFormatter.format(1024**4)
    assert_equal '1.0 PiB', Dratools::ByteFormatter.format(1024**5)
  end
end
