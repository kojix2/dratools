# frozen_string_literal: true

module Dratools
  MESSAGE_TAG = "[#{NAME}]"

  def self.message(message)
    "#{MESSAGE_TAG} #{message}"
  end
end
