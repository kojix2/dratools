# frozen_string_literal: true

module Dratools
  # Byte count formatter for human-readable IEC units.
  module ByteFormatter
    UNITS = %w[B KiB MiB GiB TiB PiB].freeze
    UNIT_BASE = 1024.0

    module_function

    def format(bytes)
      value = bytes.to_f
      unit_index = 0

      while value >= UNIT_BASE && unit_index < UNITS.length - 1
        value /= UNIT_BASE
        unit_index += 1
      end

      return "#{bytes.to_i} B" if unit_index.zero?

      "#{Kernel.format('%.1f', value)} #{UNITS[unit_index]}"
    end
  end
end
