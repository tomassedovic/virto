#!/usr/bin/env ruby

require 'libvirt'
require 'rexml/document'


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

def mac_from_ip_address(ip_address)
  bytes = ip_address.split('.')
  raise 'Invalid IP address format' unless bytes.length == 4

  ip_in_hex = bytes.map { |s| '%02x' % s.to_i }
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
  ip_range = (2..254)
  ip_range.map { |n| [192, 168, 122, n].join('.') }
end

def available_ip_addresses(conn)
  all_ip_addresses(conn) - used_ip_addresses(conn)
end


vms = list_all_vms(conn)
puts vms.map(&:name)

macs = vms.map {|vm| mac_from_vm(vm)}
puts macs

ips = used_ip_addresses(conn)
puts ips

available_ip_addresses(conn).each {|ip| puts "#{ip} <- #{mac_from_ip_address(ip)}"}