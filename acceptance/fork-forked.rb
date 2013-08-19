#!/usr/bin/env ruby

require 'bundler/setup'
require 'eventmachine'
require "em-actor"

at_exit do
  $stderr.puts "#{Process.pid} exited: #{$!}\n  #{$!.backtrace[0..5].join("\n  ")}"
end

EM.run do
  $stderr.puts "grandparent: #{Process.pid}"
  EM::PeriodicTimer.new(1) { $stderr.puts "grandparent: #{Process.pid} ." }
  EM::Timer.new(5) { Process.exit }
  EmActor::Actor.new(Object.new) do |parent|
    $stderr.puts "parent: #{Process.pid}"
    EM::PeriodicTimer.new(1) { $stderr.puts "parent: #{Process.pid} ." }
    EM::Timer.new(10) { Process.exit }
    parent.no_exit_with_parent
    1.times do
      $stderr.puts "#{Process.pid} spawning a kid"
      grandkid = EmActor::Actor.new(Object.new) do |grandchild|
        $stderr.puts "kid: #{Process.pid}"
        EM::PeriodicTimer.new(1) { $stderr.puts "kid: #{Process.pid} ." }
        EM::Timer.new(3) { EM.stop }
      end
      $stderr.puts "#{Process.pid} kid is #{grandkid.pid}"
    end
    parent.exit_with_parent
  end
end
