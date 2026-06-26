# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rubocop/rake_task'

desc 'Run the default test suite'
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
end

desc 'Run RuboCop'
RuboCop::RakeTask.new(:rubocop)

namespace :test do
  desc 'Run tests including live DDBJ integration checks'
  task :integration do
    sh({ 'DRATOOLS_INTEGRATION' => '1' }, 'bundle exec rake test')
  end
end

desc 'Smoke test CLI URL resolution against a public accession'
task :smoke do
  sh 'bundle exec ruby -Ilib bin/dratools url DRR000001'
end

task default: :test
