['atomic_integer', 'sleeper'].each { |lib| require File.join(File.dirname(__FILE__), lib) }

module Threadz
    # A batch is a collection of jobs you care about that gets pushed off to
    # the attached thread pool.  The calling thread can be signaled when the
    # batch has completed executing, or a block can be executed.
    class Batch
      # Creates a new batch attached to the given threadpool.  A number of options
      # are available:
      # +:latent+:: If latent, none of the jobs in the batch will actually start
      #            executing until the +start+ method is called.
      def initialize(threadpool, opts={})
        @threadpool = threadpool
        @waiting_threads = []
        @job_lock = Mutex.new
        @jobs_count = AtomicInteger.new(0)
        @when_done_blocks = []
        @sleeper = ::Threadz::Sleeper.new

        ## Options

        #latent
        @latent = opts.key?(:latent) ? opts[:latent] : false
        if(@latent)
          @started = false
        else
          @started = true
        end
        @job_queue = Queue.new if @latent
      end

      # Add a new job to the batch.  If this is a latent batch, the job can't
      # be scheduled until the batch is #start'ed; otherwise it may start
      # immediately.  The job can be anything that responds to +call+ or an
      # array of objects that respond to +call+.
      def push(job)
        if job.is_a? Array
          job.each {|j| self << j}
        elsif job.respond_to? :call
          @jobs_count.increment
          if @latent && !@started
            @job_queue << job
          else
            send_to_threadpool job
          end
        else
          raise "Not a valid job: needs to support #call"
        end
      end

      alias << push

      # Put the current thread to sleep until the batch is done processing.
      # There are options available:
      # +:timeout+:: If specified, will only wait for at least this many seconds
      #              for the batch to finish.  Typically used with #completed?
      def wait_until_done(opts={})
        return if completed?

        raise "Threadz: thread deadlocked because batch job was never started" if @latent && !@started

        timeout = opts.key?(:timeout) ? opts[:timeout] : 0
        #raise "Timeout not supported at the moment" if timeout

        @sleeper.wait(timeout)
      end

      # Returns true iff there are no unfinished jobs in the queue.
      def completed?
        return @jobs_count.value == 0
      end

      # If this is a latent batch, start processing all of the jobs in the queue.
      def start
        Thread.exclusive do # in case another thread tries to push new jobs onto the queue while we're starting
          if @latent
            @started = true
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
        @job_lock.lock
        if completed?
          block.call
        else
          @when_done_blocks << block
        end
        @job_lock.unlock
      end

      private
      def handle_done
        @sleeper.broadcast
        @when_done_blocks.each do |b|
          b.call
        end
        @when_done_blocks = []
      end

      def send_to_threadpool(job)
        @threadpool.process do
          job.call
          # Lock in case we get two threads at the "fork in the road" at the same time
          @job_lock.lock
          @jobs_count.decrement
          # fork in the road
          handle_done if completed?
          @job_lock.unlock
        end
      end
    end
end