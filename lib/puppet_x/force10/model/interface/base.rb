require 'puppet_x/force10/model'
require 'puppet_x/force10/model/interface'

module PuppetX::Force10::Model::Interface::Base

  def self.ifprop(base, param, base_command = param, &block)
    base.register_scoped param, /^(interface\s+(\S+\s\S+).*?shutdown)/m do
      cmd 'sh run'
      match /^\s*#{base_command}\s+(.*?)\s*$/
      add do |transport, value|
        Puppet.debug(" command #{base_command} value  #{value}" )
        transport.command("#{base_command} #{value}")
      end
      remove do |transport, old_value|
        Puppet.debug(" No  command #{base_command} value  #{value}" )
        transport.command("no #{base_command} #{old_value}")
      end
      evaluate(&block) if block
    end
  end

  def self.register(base)

    txt = ''
    ifprop(base, :ensure) do
      match do |txt|
        unless txt.nil?
          txt.match(/\S+/) ? :present : :absent
        else
          :absent
        end
      end
      default :absent
      add { |*_| }
      remove { |*_| }
    end

    ifprop(base, :portchannel) do
      match /^  port-channel (\d+)\s+.*$/
      add do |transport, value|
        if value.to_i == 0
          transport.command("no port-channel-protocol lacp")
        else
          transport.command("port-channel-protocol lacp")
          transport.command("port-channel #{value} mode active")
        end
      end
      remove do |transport, value|
        transport.command("no port-channel-protocol lacp")
      end
    end

    ifprop(base, :shutdown) do
      shutdowntxt=''
      match do |shutdowntxt|
        unless shutdowntxt.nil?
          if shutdowntxt.include? "no shutdown"
            :false
          else
            :true
          end
        end
      end
      add do |transport, value|
        if value==:true
          transport.command("shutdown")
        else
          transport.command("no shutdown")
        end
      end
      remove { |*_| }
    end

    ifprop(base, :mtu) do
      match /^\s*mtu\s+(.*?)\s*$/
      add do |transport, value|
        transport.command("mtu #{value}")
      end
      remove { |*_| }
    end

    ifprop(base, :switchport) do
      switchporttxt=''
      match do |switchporttxt|
        unless switchporttxt.nil?
          if switchporttxt.include? "switchport"
            :true
          else
            :false
          end
        end
      end
      add do |transport, value|
        if value == :true
          transport.command("switchport")do |out|
            if out =~/Error:\s*(.*)/
              Puppet.debug "#{$1}"
            end
          end
        end
        if value == :false
          transport.command("no switchport") do |out|
            if out =~/Error:\s*(.*)/
              Puppet.debug "#{$1}"
            end
          end
        end

      end
      remove { |*_| }
    end
    
    ifprop(base, :dcb_map) do
      match /^\s*dcb-map\s+(.*?)\s*$/
      add do |transport, value|
        # Commands to remove the dcb ets and pfc settings
        # Without these settings removed, DCB is not applied
        transport.command("no dcb-policy input pfc")
        transport.command("no dcb-policy output ets")
        
        # Command to enable the spanning tree edge port
        transport.command("spanning-tree estp edge-port")
        
        # Command to associate DCB map with the interface
        transport.command("dcb-map #{value}")
      end
      remove { |*_| }
    end
    
    ifprop(base, :fcoe_map) do
      match /^\s*fcoe-map\s+(.*?)\s*$/
      add do |transport, value|
        transport.command("fcoe-map #{value}")
      end
      remove { |*_| }
    end
    
    ifprop(base, :fabric) do
      match /^\s*fabric\s+(.*?)\s*$/
      add do |transport, value|
        transport.command("fabric #{value}")
      end
      remove { |*_| }
    end

    ifprop(base, :portmode) do
      match /^\s*portmode\s+(.*?)\s*$/
      add do |transport, value|
        #transport.command("fabric #{value}")
        Puppet.debug('Need to remove existing configuration')
        existing_config=(transport.command('show config') || '').split("\n").reverse
        updated_config = existing_config.find_all {|x| x.match(/dcb|switchport|spanning|vlan/)}
        updated_config.each do |remove_command|
          transport.command("no #{remove_command}")
        end
        transport.command('portmode hybrid')
        updated_config.reverse.each do |remove_command|
          transport.command("#{remove_command}")
        end
      end
      remove { |*_| }
    end

    ifprop(base, :portfast) do
      match /^\s*spanning-tree 0 (.*?)\s*$/
      add do |transport, value|
        transport.command("spanning-tree 0 #{value}")
      end
      remove { |*_| }
    end

    ifprop(base, :edge_port) do
      match /^\s*spanning-tree pvst\s+(.*?)\s*$/
      add do |transport, value|
        transport.command("spanning-tree pvst #{value}")
      end
      remove { |*_| }
    end

    ifprop(base, :protocol) do
      match /^\s*protocol\s+(.*?)\s*$/
      add do |transport, value|
        transport.command('protocol lldp')
        # Need to come out of the lldp context
        transport.command('exit')
      end
      remove do |transport, value|
        transport.command("no protocol lldp")
      end
    end

    ifprop(base, :untagged_vlan) do
      empty_match=''
      match do |empty_match|
        unless empty_match.nil?
          :false  #This is so we always go through the "add" swimlane
        end
      end
      add do |transport, value|
        existing_config = transport.command('show config') || ''
        iface = existing_config.match(/\s*interface\s+(.*?)\s*$/)[1]
        type, interface_id = PuppetX::Force10::Model::Interface::Base.parse_interface(iface)
        vlans = PuppetX::Force10::Model::Interface::Base.vlans_from_list(value)
        PuppetX::Force10::Model::Interface::Base.update_vlans(transport, vlans, false, [type, interface_id])
      end
      remove { |*_| }
    end

    ifprop(base, :tagged_vlan) do
      empty_match=''
      match do |empty_match|
        unless empty_match.nil?
          :false
        end
      end
      add do |transport, value|
        existing_config = transport.command('show config') || ''
        iface = existing_config.match(/\s*interface\s+(.*?)\s*$/)[1]
        type, interface_id = PuppetX::Force10::Model::Interface::Base.parse_interface(iface)
        vlans = PuppetX::Force10::Model::Interface::Base.vlans_from_list(value)
        PuppetX::Force10::Model::Interface::Base.update_vlans(transport, vlans, true, [type, interface_id])
      end
      remove { |*_| }
    end
  end

  def self.update_vlans(transport, new_vlans, tagged, interface_info)
    tagged ? vlan_type = "tagged" : vlan_type = "untagged"
    interface_type = interface_info[0]
    interface_id = interface_info[1]

    transport.command("exit") # bring us back to config
    transport.command("exit") # bring us back to main

    current_vlan_info = transport.command("show interfaces switchport #{interface_type} #{interface_id}")
    if tagged
      current_vlans = current_vlan_info.match(/^T\s+(.*?)\s*$/)[1].split(",")
    else
      current_vlans = current_vlan_info.match(/^U\s+(.*?)\s*$/)[1].split(",")
    end
    all_current_vlans = []
    current_vlans.each do |vlan_group|
      Puppet.debug("LKstart: #{vlan_group}")
      new_group = PuppetX::Force10::Model::Interface::Base.vlans_from_list(vlan_group)
      Puppet.debug("LKnew: #{new_group}")
      all_current_vlans.concat(new_group)
    end
    all_current_vlans.uniq!
    vlans_to_remove = all_current_vlans - new_vlans
    transport.command("config")
    # Remove all the unused vlans
    vlans_to_remove.each do |vlan|
      Puppet.debug("Removing vlan #{vlan} from interface #{interface_id}")
      transport.command("interface vlan #{vlan}")
      transport.command("no #{vlan_type} #{interface_type} #{interface_id}")
      transport.command("exit")
    end
    # Add the new vlans
    new_vlans.each do |vlan|
      Puppet.debug("Adding vlan #{vlan} to interface #{interface_id}")
      transport.command("interface vlan #{vlan}")
      transport.command("#{vlan_type} #{interface_type} #{interface_id}")
    end
    # Return transport back to beginning location
    transport.command("interface #{interface_type} #{interface_id}")
  end

  def self.parse_interface(iface)
    if iface.include? 'TenGigabitEthernet'
      iface.slice! 'TenGigabitEthernet '
      type = 'TenGigabitEthernet'
    elsif iface.include? 'FortyGigE'
      iface.slice! 'FortyGigE '
      type = 'fortyGigE'
    else
      raise Puppet::Error, "Unknown interface type #{iface}"
    end
    [type, iface]
  end

  def self.vlans_from_list(value)
    vlans = []
    value = value.to_s
    values = []
    if value.include? ","
      value.split(",").each do |vlan_group|
        values << vlan_group
      end
    else value
      values << value
    end
    values.each do |vlan_group|
      if vlan_group.include? "-"
        first = vlan_group.split("-")[0]
        last = vlan_group.split("-")[1]
        vlans.concat((first.to_i..last.to_i).to_a)
      else
        vlans << vlan_group
      end
    end
    vlans.uniq!
    vlans
  end
  
end
