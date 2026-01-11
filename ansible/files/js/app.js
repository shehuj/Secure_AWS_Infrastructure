// Modern Enterprise Web Application
// ==================================

// Mobile Menu Toggle
const mobileMenuToggle = document.querySelector('.mobile-menu-toggle');
const navMenu = document.querySelector('.nav-menu');

if (mobileMenuToggle) {
    mobileMenuToggle.addEventListener('click', () => {
        navMenu.classList.toggle('active');
        mobileMenuToggle.classList.toggle('active');
    });
}

// Smooth Scrolling for Navigation Links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
            // Close mobile menu if open
            navMenu.classList.remove('active');
        }
    });
});

// Active Navigation Link on Scroll
const sections = document.querySelectorAll('section[id]');
const navLinks = document.querySelectorAll('.nav-link');

function updateActiveNav() {
    const scrollY = window.pageYOffset;

    sections.forEach(section => {
        const sectionHeight = section.offsetHeight;
        const sectionTop = section.offsetTop - 100;
        const sectionId = section.getAttribute('id');

        if (scrollY > sectionTop && scrollY <= sectionTop + sectionHeight) {
            navLinks.forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href') === `#${sectionId}`) {
                    link.classList.add('active');
                }
            });
        }
    });
}

window.addEventListener('scroll', updateActiveNav);

// Navbar Background Change on Scroll
const navbar = document.querySelector('.navbar');

window.addEventListener('scroll', () => {
    if (window.scrollY > 50) {
        navbar.style.boxShadow = '0 4px 6px -1px rgb(0 0 0 / 0.1)';
    } else {
        navbar.style.boxShadow = 'none';
    }
});

// Simulate Real-time Metrics
function updateMetrics() {
    // CPU Usage
    const cpuUsage = Math.floor(Math.random() * 40) + 20; // 20-60%
    document.getElementById('cpu-value').textContent = `${cpuUsage}%`;
    document.getElementById('cpu-progress').style.width = `${cpuUsage}%`;

    // Memory Usage
    const memoryUsage = Math.floor(Math.random() * 30) + 40; // 40-70%
    document.getElementById('memory-value').textContent = `${memoryUsage}%`;
    document.getElementById('memory-progress').style.width = `${memoryUsage}%`;

    // Disk Usage
    const diskUsage = Math.floor(Math.random() * 20) + 30; // 30-50%
    document.getElementById('disk-value').textContent = `${diskUsage}%`;
    document.getElementById('disk-progress').style.width = `${diskUsage}%`;

    // Update progress bar colors based on usage
    updateProgressColor('cpu', cpuUsage);
    updateProgressColor('memory', memoryUsage);
    updateProgressColor('disk', diskUsage);
}

function updateProgressColor(type, value) {
    const progressBar = document.getElementById(`${type}-progress`);
    if (value < 60) {
        progressBar.style.background = 'linear-gradient(90deg, #10b981 0%, #34d399 100%)';
    } else if (value < 80) {
        progressBar.style.background = 'linear-gradient(90deg, #f59e0b 0%, #fbbf24 100%)';
    } else {
        progressBar.style.background = 'linear-gradient(90deg, #ef4444 0%, #f87171 100%)';
    }
}

// Update metrics every 5 seconds
if (document.getElementById('cpu-value')) {
    updateMetrics();
    setInterval(updateMetrics, 5000);
}

// Format Deployment Time
const deployTimeElement = document.getElementById('deploy-time');
if (deployTimeElement) {
    const deployTime = new Date(deployTimeElement.textContent);
    const now = new Date();
    const diffMs = now - deployTime;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    let timeAgo = '';
    if (diffDays > 0) {
        timeAgo = `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
    } else if (diffHours > 0) {
        timeAgo = `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
    } else if (diffMins > 0) {
        timeAgo = `${diffMins} minute${diffMins > 1 ? 's' : ''} ago`;
    } else {
        timeAgo = 'Just now';
    }

    deployTimeElement.textContent = timeAgo;
    deployTimeElement.title = deployTime.toLocaleString();
}

// Intersection Observer for Fade-in Animations
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.style.opacity = '1';
            entry.target.style.transform = 'translateY(0)';
        }
    });
}, observerOptions);

// Observe elements for animation
document.querySelectorAll('.feature-card, .info-card, .status-card').forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(20px)';
    el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    observer.observe(el);
});

// Health Check Monitoring
async function checkHealth() {
    try {
        const response = await fetch('/health');
        const data = await response.text();

        if (response.ok && data.includes('OK')) {
            updateSystemStatus('operational');
        } else {
            updateSystemStatus('degraded');
        }
    } catch (error) {
        console.error('Health check failed:', error);
        updateSystemStatus('degraded');
    }
}

function updateSystemStatus(status) {
    const statusElements = document.querySelectorAll('.status-icon');
    statusElements.forEach(el => {
        el.classList.remove('status-success', 'status-warning', 'status-danger');

        if (status === 'operational') {
            el.classList.add('status-success');
        } else if (status === 'degraded') {
            el.classList.add('status-warning');
        } else {
            el.classList.add('status-danger');
        }
    });
}

// Run health check every 30 seconds
checkHealth();
setInterval(checkHealth, 30000);

// Keyboard Navigation
document.addEventListener('keydown', (e) => {
    // Press 'H' to go to home
    if (e.key === 'h' || e.key === 'H') {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    // Press 'Escape' to close mobile menu
    if (e.key === 'Escape') {
        navMenu.classList.remove('active');
    }
});

// Copy to Clipboard Functionality
document.querySelectorAll('.info-value').forEach(element => {
    element.style.cursor = 'pointer';
    element.title = 'Click to copy';

    element.addEventListener('click', async () => {
        const text = element.textContent;
        try {
            await navigator.clipboard.writeText(text);

            // Show feedback
            const originalText = element.textContent;
            element.textContent = 'Copied!';
            element.style.color = 'var(--success-color)';

            setTimeout(() => {
                element.textContent = originalText;
                element.style.color = '';
            }, 1500);
        } catch (err) {
            console.error('Failed to copy:', err);
        }
    });
});

// Performance Metrics (Web Vitals)
function reportWebVitals() {
    if ('performance' in window) {
        const perfData = performance.getEntriesByType('navigation')[0];
        if (perfData) {
            console.log('Page Load Time:', Math.round(perfData.loadEventEnd - perfData.fetchStart), 'ms');
            console.log('DOM Interactive:', Math.round(perfData.domInteractive - perfData.fetchStart), 'ms');
            console.log('First Paint:', Math.round(perfData.responseStart - perfData.fetchStart), 'ms');
        }
    }
}

// Report web vitals when page is fully loaded
window.addEventListener('load', reportWebVitals);

// Service Worker Registration (for PWA support)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        // Uncomment to enable service worker
        // navigator.serviceWorker.register('/sw.js')
        //     .then(registration => console.log('SW registered:', registration))
        //     .catch(error => console.log('SW registration failed:', error));
    });
}

// Dark Mode Toggle (optional - respects system preference by default)
function initDarkMode() {
    const darkModeQuery = window.matchMedia('(prefers-color-scheme: dark)');

    darkModeQuery.addEventListener('change', (e) => {
        console.log('Dark mode:', e.matches ? 'enabled' : 'disabled');
    });
}

initDarkMode();

// Console Welcome Message
console.log('%c🚀 Secure AWS Infrastructure', 'color: #6366f1; font-size: 24px; font-weight: bold;');
console.log('%cBuilt with Terraform & Ansible', 'color: #8b5cf6; font-size: 14px;');
console.log('%cEnterprise-grade cloud platform', 'color: #64748b; font-size: 12px;');

// Error Handling
window.addEventListener('error', (e) => {
    console.error('Global error:', e.error);
});

window.addEventListener('unhandledrejection', (e) => {
    console.error('Unhandled promise rejection:', e.reason);
});

// Analytics Placeholder
function trackPageView(page) {
    // Integrate with your analytics service
    console.log('Page view:', page);
}

trackPageView(window.location.pathname);
