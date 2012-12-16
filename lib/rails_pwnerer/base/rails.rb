# extends Base with Rails-related functions

module RailsPwnerer::Base
  # check if the given path is the root of a Rails application
  def check_rails_root(app_path = '.')
    ['app', 'config', 'public', 'Rakefile'].all? do |path|
      File.exists? File.join(app_path, path)
    end
    ['script/rails', 'config/database.yml'].any? do |path|
      File.exists? File.join(app_path, path)
    end
  end
end
