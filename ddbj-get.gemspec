# frozen_string_literal: true

require_relative "lib/ddbj/get/version"

Gem::Specification.new do |spec|
  spec.name = "ddbj-get"
  spec.version = Ddbj::Get::VERSION
  spec.authors = ["kojix2"]
  spec.email = ["kojix2@example.com"]

  spec.summary = "DDBJ DRA downloader"
  spec.description = "DDBJ Search を使って DRA/SRA ファイル URL を解決し、DDBJ から取得する小さな CLI とライブラリです。"
  spec.homepage = "https://github.com/kojix2/ddbj-get"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["bin/*", "lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE.txt", "docs/**/*.md"]
  end
  spec.bindir = "bin"
  spec.executables = ["ddbj-get"]
  spec.require_paths = ["lib"]
end
