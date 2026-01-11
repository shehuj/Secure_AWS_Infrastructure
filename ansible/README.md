# Ansible Configuration - Enterprise Web Application

Modern, responsive, and enterprise-grade web application deployment for AWS infrastructure.

## Directory Structure

```
ansible/
├── ansible.cfg                 # Ansible configuration
├── inventory/
│   └── aws_ec2.yml            # Dynamic AWS EC2 inventory
├── playbooks/
│   └── webserver.yml          # Main web server configuration playbook
├── templates/                  # Jinja2 templates for dynamic content
│   ├── index.html.j2          # Main landing page
│   └── docs.html.j2           # Documentation page
└── files/                      # Static assets
    ├── css/
    │   └── styles.css         # Modern CSS with responsive design
    └── js/
        └── app.js             # Interactive JavaScript application
```

## Features

### Modern Enterprise Design
- **Responsive Layout**: Works seamlessly on desktop, tablet, and mobile devices
- **Modern UI**: Clean, professional design with smooth animations
- **Dark Mode Support**: Automatic dark mode based on system preferences
- **Accessibility**: WCAG compliant with keyboard navigation support

### Interactive Features
- Real-time system metrics (CPU, Memory, Disk, Network)
- Health check monitoring
- Auto-refreshing data every 5 seconds
- Smooth scrolling navigation
- Mobile-friendly hamburger menu
- Click-to-copy information fields

### Enterprise-Grade
- **Security Headers**: X-Frame-Options, X-Content-Type-Options, XSS Protection
- **Performance**: Gzip compression, static asset caching (7 days)
- **SEO Optimized**: Proper meta tags and semantic HTML
- **Web Fonts**: Google Fonts (Inter) for professional typography
- **Progressive Enhancement**: Works without JavaScript

## Quick Start

### Deploy the Web Application

```bash
cd ansible

# Test connectivity
ansible all -m ping

# Deploy the web server
ansible-playbook playbooks/webserver.yml

# Check deployment status
ansible all -m shell -a "systemctl status nginx"
```

### Verify Deployment

```bash
# Check the website
curl http://YOUR_SERVER_IP/

# Check health endpoint
curl http://YOUR_SERVER_IP/health

# Check API health
curl http://YOUR_SERVER_IP/api/health
```

## Customization

### 1. Branding & Configuration

Edit variables in `playbooks/webserver.yml`:

```yaml
vars:
  # Web server ports
  nginx_port: 80
  nginx_ssl_port: 443

  # Application directory
  app_directory: /var/www/html

  # Branding (used in templates)
  company_name: "Your Company Name"
  app_environment: "production"  # or "staging", "development"
  aws_region: "us-east-1"
```

### 2. Customize the HTML

Edit the Jinja2 templates in `templates/`:

**Main Page** (`templates/index.html.j2`):
- Update hero section text
- Modify feature cards
- Add/remove sections
- Change footer information

**Documentation** (`templates/docs.html.j2`):
- Update documentation content
- Add custom sections
- Modify code examples

### 3. Customize Styling

Edit `files/css/styles.css`:

**Colors** - Change CSS variables at the top:
```css
:root {
    --primary-color: #6366f1;     /* Main brand color */
    --secondary-color: #8b5cf6;   /* Secondary accent */
    --success-color: #10b981;     /* Success states */
    /* ... more variables ... */
}
```

**Fonts** - Update in the HTML templates or CSS:
```html
<link href="https://fonts.googleapis.com/css2?family=YOUR_FONT&display=swap" rel="stylesheet">
```

**Layout** - Modify grid layouts, spacing, and breakpoints in CSS

### 4. Add Custom JavaScript

Edit `files/js/app.js`:

```javascript
// Add custom functionality
function myCustomFunction() {
    // Your code here
}

// Call your function
myCustomFunction();
```

### 5. Add New Pages

1. Create a new template in `templates/`:
   ```bash
   cp templates/docs.html.j2 templates/my-page.html.j2
   ```

2. Edit the template content

3. Add deployment task in `playbooks/webserver.yml`:
   ```yaml
   - name: Deploy my custom page
     ansible.builtin.template:
       src: my-page.html.j2
       dest: "{{ app_directory }}/my-page.html"
       owner: nginx
       group: nginx
       mode: '0644'
   ```

4. Add nginx location in the nginx configuration:
   ```nginx
   location = /my-page {
       try_files /my-page.html =404;
   }
   ```

## Configuration Options

### Nginx Configuration

The playbook configures nginx with:
- **Gzip Compression**: Enabled for text files
- **Static Caching**: 7-day cache for /static/ assets
- **Security Headers**: XSS protection, frame options, content type
- **Custom Locations**: Root, docs, API endpoints

To modify nginx settings, edit the `Configure nginx` task in `playbooks/webserver.yml`.

### System Metrics

The JavaScript automatically fetches and displays:
- CPU usage (simulated - replace with real API calls)
- Memory usage (simulated - replace with real API calls)
- Disk usage (simulated - replace with real API calls)
- Network status

To connect to real metrics:
1. Set up a metrics API endpoint
2. Update the `updateMetrics()` function in `files/js/app.js`
3. Replace fetch calls with your API

## Advanced Customization

### Add Real-Time Metrics

Replace simulated metrics with CloudWatch data:

```javascript
async function updateMetrics() {
    try {
        const response = await fetch('/api/metrics');
        const data = await response.json();

        document.getElementById('cpu-value').textContent = `${data.cpu}%`;
        document.getElementById('cpu-progress').style.width = `${data.cpu}%`;
        // ... update other metrics
    } catch (error) {
        console.error('Failed to fetch metrics:', error);
    }
}
```

### Enable HTTPS

1. Obtain SSL certificates (Let's Encrypt recommended)
2. Update nginx configuration in the playbook:

```yaml
server {
    listen 443 ssl http2;
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    # ... rest of config
}
```

### Add Authentication

Add basic auth or integrate with OAuth:

```yaml
location / {
    auth_basic "Restricted Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
    try_files $uri $uri/ =404;
}
```

### Progressive Web App (PWA)

Uncomment service worker registration in `files/js/app.js` and create a service worker:

```javascript
// In files/js/sw.js
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open('v1').then((cache) => {
            return cache.addAll([
                '/',
                '/static/css/styles.css',
                '/static/js/app.js',
            ]);
        })
    );
});
```

## Troubleshooting

### Website Not Loading

```bash
# Check nginx status
systemctl status nginx

# Check nginx error logs
tail -f /var/log/nginx/error.log

# Test nginx configuration
nginx -t

# Restart nginx
systemctl restart nginx
```

### Static Assets Not Loading

```bash
# Check file permissions
ls -la /var/www/html/static/

# Verify files exist
find /var/www/html -type f

# Check nginx access logs
tail -f /var/log/nginx/access.log
```

### JavaScript Not Working

1. Open browser developer console (F12)
2. Check for JavaScript errors
3. Verify JS file is loading: `/static/js/app.js`
4. Check nginx mime types include JavaScript

## Testing

### Run Syntax Check

```bash
ansible-playbook playbooks/webserver.yml --syntax-check
```

### Run Linting

```bash
ansible-lint playbooks/webserver.yml
```

### Run in Check Mode (Dry Run)

```bash
ansible-playbook playbooks/webserver.yml --check
```

### Deploy to Specific Hosts

```bash
ansible-playbook playbooks/webserver.yml --limit "10.0.1.100"
```

## Best Practices

1. **Always test changes locally** before deploying to production
2. **Use version control** for all template and file changes
3. **Keep backups** of customized files
4. **Document customizations** in this README
5. **Test responsive design** on multiple devices
6. **Validate HTML/CSS** using W3C validators
7. **Run ansible-lint** before committing changes
8. **Monitor performance** after deploying changes

## Performance Optimization

### Minimize CSS/JS

For production, minify assets:

```bash
# Install minifiers
npm install -g csso-cli uglify-js

# Minify CSS
csso files/css/styles.css -o files/css/styles.min.css

# Minify JS
uglifyjs files/js/app.js -o files/js/app.min.js
```

Then update template references to use `.min.css` and `.min.js`.

### Enable HTTP/2

In nginx configuration:
```nginx
listen 443 ssl http2;
```

### Add CDN

For static assets, use a CDN:
```html
<link rel="stylesheet" href="https://cdn.example.com/static/css/styles.css">
```

## Support

For issues or questions:
- Check the main project [README](../README.md)
- Review [Ansible documentation](https://docs.ansible.com/)
- Open an issue on GitHub

## License

See the main project [LICENSE](../LICENSE) file.

---

Built with ❤️ using Ansible for enterprise-grade configuration management.
