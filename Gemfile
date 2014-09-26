source 'https://rubygems.org'

puppetversion = ENV.key?('PUPPET_VERSION') ? "= #{ENV['PUPPET_VERSION']}" : ['>= 3.3']
gem 'puppet', puppetversion
gem 'puppetlabs_spec_helper', '>= 0.1.0'
gem 'facter', '>= 1.7.0'

gem 'puppet-type', '0.1.0', :path => File.dirname(__FILE__), :require => false
