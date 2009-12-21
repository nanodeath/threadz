require 'timeout'

describe Threadz::Batch do
	before(:each) do
		@T = Threadz::ThreadPool.new(:initial_size => 25)
	end

	it "shouldn't fail under load" do
		jobs = 1000
		times_per_job = 1000
		i = ::Threadz::AtomicInteger.new(0)

		b1 = @T.new_batch(:latent => true)
		b2 = @T.new_batch(:latent => true)

		jobs.times do
			b1 << lambda { times_per_job.times { i.increment } }
			b2 << lambda { times_per_job.times { i.decrement } }
		end

		b1.start
		b2.start

		b1.wait_until_done
		b2.wait_until_done

		i.value.should == 0
	end
end
