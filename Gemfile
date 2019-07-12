source "https://rubygems.org"

git_source :github do |name|
  name = "#{name}/#{name}" unless name.include?("/")
  "https://github.com/#{name}.git"
end

gem "zonefile", "~> 2.0.0", github: "digineo/zonefile"

group :sqlite do
  gem "sqlite3"
end

group :test do
  gem "rake"
  gem "minitest"
end

group :development do
  gem "rubocop", "~> 0.72.0", require: false
end
