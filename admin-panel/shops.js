const API_URL = CONFIG.API_URL + '/shops';
const token = localStorage.getItem('token');
const form = document.getElementById('shopForm');
const list = document.getElementById('shopList');
const submitBtn = document.getElementById('submitBtn');
const cancelEditBtn = document.getElementById('cancelEdit');

let editingId = null;

async function authFetch(url, options = {}) {
    const headers = { ...options.headers, 'Authorization': `Bearer ${token}` };
    const response = await fetch(url, { ...options, headers });
    if (response.status === 401) window.logout();
    return response;
}

async function fetchShops() {
    try {
        const res = await authFetch(API_URL);
        const shops = await res.json();
        renderShops(shops);
    } catch (e) {
        console.error(e);
        list.innerHTML = '<p>Error loading shops.</p>';
    }
}

function renderShops(shops) {
    list.innerHTML = '';
    shops.forEach(shop => {
        const div = document.createElement('div');
        div.className = 'product-item';
        div.innerHTML = `
            <div class="product-info">
                <h3>${shop.name}</h3>
                <p>Location: ${shop.location}</p>
                <p>Manager: ${shop.manager || 'N/A'}</p>
            </div>
            <div>
                <button class="btn-edit" onclick="editShop('${shop._id}', '${shop.name}', '${shop.location}', '${shop.manager || ''}')">Edit</button>
                <button class="delete-btn" onclick="deleteShop('${shop._id}')">Delete</button>
            </div>
        `;
        list.appendChild(div);
    });
}

form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        name: document.getElementById('name').value,
        location: document.getElementById('location').value,
        manager: document.getElementById('manager').value
    };

    try {
        let res;
        if (editingId) {
            res = await authFetch(`${API_URL}/${editingId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
        } else {
            res = await authFetch(API_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
        }

        if (res.ok) {
            resetForm();
            fetchShops();
        } else {
            const err = await res.json();
            alert('Error: ' + err.message);
        }
    } catch (e) {
        alert('Request failed');
    }
});

window.editShop = (id, name, location, manager) => {
    editingId = id;
    document.getElementById('name').value = name;
    document.getElementById('location').value = location;
    document.getElementById('manager').value = manager;
    submitBtn.textContent = 'Update Shop';
    cancelEditBtn.style.display = 'inline-block';
};

window.deleteShop = async (id) => {
    if (!confirm('Delete this shop?')) return;
    try {
        await authFetch(`${API_URL}/${id}`, { method: 'DELETE' });
        fetchShops();
    } catch (e) {
        alert('Delete failed');
    }
};

cancelEditBtn.addEventListener('click', resetForm);

function resetForm() {
    form.reset();
    editingId = null;
    submitBtn.textContent = 'Add Shop';
    cancelEditBtn.style.display = 'none';
}

fetchShops();
