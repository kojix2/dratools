# frozen_string_literal: true

module Dratools
  class Error < StandardError
  end

  class InputError < Error
  end

  class MissingAccessionError < InputError
  end

  class InputFileError < InputError
  end

  class InvalidOptionError < Error
  end

  class InvalidProtocolError < Error
  end

  class NotFoundError < Error
  end

  class InvalidRecordError < Error
  end

  class NetworkError < Error
  end

  class CommandError < Error
  end

  class ChecksumError < Error
  end

  class UnsupportedAccessionError < Error
  end
end
