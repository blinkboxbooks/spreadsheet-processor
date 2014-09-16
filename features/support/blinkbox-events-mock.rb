# A simple library to mock the Blinkbox::Events structure.
# 
# Any event requested will be created on-the-fly and can checked at a later date (ie. in tests) to interrogate messages 'delivered'
#
#     msg = Blinkbox::Events::AnyCategoryName::AnyEventName.new({:hello => 'world'})
#     msg.deliver
#
#     Blinkbox::Events::AnyCategoryName::AnyEventName.messages
#     # => [{:hello => 'world'}]
module Blinkbox
	module Events

		def self.messages
			@@messages ||= {}
		end

		# This fake event allows the test machine to look at all the messages which have been delivered by other code.
		#
		#     msg = Blinkbox::Events::AnyCategoryName::AnyEventName.new({:hello => 'world'})
		#     msg.deliver
		#
		#     Blinkbox::Events::AnyCategoryName::AnyEventName.messages
		#     # => [{:hello => 'world'}]
		class FakeEvent
			def initialize(msg)
				Blinkbox::Events.messages[self.class] ||= []
				@msg = msg
			end

			def deliver
				Blinkbox::Events.messages[self.class].push @msg
				yield if block_given?
				true
			end

			def self.messages
				Blinkbox::Events.messages[self] || []
			end

			def self.clear
				Blinkbox::Events.messages[self] = []
			end
		end

		# This fake category has meta-programming code to create a class as it's requested. It'll create the class with the
		# FakeEvent as a superclass, so we can collect the results
		module FakeCategory
			# We do this as an instance method so when we extend the module in the next piece of code it'll come through as a module method (not an instance method): http://www.railstips.org/blog/archives/2009/05/15/include-vs-extend-in-ruby/
			def const_missing(event)
				self.module_eval("class #{event} < FakeEvent; end")
				const_get(event)
			end
		end

		# This method looks for any Constant requet of Blinkbox::Events and generates the module on-the-fly. It also extends that module with the FakeCategory module above, so that you can immediately request an Event class and start fake delivering messages.
		def self.const_missing(category)
			self.module_eval("module #{category}; extend FakeCategory; end")
			const_get(category)
		end

		def self.clear_all
			Blinkbox::Events.messages.clear
		end
	end
end