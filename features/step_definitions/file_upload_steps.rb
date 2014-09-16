require 'fileutils'
require 'securerandom'
require 'zip'
require 'rspec/matchers'
require 'equivalent-xml'

Given(/^"(.*)" is a zip file containing "(.*)"$/) do |zipfile, containing_filename|
  stringio = Zip::OutputStream::write_buffer do |zio|
    zio.put_next_entry(containing_filename)
  end

  stringio.rewind
  @contents[zipfile] = stringio.sysread
end

Given(/^the following file(?:s are| is) uploaded:$/) do |table|
  @uploads = table.hashes.collect do |file|
  	filepath = File.join(@dir,file['folder'])

  	file['content'] = @contents[file['filename']] || SecureRandom.base64
  	file['location'] = File.join(filepath, file['filename'])

    open(file['location'],'w') do |f|
      f.write file['content']
    end

    file
  end
end

Given(/^the example file "(.*?)" exists$/) do |example_filename|
  @contents[example_filename] = open(File.join(File.dirname(__FILE__),"..","support","examples",example_filename)) do |f|
    f.read
  end
end

Then(/(?:its|their) permissions (?:is|are) changed to ([0-7]{4})/) do |desired_perms|
  @uploads.each do |file|
  	real_perms = File.stat(file['location']).mode.to_s(8)[-4..-1]

  	real_perms.should eql(desired_perms)
  end
end

Then(/^these files exist and match their examples:$/) do |table|
  table.hashes.each do |file|
    publisher_file = File.join(@dir,file[:filename])
    example_file = File.join(File.dirname(__FILE__),"..","support","examples",file[:example_filename])

    expect(File).to exist(publisher_file)

    expected_doc = Nokogiri::XML( open(example_file) { |f| f.read } )
    received_doc = Nokogiri::XML( open(publisher_file) { |f| f.read } )

    expect(received_doc).to be_equivalent_to(expected_doc)
  end
end