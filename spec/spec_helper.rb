require 'simplecov'

if ENV["COVERAGE"]
  SimpleCov.start do
    add_filter "/spec/"
  end
end

require File.expand_path(File.dirname(__FILE__) + '/../lib/feedjira')
require 'sample_feeds'
require 'webmock/rspec'


RSpec.configure do |c|
  c.include SampleFeeds
end
