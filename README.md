# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

# Slack Status Automation

This Rails application automatically updates your Slack status based on your Microsoft Outlook calendar events.

## Features

- Automatically detects all-day calendar events with specific prefixes (WFH, GFC, GPH, GNW, GFF, Holiday)
- Updates Slack status with appropriate emoji and text based on calendar events
- Handles Microsoft Graph authentication automatically with token refresh
- Designed to run as a scheduled job

## Setup

### Environment Variables

Set the following environment variables:

```bash
# Microsoft Graph API credentials
MS_CLIENT_ID=your_microsoft_client_id
MS_CLIENT_SECRET=your_microsoft_client_secret
MS_TENANT_ID=your_tenant_id  # Optional, defaults to "common"

# Slack API token
SLACK_USER_API_TOKEN=xoxp-your-slack-user-token
```

### Initial Authentication

1. **Test authentication setup:**
   ```bash
   ruby script/test_auth.rb
   ```
   This will guide you through the Microsoft authentication process.

2. **Run the status update script:**
   ```bash
   ruby script/update_status_from_calendar.rb
   ```

## Calendar Event Prefixes

The script looks for all-day events with these prefixes:

- `WFH` → "Home or Other Office" :here:
- `GFC` → "GFC based today" :office:
- `GPH` → "GPH based today" :satellite_antenna:
- `GNW` → "GNW based today" :flag-wales:
- `GFF` → "GFF based today" :flag-wales:
- `Holiday` → "Not working today" :away:

## Authentication

The application uses Microsoft Graph's device code flow for authentication:

- Tokens are automatically refreshed when expired
- Authentication state is persisted in `tmp/ms_graph_token.json`
- The script will automatically retry authentication if tokens become invalid
- No manual intervention required after initial setup

## Scheduling

To run this automatically, set up a cron job or use a task scheduler:

```bash
# Example cron job to run every 15 minutes during work hours
*/15 9-17 * * 1-5 cd /path/to/app && ruby script/update_status_from_calendar.rb
```

## Troubleshooting

- If authentication fails, run `ruby script/test_auth.rb` to re-authenticate
- Check the logs for detailed error messages
- Ensure all required environment variables are set
- Verify your Microsoft app has the correct permissions (Calendars.Read)
