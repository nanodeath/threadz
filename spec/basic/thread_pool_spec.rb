require 'net/http'

describe Threadz::ThreadPool do
	before(:each) do
		@T = Threadz::ThreadPool.new
	end

	it "should perform well for IO jobs" do
		urls = []
		urls << "http://www.google.com/" << "http://www.yahoo.com/" << 'http://www.microsoft.com/'
		urls << "http://www.cnn.com/" << "http://slashdot.org/" << "http://www.mozilla.org/"
		urls << "http://www.ubuntu.com/" << "http://github.com/"
		time_single_threaded = Time.now

		begin
			(urls * 2).each do |url|
				response = Net::HTTP.get_response(URI.parse(url))
				body = response.body
			end

			time_single_threaded = Time.now - time_single_threaded

			time_multi_threaded = Time.now
			b = @T.new_batch
			(urls * 2).each do |url|
				b << Proc.new do
					response = Net::HTTP.get_response(URI.parse(url))
					body = response.body
				end
			end

			b.wait_until_done
			time_multi_threaded = Time.now - time_multi_threaded

			time_multi_threaded.should < time_single_threaded

		rescue SocketError
			pending "pending working internet connection"
		end
	end
end
