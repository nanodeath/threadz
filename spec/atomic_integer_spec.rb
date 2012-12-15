$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))
require 'spec_helper'

describe Threadz do
	describe Threadz::AtomicInteger do
		it "should perform better than an int for counting" do
			i = Threadz::AtomicInteger.new(0)
			n = 10_000
			threads = 10
			t = []
			threads.times do
				t << Thread.new do
					sleep 0.05
					n.times { i.increment }
				end
				t << Thread.new do 
					sleep 0.05
					n.times { i.decrement }
				end
			end
			t.each { |thread| thread.join }
			i.value.should == 0
		end
	end
end