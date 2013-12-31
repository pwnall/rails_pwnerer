require 'rubygems'
require 'echoe'

Echoe.new('rails_pwnerer') do |p|
  p.project = 'rails-pwnage' # rubyforge project

  p.author = 'Victor Costan'
  p.email = 'victor@costan.us'
  p.summary = 'Rails deployment hack.'
  p.url = 'http://github.com/pwnall/rails_pwnage'
  p.licenses = ['MIT']
  p.development_dependencies = ['echoe', 'fakefs', 'flexmock']
  p.runtime_dependencies = ['zerg_support']

  p.need_tar_gz = !Gem.win_platform?
  p.need_zip = !Gem.win_platform?
  p.rdoc_pattern =
      /^(lib|bin|tasks|ext)|^BUILD|^README|^CHANGELOG|^TODO|^LICENSE|^COPYING$/
end

if $0 == __FILE__
  Rake.application = Rake::Application.new
  Rake.application.run
end
