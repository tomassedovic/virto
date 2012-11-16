#!/usr/bin/env ruby

require 'libvirt'
require 'rexml/document'
require 'thor'


conn = Libvirt::open("qemu:///system")


MAC_PREFIX = '52:33:'

def ip_address_from_mac(mac_address)
  mac_address = mac_address.strip
  raise 'Invalid MAC format' unless mac_address.length == 17
  bytes = mac_address.split(':')
  raise 'Invalid MAC format' unless bytes.length == 6
  unless mac_address.start_with? MAC_PREFIX
    raise "Unknown MAC address. Use the prefix: '#{MAC_PREFIX}'"
  end

  # Assume the IP address is identical to the four least significant bytes of
  # the MAC
  ip_bytes = bytes[2..6]
  ip_bytes.map { |s| s.to_i(16) }.join('.')
end

def parse_ip_address(ip_address)
  bytes = ip_address.split('.')
  raise 'Invalid IP address format' unless bytes.length == 4
  bytes.map &:to_i
end

def mac_from_ip_address(ip_address)
  ip_in_hex = parse_ip_address(ip_address).map { |b| '%02x' % b }
  MAC_PREFIX + ip_in_hex.join(':')
end

def list_all_vms(conn)
  running_vms = conn.list_domains.map {|id| conn.lookup_domain_by_id(id)}
  stopped_vms = conn.list_defined_domains.map {|name| conn.lookup_domain_by_name(name)}
  running_vms + stopped_vms
end

def mac_from_vm(vm)
  doc = REXML::Document.new(vm.xml_desc)
  mac_element = doc.elements['domain/devices/interface/mac']
  mac_element.attributes['address'] if mac_element
end

def used_ip_addresses(conn)
  used_mac_addresses = list_all_vms(conn).map { |vm| mac_from_vm(vm) }
  used_mac_addresses.map { |mac| ip_address_from_mac(mac) }
end

def all_ip_addresses(conn)
  network = default_network(conn)
  doc = REXML::Document.new(network.xml_desc)
  range_elem = doc.elements['network/ip/dhcp/range']

  unless range_elem
    raise "DHCP IP range element not defined in the network: '#{network.name}'"
  end

  ip_range_start = parse_ip_address(range_elem.attributes['start'])
  ip_range_end = parse_ip_address(range_elem.attributes['end'])

  unless (0..2).all? { |index| ip_range_start[index] == ip_range_end[index] }
    raise "The IP Address range must form a C-type subnet. "
      "The first three segments must be the same"
  end

  range = (ip_range_start[3]..ip_range_end[3])
  ip_addresses = range.map do |n|
    [ip_range_start[0], ip_range_start[1], ip_range_start[2], n].join('.')
  end

  return ip_addresses
end

def available_ip_addresses(conn)
  all_ip_addresses(conn) - used_ip_addresses(conn)
end

def default_network(conn)
  networks = conn.list_networks.map { |name| conn.lookup_network_by_name(name) }
  network = networks.select { |n| n.autostart? }.first

  raise "No active && autostart network available." unless network

  return network
end

def command_setup_network(conn)
  ip_addresses = all_ip_addresses(conn)
  network = default_network(conn)

  doc = REXML::Document.new(network.xml_desc)
  doc.elements.delete_all('network/ip/dhcp/host')

  dhcp_elem = doc.elements['network/ip/dhcp']
  ip_addresses.each do |ip|
    dhcp_elem.add_element 'host', {'ip' => ip, 'mac' => mac_from_ip_address(ip)}
  end

  # Remove the current network
  network.destroy
  network.undefine

  # Replace it with the updated XML definition
  conn.define_network_xml(doc.to_s)
  new_network = conn.lookup_network_by_name(network.name)
  new_network.autostart = true
  new_network.create
end


class App < Thor
  desc "setup-network [NAME]", "Sets up the default libvirt network's DHCP"
  def setup_network(name=nil)
    if name
      puts "setting up network: #{name}"
    else
      puts "setting up the default network"
    end
    puts "TODO: add the IP<->MAC address mappings to the libvirt network"
  end


  desc "images", "List the base images to launch VMs from"
  def images
    puts "TODO"
  end


  desc "create IMAGE", "Launches a new virtual machine from the given image"
  def create(image)
    puts 'TODO: clone the image and launch a new VM'
  end


  desc "list", "Lists all the virtual machines (running and stopped)"
  def list
    puts "TODO"
  end


  desc "ssh NAME", "SSH into the given VM"
  def ssh(name)
    puts "TODO: get the VM's IP and SSH into it"
  end


  desc "mount NAME", "Mount the VM's filesystem using sshfs"
  def mount(name)
    puts "TODO: sshfs the VM's disk"
  end


  desc "stop NAME", "Stop the running VM"
  def stop(name)
    # alias: shutdown?
    puts "TODO"
  end


  desc "start NAME", "Start a stopped VM"
  def start(name)
    # alias: launch?
    puts "TODO"
  end


  desc "restart NAME", "Restart the running VM"
  def restart(name)
    # alias: reboot?
    puts "TODO"
  end
end

App.start