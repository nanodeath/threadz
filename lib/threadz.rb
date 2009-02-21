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
require 'thread'

=begin
  T = ThreadPool.new
  b = T.new_batch
  b << lambda { puts "foo" },
  b << lambda { puts "bar" },
  b << [ lambda { puts "can" }, lamba { puts "monkey" }]
  b.wait_until_done
  if b.completed?

=end

# All logic is contained in the Threadz namespace
module Threadz

  # The ThreadPool class contains all the threads available to whatever context
  # has access to it.
  class ThreadPool
    # Default setting for kill threshold
    KILL_THRESHOLD = 100
    # Setting for how much to decrement current kill score by when threads are very busy
    THREADS_BUSY_SCORE = 20
    # Setting for how much to increment current kill score by when there are excess idle threads
    THREADS_IDLE_SCORE = 20 

    # Creates a new thread pool into which you can queue jobs.
    # There are a number of options:
    # :initial_size:: The number of threads you start out with initially.  Also, the minimum number of threads.
    #                 By default, this is 4.
    # :maximum_size:: The highest number of threads that can be allocated.  By default, this is the minimum size x 5.
    # :kill_threshold:: Constant that determines when new threads are needed or when threads can be killed off.
    #                   If the kill score falls to negative kill_threshold, then a thread is killed off and the
    #                   kill score is reset.  If the kill score rises to positive kill_threshold, then a new thread
    #                   is created and the kill score is reset.  Every 0.01 seconds, the state of all threads in the
    #                   pool is checked.  If there is more than one idle thread (and we're above minimum size), the
    #                   kill score is incremented by THREADS_IDLE_SCORE.  If there are no idle threads (and
    #                   we're below maximum size) the kill score is decremented by THREADS_KILL_SCORE.
    def initialize(opts={})
      @min_size = opts[:initial_size] || 4 # documented
      @max_size = opts[:maximum_size] || @min_size * 5 # documented
      @queue = {}
      @batch_order = Queue.new
      @working_count = {}
      @threads = []
      @min_size.times { spawn_thread }
      @killscore = 0
      @killthreshold = opts[:kill_threshold] || KILL_THRESHOLD # documented

      spawn_watch_thread
    end


    def process(batch_name=:default, &block)
      (@queue[batch_name] ||= []).push block
      @batch_order << batch_name
    end

#    def wait_until_done(batch_name=:default)
#      return if @queue[batch_name].nil? or @working_count[batch_name].nil?
#      sleep 0.001 until @queue[batch_name].empty?
#      sleep 0.001 until @working_count[batch_name] <= 0
#    end

    def new_batch(opts={})
      return Batch.new(self, opts)
    end

    private
    def jobs_queued
      @batch_order.length
    end

    def spawn_thread
      @threads << Thread.new do
        while true
          next_batch = @batch_order.pop
          x = nil
          Thread.exclusive do
            x = @queue[next_batch].pop
            @working_count[next_batch] ||= 0
            @working_count[next_batch] += 1
          end
          begin
            x.call
          rescue Exception => e
            puts e.inspect
          ensure
            #          Thread.exclusive do
            @working_count[next_batch] -= 1
            #          end
          end
          exit if Thread.current[:suicide]
        end
      end
      puts "spawning thread: now thread count is #{@threads.length}" if $DEBUG
    end

    def kill_thread
      Thread.exclusive do
        t = @threads.pop
        t[:suicide] = true unless t.nil?
      end
      puts "killing thread: now threadcount is #{@threads.length}" if $DEBUG
    end

    # This thread watches over the pool and allocated and deallocates threads
    # as necessary
    def spawn_watch_thread
      @watch_thread = Thread.new do
        while true
          # If there are idle threads and we're above minimum
          if @batch_order.num_waiting > 1 && @threads.length > @min_size # documented
            @killscore += THREADS_IDLE_SCORE
            # If there are no threads idle and we have room for more
          elsif(@batch_order.num_waiting == 0 && @threads.length < @max_size) # documented
            @killscore -= THREADS_KILL_SCORE
          else
            # Decay,
            if(@killscore < 0)
              @killscore += 1
            elsif(@killscore > 0)
              @killscore -= 1
            end
          end
          if @killscore.abs >= @killthreshold
            @killscore > 0 ? kill_thread : spawn_thread
            @killscore = 0
          end
#          if @killscore >= @killthreshold
#            @killscore = 0
#            kill_thread
#          end
#          if @killscore *-1 >= @killthreshold
#            @killscore = 0
#            spawn_thread
#          end
          sleep 0.01
        end
      end
    end

    class Batch
      def initialize(threadpool, opts={})
        @threadpool = threadpool
        @waiting_threads = []
        @jobs = 0

        ## Options

        #latent
        @latent = opts.key?(:latent) ? opts[:latent] : false
        @job_queue = [] if @latent
      end

      def << job
        if job.is_a? Array
          job.each {|j| self << j}
        else
          @jobs += 1
          if @latent
            @job_queue << job
          else
            send_to_threadpool job
          end
        end
      end

      alias_method(:push, :<<)

      def wait_until_done(opts={})
        return if completed?
        @waiting_threads << Thread.current
        timeout = opts.key?(:timeout) ? opts[:timeout] : -1
        if timeout > 0.0
          sleep(timeout)
        else
          Thread.stop
        end
      end

      def completed?
        return @jobs == 0
      end

      def start
        if @latent
          until @job_queue.empty?
            send_to_threadpool @job_queue.pop
          end
          return true
        else
          return false
        end
      end

      private
      def signal_done
        Thread.exclusive do
          @waiting_threads.pop.wakeup until @waiting_threads.empty?
        end
      end

      def send_to_threadpool job
        @threadpool.process do
          job.call
          @jobs -= 1
          signal_done if completed?
        end
      end
    end
  end
end