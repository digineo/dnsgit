#!/usr/bin/env ruby

require_relative '../lib/environment'

generator = ZoneGenerator.new "#{__dir__}/.."
generator.generate
generator.deploy
