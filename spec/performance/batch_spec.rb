require 'timeout'

describe Threadz::Batch do
	before(:each) do
		@T = Threadz::ThreadPool.new
	end

	it "shouldn't fail under load" do
		jobs = 100
		times_per_job = 100
		i = ::Threadz::AtomicInteger.new(0)

		b1 = @T.new_batch(:latent => true)
		b2 = @T.new_batch(:latent => true)

		jobs.times do
			b1 << lambda { times_per_job.times { i.increment } }
			b2 << lambda { times_per_job.times { i.decrement } }
		end

		begin
			Timeout::timeout(30) do
				b1.start
				# Got stuck here once on 12/19/09 11:07 PM
				b2.start

				b1.wait_until_done
				b2.wait_until_done
			end
		rescue Timeout::Error
			$stderr.puts "Timeout hit: i was #{i.inspect}."
		end


		i.value.should == 0
	end
end
