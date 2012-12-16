# keeps track of the available ports on the machine

module RailsPwnerer::Config
  def self.init_ports(free_ports = [[8000, 16000]])
    self.create_db :free_ports
    self[:free_ports][:list] = free_ports
    self.flush_db :free_ports
  end
  
  # allocates a contiguous range of ports
  # returns the starting port or nil
  def self.alloc_ports(nports = 1)
    free_ports = self[:free_ports][:list]
    free_ports.each_index do |i|
      next if free_ports[i][1] - free_ports[i][0] < nports      
      first_port = free_ports[i][0]
      free_ports[i][0] += nports
      free_ports.delete_at i if free_ports[i][0] == free_ports[i][1]
      self[:free_ports][:list] = free_ports
      self.flush_db :free_ports
      return first_port
    end
  end
  
  # returns a continuous range of ports to the free list
  def self.free_ports(start, count = 1)
    free_ports = self[:free_ports][:list]
    free_ports << [start, start + count]
    
    # concatenate duplicates
    free_ports.sort! { |a, b| a[0] <=> b[0]}
    new_ports = [free_ports.first]
    free_ports.each_index do |i|
      if new_ports.last[1] >= free_ports[i][0]
        new_ports.last[1] = [new_ports.last[1], free_ports[i][1]].max
      else
        new_ports << free_ports[i]
      end
    end
    
    # write the new database
    self[:free_ports][:list] = new_ports
    self.flush_db :free_ports
  end
end