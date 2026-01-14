# User Analytics Integration Summary

## Overview

I've successfully integrated a comprehensive real-time user analytics system into your Ghost blog infrastructure. This provides deep visibility into your site visitors, their behavior, and your site's performance.

## What Was Implemented

### 1. **New Terraform Module: `user_analytics`**

Location: `terraform/modules/user_analytics/`

**Components Created:**
- `main.tf` - Core infrastructure (CloudWatch RUM, Cognito, S3, Dashboards, Alarms)
- `lambda.tf` - Backend processing (Lambda + API Gateway)
- `variables.tf` - Module configuration variables
- `outputs.tf` - Module outputs (RUM snippet, API endpoint, dashboard URL)
- `analytics.js` - Frontend tracking JavaScript library
- `README.md` - Comprehensive module documentation

### 2. **Infrastructure Changes**

**Root Configuration:**
- Added `user_analytics` module to `main.tf` (declared before `ghost_blog` to avoid circular dependencies)
- Updated `ghost_blog` module to support ALB access logging when analytics is enabled
- Added 7 new variables to `variables.tf` for analytics configuration
- Added 6 new outputs to `outputs.tf` for analytics integration details
- Updated `terraform.tfvars.example` with analytics configuration examples

**Ghost ECS Module:**
- Added `enable_alb_access_logs` and `alb_logs_bucket` variables
- Updated ALB resource with dynamic `access_logs` block for conditional logging

### 3. **Analytics Capabilities**

#### Real-Time Monitoring
- **CloudWatch RUM**: Automated frontend performance monitoring
  - Core Web Vitals (LCP, FID, CLS)
  - JavaScript error tracking
  - HTTP request monitoring
  - Session replay capabilities

#### Custom Analytics
- **Visitor Tracking**: Unique visitors, sessions, returning visitors
- **Page Views**: Complete user journey mapping
- **Engagement Metrics**: Time on page, scroll depth, bounce rate, engagement score (0-100)
- **Device Analytics**: Desktop, Mobile, Tablet distribution
- **Browser & OS**: Complete browser and operating system breakdown
- **Geographic Data**: Country, city, timezone tracking
- **Traffic Sources**: Referrer analysis and source tracking

#### Visualization & Querying
- **CloudWatch Dashboard**: Real-time dashboard with 8+ widget types
- **Pre-built Queries**: 5 CloudWatch Insights queries for analysis:
  - Top Pages
  - Visitor Journey
  - Engagement Analysis
  - Traffic Sources
  - Device/Browser Stats

#### Alerting
- **Low Traffic Alarm**: Triggers when visitors < threshold (default: 10/hour)
- **High Error Rate Alarm**: Triggers when JS errors > threshold (default: 50/5min)
- **Poor Performance Alarm**: Triggers when page load > 3 seconds

### 4. **Data Flow**

```
┌──────────────────────────────────────────────────────────────┐
│                     Ghost Blog Visitors                       │
└──────────────────────┬───────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
┌──────────────────┐         ┌──────────────────┐
│  CloudWatch RUM  │         │  analytics.js    │
│  (Automatic)     │         │  (Custom Events) │
└────────┬─────────┘         └────────┬─────────┘
         │                            │
         ▼                            ▼
┌──────────────────┐         ┌──────────────────┐
│ CloudWatch Logs  │         │  API Gateway     │
│ /aws/rum/{env}/  │         │  + Lambda        │
└────────┬─────────┘         └────────┬─────────┘
         │                            │
         │                            ▼
         │                   ┌──────────────────┐
         │                   │ CloudWatch Logs  │
         │                   │ - pageviews      │
         │                   │ - engagement     │
         │                   │ - user_analytics │
         │                   └────────┬─────────┘
         │                            │
         └────────────┬───────────────┘
                      │
                      ▼
         ┌───────────────────────────┐
         │  CloudWatch Dashboard     │
         │  + Insights Queries       │
         │  + Metric Alarms          │
         └───────────────────────────┘
```

### 5. **ALB Access Logs**

```
┌──────────────────┐
│   Ghost ALB      │
│  (HTTP Traffic)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│   S3 Bucket      │
│ {env}-ghost-alb- │
│    logs-*        │
└────────┬─────────┘
         │
         ▼ (Lifecycle: 90 days)
    [Archived/Deleted]
```

## Configuration Variables

### New Root Variables (terraform/variables.tf)

```hcl
enable_user_analytics      # Enable/disable the entire analytics module (default: false)
rum_sample_rate           # CloudWatch RUM sampling rate (default: 1.0 = 100%)
analytics_favorite_pages  # Pages to specifically track
analytics_excluded_pages  # Pages to exclude (admin, preview, etc.)
alb_log_retention_days    # S3 log retention (default: 90 days)
low_traffic_threshold     # Low traffic alarm threshold (default: 10/hour)
high_error_threshold      # High error alarm threshold (default: 50/5min)
```

## How to Enable

### Step 1: Enable in terraform.tfvars

```hcl
# Enable user analytics
enable_user_analytics = true

# Optional: Customize settings
rum_sample_rate = 1.0  # 100% sampling

analytics_favorite_pages = [
  "/",
  "/about",
  "/contact",
  "/blog/*"
]

analytics_excluded_pages = [
  "/ghost/*",      # Ghost admin
  "/admin/*",
  "*/preview/*"
]

# Log retention and alerting
alb_log_retention_days = 90
low_traffic_threshold  = 10
high_error_threshold   = 50
```

### Step 2: Deploy the Infrastructure

```bash
cd terraform
terraform plan   # Review changes
terraform apply  # Deploy
```

### Step 3: Capture Terraform Outputs

```bash
# Get the RUM JavaScript snippet
terraform output rum_javascript_snippet

# Get the analytics API endpoint
terraform output analytics_api_endpoint

# Get the dashboard URL
terraform output analytics_dashboard_url
```

### Step 4: Add Scripts to Ghost Theme

1. **Add CloudWatch RUM Script** (Required)
   - Edit your Ghost theme's `default.hbs`
   - Add the RUM snippet before `</head>`
   - Use the output from `terraform output rum_javascript_snippet`

2. **Add Custom Analytics Script** (Optional but Recommended)
   - Copy `modules/user_analytics/analytics.js` to Ghost theme's `assets/` folder
   - Update `CONFIG.endpoint` in analytics.js with API endpoint from outputs
   - Add `<script src="/assets/analytics.js"></script>` before `</body>` in `default.hbs`

## Accessing Your Analytics

### CloudWatch Dashboard

```bash
# Open in browser
terraform output analytics_dashboard_url
```

Or navigate to:
**AWS Console → CloudWatch → Dashboards → `{environment}-ghost-user-analytics`**

### CloudWatch Insights

**AWS Console → CloudWatch → Logs Insights**

Select from saved queries:
- `{environment}-ghost-top-pages`
- `{environment}-ghost-visitor-journey`
- `{environment}-ghost-engagement-analysis`
- `{environment}-ghost-traffic-sources`
- `{environment}-ghost-device-browser-stats`

### CloudWatch Alarms

**AWS Console → CloudWatch → Alarms**

View alarms:
- `{environment}-ghost-low-traffic`
- `{environment}-ghost-high-error-rate`
- `{environment}-ghost-poor-performance`

## Cost Estimate

Based on 10,000 visitors/month:

| Service | Monthly Cost |
|---------|--------------|
| CloudWatch RUM | ~$20 |
| CloudWatch Logs | ~$5 |
| Lambda Invocations | ~$1 |
| API Gateway | ~$1 |
| S3 (ALB Logs) | ~$2 |
| **Total** | **~$29/month** |

### Cost Optimization

To reduce costs:

```hcl
# Sample only 10% of sessions
rum_sample_rate = 0.1

# Reduce log retention
log_retention_days     = 30
alb_log_retention_days = 30

# Exclude non-essential pages
analytics_excluded_pages = [
  "/ghost/*",
  "/admin/*",
  "*/preview/*",
  "/static/*",
  "/assets/*"
]
```

## Files Created/Modified

### New Files
- `terraform/modules/user_analytics/main.tf` (432 lines)
- `terraform/modules/user_analytics/lambda.tf` (261 lines)
- `terraform/modules/user_analytics/variables.tf` (70 lines)
- `terraform/modules/user_analytics/outputs.tf` (86 lines)
- `terraform/modules/user_analytics/analytics.js` (271 lines)
- `terraform/modules/user_analytics/README.md` (363 lines)
- `terraform/USER_ANALYTICS_SETUP.md` (Complete setup guide)
- `terraform/ANALYTICS_INTEGRATION_SUMMARY.md` (This file)

### Modified Files
- `terraform/main.tf` - Added user_analytics module, updated ghost_blog module
- `terraform/variables.tf` - Added 7 analytics variables
- `terraform/outputs.tf` - Added 6 analytics outputs
- `terraform/terraform.tfvars.example` - Added analytics configuration examples
- `terraform/modules/ecs_ghost/main.tf` - Added dynamic ALB access logging
- `terraform/modules/ecs_ghost/variables.tf` - Added alb_logs_bucket and enable_alb_access_logs

## Key Technical Decisions

### 1. Module Ordering
Placed `user_analytics` module **before** `ghost_blog` in `main.tf` to avoid circular dependencies. The Ghost ALB needs the S3 bucket name from user_analytics, so user_analytics must be created first.

### 2. Conditional ALB Logging
Used Terraform's `dynamic` block to conditionally enable ALB access logging only when `enable_user_analytics = true`:

```hcl
dynamic "access_logs" {
  for_each = var.enable_alb_access_logs && var.alb_logs_bucket != "" ? [1] : []
  content {
    bucket  = var.alb_logs_bucket
    enabled = true
  }
}
```

### 3. JavaScript Template Literals
Escaped JavaScript template literals in Lambda function code (`$${variable}` instead of `${variable}`) to prevent Terraform interpolation conflicts.

### 4. CloudWatch RUM Configuration
- Removed `cw_log_group` attribute (not supported)
- Moved `custom_events` block to resource level (not in `app_monitor_configuration`)
- Used `data.aws_region.current.id` instead of deprecated `.name`

### 5. Privacy & Security
- Anonymous visitor IDs (no PII collected)
- Session IDs stored in browser sessionStorage only
- IP addresses logged in ALB logs (can be disabled if needed)
- CORS configured for API Gateway
- IAM roles with least-privilege access

## Validation Results

✅ **Terraform Init**: Successful
✅ **Terraform Validate**: `Success! The configuration is valid.`
✅ **Module Dependencies**: Resolved (no circular dependencies)
✅ **Syntax**: All HCL syntax valid
✅ **Providers**: Required providers declared

## Next Steps

1. **Enable Analytics**: Set `enable_user_analytics = true` in `terraform.tfvars`
2. **Deploy**: Run `terraform apply`
3. **Configure Theme**: Add RUM and analytics scripts to Ghost theme
4. **Verify**: Check CloudWatch Dashboard after 5-10 minutes
5. **Set Up Alerts**: Configure SNS topic for alarm notifications (optional)
6. **Create Reports**: Use CloudWatch Insights to analyze visitor data
7. **Optimize**: Adjust sampling rate and thresholds based on traffic patterns

## Troubleshooting

### No data in dashboard
- Verify RUM script is loaded: Check browser console for `AwsRumClient`
- Check CloudWatch Logs: `/aws/rum/{environment}/ghost`
- Verify IAM permissions: Guest role has RUM write permissions

### Analytics API errors
- Check Lambda logs: `/aws/lambda/{environment}-ghost-analytics-processor`
- Test API endpoint: `curl -X POST <api_endpoint> -H "Content-Type: application/json" -d '{"test":"data"}'`

### High costs
- Reduce sampling: `rum_sample_rate = 0.1`
- Shorten retention: `log_retention_days = 30`
- Exclude more pages: Add to `analytics_excluded_pages`

## Documentation References

- **Setup Guide**: `USER_ANALYTICS_SETUP.md`
- **Module README**: `modules/user_analytics/README.md`
- **Terraform Variables**: `variables.tf`
- **Example Config**: `terraform.tfvars.example`

## Support

For questions or issues:
1. Review `USER_ANALYTICS_SETUP.md` for detailed setup instructions
2. Check `modules/user_analytics/README.md` for troubleshooting
3. Review CloudWatch Logs for error messages
4. Test components individually (RUM, API Gateway, Lambda)

---

**Status**: ✅ Integration Complete - Ready to Enable

**Impact**: Zero impact to existing infrastructure when `enable_user_analytics = false` (default)

**Dependencies**: None (module is optional and independent)

**Cost**: ~$29/month for 10K visitors (adjustable via sampling rate)
