require 'libvirt'
require 'rexml/document'

class VirtManager
  class UnknownImage < StandardError; end
  class InvalidName < StandardError; end
  class NameAlreadyTaken < StandardError; end
  class CommandError < StandardError; end

  def initialize(libvirt_uri, mac_prefix, network_name=nil)
    @uri = libvirt_uri
    @mac_prefix = mac_prefix
    @libvirt = Libvirt::open(@uri)
    @network = if network_name
      @libvirt.lookup_network_by_name(network_name)
    else
      default_network
    end
  end

  def network_name()
    @network.name
  end

  def ip_address_from_mac(mac_address)
    mac_address = mac_address.strip
    raise 'Invalid MAC format' unless mac_address.length == 17

    bytes = mac_address.split(':')
    raise 'Invalid MAC format' unless bytes.length == 6

    unless known_mac?(mac_address)
      raise "Unknown MAC address. Use the prefix: '#{@mac_prefix}'"
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
    @mac_prefix + ip_in_hex.join(':')
  end

  def running_vms()
    @libvirt.list_domains.map {|id| @libvirt.lookup_domain_by_id(id)}
  end

  def stopped_vms()
    @libvirt.list_defined_domains.map {|name| @libvirt.lookup_domain_by_name(name)}
  end

  def images()
    stopped_vms.map(&:name)
  end

  def all_vms()
    running_vms + stopped_vms
  end

  def known_mac?(mac_address)
    mac_address.start_with? @mac_prefix
  end

  def mac_address_from_vm(vm)
    doc = REXML::Document.new(vm.xml_desc)
    mac_element = doc.elements['domain/devices/interface/mac']
    mac_element.attributes['address'] if mac_element
  end

  def used_ip_addresses()
    used_mac_addresses = all_vms.map { |vm| mac_address_from_vm(vm) }
    used_mac_addresses.select { |mac| known_mac? mac }.map { |mac| ip_address_from_mac(mac) }
  end

  def all_ip_addresses()
    doc = REXML::Document.new(@network.xml_desc)
    range_elem = doc.elements['network/ip/dhcp/range']

    unless range_elem
      raise "DHCP IP range element not defined in the network: '#{@network.name}'"
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

  def available_ip_addresses()
    all_ip_addresses - used_ip_addresses
  end

  def default_network()
    networks = @libvirt.list_networks.map { |name| @libvirt.lookup_network_by_name(name) }
    network = networks.select { |n| n.autostart? }.first

    raise "No active && autostart network available." unless network

    return network
  end

  def setup_network()
    ip_addresses = all_ip_addresses

    doc = REXML::Document.new(@network.xml_desc)
    doc.elements.delete_all('network/ip/dhcp/host')

    dhcp_elem = doc.elements['network/ip/dhcp']
    ip_addresses.each do |ip|
      dhcp_elem.add_element 'host', {'ip' => ip, 'mac' => mac_from_ip_address(ip)}
    end

    # Remove the current network
    @network.destroy
    @network.undefine

    # Replace it with the updated XML definition
    @libvirt.define_network_xml(doc.to_s)
    new_network = @libvirt.lookup_network_by_name(@network.name)
    new_network.autostart = true
    new_network.create
  end

  def clone_vm(image_name, name, new_mac_address)
    raise UnknownImage.new(image_name) unless images.include? image_name

    legal_vm_name = /\A[a-zA-Z0-9_-]+\Z/  # alphanumerics, underscore, dash
    raise InvalidName.new(name) unless legal_vm_name.match(name)

    raise NameAlreadyTaken.new(name) if find_vm_by_name(name)

    image = find_vm_by_name(image_name)
    doc = REXML::Document.new(image.xml_desc)
    # Get the element containing the path to the source image
    source_element = doc.elements["domain/devices/disk[contains(@type,'file') and contains(@device,'disk')]/source"]
    source_image_path = source_element.attributes['file']
    raise "Error getting the source image path" unless source_image_path

    new_image_file_path = File.join(File.dirname(source_image_path),
        "#{name}#{File.extname(source_image_path)}")
    virt_clone_command = [
      %Q(virt-clone --quiet --force --connect "#{@uri}"),
      %Q(--original "#{image_name}" --name "#{name}"),
      %Q(--mac "#{new_mac_address}" --file "#{new_image_file_path}"),
    ].join(' ')
    puts(virt_clone_command)
    result = system(virt_clone_command)
    raise CommandError.new(virt_clone_command) unless result
  end

  def find_vm_by_name(name)
    begin
      @libvirt.lookup_domain_by_name(name)
    rescue Libvirt::RetrieveError
      nil
    end
  end
end