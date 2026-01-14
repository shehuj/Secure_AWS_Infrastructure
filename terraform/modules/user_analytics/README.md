# User Analytics Module

This module provides comprehensive real-time user analytics and monitoring for your Ghost blog using AWS CloudWatch RUM and custom event tracking.

## Features

### 1. **AWS CloudWatch RUM (Real User Monitoring)**
- Real-time frontend performance monitoring
- Core Web Vitals tracking (LCP, FID, CLS)
- JavaScript error tracking
- HTTP request monitoring
- Session replay capabilities
- Automatic performance insights

### 2. **Custom User Analytics**
- **Visitor Tracking**: Unique visitors, returning visitors, session tracking
- **Page Views**: Individual page views with full journey mapping
- **Engagement Metrics**: Time on page, scroll depth, session duration, bounce rate
- **Device Analytics**: Desktop vs Mobile vs Tablet breakdown
- **Browser & OS Stats**: Complete browser and operating system distribution
- **Geographic Data**: Country, city, timezone information
- **Traffic Sources**: Referrer tracking and traffic source analysis
- **User Journey**: Complete path analysis through your site

### 3. **CloudWatch Dashboards**
- Real-time traffic monitoring
- Performance metrics visualization
- Error rate tracking
- Device and geographic distribution
- Engagement score tracking
- Custom event visualization

### 4. **CloudWatch Insights Queries**
- **Top Pages**: Most visited pages
- **Visitor Journey**: Complete user path through your site
- **Engagement Analysis**: Deep dive into user behavior
- **Traffic Sources**: Where your visitors come from
- **Device/Browser Stats**: Detailed device and browser breakdown

### 5. **ALB Access Logs**
- Complete HTTP request logging
- IP address tracking
- Request/response details
- SSL/TLS information

## Installation

### Step 1: Add Module to Your Terraform Configuration

Add this to your `main.tf`:

```hcl
module "user_analytics" {
  source = "./modules/user_analytics"

  environment  = var.environment
  domain_name  = "yourblog.com"  # Your Ghost blog domain

  # Sampling rate (1.0 = 100%, 0.1 = 10%)
  rum_sample_rate = 1.0

  # Important pages to track
  favorite_pages = [
    "/",
    "/about",
    "/contact",
    "/blog/*"
  ]

  # Pages to exclude from tracking
  excluded_pages = [
    "/ghost/*",
    "/admin/*",
    "*/preview/*"
  ]

  # Alert thresholds
  low_traffic_threshold = 10    # Alert if < 10 visitors/hour
  high_error_threshold  = 50    # Alert if > 50 JS errors/5min

  # Notification SNS topic (optional)
  alarm_actions = [module.monitoring.sns_topic_arn]

  tags = var.tags
}
```

### Step 2: Enable ALB Access Logging

Update your ALB configuration to enable access logging:

```hcl
resource "aws_lb" "ghost" {
  # ... other configuration ...

  access_logs {
    bucket  = module.user_analytics.alb_logs_bucket
    enabled = true
  }
}
```

### Step 3: Add RUM Script to Ghost Theme

1. Go to your Ghost Admin Panel → Design → Edit Theme
2. Open `default.hbs` in the theme editor
3. Add this code right before the closing `</head>` tag:

```html
{{! CloudWatch RUM - Copy from Terraform output }}
<script>
  (function(n,i,v,r,s,c,x,z){x=window.AwsRumClient={q:[],n:n,i:i,v:v,r:r,c:c};window[n]=function(c,p){x.q.push({c:c,p:p});};z=document.createElement('script');z.async=true;z.src=s;document.head.insertBefore(z,document.head.getElementsByTagName('script')[0]);})(
    'cwr',
    'YOUR_RUM_APP_MONITOR_ID',  // Get from: terraform output rum_app_monitor_id
    '1.0.0',
    'YOUR_AWS_REGION',
    'https://client.rum.us-east-1.amazonaws.com/1.x/cwr.js',
    {
      sessionSampleRate: 1.0,
      guestRoleArn: 'YOUR_GUEST_ROLE_ARN',      // Get from: terraform output rum_guest_role_arn
      identityPoolId: 'YOUR_IDENTITY_POOL_ID',  // Get from: terraform output rum_identity_pool_id
      endpoint: 'https://dataplane.rum.YOUR_AWS_REGION.amazonaws.com',
      telemetries: ['performance', 'errors', 'http'],
      allowCookies: true,
      enableXRay: true
    }
  );
</script>
```

### Step 4: Add Custom Analytics Script (Optional but Recommended)

For detailed visitor analytics, add the custom analytics script before `</body>`:

```html
{{! Custom Analytics }}
<script src="/assets/analytics.js"></script>
```

Upload the `analytics.js` file from this module to your Ghost theme's `assets` folder.

Update the configuration in `analytics.js`:

```javascript
const CONFIG = {
  endpoint: 'YOUR_API_GATEWAY_ENDPOINT',  // Get from: terraform output analytics_api_endpoint
  environment: 'prod'
};
```

## Viewing Your Analytics

### CloudWatch Dashboard

Access your real-time dashboard:
```bash
terraform output dashboard_url
```

Or navigate to: AWS Console → CloudWatch → Dashboards → `{environment}-ghost-user-analytics`

### CloudWatch Insights

Run pre-built queries:

**Top Pages:**
```
AWS Console → CloudWatch → Logs Insights
→ Select Query: "{environment}-ghost-top-pages"
```

**Visitor Journey:**
```
AWS Console → CloudWatch → Logs Insights
→ Select Query: "{environment}-ghost-visitor-journey"
→ Replace <VISITOR_ID> with actual visitor ID
```

**Engagement Analysis:**
```
AWS Console → CloudWatch → Logs Insights
→ Select Query: "{environment}-ghost-engagement-analysis"
```

### Custom Queries

#### Find Active Visitors Right Now
```
fields @timestamp, visitor_id, page, device_type, country
| filter @timestamp > now() - 5m
| sort @timestamp desc
```

#### Most Popular Content This Week
```
fields page, page_title
| filter @timestamp > now() - 7d
| stats count() as views by page, page_title
| sort views desc
| limit 20
```

#### Average Session Duration by Device
```
fields device_type, session_duration
| stats avg(session_duration) as avg_duration by device_type
| sort avg_duration desc
```

#### Geographic Distribution
```
fields country, city
| stats count() as visitors by country, city
| sort visitors desc
| limit 50
```

#### Traffic Sources
```
fields referrer_domain
| filter referrer_domain != "Direct"
| stats count() as visits by referrer_domain
| sort visits desc
```

#### High Engagement Users
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

## Alerts

The module creates CloudWatch Alarms for:

1. **Low Traffic**: Alerts when unique visitors < threshold (default: 10/hour)
2. **High Error Rate**: Alerts when JS errors > threshold (default: 50/5min)
3. **Poor Performance**: Alerts when page load time > 3 seconds

Configure SNS notifications:
```hcl
alarm_actions = ["arn:aws:sns:region:account:topic-name"]
```

## Data Collected

### Personal Information
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

## Privacy Considerations

1. **Cookie Consent**: Add cookie consent banner if required by GDPR/CCPA
2. **Privacy Policy**: Update your privacy policy to mention analytics
3. **Data Retention**: Logs are retained for 90 days by default
4. **Opt-Out**: Users can disable tracking via browser settings
5. **IP Anonymization**: Consider enabling in ALB logs

## Cost Estimation

Based on 10,000 visitors/month:

- CloudWatch RUM: ~$20/month
- CloudWatch Logs: ~$5/month
- Lambda invocations: ~$1/month
- API Gateway: ~$1/month
- S3 (ALB logs): ~$2/month

**Total**: ~$29/month for comprehensive analytics

## Troubleshooting

### No data appearing in dashboard

1. Check RUM script is loaded: Open browser console and check for `AwsRumClient`
2. Verify IAM permissions: Check that the guest role can write to RUM
3. Check CloudWatch Logs: Look for errors in `/aws/rum/{environment}/ghost`

### Analytics API not working

1. Verify API Gateway endpoint: `terraform output analytics_api_endpoint`
2. Check Lambda logs: `/aws/lambda/{environment}-ghost-analytics-processor`
3. Test endpoint: `curl -X POST https://YOUR_ENDPOINT/track -d '{"test":"data"}'`

### High costs

1. Reduce RUM sampling rate: Set `rum_sample_rate = 0.1` (10%)
2. Exclude non-essential pages
3. Reduce log retention: Set `log_retention_days = 30`

## Advanced Configuration

### Custom Events

Track custom events with RUM:

```javascript
window.cwr('recordEvent', {
  type: 'newsletter_signup',
  data: {
    location: 'footer',
    list: 'main'
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
3. Test individual components
4. Contact AWS Support for RUM-specific issues
