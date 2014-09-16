Then(/^a warning message is added to the log$/) do
  @log.rewind
  log_output = nil
  
  expect {
    log_output = JSON::load(@log.read)
  }.to_not raise_error

  expect(log_output['severity']).to eq("WARN")
end