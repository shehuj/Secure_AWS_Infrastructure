/**
 * Custom Analytics Script for Ghost Blog
 *
 * This script collects detailed user analytics and sends them to CloudWatch Logs
 * Place this in your Ghost theme's default.hbs file before </body>
 */

(function() {
  'use strict';

  // Configuration - Replace with your values
  const CONFIG = {
    endpoint: 'YOUR_API_GATEWAY_ENDPOINT', // We'll create this
    logGroup: '/aws/analytics/ENVIRONMENT/ghost/pageviews',
    environment: 'prod'
  };

  // Generate or retrieve visitor ID
  function getVisitorId() {
    let visitorId = localStorage.getItem('ghost_visitor_id');
    if (!visitorId) {
      visitorId = 'visitor_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
      localStorage.setItem('ghost_visitor_id', visitorId);
    }
    return visitorId;
  }

  // Generate session ID
  function getSessionId() {
    let sessionId = sessionStorage.getItem('ghost_session_id');
    if (!sessionId) {
      sessionId = 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
      sessionStorage.setItem('ghost_session_id', sessionId);
      sessionStorage.setItem('session_start', Date.now());
      sessionStorage.setItem('page_count', 0);
    }
    return sessionId;
  }

  // Detect device type
  function getDeviceType() {
    const ua = navigator.userAgent;
    if (/(tablet|ipad|playbook|silk)|(android(?!.*mobi))/i.test(ua)) {
      return 'Tablet';
    }
    if (/Mobile|iP(hone|od)|Android|BlackBerry|IEMobile|Kindle|Silk-Accelerated|(hpw|web)OS|Opera M(obi|ini)/.test(ua)) {
      return 'Mobile';
    }
    return 'Desktop';
  }

  // Get browser info
  function getBrowserInfo() {
    const ua = navigator.userAgent;
    let browser = 'Unknown';

    if (ua.indexOf('Firefox') > -1) browser = 'Firefox';
    else if (ua.indexOf('Chrome') > -1) browser = 'Chrome';
    else if (ua.indexOf('Safari') > -1) browser = 'Safari';
    else if (ua.indexOf('Edge') > -1) browser = 'Edge';
    else if (ua.indexOf('MSIE') > -1 || ua.indexOf('Trident') > -1) browser = 'IE';

    return browser;
  }

  // Get OS info
  function getOS() {
    const ua = navigator.userAgent;

    if (ua.indexOf('Win') > -1) return 'Windows';
    if (ua.indexOf('Mac') > -1) return 'MacOS';
    if (ua.indexOf('Linux') > -1) return 'Linux';
    if (ua.indexOf('Android') > -1) return 'Android';
    if (ua.indexOf('iOS') > -1) return 'iOS';

    return 'Unknown';
  }

  // Get referrer domain
  function getReferrerDomain() {
    if (!document.referrer) return 'Direct';
    try {
      const url = new URL(document.referrer);
      return url.hostname;
    } catch (e) {
      return 'Unknown';
    }
  }

  // Get country from timezone (approximation)
  function getApproxCountry() {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    // This is an approximation - real geolocation should be done server-side
    return timezone.split('/')[0] || 'Unknown';
  }

  // Track scroll depth
  let maxScrollDepth = 0;
  function trackScrollDepth() {
    const windowHeight = window.innerHeight;
    const documentHeight = document.documentElement.scrollHeight;
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    const scrollDepth = Math.round(((scrollTop + windowHeight) / documentHeight) * 100);

    if (scrollDepth > maxScrollDepth) {
      maxScrollDepth = scrollDepth;
    }
  }

  // Track time on page
  const pageLoadTime = Date.now();

  // Send analytics event
  function sendAnalytics(eventType, data) {
    const visitorId = getVisitorId();
    const sessionId = getSessionId();
    const timestamp = new Date().toISOString();

    const event = {
      timestamp: timestamp,
      event_type: eventType,
      visitor_id: visitorId,
      session_id: sessionId,
      page: window.location.pathname,
      page_title: document.title,
      referrer: document.referrer,
      referrer_domain: getReferrerDomain(),
      device_type: getDeviceType(),
      browser: getBrowserInfo(),
      os: getOS(),
      screen_width: window.screen.width,
      screen_height: window.screen.height,
      viewport_width: window.innerWidth,
      viewport_height: window.innerHeight,
      language: navigator.language,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      country: getApproxCountry(),
      ...data
    };

    // Log to console in development
    if (window.location.hostname === 'localhost') {
      console.log('Analytics Event:', eventType, event);
      return;
    }

    // Send to CloudWatch via custom API (if configured)
    if (CONFIG.endpoint) {
      fetch(CONFIG.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(event),
        keepalive: true
      }).catch(err => console.error('Analytics error:', err));
    }

    // Also send to CloudWatch RUM if available
    if (window.cwr) {
      window.cwr('recordEvent', {
        type: eventType,
        data: event
      });
    }
  }

  // Page view tracking
  function trackPageView() {
    const pageCount = parseInt(sessionStorage.getItem('page_count') || 0) + 1;
    sessionStorage.setItem('page_count', pageCount);

    sendAnalytics('pageview', {
      page_count: pageCount,
      session_duration: Math.round((Date.now() - sessionStorage.getItem('session_start')) / 1000),
      page_load_time: performance.timing ?
        (performance.timing.loadEventEnd - performance.timing.navigationStart) : 0
    });
  }

  // Engagement tracking
  function trackEngagement() {
    const sessionStart = parseInt(sessionStorage.getItem('session_start'));
    const sessionDuration = Math.round((Date.now() - sessionStart) / 1000);
    const pageCount = parseInt(sessionStorage.getItem('page_count') || 0);
    const timeOnPage = Math.round((Date.now() - pageLoadTime) / 1000);

    // Calculate engagement score (0-100)
    let engagementScore = 0;
    if (timeOnPage > 30) engagementScore += 20; // Spent significant time
    if (maxScrollDepth > 50) engagementScore += 20; // Scrolled halfway
    if (maxScrollDepth > 75) engagementScore += 20; // Scrolled most of page
    if (pageCount > 1) engagementScore += 20; // Viewed multiple pages
    if (sessionDuration > 120) engagementScore += 20; // Long session

    sendAnalytics('engagement', {
      session_duration: sessionDuration,
      time_on_page: timeOnPage,
      page_count: pageCount,
      scroll_depth: maxScrollDepth,
      engagement_score: engagementScore
    });
  }

  // Click tracking for important elements
  function setupClickTracking() {
    // Track clicks on links
    document.addEventListener('click', function(e) {
      const link = e.target.closest('a');
      if (link) {
        sendAnalytics('click', {
          element: 'link',
          text: link.textContent.substring(0, 100),
          href: link.href,
          is_external: link.hostname !== window.location.hostname
        });
      }

      // Track button clicks
      const button = e.target.closest('button');
      if (button) {
        sendAnalytics('click', {
          element: 'button',
          text: button.textContent.substring(0, 100),
          id: button.id,
          class: button.className
        });
      }
    });
  }

  // Track when user leaves page
  function trackPageExit() {
    trackEngagement();
  }

  // Initialize analytics
  function init() {
    // Track page view on load
    if (document.readyState === 'complete') {
      trackPageView();
    } else {
      window.addEventListener('load', trackPageView);
    }

    // Track scroll depth
    window.addEventListener('scroll', trackScrollDepth, { passive: true });

    // Track engagement on page exit
    window.addEventListener('beforeunload', trackPageExit);
    document.addEventListener('visibilitychange', function() {
      if (document.hidden) {
        trackPageExit();
      }
    });

    // Setup click tracking
    setupClickTracking();

    // Send engagement updates periodically
    setInterval(trackEngagement, 30000); // Every 30 seconds
  }

  // Start analytics when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
