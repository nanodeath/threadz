['atomic_integer', 'sleeper', 'errors'].each { |lib| require File.join(File.dirname(__FILE__), lib) }

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
        @error_lock = Mutex.new
        @errors = []
        @error_handler = opts[:error_handler]
        if @error_handler && !@error_handler.respond_to?(:call)
          raise ArgumentError.new("ErrorHandler must respond to #call")
        end

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
        raise "Threadz: thread deadlocked because batch job was never started" if @latent && !@started

        timeout = opts.key?(:timeout) ? opts[:timeout] : 0
        @sleeper.wait(timeout) unless completed?
        errors = self.errors
        if !errors.empty? && !@error_handler
          raise JobError.new(errors)
        end
      end

      # Returns true iff there are no jobs outstanding.
      def completed?
        return @jobs_count.value == 0
      end

      # Returns the list of errors that occurred
      def errors
        arr = nil
        @error_lock.synchronize { arr = @errors.dup }
        arr
      end

      # If this is a latent batch, start processing all of the jobs in the queue.
      def start
				@job_lock.synchronize {  # in case another thread tries to push new jobs onto the queue while we're starting
          if @latent
            @started = true
            until @job_queue.empty?
              send_to_threadpool @job_queue.pop
            end
            return true
          else
            return false
          end
				}
      end

      # Execute a given block when the batch has finished processing.  If the batch
      # has already finished executing, execute immediately.
      def when_done(&block)
        @job_lock.synchronize { completed? ? block.call : @when_done_blocks << block }
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
          control = Control.new
          begin
            control.reset_retry
            job.call
          rescue StandardError => e
            @error_lock.synchronize { @errors << e }
            control.errors << e
            if @error_handler
              @error_handler.call(e, control)
              if control.retry?
                retry
              end
            end
          end
          # Lock in case we get two threads at the "fork in the road" at the same time
					# Note: locking here actually creates undesirable behavior.  Still investigating why,
					# seems like it should be useful.
          #@job_lock.lock
          @jobs_count.decrement
          # fork in the road
          handle_done if completed?
          #@job_lock.unlock
        end
      end
    end
end
