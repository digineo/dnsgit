#!/usr/bin/env ruby

require File.expand_path('../../lib/environment',  __FILE__)

generator = ZoneGenerator.new(BASEDIR)
generator.generate
generator.deploy
