# Gemfile for MyTree development dependencies

source "https://rubygems.org"

# Fastlane for automating development and release tasks
gem "fastlane", "~> 2.220"

# Additional fastlane plugins
plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
