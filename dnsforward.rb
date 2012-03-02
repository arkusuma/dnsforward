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
  attr_accessor :dns_addr, :dns_port, :dns_mode, :bind_addr, :bind_port

  def initialize(dns_addr, dns_port, dns_mode, bind_addr = '127.0.0.1', bind_port = 53)
    @dns_addr = dns_addr
    @dns_port = dns_port
    @dns_mode = dns_mode
    @bind_addr = bind_addr
    @bind_port = bind_port
  end

  def start
    @works = []
    @mutex = Mutex.new
    Socket.udp_server_loop(@bind_addr, @bind_port) do |msg, src|
      resolve msg, src
    end
  end

  def resolve(msg, src)
    @mutex.synchronize do
      return if @works.include? src.remote_address
      @works << src.remote_address
    end

    Thread.new do
      sock = nil
      begin
        if @dns_mode == :tcp
          sock = TCPSocket.new @dns_addr, @dns_port
          sock.write [msg.size].pack('n') + msg
          sock.close_write
          len = sock.read(2).unpack('n')[0]
          src.reply(sock.read len)
        else
          sock = UDPSocket.new
          sock.send msg, 0, @dns_addr, @dns_port
          src.reply(sock.recv 512)
        end
      ensure
        sock.close
        @mutex.synchronize { @works.delete src.remote_address }
      end
    end
  end
end

if ARGV.include? '-h' or ARGV.include? '--help'
  puts "Usage: dnsforward [dns_addr] [dns_port] [dns_mode] [bind_addr] [bind_port]"
  puts "Forward local UDP DNS request to a remote UDP/TCP DNS server."
  exit
end

#dns_addr, dns_port, dns_mode = '87.118.100.175', 110, :tcp
dns_addr, dns_port, dns_mode = '208.67.222.222', 5353, :udp
#dns_addr, dns_port, dns_mode = '208.67.220.220', 5353, :udp

bind_addr, bind_port = '0.0.0.0', 53

dns_addr = ARGV[0] if ARGV.count > 0
dns_port = ARGV[1] if ARGV.count > 1
dns_mode = (ARGV[2] == 'tcp' ? :tcp : :udp) if ARGV.count > 2
bind_addr = ARGV[3] if ARGV.count > 3
bind_port = ARGV[4] if ARGV.count > 4

dns = DNSForwarder.new dns_addr, dns_port, dns_mode, bind_addr, bind_port
dns.start
