const API_URL = CONFIG.API_URL + '/banners';
const token = localStorage.getItem('token');

async function authFetch(url, options = {}) {
    const headers = {
        ...options.headers,
        'Authorization': `Bearer ${token}`
    };
    const response = await fetch(url, { ...options, headers });
    if (response.status === 401) {
        window.location.href = 'login.html';
    }
    return response;
}

const bannerForm = document.getElementById('bannerForm');
const bannerList = document.getElementById('bannerList');
const submitBtn = document.getElementById('submitBtn');
const cancelEditBtn = document.getElementById('cancelEdit');
let editingBannerId = null;

async function fetchBanners() {
    try {
        const response = await authFetch(API_URL);
        const banners = await response.json();
        renderBanners(banners);
    } catch (error) {
        console.error('Error fetching banners:', error);
    }
}

function renderBanners(banners) {
    bannerList.innerHTML = '';
    banners.forEach(banner => {
        const div = document.createElement('div');
        div.className = 'product-item';
        div.innerHTML = `
            <div class="product-info">
                <h3>${banner.title} <span class="${banner.isActive ? 'badge-active' : 'badge-inactive'}">(${banner.isActive ? 'Active' : 'Inactive'})</span></h3>
                <p>${banner.description}</p>
                ${banner.imageUrl ? `<img src="${banner.imageUrl}" style="max-height: 50px; margin-top:5px; border-radius:4px;">` : ''}
            </div>
            <div>
                <button class="btn-edit" onclick="editBanner('${banner._id}', '${escape(JSON.stringify(banner))}')">Edit</button>
                <button onclick="deleteBanner('${banner._id}')" class="delete-btn">Delete</button>
            </div>
        `;
        bannerList.appendChild(div);
    });
}

bannerForm.addEventListener('submit', async (e) => {
    e.preventDefault();

    const bannerData = {
        title: document.getElementById('title').value,
        description: document.getElementById('description').value,
        imageUrl: document.getElementById('imageUrl').value,
        isActive: document.getElementById('isActive').checked
    };

    try {
        let response;
        if (editingBannerId) {
            response = await authFetch(`${API_URL}/${editingBannerId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(bannerData)
            });
        } else {
            response = await authFetch(API_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(bannerData)
            });
        }

        if (response.ok) {
            alert(editingBannerId ? 'Banner updated' : 'Banner created');
            resetForm();
            fetchBanners();
        } else {
            const err = await response.json();
            alert('Error: ' + err.message);
        }
    } catch (error) {
        console.error('Error saving banner', error);
    }
});

window.editBanner = (id, bannerString) => {
    const banner = JSON.parse(unescape(bannerString));
    editingBannerId = id;

    document.getElementById('title').value = banner.title;
    document.getElementById('description').value = banner.description;
    document.getElementById('imageUrl').value = banner.imageUrl || '';
    document.getElementById('isActive').checked = banner.isActive;

    submitBtn.textContent = 'Update Banner';
    cancelEditBtn.style.display = 'inline-block';
};

window.deleteBanner = async (id) => {
    if (!confirm('Delete this banner?')) return;
    try {
        const response = await authFetch(`${API_URL}/${id}`, { method: 'DELETE' });
        if (response.ok) fetchBanners();
    } catch (e) { console.error(e); }
};

cancelEditBtn.addEventListener('click', resetForm);

function resetForm() {
    bannerForm.reset();
    editingBannerId = null;
    submitBtn.textContent = 'Save Banner';
    cancelEditBtn.style.display = 'none';
}

fetchBanners();
