$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))
require 'spec_helper'

describe Threadz do
	describe Fixnum do
		it "should perform badly when under heavy thread usage" do
			# This test should always fail, but there is a small chance it won't...
			
			i = 0
			n = 100_000
			threads = 100
			t = []
			threads.times do
				t << Thread.new do
					sleep 0.1
					n.times { i += 1 }
				end
				t << Thread.new do 
					sleep 0.1
					n.times { i -= 1 }
				end
			end
			t.each { |thread| thread.join }
			i.should_not == 0
		end
	end
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