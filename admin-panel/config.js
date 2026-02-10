const CONFIG = {
    // API_URL: 'http://localhost:5000/api'
    API_URL: 'https://superapp-diht.onrender.com/api'
};

// Auto-detect local development
if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' || window.location.protocol === 'file:') {
    CONFIG.API_URL = 'http://localhost:5000/api';
}
