require_relative '../config/environment'
require_relative '../lib/ms_graph'
require 'microsoft_kiota_abstractions'
require 'slack-ruby-client'

client = MsGraph.new.client

start_time = Date.today.iso8601
end_time   = (Date.today + 1).iso8601

# Build query parameters using the correct class
query_params = MicrosoftGraph::Me::CalendarView::CalendarViewRequestBuilder::CalendarViewRequestBuilderGetQueryParameters.new
query_params.start_date_time = "#{start_time}T00:00:00Z"
query_params.end_date_time   = "#{end_time}T23:59:59Z"
query_params.top             = 50

request_config = MicrosoftKiotaAbstractions::RequestConfiguration.new
request_config.query_parameters = query_params

begin
  events = client
    .me
    .calendar_view
    .get(request_config)
    .resume

  puts "✅ Successfully retrieved events:"

  # Check if events have a value property
  if events.respond_to?(:value)
    puts "\n📅 Events found: #{events.value.count}"
    events.value.each do |event|
      puts "- #{event.subject} (#{event.start&.date_time || event.start&.date})"
    end

    prefixes = [ "WFH", "GFC", "GPH", "GNW", "GFF", "Holiday" ]

    filtered_events = events.value.select do |event|
      event.is_all_day &&
        event.subject &&
        prefixes.any? { |prefix| event.subject.start_with?(prefix) }
    end

    puts "\n🗓️ Filtered all-day events with desired prefixes:"
    filtered_events.each do |event|
      puts "- #{event.subject} (#{event.start&.date_time || event.start&.date})"
    end

    # Set Slack status based on the first matching event
    if filtered_events.any?
      event = filtered_events.first
      case event.subject
      when /WFH/
        status_text = "Home or Other Office"
        status_emoji = ":here:"
      when /GFC/
        status_text = "GFC based today"
        status_emoji = ":office:"
      when /GPH/
        status_text = "GPH based today"
        status_emoji = ":satellite_antenna:"
      when /GNW/
        status_text = "GNW based today"
        status_emoji = ":flag-wales:"
      when /GFF/
        status_text = "GFF based today"
        status_emoji = ":flag-wales:"
      when /Holiday/
        status_text = "Not working today"
        status_emoji = ":away:"
      end

      # Find the matching prefix and get its emoji
      matching_prefix = prefixes.find { |prefix| event.subject.start_with?(prefix) }

      slack_client = Slack::Web::Client.new
      slack_client.users_profile_set(
        profile: {
          status_text: status_text,
          status_emoji: status_emoji,
          status_expiration: Time.now.end_of_day.to_i
        }
      )
      puts "\n✅ Slack status set to: #{status_emoji} #{status_text}"
    else
      puts "\n❌ No matching all-day event found for Slack status."
    end
  else
    puts "\n📅 Events found: #{events.count}" if events.respond_to?(:count)
    puts events
  end

rescue MicrosoftGraph::Models::ODataErrorsODataError => e
  puts "🔴 Microsoft Graph returned an OData error:"
  puts e&.error&.code
  puts e&.error&.message
  puts e.inspect
rescue => e
  puts "⚠️ Other error:"
  puts e.message
  puts e.backtrace.join("\n")
end

# Filter for all-day events
# all_day_events = events.value.select { |event| event.is_all_day }
#
# puts "🗓️ All-day events today:"
# all_day_events.each do |event|
#   puts "- #{event.subject} (#{event.start.date_time})"
# end
