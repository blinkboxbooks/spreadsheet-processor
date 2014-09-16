def validate_message_attribute(message, attribute, content)
	if content.nil? or content.empty?
		# It's valid, this message isn't expected to have this attribute
	else
		if attribute == 'uri'
			# Check the end of the message only
			message[attribute] = message[attribute][(content.length*-1)..-1]
		end

		expect(message[attribute]).to eql(content)
	end
end

Then(/^the following message(?:s are| is) posted to the "([^\"]+)" queue:$/) do |queue_name, table|
	type, queue = queue_name.split('.')
	message_class = Blinkbox::Events.const_get(type).const_get(queue)

	expect(message_class.messages.size).to eq(table.hashes.length)

	message_class.messages.each_with_index do |message, i|
		table.hashes[i].each_pair do |attribute, content|
			validate_message_attribute(message, attribute, content)
		end
	end
end