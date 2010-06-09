module RailsPwnerer::Base   
  # initializes the module in UNIX mode
  def self._setup_unix
    #SUDO_PREFIX = 'sudo '
  end
  
  # initializes the module in Windows mode
  def self._setup_windows
    #SUDO_PREFIX = ''
  end
  
  # dispatch to the right initializer based on Ruby's platform
  if RUBY_PLATFORM =~ /win/ && !(RUBY_PLATFORM =~ /darwin/)
    self._setup_windows
  else
    self._setup_unix
  end  
  
  # unrolls a collection
  def unroll_collection(arg, &proc)
    if arg.kind_of? String
      yield arg
    else
      arg.each { |i| unroll_collection(i, &proc) }
    end
  end  
end
