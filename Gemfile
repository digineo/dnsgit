source "https://rubygems.org"

gem "zonefile", ">= 2.2.3", "< 3.0", git: "https://github.com/digineo/zonefile.git"

group :sqlite do
  gem "sqlite3"
end

group :test do
  gem "rake"
  gem "minitest"
end

local_gemfile = 'Gemfile.local'
if File.exist?(local_gemfile)
  eval(File.read(local_gemfile)) # rubocop:disable Lint/Eval
end
