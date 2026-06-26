# frozen_string_literal: true

require 'digest/md5'

require_relative 'errors'

module Dratools
  # ダウンロード済みファイルのチェックサムを検証する。
  #
  # Digest::MD5.file はストリーム処理なので、巨大ファイルでも全体をメモリに載せない。
  class ChecksumVerifier
    def md5_matches?(path, expected_md5)
      md5_for(path).casecmp?(normalize_md5(expected_md5))
    end

    def verify_md5!(path, expected_md5)
      expected_md5 = normalize_md5(expected_md5)
      actual_md5 = md5_for(path)
      return true if actual_md5.casecmp?(expected_md5)

      raise ChecksumError, "MD5 mismatch for #{path}: expected #{expected_md5}, got #{actual_md5}"
    end

    private

    def normalize_md5(md5)
      md5.to_s.strip
    end

    def md5_for(path)
      Digest::MD5.file(path).hexdigest
    end
  end
end
