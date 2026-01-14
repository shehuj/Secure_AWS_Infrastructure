# AWS CloudWatch Logs - Complete Viewing Guide

## Table of Contents
1. [Quick Reference](#quick-reference)
2. [AWS Console (Web UI)](#aws-console-web-ui)
3. [AWS CLI Commands](#aws-cli-commands)
4. [CloudWatch Insights Queries](#cloudwatch-insights-queries)
5. [Log Groups in This Project](#log-groups-in-this-project)
6. [Common Use Cases](#common-use-cases)

---

## Quick Reference

### Fastest Ways to View Logs

**1. Real-time tail (like `tail -f`):**
```bash
aws logs tail LOG_GROUP_NAME --follow
```

**2. Last hour:**
```bash
aws logs tail LOG_GROUP_NAME --since 1h
```

**3. Filter by keyword:**
```bash
aws logs tail LOG_GROUP_NAME --filter-pattern "ERROR"
```

**4. Web browser:**
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups
```

---

## AWS Console (Web UI)

### Access CloudWatch Logs

1. **Open AWS Console:**
   - Go to https://console.aws.amazon.com/
   - Search for "CloudWatch" in the services search bar
   - Or use direct link: https://console.aws.amazon.com/cloudwatch/

2. **Navigate to Logs:**
   - Left sidebar → Click "Logs" → "Log groups"
   - Or direct link: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups

3. **View a Log Group:**
   - Click on any log group name
   - Click on a log stream
   - View individual log events

4. **Search Logs:**
   - In the log group view, click "Search log group"
   - Enter search terms or filter patterns
   - Select time range
   - Click "Search log group"

### CloudWatch Insights (Advanced Queries)

1. **Access Insights:**
   - Left sidebar → "Logs" → "Insights"
   - Or: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:logs-insights

2. **Select Log Groups:**
   - Click "Select log group(s)"
   - Choose one or more log groups

3. **Run Query:**
   - Enter your query (examples below)
   - Select time range
   - Click "Run query"

4. **View Results:**
   - Results appear in table or visualization
   - Export to CSV if needed
   - Save query for reuse

---

## AWS CLI Commands

### Installation & Setup

```bash
# Check if AWS CLI is installed
aws --version

# If not installed, install via Homebrew (macOS)
brew install awscli

# Configure AWS CLI
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)
```

### Basic Log Commands

#### 1. List All Log Groups
```bash
# Simple list
aws logs describe-log-groups --query 'logGroups[*].logGroupName'

# Formatted table
aws logs describe-log-groups \
  --query 'logGroups[*].[logGroupName,storedBytes]' \
  --output table

# Search for specific log groups
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/analytics"
```

#### 2. Tail Logs (Real-time)
```bash
# Follow logs in real-time (like tail -f)
aws logs tail /aws/analytics/prod/ghost/pageviews --follow

# Tail with timestamp format
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --follow \
  --format short

# Tail since specific time
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --follow \
  --since 30m
```

#### 3. View Historical Logs
```bash
# Last 10 minutes
aws logs tail /aws/analytics/prod/ghost/pageviews --since 10m

# Last hour
aws logs tail /aws/analytics/prod/ghost/pageviews --since 1h

# Last 24 hours
aws logs tail /aws/analytics/prod/ghost/pageviews --since 24h

# Specific time range
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --since '2026-01-13T10:00:00' \
  --until '2026-01-13T12:00:00'
```

#### 4. Filter Logs
```bash
# Filter by simple text
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --filter-pattern "ERROR"

# Filter by JSON field
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --filter-pattern '{$.event_type = "pageview"}'

# Multiple conditions
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --filter-pattern '{($.event_type = "pageview") && ($.device_type = "Mobile")}'

# Numeric comparisons
aws logs tail /aws/analytics/prod/ghost/engagement \
  --filter-pattern '{$.engagement_score > 60}'
```

#### 5. Export Logs to File
```bash
# Save last hour to file
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --since 1h > pageviews_last_hour.log

# Save with JSON formatting
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --since 1h \
  --format json > pageviews.json

# Save filtered logs
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --filter-pattern "ERROR" \
  --since 24h > errors_24h.log
```

#### 6. Get Log Streams
```bash
# List log streams in a group
aws logs describe-log-streams \
  --log-group-name /aws/analytics/prod/ghost/pageviews \
  --order-by LastEventTime \
  --descending

# Get latest log stream
aws logs describe-log-streams \
  --log-group-name /aws/analytics/prod/ghost/pageviews \
  --order-by LastEventTime \
  --descending \
  --max-items 1
```

#### 7. Get Specific Log Events
```bash
# Get events from a specific stream
aws logs get-log-events \
  --log-group-name /aws/analytics/prod/ghost/pageviews \
  --log-stream-name "pageview-2026-01-13" \
  --limit 50
```

---

## CloudWatch Insights Queries

### Basic Query Syntax

```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

### Analytics Queries for Your Project

#### 1. Most Viewed Pages (Last Hour)
```sql
fields page, page_title
| filter @timestamp > now() - 1h
| stats count() as views by page, page_title
| sort views desc
| limit 10
```

#### 2. Active Visitors Right Now
```sql
fields @timestamp, visitor_id, page, device_type, country
| filter @timestamp > now() - 5m
| sort @timestamp desc
| limit 50
```

#### 3. Visitor Journey Analysis
```sql
fields @timestamp, visitor_id, page, event_type
| filter visitor_id = "VISITOR_ID_HERE"
| sort @timestamp asc
```

#### 4. Engagement Score Distribution
```sql
fields engagement_score
| filter @timestamp > now() - 24h
| stats count() as visitors by engagement_score
| sort engagement_score desc
```

#### 5. Booking Funnel Analysis
```sql
fields event_type, visitor_id
| filter event_type in ["booking_form_viewed", "service_selected", "booking_time_selected", "booking_created"]
| stats count() as events, count_distinct(visitor_id) as unique_visitors by event_type
```

#### 6. Conversion Rate
```sql
fields event_type
| filter event_type in ["booking_form_viewed", "booking_created"]
| stats count() as events by event_type
```

#### 7. Average Session Duration
```sql
fields session_duration
| filter @timestamp > now() - 24h
| stats avg(session_duration) as avg_session, max(session_duration) as max_session
```

#### 8. Device Type Distribution
```sql
fields device_type
| filter @timestamp > now() - 24h
| stats count() as visits by device_type
```

#### 9. Error Rate
```sql
fields @timestamp, @message
| filter @message like /ERROR/ or @message like /Exception/
| stats count() as errors by bin(1h)
```

#### 10. Geographic Distribution
```sql
fields country, city
| filter @timestamp > now() - 24h
| stats count() as visitors by country, city
| sort visitors desc
| limit 20
```

#### 11. Traffic Sources
```sql
fields referrer_domain
| filter @timestamp > now() - 24h
| stats count() as visits by referrer_domain
| sort visits desc
| limit 10
```

#### 12. Peak Hours Analysis
```sql
fields @timestamp
| filter @timestamp > now() - 7d
| stats count() as events by bin(1h)
```

---

## Log Groups in This Project

### Current Log Groups

#### 1. ECS Container Insights
```
/aws/ecs/containerinsights/prod-ghost-cluster/performance
```
**Contains:** CPU, memory, network, storage metrics for Ghost containers

**View:**
```bash
aws logs tail /aws/ecs/containerinsights/prod-ghost-cluster/performance --follow
```

### When You Enable User Analytics Module

After deploying with `enable_user_analytics = true`, you'll have:

#### 2. CloudWatch RUM
```
/aws/rum/prod/ghost
```
**Contains:** Real User Monitoring data (performance, errors, HTTP requests)

**View:**
```bash
aws logs tail /aws/rum/prod/ghost --follow
```

#### 3. Page Views
```
/aws/analytics/prod/ghost/pageviews
```
**Contains:** All page view events with visitor, session, device, location data

**View:**
```bash
aws logs tail /aws/analytics/prod/ghost/pageviews --follow
```

#### 4. User Analytics
```
/aws/analytics/prod/ghost/user_analytics
```
**Contains:** General user behavior events (clicks, searches, etc.)

**View:**
```bash
aws logs tail /aws/analytics/prod/ghost/user_analytics --follow
```

#### 5. Engagement Metrics
```
/aws/analytics/prod/ghost/engagement
```
**Contains:** Engagement scores, scroll depth, time on page

**View:**
```bash
aws logs tail /aws/analytics/prod/ghost/engagement --follow
```

#### 6. Lambda Function Logs
```
/aws/lambda/prod-ghost-analytics-processor
```
**Contains:** Lambda function execution logs, errors, debugging info

**View:**
```bash
aws logs tail /aws/lambda/prod-ghost-analytics-processor --follow
```

#### 7. API Gateway Logs
```
/aws/apigateway/prod/ghost-analytics
```
**Contains:** API Gateway access logs, request/response details

**View:**
```bash
aws logs tail /aws/apigateway/prod/ghost-analytics --follow
```

---

## Common Use Cases

### 1. Debug Lambda Function
```bash
# Tail Lambda logs with errors only
aws logs tail /aws/lambda/prod-ghost-analytics-processor \
  --follow \
  --filter-pattern "ERROR"

# View last execution
aws logs tail /aws/lambda/prod-ghost-analytics-processor \
  --since 5m
```

### 2. Monitor Real-Time Traffic
```bash
# Watch pageviews in real-time
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --follow \
  --format short
```

### 3. Find Specific Visitor's Journey
```bash
# Filter by visitor ID
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --filter-pattern '{$.visitor_id = "visitor_123"}' \
  --since 24h
```

### 4. Track Booking Conversions
```bash
# Filter booking events
aws logs tail /aws/analytics/prod/ghost/user_analytics \
  --filter-pattern "booking_created" \
  --follow
```

### 5. Monitor Performance Issues
```bash
# Find slow page loads
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --filter-pattern '{$.page_load_time > 3000}' \
  --since 1h
```

### 6. Check Error Rate
```bash
# Count errors in last hour
aws logs tail /aws/lambda/prod-ghost-analytics-processor \
  --filter-pattern "ERROR" \
  --since 1h | wc -l
```

### 7. Export for Analysis
```bash
# Export all data from yesterday
aws logs tail /aws/analytics/prod/ghost/pageviews \
  --since '2026-01-13T00:00:00' \
  --until '2026-01-13T23:59:59' \
  --format json > pageviews_jan_13.json
```

### 8. Monitor Multiple Log Groups
```bash
# Open multiple terminals and tail different logs
# Terminal 1: Pageviews
aws logs tail /aws/analytics/prod/ghost/pageviews --follow

# Terminal 2: Lambda errors
aws logs tail /aws/lambda/prod-ghost-analytics-processor \
  --follow --filter-pattern "ERROR"

# Terminal 3: Engagement
aws logs tail /aws/analytics/prod/ghost/engagement --follow
```

---

## Filter Pattern Syntax

### Text Patterns
```bash
# Simple text match
--filter-pattern "ERROR"

# Multiple terms (OR)
--filter-pattern "ERROR WARN FATAL"

# Exclude pattern
--filter-pattern "ERROR" -v
```

### JSON Patterns
```bash
# Exact match
--filter-pattern '{$.event_type = "pageview"}'

# Multiple conditions (AND)
--filter-pattern '{($.event_type = "pageview") && ($.device_type = "Mobile")}'

# Multiple conditions (OR)
--filter-pattern '{($.event_type = "pageview") || ($.event_type = "engagement")}'

# Numeric comparison
--filter-pattern '{$.engagement_score > 60}'

# String contains
--filter-pattern '{$.page = "/blog*"}'

# Field exists
--filter-pattern '{$.visitor_id = *}'
```

---

## Terraform Commands to Get Log Info

```bash
# Get all log group names
terraform output analytics_log_groups

# Get dashboard URL
terraform output analytics_dashboard_url

# Get API endpoint
terraform output analytics_api_endpoint
```

---

## Tips & Best Practices

### 1. Use Aliases for Common Commands
Add to `~/.zshrc` or `~/.bashrc`:
```bash
alias logs-pageviews='aws logs tail /aws/analytics/prod/ghost/pageviews --follow'
alias logs-lambda='aws logs tail /aws/lambda/prod-ghost-analytics-processor --follow'
alias logs-errors='aws logs tail /aws/lambda/prod-ghost-analytics-processor --follow --filter-pattern ERROR'
```

### 2. Save Queries
Save frequently used Insights queries in CloudWatch Console:
- Run query → Click "Save" → Give it a name
- Access saved queries from dropdown

### 3. Set Up Alarms
Create alarms for important metrics:
```bash
# Example: Alarm on high error rate
aws cloudwatch put-metric-alarm \
  --alarm-name high-error-rate \
  --alarm-description "Alert when error rate is high" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold
```

### 4. Use Log Retention
Set appropriate retention to manage costs:
- Development: 7 days
- Production: 30-90 days
- Compliance: 1-7 years

### 5. Cost Management
- Use sampling for high-volume logs
- Filter before querying (more efficient)
- Export to S3 for long-term storage (cheaper)

---

## Troubleshooting

### "No log groups found"
- Check AWS region: `aws configure get region`
- Verify you have proper IAM permissions
- Ensure analytics module is deployed: `terraform output`

### "Access Denied"
- Check IAM permissions for CloudWatch Logs
- Required permissions: `logs:FilterLogEvents`, `logs:GetLogEvents`, `logs:DescribeLogGroups`

### "Empty results"
- Verify time range (logs might be outside range)
- Check filter pattern syntax
- Ensure data is actually being logged

### Slow queries
- Reduce time range
- Add more specific filters
- Use `| limit N` to restrict results

---

## Quick Reference Card

### Most Used Commands

```bash
# 1. Tail logs
aws logs tail LOG_GROUP --follow

# 2. Last hour
aws logs tail LOG_GROUP --since 1h

# 3. Filter errors
aws logs tail LOG_GROUP --filter-pattern "ERROR"

# 4. Save to file
aws logs tail LOG_GROUP --since 24h > logs.txt

# 5. JSON query
aws logs tail LOG_GROUP --filter-pattern '{$.field = "value"}'
```

### Time Shortcuts
- `5m` = 5 minutes
- `1h` = 1 hour
- `24h` = 24 hours
- `7d` = 7 days
- `now() - 1h` = Last hour (in Insights queries)

### Format Options
- `--format short` = Timestamp + message
- `--format detailed` = All log event details
- `--format json` = JSON format

---

## Additional Resources

- [AWS CloudWatch Logs Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)
- [CloudWatch Logs Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [AWS CLI Logs Reference](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/logs/index.html)
- [Your Analytics Dashboard](#) - Will be available after deployment

---

**Last Updated:** January 13, 2026
**Project:** Secure AWS Infrastructure + User Analytics
