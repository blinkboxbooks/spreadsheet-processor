require 'stringio'
require 'fileutils'

Given(/^the (file|folder) "([^\"]+)" (does not exist|exists)$/) do |type, file,exists|
  path = File.join(@dir,file)

  if exists == "does not exist"
    raise RuntimeError, "#{file} should not exist for this test" if File.exists?(path)
  else
    if type == 'file'
      FileUtils.touch(path)
    else
      FileUtils.mkdir_p(path)
    end
  end
end

When(/^(?:it is|they are) found by the watcher$/) do
  @uploads.each do |file|
  	@watcher.send(:file_found,file['location'])
  end
end

Then(/^"([^\"]+)" is( not)? a (file|folder)$/) do |file, exists, type|
  (@paths ||= {})[type] = File.join(@dir,file)

  expect(File.exists?(@paths[type])).to eql(exists.nil?), "The expected #{type} #{exists.nil? ? 'does not exist' : 'exists'}."

  if exists.nil?
    desired_mode = (type == "file") ? "0664" : "0775"
    actual_mode = File.stat(@paths[type]).mode.to_s(8)[-4..-1]
    expect(actual_mode).to eq(desired_mode) 
  end
end