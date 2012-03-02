#!/usr/bin/ruby

# Copyright (c) 2012, Anugrah Redja Kusuma <anugrah.redja@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

require 'socket'

class DNSForwarder
  attr_accessor :dns_addr, :dns_port, :bind_addr, :bind_port

  def initialize(dns_addr, dns_port, bind_addr = '127.0.0.1', bind_port = 53)
    @bind_addr = bind_addr
    @bind_port = bind_port
    @dns_addr = dns_addr
    @dns_port = dns_port
  end

  def start
    @works = []
    @mutex = Mutex.new
    @udp = UDPSocket.new
    @udp.bind @bind_addr, @bind_port
    while true
      request, client = @udp.recvfrom 512
      resolve request, client
    end
  end

  def resolve(request, client)
    key = "#{client[3]}:#{client[1]}"
    @mutex.synchronize do
      return if @works.include? key
      @works << key
    end

    Thread.new do
      Socket.tcp @dns_addr, @dns_port do |tcp|
        tcp.write [request.size].pack('n') + request
        tcp.close_write
        len = tcp.read(2).unpack('n')[0]
        response = tcp.read(len)
        @udp.send response, 0, client[3], client[1]
      end
      @mutex.synchronize { @works.delete key }
    end
  end
end

if ARGV.include? '-h' or ARGV.include? '--help'
  puts "Usage: dnsforward [dns_addr] [dns_port] [bind_addr] [bind_port]"
  puts "Forward local UDP DNS request to a remote TCP DNS server."
  exit
end

dns_addr, dns_port = '87.118.100.175', 110
bind_addr, bind_port = '127.0.0.1', 53

dns_addr = ARGV[0] if ARGV.count > 0
dns_port = ARGV[1] if ARGV.count > 1
bind_addr = ARGV[2] if ARGV.count > 2
bind_port = ARGV[3] if ARGV.count > 3

dns = DNSForwarder.new dns_addr, dns_port, bind_addr, bind_port
dns.start
