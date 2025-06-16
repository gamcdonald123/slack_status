#!/usr/bin/env ruby
require_relative '../config/environment'
require_relative '../lib/ms_graph'

puts "🔐 Testing Microsoft Graph Authentication"
puts "=" * 50

begin
  # Test authentication
  puts "📡 Attempting to connect to Microsoft Graph..."
  client = MsGraph.new.client

  # Test calendar access directly (this is what we actually need)
  puts "📅 Testing calendar access..."
  start_time = Date.today.iso8601
  end_time = (Date.today + 1).iso8601

  query_params = MicrosoftGraph::Me::CalendarView::CalendarViewRequestBuilder::CalendarViewRequestBuilderGetQueryParameters.new
  query_params.start_date_time = "#{start_time}T00:00:00Z"
  query_params.end_date_time = "#{end_time}T23:59:59Z"
  query_params.top = 5

  request_config = MicrosoftKiotaAbstractions::RequestConfiguration.new
  request_config.query_parameters = query_params

  events = client.me.calendar_view.get(request_config).resume

  if events.respond_to?(:value)
    puts "✅ Calendar access successful! Found #{events.value.count} events today."
    if events.value.any?
      puts "📋 Sample events:"
      events.value.first(3).each do |event|
        puts "  - #{event.subject} (#{event.start&.date_time || event.start&.date})"
      end
    else
      puts "📋 No events found for today."
    end
  else
    puts "⚠️ Calendar access successful but unexpected response format"
  end

  puts "\n🎉 Authentication test passed!"
  puts "💾 Token saved to: #{MsGraph::TOKEN_FILE}"
  puts "✅ Ready for automated execution!"

rescue => e
  puts "❌ Authentication test failed:"
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
  exit 1
end
