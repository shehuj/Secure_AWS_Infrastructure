// ClaudiQ — Frontend Application
// ================================

const navbar     = document.getElementById('navbar');
const navMenu    = document.getElementById('nav-menu');
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

// ── Inject scroll progress bar ────────────────────────────────────────────────
const scrollProgress = document.createElement('div');
scrollProgress.className = 'scroll-progress';
document.body.prepend(scrollProgress);

// ── Inject back-to-top button ─────────────────────────────────────────────────
const backToTop = document.createElement('button');
backToTop.className = 'back-to-top';
backToTop.setAttribute('aria-label', 'Back to top');
backToTop.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"><polyline points="18 15 12 9 6 15"/></svg>`;
document.body.appendChild(backToTop);

backToTop.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));

// ── Navbar scroll class + active link (rAF-throttled) ────────────────────────
const sections = document.querySelectorAll('section[id]');
const navLinks = document.querySelectorAll('.nav-link[href^="#"]');

let scrollTicking = false;

function handleScroll() {
    const y = window.scrollY;

    navbar.classList.toggle('scrolled', y > 50);

    // Active nav link
    sections.forEach(section => {
        const top = section.offsetTop - 120;
        const bot = top + section.offsetHeight;
        if (y >= top && y < bot) {
            const id = section.id;
            navLinks.forEach(l => {
                l.classList.toggle('active', l.getAttribute('href') === `#${id}`);
            });
        }
    });

    // Scroll progress bar
    const docHeight = document.documentElement.scrollHeight - window.innerHeight;
    scrollProgress.style.width = docHeight > 0 ? `${(y / docHeight) * 100}%` : '0%';

    // Back to top visibility
    backToTop.classList.toggle('visible', y > 400);

    scrollTicking = false;
}

window.addEventListener('scroll', () => {
    if (!scrollTicking) {
        requestAnimationFrame(handleScroll);
        scrollTicking = true;
    }
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

// Assign stagger index to grid children so fade-in delays cascade
document.querySelectorAll('.features-grid, .info-grid, .metrics-grid, .status-grid').forEach(grid => {
    grid.querySelectorAll('.fade-in').forEach((el, i) => el.style.setProperty('--i', i));
});

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

// ── Number counter animation (ease-out quart) ─────────────────────────────────
function animateCounter(el) {
    const target   = parseFloat(el.dataset.target);
    const suffix   = el.dataset.suffix || '';
    const duration = 1800;
    const start    = performance.now();

    function step(now) {
        const progress = Math.min((now - start) / duration, 1);
        const eased    = 1 - Math.pow(1 - progress, 4);
        const current  = target * eased;
        el.textContent = (Number.isInteger(target) ? Math.round(current) : current.toFixed(1)) + suffix;
        if (progress < 1) requestAnimationFrame(step);
    }

    requestAnimationFrame(step);
}

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

// ── Button ripple ─────────────────────────────────────────────────────────────
document.querySelectorAll('.btn').forEach(btn => {
    btn.addEventListener('click', e => {
        const ripple = document.createElement('span');
        ripple.className = 'ripple';
        const rect = btn.getBoundingClientRect();
        ripple.style.left = `${e.clientX - rect.left - 4}px`;
        ripple.style.top  = `${e.clientY - rect.top  - 4}px`;
        btn.appendChild(ripple);
        ripple.addEventListener('animationend', () => ripple.remove());
    });
});

// ── Health check ──────────────────────────────────────────────────────────────
async function checkHealth() {
    try {
        const r = await fetch('/health', { cache: 'no-store' });
        return r.ok;
    } catch { return false; }
}

function applyHealthStatus(healthy) {
    document.querySelectorAll('.status-badge').forEach(b => {
        if (healthy) {
            if (b.classList.contains('warn') && b.textContent.trim() === 'Checking') {
                b.className = 'status-badge ok';
                b.textContent = 'Operational';
            }
        } else {
            b.className = 'status-badge warn';
            b.textContent = 'Checking';
        }
    });
}

(async () => applyHealthStatus(await checkHealth()))();
setInterval(async () => applyHealthStatus(await checkHealth()), 30000);

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

// ── Typed word cycler (#typed-word on index page) ────────────────────────────
const typedEl  = document.getElementById('typed-word');
const typedCursor = document.querySelector('.hero-cursor');
if (typedEl) {
    const words = ['Infrastructure', 'Security', 'Scalability', 'Reliability', 'Automation'];
    let wordIndex = 0;
    let charIndex = 0;
    let deleting  = false;

    function typeStep() {
        const current = words[wordIndex];
        typedEl.textContent = deleting
            ? current.slice(0, --charIndex)
            : current.slice(0, ++charIndex);

        let delay = deleting ? 55 : 95;
        if (!deleting && charIndex === current.length) {
            delay    = 2000;
            deleting = true;
        } else if (deleting && charIndex === 0) {
            deleting  = false;
            wordIndex = (wordIndex + 1) % words.length;
            delay     = 300;
        }
        setTimeout(typeStep, delay);
    }
    // Hide built-in cursor while static, start after initial load pause
    setTimeout(typeStep, 1600);
}

// ── Code block copy buttons (docs page) ───────────────────────────────────────
document.querySelectorAll('.docs-pre-wrap').forEach(wrap => {
    const btn = document.createElement('button');
    btn.className   = 'code-copy-btn';
    btn.textContent = 'Copy';
    wrap.appendChild(btn);

    btn.addEventListener('click', async () => {
        const pre  = wrap.querySelector('pre');
        const code = pre?.querySelector('code')?.textContent ?? pre?.textContent ?? '';
        try {
            await navigator.clipboard.writeText(code.trim());
            btn.textContent = '✓ Copied';
            setTimeout(() => { btn.textContent = 'Copy'; }, 1800);
        } catch { /* clipboard unavailable */ }
    });
});

// ── Docs sidebar: active link tracking + mobile toggle ────────────────────────
const docsNavLinks = document.querySelectorAll('#docs-nav a[href^="#"]');
if (docsNavLinks.length > 0) {
    const docsSections = document.querySelectorAll('#docs-content section[id]');

    function updateDocsNav() {
        const y = window.scrollY + 130;
        docsSections.forEach(section => {
            const top = section.offsetTop;
            const bot = top + section.offsetHeight;
            if (y >= top && y < bot) {
                docsNavLinks.forEach(l => {
                    l.classList.toggle('active', l.getAttribute('href') === `#${section.id}`);
                });
            }
        });
    }

    window.addEventListener('scroll', updateDocsNav, { passive: true });
    updateDocsNav();
}

const sidebarToggle  = document.getElementById('sidebar-toggle');
const sidebarNavBody = document.getElementById('sidebar-nav-body');
const toggleIcon     = document.getElementById('toggle-icon');
if (sidebarToggle && sidebarNavBody) {
    // Collapse by default on narrow screens
    if (window.innerWidth <= 900) {
        sidebarNavBody.classList.add('hidden');
        toggleIcon.textContent = '▾';
        sidebarToggle.setAttribute('aria-expanded', 'false');
    }
    sidebarToggle.addEventListener('click', () => {
        const isHidden = sidebarNavBody.classList.toggle('hidden');
        toggleIcon.textContent = isHidden ? '▾' : '▴';
        sidebarToggle.setAttribute('aria-expanded', String(!isHidden));
    });
    // Auto-close after a sidebar link click on mobile
    docsNavLinks.forEach(l => {
        l.addEventListener('click', () => {
            if (window.innerWidth <= 900) {
                sidebarNavBody.classList.add('hidden');
                toggleIcon.textContent = '▾';
                sidebarToggle.setAttribute('aria-expanded', 'false');
            }
        });
    });
}

// ── Console banner ────────────────────────────────────────────────────────────
console.log('%c⬡ ClaudiQ', 'color:#a3e635;font-size:22px;font-weight:800;');
console.log('%cBuilt with Terraform & Ansible on AWS', 'color:#65a30d;font-size:13px;');

// ── Global error handling ─────────────────────────────────────────────────────
window.addEventListener('error', e => console.error('Error:', e.error));
window.addEventListener('unhandledrejection', e => console.error('Rejection:', e.reason));
