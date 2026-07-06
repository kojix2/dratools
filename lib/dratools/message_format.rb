# frozen_string_literal: true

# dratools 自身が stderr に出す人間向けメッセージの書式。
module Dratools
  MESSAGE_TAG = "[#{NAME}]".freeze

  def self.message(message)
    "#{MESSAGE_TAG} #{message}"
  end
end
