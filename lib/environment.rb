require 'rubygems'
require 'bundler/setup'
require 'zonefile'
require 'yaml'

BASEDIR = File.expand_path('../..',  __FILE__)

require "#{BASEDIR}/lib/hash_ext"
require "#{BASEDIR}/lib/zone"
require "#{BASEDIR}/lib/zone_generator"
