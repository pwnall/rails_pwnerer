# manages the precompiled assets in the Rails 3.1+ asset pipeline

class RailsPwnerer::App::Assets
  include RailsPwnerer::Base
  
  def setup(app_name, instance_name)
    build_app_caches app_name, instance_name
  end
  
  def update_prefetch(app_name, instance_name)
    cleanup_app_caches app_name, instance_name
  end
  
  def update(app_name, instance_name)
    build_app_caches app_name, instance_name
  end
  
  # removes asset caches from the application directory 
  def cleanup_app_caches(app_name, instance_name)
    Dir.chdir RailsPwnerer::Config[app_name, instance_name][:app_path] do
      if File.exist?('Gemfile')
        Kernel.system 'bundle exec rake assets:clean RAILS_ENV=production'
      else
        Kernel.system 'rake assets:clean RAILS_ENV=production'
      end
    end
  end
  
  # builds up the asset caches
  def build_app_caches(app_name, instance_name)
    Dir.chdir RailsPwnerer::Config[app_name, instance_name][:app_path] do
      if File.exist?('Gemfile')
        Kernel.system 'bundle exec rake assets:precompile RAILS_ENV=production'
      else
        Kernel.system 'rake assets:precompile RAILS_ENV=production'
      end
    end
  end
end
