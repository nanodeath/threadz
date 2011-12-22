# Threadz is a library that makes it easier to queue up batches of jobs and
# execute them as the developer pleases.  With Threadz, it's also easier to
# wait on that batch completing: i.e. fire off 5 jobs at the same time and then
# wait until they're all finished.  Of course, this is also a threadpool: the
# number of threads available for scheduling can scale up and down as load
# requires.
#
# Author::       Max Aller (mailto: nanodeath@gmail.com)
# Copyright::    Copyright (c) 2009
# License::      Distributed under the MIT License

# Example:
#  T = ThreadPool.new
#  b = T.new_batch
#  b << lambda { puts "foo" },
#  b << lambda { puts "bar" },
#  b << [ lambda { puts "can" }, lamba { puts "monkey" }]
#  b.wait_until_done

require 'thread'

require "threadz/version"

module Threadz
  DEBUG = ENV['THREADZ_DEBUG'] == "1"
  
  def Threadz.dputs(string)
    puts(string) if DEBUG
  end
end

Threadz::dputs("Loading threadz")

['atomic_integer', 'sleeper', 'directive', 'batch', 'thread_pool'].each { |lib| require File.join(File.dirname(__FILE__), 'threadz', lib) }

