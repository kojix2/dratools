# frozen_string_literal: true

require_relative 'lib/dratools/version'

Gem::Specification.new do |spec|
  spec.name = 'dratools'
  spec.version = Dratools::VERSION
  spec.authors = ['kojix2']
  spec.email = ['2xijok@gmail.com']

  spec.summary = 'DDBJ DRA toolkit'
  spec.description = 'DDBJ Search を使って DRA/SRA ファイル URL を解決し、DDBJ から取得する小さな CLI とライブラリです。'
  spec.homepage = 'https://github.com/kojix2/dratools'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    Dir['bin/*', 'lib/**/*.rb', 'README.md', 'CHANGELOG.md', 'LICENSE.txt', 'docs/**/*.md']
  end
  spec.bindir = 'bin'
  spec.executables = ['dratools']
  spec.require_paths = ['lib']
end
