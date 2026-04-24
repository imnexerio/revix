// Navigation Toggle
const navToggle = document.getElementById('nav-toggle');
const navMenu = document.getElementById('nav-menu');

navToggle.addEventListener('click', () => {
    navMenu.classList.toggle('active');
    navToggle.classList.toggle('active');
});

// Close mobile menu when clicking on a link
document.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', () => {
        navMenu.classList.remove('active');
        navToggle.classList.remove('active');
    });
});

// Theme Toggle Functionality
const themeToggle = document.getElementById('theme-toggle');
const themeIcon = document.getElementById('theme-icon');
const body = document.body;

// Check for saved theme preference or default to 'dark'
const currentTheme = localStorage.getItem('theme') || 'dark';

// Apply the saved theme on page load
if (currentTheme === 'dark') {
    body.setAttribute('data-theme', 'dark');
    themeIcon.textContent = 'nights_stay'; // Show moon icon for current dark theme
} else {
    body.setAttribute('data-theme', 'light');
    themeIcon.textContent = 'wb_sunny'; // Show sun icon for current light theme
}

// Theme toggle event listener
themeToggle.addEventListener('click', () => {
    const currentTheme = body.getAttribute('data-theme');
    
    if (currentTheme === 'dark') {
        // Switching FROM dark TO light
        body.setAttribute('data-theme', 'light');
        themeIcon.textContent = 'wb_sunny'; // Show sun icon for light theme
        localStorage.setItem('theme', 'light');
    } else {
        // Switching FROM light TO dark
        body.setAttribute('data-theme', 'dark');
        themeIcon.textContent = 'nights_stay'; // Show moon icon for dark theme
        localStorage.setItem('theme', 'dark');
    }
    
    const navbar = document.querySelector('.navbar');
    if (navbar && navbar.style.background) {
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        const newTheme = body.getAttribute('data-theme');
        
        if (scrollTop > 50) {
            if (newTheme === 'dark') {
                navbar.style.background = 'rgba(26, 26, 26, 0.98)';
            } else {
                navbar.style.background = 'rgba(255, 255, 255, 0.98)';
            }
        } else {
            if (newTheme === 'dark') {
                navbar.style.background = 'rgba(26, 26, 26, 0.95)';
            } else {
                navbar.style.background = 'rgba(255, 255, 255, 0.95)';
            }
        }
    }
    
    // Add a subtle animation to the theme toggle
    themeToggle.style.transform = 'scale(0.9)';
    setTimeout(() => {
        themeToggle.style.transform = 'scale(1)';
    }, 150);
});

// Smooth scroll for navigation links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            const headerOffset = 80;
            const elementPosition = target.getBoundingClientRect().top;
            const offsetPosition = elementPosition + window.pageYOffset - headerOffset;

            window.scrollTo({
                top: offsetPosition,
                behavior: 'smooth'
            });
        }
    });
});

// Navbar scroll effect
let lastScrollTop = 0;
const navbar = document.querySelector('.navbar');

window.addEventListener('scroll', () => {
    const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
    
    if (scrollTop > lastScrollTop && scrollTop > 100) {
        // Scrolling down
        navbar.style.transform = 'translateY(-100%)';
    } else {
        // Scrolling up
        navbar.style.transform = 'translateY(0)';
    }
    
    // Add background opacity based on scroll and theme
    const currentTheme = document.body.getAttribute('data-theme');
    if (scrollTop > 50) {
        if (currentTheme === 'dark') {
            navbar.style.background = 'rgba(26, 26, 26, 0.98)';
        } else {
            navbar.style.background = 'rgba(255, 255, 255, 0.98)';
        }
        navbar.style.boxShadow = '0 2px 20px rgba(0, 0, 0, 0.1)';
    } else {
        if (currentTheme === 'dark') {
            navbar.style.background = 'rgba(26, 26, 26, 0.95)';
        } else {
            navbar.style.background = 'rgba(255, 255, 255, 0.95)';
        }
        navbar.style.boxShadow = 'none';
    }
    
    lastScrollTop = scrollTop <= 0 ? 0 : scrollTop;
});

// Screenshots Carousel
let currentSlide = 0;
const slides = document.querySelectorAll('.screenshot-item');
const dots = document.querySelectorAll('.nav-dot');

function showSlide(index) {
    // Hide all slides
    slides.forEach(slide => {
        slide.classList.remove('active');
    });
    
    // Remove active class from all dots
    dots.forEach(dot => {
        dot.classList.remove('active');
    });
    
    // Show current slide and activate corresponding dot
    if (slides[index]) {
        slides[index].classList.add('active');
        dots[index].classList.add('active');
    }
}

function nextSlide() {
    currentSlide = (currentSlide + 1) % slides.length;
    showSlide(currentSlide);
}

function prevSlide() {
    currentSlide = (currentSlide - 1 + slides.length) % slides.length;
    showSlide(currentSlide);
}

// Dot navigation
dots.forEach((dot, index) => {
    dot.addEventListener('click', () => {
        currentSlide = index;
        showSlide(currentSlide);
    });
});

// Auto-advance carousel
let carouselInterval = setInterval(nextSlide, 5000);

// Pause auto-advance on hover
const screenshotsCarousel = document.querySelector('.screenshots-carousel');
if (screenshotsCarousel) {
    screenshotsCarousel.addEventListener('mouseenter', () => {
        clearInterval(carouselInterval);
    });
    
    screenshotsCarousel.addEventListener('mouseleave', () => {
        carouselInterval = setInterval(nextSlide, 5000);
    });
}

// Keyboard navigation for carousel
document.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowLeft') {
        prevSlide();
        clearInterval(carouselInterval);
        carouselInterval = setInterval(nextSlide, 5000);
    } else if (e.key === 'ArrowRight') {
        nextSlide();
        clearInterval(carouselInterval);
        carouselInterval = setInterval(nextSlide, 5000);
    }
});

// Animation on scroll
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
document.querySelectorAll('.feature-card, .download-option, .hero-stats, .floating-card').forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(30px)';
    el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
    observer.observe(el);
});

// Counter animation for hero stats
function animateCounter(element, target, duration = 2000) {
    const start = 0;
    const increment = target / (duration / 16);
    let current = start;
    
    const timer = setInterval(() => {
        current += increment;
        if (current >= target) {
            current = target;
            clearInterval(timer);
        }
        
        // Format numbers nicely
        if (target >= 1000) {
            element.textContent = (current / 1000).toFixed(1) + 'K+';
        } else {
            element.textContent = current.toFixed(1);
        }
    }, 16);
}

// Trigger counter animation when stats come into view
const statsObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            const statNumbers = entry.target.querySelectorAll('.stat-number');
            statNumbers.forEach(stat => {
                const text = stat.textContent;
                let target = 0;
                
                if (text.includes('10K+')) target = 10000;
                else if (text.includes('4.8')) target = 4.8;
                else if (text.includes('100K+')) target = 100000;
                
                if (target > 0) {
                    animateCounter(stat, target);
                }
            });
            statsObserver.unobserve(entry.target);
        }
    });
}, observerOptions);

const heroStats = document.querySelector('.hero-stats');
if (heroStats) {
    statsObserver.observe(heroStats);
}

// Modal functionality
const modal = document.getElementById('comingSoonModal');
const modalMessage = document.getElementById('modalMessage');
const closeModal = document.querySelector('.close');

function showComingSoon(platform) {
    modalMessage.textContent = `${platform} version is coming soon! Stay tuned for updates.`;
    modal.style.display = 'block';
    document.body.style.overflow = 'hidden';
    
    // Add entrance animation
    modal.style.opacity = '0';
    setTimeout(() => {
        modal.style.opacity = '1';
    }, 10);
}

function hideModal() {
    modal.style.opacity = '0';
    setTimeout(() => {
        modal.style.display = 'none';
        document.body.style.overflow = 'auto';
    }, 300);
}

// Close modal events
closeModal.addEventListener('click', hideModal);

window.addEventListener('click', (event) => {
    if (event.target === modal) {
        hideModal();
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && modal.style.display === 'block') {
        hideModal();
    }
});

// Make functions available globally
window.closeModal = hideModal;
window.showComingSoon = showComingSoon;
window.downloadSelectedFormat = downloadSelectedFormat;
window.updateFormatInfo = updateFormatInfo;

// Parallax effect for hero background shapes
window.addEventListener('scroll', () => {
    const scrolled = window.pageYOffset;
    const shapes = document.querySelectorAll('.bg-shape');
    
    shapes.forEach((shape, index) => {
        const speed = 0.5 + (index * 0.1);
        shape.style.transform = `translateY(${scrolled * speed}px) rotate(${scrolled * 0.1}deg)`;
    });
});

// Floating cards animation enhancement
document.querySelectorAll('.floating-card').forEach((card, index) => {
    card.addEventListener('mouseenter', () => {
        card.style.transform = 'scale(1.05) translateY(-10px)';
        card.style.boxShadow = '0 20px 40px rgba(0, 0, 0, 0.15)';
    });
    
    card.addEventListener('mouseleave', () => {
        card.style.transform = 'scale(1) translateY(0)';
        card.style.boxShadow = '0 10px 15px rgba(0, 0, 0, 0.1)';
    });
});

// Progressive loading simulation for app preview
function simulateAppLoading() {
    const appPreview = document.querySelector('.app-preview');
    if (appPreview) {
        appPreview.style.opacity = '0.3';
        appPreview.style.filter = 'blur(5px)';
        
        setTimeout(() => {
            appPreview.style.transition = 'all 1s ease';
            appPreview.style.opacity = '1';
            appPreview.style.filter = 'blur(0px)';
        }, 500);
    }
}

// Feature cards hover effect
document.querySelectorAll('.feature-card').forEach(card => {
    card.addEventListener('mouseenter', () => {
        const icon = card.querySelector('.feature-icon');
        if (icon) {
            icon.style.transform = 'scale(1.1) rotate(5deg)';
        }
    });
    
    card.addEventListener('mouseleave', () => {
        const icon = card.querySelector('.feature-icon');
        if (icon) {
            icon.style.transform = 'scale(1) rotate(0deg)';
        }
    });
});

// Download options pulse effect
document.querySelectorAll('.download-option').forEach(option => {
    option.addEventListener('mouseenter', () => {
        const icon = option.querySelector('.platform-icon');
        if (icon) {
            icon.style.animation = 'pulse 0.6s ease infinite';
        }
    });
    
    option.addEventListener('mouseleave', () => {
        const icon = option.querySelector('.platform-icon');
        if (icon) {
            icon.style.animation = 'none';
        }
    });
});

// Add pulse animation to CSS dynamically
const style = document.createElement('style');
style.textContent = `
    @keyframes pulse {
        0%, 100% { transform: scale(1); }
        50% { transform: scale(1.05); }
    }
`;
document.head.appendChild(style);

// Initialize everything when DOM is fully loaded
document.addEventListener('DOMContentLoaded', () => {
    simulateAppLoading();
    
    // Add loading animation to buttons
    document.querySelectorAll('.btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            if (this.getAttribute('href') === '#' || this.getAttribute('onclick')) {
                e.preventDefault();
                
                // Add loading state
                const originalText = this.innerHTML;
                this.innerHTML = '<span class="material-icons-outlined rotating">autorenew</span>Loading...';
                this.style.pointerEvents = 'none';
                
                // Add rotation animation
                const rotatingIcon = this.querySelector('.rotating');
                if (rotatingIcon) {
                    rotatingIcon.style.animation = 'rotate 1s linear infinite';
                }
                
                setTimeout(() => {
                    this.innerHTML = originalText;
                    this.style.pointerEvents = 'auto';
                    
                    // Trigger the actual function if it exists
                    const onclickAttr = this.getAttribute('onclick');
                    if (onclickAttr) {
                        eval(onclickAttr);
                    }
                }, 1000);
            }
        });
    });
});

// Performance optimization: Debounce scroll events
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Apply debouncing to scroll events
const debouncedScrollHandler = debounce(() => {
    // Any expensive scroll operations can go here
}, 16);

window.addEventListener('scroll', debouncedScrollHandler);


// Platform Showcase Functionality
document.addEventListener('DOMContentLoaded', function() {
    // Platform tab switching
    const platformTabs = document.querySelectorAll('.tab-btn');
    const platformViews = document.querySelectorAll('.platform-view');
    
    // Create realistic sync pulse effect
    function createSyncPulse() {
        platformTabs.forEach((tab, index) => {
            setTimeout(() => {
                tab.classList.add('sync-pulse');
                tab.classList.add('sync-active');
                
                setTimeout(() => {
                    tab.classList.remove('sync-pulse');
                }, 800);
                
                setTimeout(() => {
                    tab.classList.remove('sync-active');
                }, 1500);
            }, index * 150);
        });
    }
    
    // Enhanced sync animation every 3 seconds
    setInterval(() => {
        createSyncPulse();
    }, 3000);
    
    platformTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const platform = tab.dataset.platform;
            
            // Remove active class from all tabs and views
            platformTabs.forEach(t => t.classList.remove('active'));
            platformViews.forEach(v => v.classList.remove('active'));
            
            // Add active class to clicked tab and corresponding view
            tab.classList.add('active');
            document.getElementById(`${platform}-view`).classList.add('active');
            
            // Trigger immediate sync animation when platform is switched
            triggerSyncSequence();
        });
    });
    
    // Enhanced sync sequence when switching platforms
    function triggerSyncSequence() {
        // Show sync animation across all platforms
        platformTabs.forEach((tab, index) => {
            setTimeout(() => {
                tab.classList.add('sync-pulse');
                tab.classList.add('sync-active');
                
                setTimeout(() => {
                    tab.classList.remove('sync-pulse');
                    tab.classList.remove('sync-active');
                }, 600);
            }, index * 100);
        });
    }
    
    // Auto-rotate platform tabs for demonstration
    let currentPlatformIndex = 0;
    const platforms = ['web', 'android', 'ios', 'windows', 'macos', 'linux'];
    
    function autoRotatePlatforms() {
        const currentTab = document.querySelector(`.tab-btn[data-platform="${platforms[currentPlatformIndex]}"]`);
        if (currentTab) {
            currentTab.click();
        }
        currentPlatformIndex = (currentPlatformIndex + 1) % platforms.length;
    }
    
    // Auto-rotate every 6 seconds to show sync effect
    setInterval(autoRotatePlatforms, 6000);
    
    // Initial sync pulse after page load
    setTimeout(() => {
        createSyncPulse();
    }, 1000);
});

// OS Detection
function detectUserOS() {
    const userAgent = window.navigator.userAgent.toLowerCase();
    const platform = window.navigator.platform.toLowerCase();
    
    if (userAgent.indexOf('android') > -1) return 'android';
    if (userAgent.indexOf('iphone') > -1 || userAgent.indexOf('ipad') > -1) return 'ios';
    if (platform.indexOf('win') > -1) return 'windows';
    if (platform.indexOf('mac') > -1) return 'macos';
    if (platform.indexOf('linux') > -1 || platform.indexOf('x11') > -1) return 'linux';
    
    return null;
}

// Show OS Detection Hero
function showOSDetectionHero(detectedOS, release, assets) {
    const hero = document.getElementById('download-hero');
    if (!hero || !detectedOS) return;
    
    const platformConfig = {
        android: { name: 'Android', icon: 'phone_android', pattern: /\.(apk|aab)$/i },
        ios: { name: 'iOS', icon: 'phone_iphone', pattern: /\.(ipa)$/i },
        windows: { name: 'Windows', icon: 'computer', pattern: /\.(exe|msi|msix)$/i },
        macos: { name: 'macOS', icon: 'laptop_mac', pattern: /\.(dmg|pkg|app\.zip)$/i },
        linux: { name: 'Linux', icon: 'desktop_windows', pattern: /\.(AppImage|deb|rpm|tar\.gz)$/i }
    };
    
    const config = platformConfig[detectedOS];
    if (!config) return;
    
    // Find matching asset
    let matchingAsset = null;
    if (assets && assets.length > 0) {
        matchingAsset = assets.find(asset => config.pattern.test(asset.name.toLowerCase()));
    }
    
    if (matchingAsset) {
        document.getElementById('hero-icon').textContent = config.icon;
        document.getElementById('hero-title').textContent = `Download for ${config.name}`;
        document.getElementById('hero-version').textContent = release?.tag_name || 'Latest';
        document.getElementById('hero-size').textContent = formatFileSize(matchingAsset.size);
        document.getElementById('hero-download-btn').href = matchingAsset.browser_download_url;
        hero.style.display = 'block';
    }
}

// Update format info when selection changes
function updateFormatInfo(platformKey) {
    const select = document.getElementById(`format-select-${platformKey}`);
    const infoDiv = document.getElementById(`format-info-${platformKey}`);
    
    if (select && infoDiv) {
        const selectedOption = select.options[select.selectedIndex];
        const optionText = selectedOption.text;
        const infoText = infoDiv.querySelector('.format-info-text');
        
        // Extract helpful info from the option
        if (optionText.includes('Universal')) {
            infoText.textContent = 'Recommended: Works on all Mac computers';
        } else if (optionText.includes('ARM64')) {
            infoText.textContent = 'For newer Macs with M1/M2/M3 chips or ARM devices';
        } else if (optionText.includes('x64')) {
            infoText.textContent = 'For older Intel-based computers';
        } else if (optionText.includes('installer')) {
            infoText.textContent = 'Installs to your system with auto-updates';
        } else if (optionText.includes('Portable')) {
            infoText.textContent = 'No installation needed, run directly';
        } else if (optionText.includes('AppImage')) {
            infoText.textContent = 'Universal Linux package, just make executable and run';
        } else if (optionText.includes('DEB')) {
            infoText.textContent = 'For Debian, Ubuntu, Linux Mint, Pop!_OS';
        } else if (optionText.includes('RPM')) {
            infoText.textContent = 'For Fedora, RHEL, CentOS, openSUSE';
        } else {
            infoText.textContent = 'Click Download to get this version';
        }
    }
}

// Download selected format from dropdown
function downloadSelectedFormat(platformKey, defaultUrl) {
    const select = document.getElementById(`format-select-${platformKey}`);
    const downloadUrl = select ? select.value : defaultUrl;
    
    // Create temporary link and trigger download
    const link = document.createElement('a');
    link.href = downloadUrl;
    link.download = '';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

// Download Tab Filtering
function initializeDownloadTabs() {
    const tabButtons = document.querySelectorAll('.download-tab-btn');
    const downloadCards = document.querySelectorAll('.download-option');
    
    tabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const category = btn.dataset.category;
            
            // Update active tab
            tabButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            
            // Filter cards
            downloadCards.forEach(card => {
                const cardCategory = card.dataset.category;
                if (category === 'all' || cardCategory === category) {
                    card.style.display = 'flex';
                } else {
                    card.style.display = 'none';
                }
            });
        });
    });
}

// Dynamic Downloads from GitHub Releases
async function loadGitHubReleases() {
    const downloadGrid = document.getElementById('download-grid');
    if (!downloadGrid) return;

    try {
        // Fetch latest release from GitHub API
        const response = await fetch('https://api.github.com/repos/imnexerio/revix/releases/latest');
        
        let release = null;
        let assets = [];
        
        if (response.ok) {
            release = await response.json();
            assets = release.assets || [];
        }
        
        // Detect user's OS
        const detectedOS = detectUserOS();
        
        // Show hero section if OS detected
        showOSDetectionHero(detectedOS, release, assets);
        
        // Clear loading message
        downloadGrid.innerHTML = '';
        
        // Define all platforms (always show these 6)
        const allPlatforms = [
            {
                key: 'android',
                pattern: /\.(apk|aab)$/i,
                icon: 'phone_android',
                name: 'Android',
                description: 'APK for Android devices',
                fallbackDescription: 'Use web app on Android'
            },
            {
                key: 'ios',
                pattern: /\.(ipa)$/i,
                icon: 'phone_iphone',
                name: 'iOS',
                description: 'IPA for iOS devices',
                fallbackDescription: 'Use web app on iOS'
            },
            {
                key: 'windows',
                pattern: /\.(exe|msi|msix)$/i,
                icon: 'computer',
                name: 'Windows',
                description: 'Installer for Windows',
                fallbackDescription: 'Use web app on Windows'
            },
            {
                key: 'macos',
                pattern: /\.(dmg|pkg|app\.zip)$/i,
                icon: 'laptop_mac',
                name: 'macOS',
                description: 'Package for macOS',
                fallbackDescription: 'Use web app on macOS'
            },
            {
                key: 'linux',
                pattern: /\.(AppImage|deb|rpm|tar\.gz|tar\.xz)$/i,
                icon: 'desktop_windows',
                name: 'Linux',
                description: 'Package for Linux',
                fallbackDescription: 'Use web app on Linux'
            },
            {
                key: 'web',
                pattern: null, // Always available
                icon: 'language',
                name: 'Web App',
                description: 'Use directly in your browser',
                fallbackDescription: 'Works on all devices'
            }
        ];
        
        // Create download options for all platforms
        allPlatforms.forEach(platform => {
            let matchingAssets = [];
            
            // Find all matching assets for this platform (except web)
            if (platform.pattern && assets.length > 0) {
                matchingAssets = assets.filter(asset => 
                    platform.pattern.test(asset.name.toLowerCase())
                );
            }
            
            // Create download option (with assets or fallback to web app)
            createDownloadOption(platform, matchingAssets, release?.tag_name, assets);
        });
        
    } catch (error) {
        console.error('Error loading GitHub releases:', error);
        // Even if API fails, show all platforms with web app fallback
        showAllPlatformsWithWebFallback();
    }
}

function createDownloadOption(platform, matchingAssets, version, allAssets) {
    const downloadGrid = document.getElementById('download-grid');
    const detectedOS = detectUserOS();
    
    const downloadOption = document.createElement('div');
    downloadOption.className = 'download-option';
    
    // Set category for filtering
    if (platform.key === 'android' || platform.key === 'ios') {
        downloadOption.dataset.category = 'mobile';
    } else if (platform.key === 'web') {
        downloadOption.dataset.category = 'web';
    } else {
        downloadOption.dataset.category = 'desktop';
    }
    
    // Mark as detected platform
    if (platform.key === detectedOS) {
        downloadOption.classList.add('detected');
    }
    
    let downloadContent;
    const primaryAsset = matchingAssets && matchingAssets.length > 0 ? matchingAssets[0] : null;
    
    if (platform.key === 'web') {
        // Web app - always available
        downloadContent = `
            <div class="platform-icon web">
                <span class="material-icons-outlined">${platform.icon}</span>
            </div>
            <h3>${platform.name}</h3>
            <div class="download-meta">
                <span class="version-badge">Progressive Web App</span>
                <span class="rating-badge">★★★★★ 4.8</span>
            </div>
            <p>Access Revix instantly from any browser. Full-featured experience with no installation required.</p>
            <div class="download-options">
                <a href="https://revix-web.web.app" class="btn btn-platform download-primary" target="_blank">
                    <span class="material-icons-outlined">open_in_new</span>
                    Launch Web App
                </a>
            </div>
        `;
    } else if (primaryAsset) {
        // Platform-specific download available
        const fileExt = getFileExtension(primaryAsset.name).toUpperCase();
        
        // Build select dropdown if multiple files
        let selectHTML = '';
        if (matchingAssets.length > 1) {
            const options = matchingAssets.map((asset, index) => {
                const ext = getFileExtension(asset.name).toUpperCase();
                const fileName = asset.name.toLowerCase();
                
                // Determine architecture and description
                let arch = '';
                let description = '';
                
                if (fileName.includes('universal') || fileName.includes('mac.zip')) {
                    arch = 'Universal';
                    description = 'For all Macs (Intel & Apple Silicon)';
                } else if (fileName.includes('arm64') || fileName.includes('aarch64')) {
                    arch = 'ARM64';
                    description = 'For Apple Silicon Macs & ARM devices';
                } else if (fileName.includes('amd64') || fileName.includes('x86_64') || fileName.includes('x64')) {
                    arch = 'x64';
                    description = 'For Intel/AMD 64-bit processors';
                } else if (fileName.includes('setup')) {
                    description = 'Full installer with auto-update';
                } else if (fileName.includes('portable') || !fileName.includes('setup')) {
                    description = 'Portable/standalone version';
                }
                
                const archText = arch ? ` (${arch})` : '';
                const descText = description ? ` - ${description}` : '';
                const sizeText = `${formatFileSize(asset.size)}`;
                
                return `<option value="${asset.browser_download_url}">${ext}${archText} - ${sizeText}${descText}</option>`;
            }).join('');
            
            selectHTML = `
                <div class="format-selector">
                    <label for="format-select-${platform.key}">Choose your format:</label>
                    <select id="format-select-${platform.key}" class="format-select" onchange="updateFormatInfo('${platform.key}')">
                        ${options}
                    </select>
                    <div class="format-info" id="format-info-${platform.key}">
                        <span class="material-icons-outlined">info</span>
                        <span class="format-info-text"></span>
                    </div>
                </div>
            `;
        }
        
        downloadContent = `
            <div class="platform-icon ${platform.key}">
                <span class="material-icons-outlined">${platform.icon}</span>
            </div>
            <h3>${platform.name}</h3>
            <div class="download-meta">
                <span class="version-badge">${version || 'Latest'}</span>
                <span class="size-badge">${formatFileSize(primaryAsset.size)}</span>
                <span class="rating-badge">★★★★★ 4.8</span>
            </div>
            <p>${platform.description} • ${fileExt} installer with automatic updates.</p>
            ${selectHTML}
            <div class="download-options">
                <button class="btn btn-platform download-primary" onclick="downloadSelectedFormat('${platform.key}', '${primaryAsset.browser_download_url}')">
                    <span class="material-icons-outlined">download</span>
                    Download ${matchingAssets.length > 1 ? 'Selected' : fileExt}
                </button>
            </div>
        `;
    } else {
        // No platform-specific file, fallback to web app
        downloadContent = `
            <div class="platform-icon ${platform.key}">
                <span class="material-icons-outlined">${platform.icon}</span>
            </div>
            <h3>${platform.name}</h3>
            <div class="download-meta">
                <span class="version-badge">Coming Soon</span>
                <span class="rating-badge">★★★★★ 4.8</span>
            </div>
            <p>Native ${platform.name} app in development. Use our full-featured web app in the meantime.</p>
            <div class="download-options">
                <a href="https://revix-web.web.app" class="btn btn-platform download-primary" target="_blank">
                    <span class="material-icons-outlined">open_in_new</span>
                    Use Web App
                </a>
            </div>
        `;
    }
    
    downloadOption.innerHTML = downloadContent;
    downloadGrid.appendChild(downloadOption);
}

function showAllPlatformsWithWebFallback() {
    const downloadGrid = document.getElementById('download-grid');
    
    const platforms = [
        { key: 'android', icon: 'phone_android', name: 'Android' },
        { key: 'ios', icon: 'phone_iphone', name: 'iOS' },
        { key: 'windows', icon: 'computer', name: 'Windows' },
        { key: 'macos', icon: 'laptop_mac', name: 'macOS' },
        { key: 'linux', icon: 'desktop_windows', name: 'Linux' },
        { key: 'web', icon: 'language', name: 'Web App' }
    ];
    
    downloadGrid.innerHTML = '';
    
    platforms.forEach(platform => {
        const downloadOption = document.createElement('div');
        downloadOption.className = 'download-option';
        
        const isWebApp = platform.key === 'web';
        
        downloadOption.innerHTML = `
            <div class="platform-icon">
                <span class="material-icons-outlined">${platform.icon}</span>
            </div>
            <h3>${platform.name}</h3>
            <p>${isWebApp ? 'Use directly in your browser' : 'Use web app on ' + platform.name}</p>
            <div class="download-info">
                <small>${isWebApp ? 'No installation required' : 'Native app coming soon'}</small>
                <small>${isWebApp ? 'Works on all devices' : 'Web app works great meanwhile'}</small>
            </div>
            <a href="https://revix-web.web.app" class="btn btn-platform" target="_blank">
                <span class="material-icons-outlined">open_in_new</span>
                ${isWebApp ? 'Launch Web App' : 'Use Web App'}
            </a>
        `;
        
        downloadGrid.appendChild(downloadOption);
    });
}

function addWebAppOption() {
    const downloadGrid = document.getElementById('download-grid');
    
    const webOption = document.createElement('div');
    webOption.className = 'download-option';
    
    webOption.innerHTML = `
        <div class="platform-icon">
            <span class="material-icons-outlined">language</span>
        </div>
        <h3>Web App</h3>
        <p>Use directly in your browser</p>
        <div class="download-info">
            <small>No installation required</small>
            <small>Works on all devices</small>
        </div>
        <a href="https://revix-web.web.app" class="btn btn-platform" target="_blank">
            <span class="material-icons-outlined">open_in_new</span>
            Launch Web App
        </a>
    `;
    
    downloadGrid.appendChild(webOption);
}

function addGenericDownloadOption(release) {
    const downloadGrid = document.getElementById('download-grid');
    
    const genericOption = document.createElement('div');
    genericOption.className = 'download-option';
    
    genericOption.innerHTML = `
        <div class="platform-icon">
            <span class="material-icons-outlined">folder_zip</span>
        </div>
        <h3>Source Code</h3>
        <p>Download source code and build yourself</p>
        <div class="download-info">
            <small>Version: ${release.tag_name}</small>
            <small>For developers</small>
        </div>
        <a href="${release.zipball_url}" class="btn btn-platform" download>
            <span class="material-icons-outlined">download</span>
            Download ZIP
        </a>
    `;
    
    downloadGrid.appendChild(genericOption);
}

function showNoReleasesMessage() {
    const downloadGrid = document.getElementById('download-grid');
    downloadGrid.innerHTML = `
        <div class="loading-downloads">
            <span class="material-icons-outlined">info</span>
            <p>No releases available yet. Check back soon!</p>
            <a href="https://github.com/imnexerio/revix" class="btn btn-primary" target="_blank">
                View on GitHub
            </a>
        </div>
    `;
}

function showErrorMessage() {
    const downloadGrid = document.getElementById('download-grid');
    downloadGrid.innerHTML = `
        <div class="loading-downloads">
            <span class="material-icons-outlined">error</span>
            <p>Unable to load downloads. Please try again later.</p>
            <a href="https://github.com/imnexerio/revix/releases" class="btn btn-primary" target="_blank">
                View on GitHub
            </a>
        </div>
    `;
}

function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function getFileExtension(filename) {
    return filename.split('.').pop() || '';
}

// Load downloads when page loads
document.addEventListener('DOMContentLoaded', function() {
    loadGitHubReleases().then(() => {
        // Initialize tab filtering after downloads are loaded
        initializeDownloadTabs();
        
        // Initialize format info for all selects
        document.querySelectorAll('.format-select').forEach(select => {
            const platformKey = select.id.replace('format-select-', '');
            updateFormatInfo(platformKey);
        });
    });
    init3DAnimatedBackground();
});

// 3D Animated Background System
function init3DAnimatedBackground() {
    const bgContainer = document.getElementById('animated-bg');
    if (!bgContainer) return;

    // Only initialize once - prevent multiple calls
    if (bgContainer.hasAttribute('data-initialized')) return;
    bgContainer.setAttribute('data-initialized', 'true');

    // Clear any existing elements
    bgContainer.innerHTML = '';

    // Get responsive configurations
    const config = getResponsiveConfig();
    
    // Create 3D cubes only (remove particles for performance)
    createAnimatedCubes(bgContainer, config);
    
    // Handle resize with debounce and check if really needed
    let resizeTimeout;
    let lastWidth = window.innerWidth;
    
    window.addEventListener('resize', () => {
        clearTimeout(resizeTimeout);
        resizeTimeout = setTimeout(() => {
            const currentWidth = window.innerWidth;
            // Only reinitialize if screen size category changed
            if ((lastWidth < 768 && currentWidth >= 768) || 
                (lastWidth < 1024 && currentWidth >= 1024) ||
                (lastWidth >= 768 && currentWidth < 768) ||
                (lastWidth >= 1024 && currentWidth < 1024)) {
                
                bgContainer.removeAttribute('data-initialized');
                init3DAnimatedBackground();
                lastWidth = currentWidth;
            }
        }, 500); // Increased debounce time
    });
}

function getResponsiveConfig() {
    const width = window.innerWidth;
    
    if (width < 768) { // Mobile
        return {
            cubeCount: 2, // Reduced from 3
            cubeSize: '70px',
            positions: [
                { left: '10%', top: '20%' },
                { right: '10%', top: '60%' }
            ]
        };
    } else if (width < 1024) { // Tablet
        return {
            cubeCount: 3, // Reduced from 4
            cubeSize: '100px',
            positions: [
                { left: '8%', top: '25%' },
                { right: '12%', top: '40%' },
                { left: '20%', bottom: '30%' }
            ]
        };
    } else { // Desktop
        return {
            cubeCount: 4, // Reduced from 6
            cubeSize: '130px',
            positions: [
                { left: '8%', top: '20%' },
                { right: '10%', top: '35%' },
                { left: '18%', bottom: '25%' },
                { right: '20%', top: '60%' }
            ]
        };
    }
}

function createAnimatedCubes(container, config) {
    const iconSets = [
        ['🧠', '📚', '⚡', '🎯', '🚀', '⭐'],
        ['💡', '📈', '🔄', '✨', '🎲', '🔥'],
        ['🎨', '💎', '🌟', '⚖️', '🔮', '🎪'],
        ['⚙️', '🎵', '🌈', '💫', '🔥', '🎭']
    ];
    
    const faces = ['front', 'back', 'right', 'left', 'top', 'bottom'];
    
    for (let i = 0; i < config.cubeCount; i++) {
        const position = config.positions[i];
        const currentIcons = iconSets[i % iconSets.length];
        
        // Create cube container
        const cubeContainer = document.createElement('div');
        cubeContainer.className = 'cube-container-3d';
        
        // Set position
        Object.keys(position).forEach(key => {
            cubeContainer.style[key] = position[key];
        });
        
        // Create cube
        const cube = document.createElement('div');
        cube.className = 'cube-3d';
        cube.style.width = config.cubeSize;
        cube.style.height = config.cubeSize;
        
        // Stagger animation delays to prevent sync issues
        cube.style.animationDelay = `${i * 3}s`;
        
        // Create cube faces
        faces.forEach((face, faceIndex) => {
            const cubeFace = document.createElement('div');
            cubeFace.className = `cube-face-3d ${face}`;
            cubeFace.innerHTML = currentIcons[faceIndex];
            cube.appendChild(cubeFace);
        });
        
        cubeContainer.appendChild(cube);
        container.appendChild(cubeContainer);
    }
}


