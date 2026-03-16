// ClaudiQ — Frontend Application
// ================================

const navbar    = document.getElementById('navbar');
const navMenu   = document.getElementById('nav-menu');
const menuToggle = document.getElementById('menu-toggle');

// ── Mobile menu ──────────────────────────────────────────────────────────────
if (menuToggle) {
    menuToggle.addEventListener('click', () => {
        const open = navMenu.classList.toggle('active');
        menuToggle.classList.toggle('open', open);
        menuToggle.setAttribute('aria-expanded', open);
    });
}

// Close menu on nav link click
document.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', () => {
        navMenu.classList.remove('active');
        menuToggle?.classList.remove('open');
        menuToggle?.setAttribute('aria-expanded', 'false');
    });
});

// ── Smooth scroll ─────────────────────────────────────────────────────────────
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', e => {
        const target = document.querySelector(anchor.getAttribute('href'));
        if (!target) return;
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
});

// ── Navbar scroll class + active link ────────────────────────────────────────
const sections  = document.querySelectorAll('section[id]');
const navLinks  = document.querySelectorAll('.nav-link[href^="#"]');

window.addEventListener('scroll', () => {
    const y = window.scrollY;

    // Scrolled class
    navbar.classList.toggle('scrolled', y > 50);

    // Active link
    sections.forEach(section => {
        const top  = section.offsetTop - 120;
        const bot  = top + section.offsetHeight;
        if (y >= top && y < bot) {
            const id = section.id;
            navLinks.forEach(l => {
                l.classList.toggle('active', l.getAttribute('href') === `#${id}`);
            });
        }
    });
}, { passive: true });

// ── Fade-in via IntersectionObserver ─────────────────────────────────────────
const fadeObserver = new IntersectionObserver(
    entries => entries.forEach(e => {
        if (e.isIntersecting) {
            e.target.classList.add('visible');
            fadeObserver.unobserve(e.target);
        }
    }),
    { threshold: 0.1, rootMargin: '0px 0px -40px 0px' }
);

document.querySelectorAll('.fade-in').forEach(el => fadeObserver.observe(el));

// ── Deploy time formatting ────────────────────────────────────────────────────
const deployEl = document.getElementById('deploy-time');
if (deployEl) {
    const t    = new Date(deployEl.textContent.trim());
    const diff = Date.now() - t;
    const mins  = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days  = Math.floor(diff / 86400000);

    deployEl.title = t.toLocaleString();
    deployEl.textContent =
        days  > 0 ? `${days}d ago` :
        hours > 0 ? `${hours}h ago` :
        mins  > 0 ? `${mins}m ago` : 'Just now';
}

// ── Number counter animation ──────────────────────────────────────────────────
function animateCounter(el) {
    const target = parseFloat(el.dataset.target);
    const suffix = el.dataset.suffix || '';
    const duration = 1800;
    const steps = 60;
    const increment = target / steps;
    let current = 0;
    let step = 0;

    const timer = setInterval(() => {
        step++;
        current = Math.min(increment * step, target);
        const display = Number.isInteger(target) ? Math.round(current) : current.toFixed(1);
        el.textContent = display + suffix;
        if (step >= steps) clearInterval(timer);
    }, duration / steps);
}

// Trigger counter when element becomes visible
const counterObserver = new IntersectionObserver(
    entries => entries.forEach(e => {
        if (e.isIntersecting && e.target.dataset.target) {
            animateCounter(e.target);
            counterObserver.unobserve(e.target);
        }
    }),
    { threshold: 0.5 }
);

document.querySelectorAll('[data-target]').forEach(el => counterObserver.observe(el));

// ── Live system metrics (simulated) ──────────────────────────────────────────
function updateProgress(id, value) {
    const fill = document.getElementById(`${id}-progress`);
    const val  = document.getElementById(`${id}-value`);
    if (!fill || !val) return;
    fill.style.width = `${value}%`;
    val.textContent  = `${value}%`;
    fill.className   = 'progress-fill' +
        (value >= 80 ? ' danger' : value >= 60 ? ' warning' : '');
}

function tick() {
    updateProgress('cpu',    20 + Math.floor(Math.random() * 40));
    updateProgress('memory', 40 + Math.floor(Math.random() * 30));
    updateProgress('disk',   30 + Math.floor(Math.random() * 20));
}

if (document.getElementById('cpu-value')) {
    tick();
    setInterval(tick, 5000);
}

// ── Copy on click (.copyable and .info-value) ─────────────────────────────────
document.querySelectorAll('.copyable, .info-value').forEach(el => {
    el.style.cursor = 'pointer';
    if (!el.title) el.title = 'Click to copy';
    el.addEventListener('click', async () => {
        const original = el.textContent;
        try {
            await navigator.clipboard.writeText(original.trim());
            el.textContent = '✓ Copied';
            el.style.color = 'var(--primary)';
            setTimeout(() => {
                el.textContent = original;
                el.style.color = '';
            }, 1500);
        } catch {/* clipboard unavailable */}
    });
});

// ── Health check ──────────────────────────────────────────────────────────────
async function checkHealth() {
    try {
        const r = await fetch('/health', { cache: 'no-store' });
        return r.ok;
    } catch { return false; }
}

(async () => {
    const healthy = await checkHealth();
    if (!healthy) {
        document.querySelectorAll('.status-badge.ok').forEach(b => {
            b.className = 'status-badge warn';
            b.textContent = 'Checking';
        });
    }
})();

// ── Keyboard shortcuts ────────────────────────────────────────────────────────
document.addEventListener('keydown', e => {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    if (e.key === 'Escape') {
        navMenu.classList.remove('active');
        menuToggle?.classList.remove('open');
        menuToggle?.setAttribute('aria-expanded', 'false');
    }
    if (e.key === 'h' || e.key === 'H') window.scrollTo({ top: 0, behavior: 'smooth' });
});

// ── Console banner ────────────────────────────────────────────────────────────
console.log('%c⬡ ClaudiQ', 'color:#a3e635;font-size:22px;font-weight:800;');
console.log('%cBuilt with Terraform & Ansible on AWS', 'color:#65a30d;font-size:13px;');

// ── Global error handling ─────────────────────────────────────────────────────
window.addEventListener('error', e => console.error('Error:', e.error));
window.addEventListener('unhandledrejection', e => console.error('Rejection:', e.reason));
