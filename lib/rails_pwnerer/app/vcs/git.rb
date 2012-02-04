# checks out and updates the application from a Git repository

class RailsPwnerer::App::Git
  include RailsPwnerer::Base
  
  # remove any files not in Git in the application dir
  def cleanup_app_dir(app_name, instance_name, target_dir, app_name_is_dir = false)
    Dir.chdir(app_name_is_dir ? app_name : RailsPwnerer::Config[app_name, instance_name][:app_path]) do
      next unless File.exist?(target_dir)
      Kernel.system "git clean -d -f -x -- #{target_dir}"
      Kernel.system "git checkout -- #{target_dir}"
    end
  end
  
  # clean up the application directory by removing caches 
  def cleanup_app_caches(app_name, instance_name, app_name_is_dir = false)
    # TODO: this is almost-duplicated in git.rb -- pull up somewhere    
    app_path = app_name_is_dir ? app_name : RailsPwnerer::Config[app_name, instance_name][:app_path]
    return unless File.exists?(File.join(app_path, '.git'))
    
    # TODO: learn how Rails caches work and kill those too
    ['app', 'db', 'lib', 'public/images',
    'public/javascripts', 'public/stylesheets', 'script',
    'test', 'tmp', 'vendor',
    ].each { |dir| cleanup_app_dir app_name, instance_name, dir, app_name_is_dir }
  end

  # reverts the config changes made by rpwn, so git fetch doesn't get confused
  def revert_config_changes(app_name, instance_name)
    Dir.chdir RailsPwnerer::Config[app_name, instance_name][:app_path] do
      ['config', 'Gemfile', 'Gemfile.lock'].each do |dir|
        next unless File.exist?(target_dir)
        Kernel.system "git clean -d -f -x -- #{dir}"
        Kernel.system "git checkout -- #{dir}"
      end
    end
  end
  
  def git_update(app_name, instance_name)
    Dir.chdir RailsPwnerer::Config[app_name, instance_name][:app_path] do
      print "Doing Git pull, please enter your password if prompted...\n"
      Kernel.system 'git pull'
    end
  end
  
  def update(app_name, instance_name)
    app_path = RailsPwnerer::Config[app_name, instance_name][:app_path]
    return unless File.exists?(File.join(app_path, '.git'))
    # TODO: maybe backup old version before issuing the git update?
    
    cleanup_app_caches app_name, instance_name    
    revert_config_changes app_name, instance_name
    git_update app_name, instance_name
  end
  
  def update_prefetch(app_name, instance_name)
    app_path = RailsPwnerer::Config[app_name, instance_name][:app_path]
    return unless File.exists?(File.join(app_path, '.git'))
    
    Dir.chdir app_path do
      print "Doing Git fetch, please enter your password if prompted...\n"
      Kernel.system 'git fetch origin'
    end
  end
  
  def cleanup
    # git checkout -- paths
  end
    
  def checkout(remote_path, app_name, instance_name)    
    if hash_index = remote_path.rindex('#')
      git_repository = remote_path[0, hash_index]
      git_branch = remote_path[(hash_index + 1)..-1]
    else
      git_repository = remote_path
      git_branch = 'master'
    end
    
    return :next unless git_repository =~ /\.git(\/.*)?$/
    app_path = RailsPwnerer::Config[app_name, instance_name][:app_path]
    
    FileUtils.rm_rf app_path
    print "Doing Git clone, please enter your password if prompted...\n"
    system "git clone -b #{git_branch} -- #{git_repository} #{app_path}"
    FileUtils.mkpath app_path unless File.exists? app_path

    # check that we really checked out a Rails app
    return check_rails_root(app_path) ? :ok : false
  end
end
