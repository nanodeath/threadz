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

# Example:
#  T = ThreadPool.new
#  b = T.new_batch
#  b << lambda { puts "foo" },
#  b << lambda { puts "bar" },
#  b << [ lambda { puts "can" }, lamba { puts "monkey" }]
#  b.wait_until_done

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
    #                   If the internally tracked kill score falls to positive kill_threshold, then a thread is killed off and the
    #                   kill score is reset.  If the kill score rises to negative kill_threshold, then a new thread
    #                   is created and the kill score is reset.  Every 0.01 seconds, the state of all threads in the
    #                   pool is checked.  If there is more than one idle thread (and we're above minimum size), the
    #                   kill score is incremented by THREADS_IDLE_SCORE.  If there are no idle threads (and
    #                   we're below maximum size) the kill score is decremented by THREADS_KILL_SCORE.
    def initialize(opts={})
      @min_size = opts[:initial_size] || 4 # documented
      @max_size = opts[:maximum_size] || @min_size * 5 # documented

      # This is our main queue for jobs
      @queue = Queue.new
      @threads = []
      @min_size.times { spawn_thread }
      @killscore = 0
      @killthreshold = opts[:kill_threshold] || KILL_THRESHOLD # documented

      spawn_watch_thread
    end

    # Push a process onto the job queue for the thread pool to pick up.
    # Note that using this method, you can't keep track of when the job
    # finishes.  If you care about when it finishes, use batches.
    def process(&block)
      @queue << block
      nil
    end

    # Return a new batch that's attached into this thread pool.  See Threadz::ThreadPool::Batch
    # for documention on opts.
    def new_batch(opts={})
      return Batch.new(self, opts)
    end

    private

    # Spin up a new thread
    def spawn_thread
      @threads << Thread.new do
        while true
          x = @queue.shift
          begin
            x.call
          rescue Exception => e
            puts e.inspect
          end
          exit if Thread.current[:suicide]
        end
      end
      puts "spawning thread: now thread count is #{@threads.length}" if $DEBUG
    end

    # Kill a thread after it completes its current job
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
          if @queue.num_waiting > 1 && @threads.length > @min_size # documented
            @killscore += THREADS_IDLE_SCORE
            # If there are no threads idle and we have room for more
          elsif(@queue.num_waiting == 0 && @threads.length < @max_size) # documented
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
          
          sleep 0.01
        end
      end
    end

    # A batch is a collection of jobs you care about that gets pushed off to
    # the attached thread pool.  The calling thread can be signaled when the
    # batch has completed executing.
    class Batch
      # Creates a new batch attached to the given threadpool.  A number of options
      # are available:
      # +:latent+:: If latent, none of the jobs in the batch will actually start
      #            executing until the +start+ method is called.
      def initialize(threadpool, opts={})
        @threadpool = threadpool
        @waiting_threads = []
        @jobs = 0
        @when_done_blocks = []

        ## Options

        #latent
        @latent = opts.key?(:latent) ? opts[:latent] : false
        @job_queue = [] if @latent
      end

      # Add a new job to the batch.  If this is a latent batch, the job can't
      # be scheduled until the batch is #start'ed; otherwise it may start
      # immediately.  The job can be anything that responds to +call+ or an
      # array of objects that respond to +call+.
      def <<(job)
        if job.is_a? Array
          job.each {|j| self << j}
        elsif job.respond_to? :call
          @jobs += 1
          if @latent
            @job_queue << job
          else
            send_to_threadpool job
          end
        else
          raise "Not a valid job: needs to support #call"
        end
      end

      alias_method(:push, :<<)

      # Put the current thread to sleep until the batch is done processing.
      # There are options available:
      # +:timeout+:: If specified, will only wait for at least this many seconds
      #              for the batch to finish.  Typically used with #completed?
      def wait_until_done(opts={})
        Thread.exclusive do
          return if completed?
          @waiting_threads << Thread.current
          timeout = opts.key?(:timeout) ? opts[:timeout] : -1
          if timeout > 0.0
            # Go to sleep for at most timeout seconds.  It will wake up again if
            # Thread#wakeup is called on it, though.
            sleep(timeout)
          else
            Thread.stop
          end
        end
      end

      # Returns true iff there are no unfinished jobs in the queue.
      def completed?
        return @jobs == 0
      end

      # If this is a latent batch, start processing all of the jobs in the queue.
      def start
        
        Thread.exclusive do # in case another thread tries to push new jobs onto the queue while we're starting
          if @latent
            until @job_queue.empty?
              send_to_threadpool @job_queue.pop
            end
            return true
          else
            return false
          end
        end
      end

      # Execute a given block when the batch has finished processing.  If the batch
      # has already finished executing, execute immediately.
      def when_done(&block)
        Thread.exclusive do # in case a new job gets added between completed? and block.call
          if completed?
            block.call
          else
            @when_done_blocks << block
          end
        end
      end

      private
      def signal_done
        @waiting_threads.shift.wakeup until @waiting_threads.empty?
        @when_done_blocks.shift.call until @when_done_blocks.empty?
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