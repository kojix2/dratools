# frozen_string_literal: true

module Ddbj
  module Get
    Error = Class.new(StandardError)
    NotFoundError = Class.new(Error)
    NetworkError = Class.new(Error)
    CommandError = Class.new(Error)
    UnsupportedAccessionError = Class.new(Error)
  end
end
