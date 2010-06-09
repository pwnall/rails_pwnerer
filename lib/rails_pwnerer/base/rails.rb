# extends Base with Rails-related functions

module RailsPwnage::Base
  # check if the given path is the root of a Rails application
  def check_rails_root(path = '.')
    ['app', 'config', 'db', 'public', 'script', 'vendor',
     'Rakefile'].all? { |dir| File.exists? File.join(path, dir) }     
  end
end
