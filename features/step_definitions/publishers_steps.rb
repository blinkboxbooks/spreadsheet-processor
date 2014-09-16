Given(/^there is a publisher called "([^\"]+)"$/) do |publisher|
	FileUtils.mkdir_p File.join(@dir,publisher)
end