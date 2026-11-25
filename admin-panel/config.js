const CONFIG = {
    // API_URL: 'http://localhost:5000/api'
    API_URL: 'https://superapp-diht.onrender.com/api'
};

// Auto-detect local development
if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' || window.location.protocol === 'file:') {
    CONFIG.API_URL = 'http://localhost:5000/api';
}

// Global Sidebar Toggle for Mobile
window.toggleSidebar = () => {
    const sidebar = document.querySelector('.sidebar');
    if (sidebar) {
        sidebar.classList.toggle('active');

        // Optional: Create overlay if not exists
        let overlay = document.querySelector('.sidebar-overlay');
        if (!overlay) {
            overlay = document.createElement('div');
            overlay.className = 'sidebar-overlay';
            overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.3);z-index:99;display:none;backdrop-filter:blur(2px);';
            document.body.appendChild(overlay);
            overlay.addEventListener('click', window.toggleSidebar);
        }

        if (sidebar.classList.contains('active')) {
            overlay.style.display = 'block';
        } else {
            overlay.style.display = 'none';
        }
    }
};

// Remove elements whose data-requires-role list does not include the signed-in role.
// UI only: the server enforces access. Must not throw when there is no stored user.
(function hideByRole() {
    const apply = () => {
        let role = null;
        try {
            const user = JSON.parse(localStorage.getItem('user'));
            role = user && typeof user.role === 'string' ? user.role : null;
        } catch (err) {
            role = null;
        }
        document.querySelectorAll('[data-requires-role]').forEach((node) => {
            const allowed = (node.getAttribute('data-requires-role') || '').split(/\s+/).filter(Boolean);
            if (!role || !allowed.includes(role)) node.remove();
        });
    };
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', apply);
    else apply();
})();
