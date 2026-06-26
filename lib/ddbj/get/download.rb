# frozen_string_literal: true

require "uri"

module Ddbj
  module Get
    Download = Struct.new(
      :run_accession,
      :type,
      :url,
      :ftp_url,
      :size,
      :md5,
      keyword_init: true
    ) do
      def preferred_url(protocol)
        case protocol.to_s
        when "ftp"
          ftp_url || url
        when "https", "http"
          url || ftp_url
        else
          raise ArgumentError, "unknown protocol: #{protocol}"
        end
      end

      def filename(protocol = "https")
        File.basename(URI(preferred_url(protocol)).path)
      end
    end
  end
end
