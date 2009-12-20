require 'thread'

module Threadz

  # The ThreadPool class contains all the threads available to whatever context
  # has access to it.
  class ThreadPool
    # Default setting for kill threshold
    KILL_THRESHOLD = 10
    # Setting for how much to decrement current kill score by for each queued job
    THREADS_BUSY_SCORE = 1
    # Setting for how much to increment current kill score by for *each* idle thread
    THREADS_IDLE_SCORE = 1

    # Creates a new thread pool into which you can queue jobs.
    # There are a number of options:
    # :initial_size:: The number of threads you start out with initially.  Also, the minimum number of threads.
    #                 By default, this is 10.
    # :maximum_size:: The highest number of threads that can be allocated.  By default, this is the minimum size x 5.
    # :kill_threshold:: Constant that determines when new threads are needed or when threads can be killed off.
    #                   If the internally tracked kill score falls to positive kill_threshold, then a thread is killed off and the
    #                   kill score is reset.  If the kill score rises to negative kill_threshold, then a new thread
    #                   is created and the kill score is reset.  Every 0.1 seconds, the state of all threads in the
    #                   pool is checked.  If there is more than one idle thread (and we're above minimum size), the
    #                   kill score is incremented by THREADS_IDLE_SCORE for each idle thread.  If there are no idle threads
    #                   (and we're below maximum size) the kill score is decremented by THREADS_KILL_SCORE for each queued job.
    def initialize(opts={})
      @min_size = opts[:initial_size] || 10 # documented
      @max_size = opts[:maximum_size] || @min_size * 5 # documented

      # This is our main queue for jobs
      @queue = Queue.new
      @worker_threads_count = AtomicInteger.new(0)
      @min_size.times { spawn_thread }
      @killscore = 0
      @killthreshold = opts[:kill_threshold] || KILL_THRESHOLD # documented

      spawn_watch_thread
    end
    
    def thread_count
      @worker_threads_count.value
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
      Thread.new do
        while true
          x = @queue.shift
          if x == Directive::SUICIDE_PILL
          	@worker_threads_count.decrement
          	Thread.current.terminate
          end
          Thread.pass
          begin
            x.call
          rescue StandardError => e
            $stderr.puts "Threadz: Error in thread, but restarting with next job: #{e.inspect}\n#{e.backtrace.join("\n")}"
          end
        end
      end
      @worker_threads_count.increment
    end

    # Kill a thread after it completes its current job
    def kill_thread
      @queue.unshift(Directive::SUICIDE_PILL)
    end

    # This thread watches over the pool and allocated and deallocates threads
    # as necessary
    def spawn_watch_thread
      @watch_thread = Thread.new do
        while true
          # If there are idle threads and we're above minimum
          if @queue.num_waiting > 0 && @worker_threads_count.value > @min_size # documented
            @killscore += THREADS_IDLE_SCORE * @queue.num_waiting
          
          # If there are no threads idle and we have room for more
          elsif(@queue.num_waiting == 0 && @worker_threads_count.value < @max_size) # documented
            @killscore -= THREADS_BUSY_SCORE * @queue.length
          
          else
            # Decay,
            if(@killscore != 0)
              @killscore *= 0.9
            end
            if(@killscore.abs < 1)
              @killscore = 0
            end
          end
          if @killscore.abs >= @killthreshold
            @killscore > 0 ? kill_thread : spawn_thread
            @killscore = 0
          end
          puts "killscore: #{@killscore}. waiting: #{@queue.num_waiting}.  threads length: #{@worker_threads_count.value}.  min/max: [#{@min_size}, #{@max_size}]" if $DEBUG
          sleep 0.1
        end
      end
    end
  end
end