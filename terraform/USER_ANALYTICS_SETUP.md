# User Analytics Setup Guide

This guide walks you through enabling comprehensive real-time user analytics for your Ghost blog using AWS CloudWatch RUM and custom tracking.

## What You'll Get

- **Real-time visitor tracking**: Monitor who's visiting your site right now
- **Performance metrics**: Core Web Vitals (LCP, FID, CLS), page load times
- **User behavior**: Engagement scores, scroll depth, time on page, session duration
- **Device analytics**: Desktop vs Mobile vs Tablet breakdown
- **Geographic data**: Country, city, timezone information
- **Traffic sources**: Referrer tracking and source analysis
- **Error tracking**: JavaScript errors and HTTP failures
- **CloudWatch Dashboard**: Visual analytics with 8+ widget types
- **Pre-built queries**: 5 CloudWatch Insights queries for deep analysis
- **Automated alerts**: Low traffic and high error rate notifications

## Cost Estimate

Based on 10,000 visitors/month:
- CloudWatch RUM: ~$20/month
- CloudWatch Logs: ~$5/month
- Lambda invocations: ~$1/month
- API Gateway: ~$1/month
- S3 (ALB logs): ~$2/month

**Total**: ~$29/month for comprehensive analytics

## Step 1: Enable User Analytics in Terraform

Edit your `terraform.tfvars` file:

```hcl
# Enable user analytics
enable_user_analytics = true

# Sampling rate (1.0 = 100%, 0.1 = 10% for cost savings)
rum_sample_rate = 1.0

# Pages to specifically track
analytics_favorite_pages = [
  "/",
  "/about",
  "/contact",
  "/blog/*"
]

# Pages to exclude from tracking
analytics_excluded_pages = [
  "/ghost/*",      # Admin panel
  "/admin/*",      # Admin pages
  "*/preview/*"    # Preview pages
]

# Log retention and alerting
alb_log_retention_days = 90
low_traffic_threshold  = 10  # Alert if < 10 visitors/hour
high_error_threshold   = 50  # Alert if > 50 JS errors/5min
```

## Step 2: Deploy the Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

After deployment, capture these outputs:

```bash
# Get the RUM JavaScript snippet
terraform output rum_javascript_snippet

# Get the analytics API endpoint
terraform output analytics_api_endpoint

# Get the dashboard URL
terraform output analytics_dashboard_url
```

## Step 3: Add RUM Script to Ghost Theme

1. Log into your Ghost Admin Panel
2. Go to **Design** → **Edit Theme**
3. Open `default.hbs` in the theme editor
4. Add the RUM script **before the closing `</head>` tag**:

```html
<!-- AWS CloudWatch RUM - Real User Monitoring -->
<!-- Paste the output from: terraform output rum_javascript_snippet -->
<script>
  (function(n,i,v,r,s,c,x,z){x=window.AwsRumClient={q:[],n:n,i:i,v:v,r:r,c:c};window[n]=function(c,p){x.q.push({c:c,p:p});};z=document.createElement('script');z.async=true;z.src=s;document.head.insertBefore(z,document.head.getElementsByTagName('script')[0]);})(...);
</script>
```

5. **Save and activate** the theme

## Step 4: Add Custom Analytics Script (Optional but Recommended)

For detailed visitor analytics beyond RUM:

1. Copy `modules/user_analytics/analytics.js` to your Ghost theme's `assets/` folder
2. Update the configuration in `analytics.js`:

```javascript
const CONFIG = {
  endpoint: 'YOUR_API_GATEWAY_ENDPOINT',  // From: terraform output analytics_api_endpoint
  environment: 'prod'
};
```

3. Add to `default.hbs` **before the closing `</body>` tag**:

```html
{{! Custom User Analytics }}
<script src="/assets/analytics.js"></script>
```

4. **Save and activate** the theme

## Step 5: View Your Analytics

### CloudWatch Dashboard

Access your real-time dashboard:

```bash
# Open the dashboard URL
terraform output analytics_dashboard_url
```

Or navigate to: **AWS Console → CloudWatch → Dashboards → `{environment}-ghost-user-analytics`**

The dashboard shows:
- Real-time traffic and sessions
- Device distribution (Desktop/Mobile/Tablet)
- Engagement scores and session durations
- Performance metrics (page load times, Core Web Vitals)
- Error rates (JS errors, HTTP failures)
- Geographic distribution

### CloudWatch Insights Queries

Run pre-built queries in **AWS Console → CloudWatch → Logs Insights**:

#### Top Pages (Most Visited)
```
Select Query: "{environment}-ghost-top-pages"
```

#### Visitor Journey (User Path Through Site)
```
Select Query: "{environment}-ghost-visitor-journey"
Replace <VISITOR_ID> with actual visitor ID
```

#### Engagement Analysis (Deep Dive)
```
Select Query: "{environment}-ghost-engagement-analysis"
```

#### Traffic Sources (Referrer Analysis)
```
Select Query: "{environment}-ghost-traffic-sources"
```

#### Device & Browser Statistics
```
Select Query: "{environment}-ghost-device-browser-stats"
```

## Custom Queries Examples

### Find Active Visitors Right Now
```
fields @timestamp, visitor_id, page, device_type, country
| filter @timestamp > now() - 5m
| sort @timestamp desc
```

### Most Popular Content This Week
```
fields page, page_title
| filter @timestamp > now() - 7d
| stats count() as views by page, page_title
| sort views desc
| limit 20
```

### Average Session Duration by Device
```
fields device_type, session_duration
| stats avg(session_duration) as avg_duration by device_type
| sort avg_duration desc
```

### High Engagement Users (Score > 60)
```
fields visitor_id, engagement_score, session_duration, page_count
| filter engagement_score > 60
| sort engagement_score desc
```

## Metrics Available

### Real User Monitoring (RUM)
- `PerformanceNavigationDuration` - Page load time
- `PerformanceLargestContentfulPaint` - LCP (Core Web Vital)
- `PerformanceFirstInputDelay` - FID (Core Web Vital)
- `PerformanceCumulativeLayoutShift` - CLS (Core Web Vital)
- `JsErrorCount` - JavaScript errors
- `HttpErrorCount` - HTTP request errors

### Custom Analytics
- `UniqueVisitors` - Unique visitor count
- `PageViews` - Total page views
- `SessionDuration` - Average session length
- `Bounces` - Single-page sessions
- `EngagementScore` - User engagement (0-100)
- `MobileVisitors` - Mobile traffic
- `DesktopVisitors` - Desktop traffic
- `VisitorsByCountry` - Geographic distribution

## CloudWatch Alarms

The module creates alarms for:

1. **Low Traffic**: Alerts when unique visitors < threshold (default: 10/hour)
2. **High Error Rate**: Alerts when JS errors > threshold (default: 50/5min)
3. **Poor Performance**: Alerts when page load time > 3 seconds

Configure SNS notifications in `terraform.tfvars`:
```hcl
create_sns_topic      = true
alarm_email_endpoints = ["devops@example.com"]
```

## Privacy Considerations

### Data Collected
- **Stored**: Anonymized visitor IDs, session IDs
- **Not Stored**: Names, emails, or other PII
- **IP Addresses**: Logged in ALB access logs (can be disabled)

### Technical Data
- Device type, browser, OS
- Screen resolution, viewport size
- Language, timezone
- Approximate geographic location
- Page views and navigation
- Performance metrics
- Error messages

### Compliance
1. **Cookie Consent**: Add cookie consent banner if required by GDPR/CCPA
2. **Privacy Policy**: Update your privacy policy to mention analytics
3. **Data Retention**: Logs retained for 90 days by default (configurable)
4. **Opt-Out**: Users can disable tracking via browser settings

## Troubleshooting

### No data appearing in dashboard

1. Check RUM script is loaded:
```javascript
// In browser console:
console.log(window.AwsRumClient);
```

2. Verify IAM permissions: Check that the guest role can write to RUM
3. Check CloudWatch Logs: Look for errors in `/aws/rum/{environment}/ghost`

### Analytics API not working

1. Verify API endpoint:
```bash
terraform output analytics_api_endpoint
```

2. Check Lambda logs:
```bash
aws logs tail /aws/lambda/{environment}-ghost-analytics-processor --follow
```

3. Test endpoint:
```bash
curl -X POST https://YOUR_ENDPOINT/track \
  -H "Content-Type: application/json" \
  -d '{"event_type":"test","page":"/"}'
```

### High costs

1. Reduce RUM sampling rate: `rum_sample_rate = 0.1` (10%)
2. Exclude non-essential pages in `analytics_excluded_pages`
3. Reduce log retention: `log_retention_days = 30`

## Advanced Configuration

### Track Custom Events with RUM

Add custom event tracking to your Ghost theme:

```javascript
// Track newsletter signup
window.cwr('recordEvent', {
  type: 'newsletter_signup',
  data: {
    location: 'footer',
    list: 'main'
  }
});

// Track button click
window.cwr('recordEvent', {
  type: 'cta_click',
  data: {
    button: 'download',
    page: window.location.pathname
  }
});
```

### Custom Metrics

Add custom CloudWatch metrics:

```hcl
resource "aws_cloudwatch_log_metric_filter" "custom_metric" {
  name           = "custom-event"
  log_group_name = module.user_analytics.analytics_log_groups.user_analytics
  pattern        = "[timestamp, event_type=custom_event, ...]"

  metric_transformation {
    name      = "CustomEvents"
    namespace = "Ghost/Analytics"
    value     = "1"
  }
}
```

## Support

For issues or questions:
1. Check CloudWatch Logs for errors
2. Review Terraform state: `terraform state show module.user_analytics`
3. Check module README: `modules/user_analytics/README.md`
4. Test individual components

## Next Steps

1. Set up CloudWatch Alarms to send notifications to your email
2. Create custom dashboards for specific metrics you care about
3. Set up automated reports using CloudWatch Insights scheduled queries
4. Integrate with your existing monitoring stack (Prometheus, Grafana, etc.)
5. Use the data to improve user experience and content strategy
