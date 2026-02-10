const API_URL = CONFIG.API_URL + '/categories';
const token = localStorage.getItem('token');
const form = document.getElementById('categoryForm');
const list = document.getElementById('categoryList');
const submitBtn = document.getElementById('submitBtn');
const cancelEditBtn = document.getElementById('cancelEdit');

let editingId = null;

async function authFetch(url, options = {}) {
    const headers = { ...options.headers, 'Authorization': `Bearer ${token}` };
    const response = await fetch(url, { ...options, headers });
    if (response.status === 401) window.logout();
    return response;
}

async function fetchCategories() {
    try {
        const res = await authFetch(API_URL);
        const categories = await res.json();
        renderCategories(categories);
    } catch (e) {
        console.error(e);
        list.innerHTML = '<p>Error loading categories.</p>';
    }
}

function renderCategories(categories) {
    list.innerHTML = '';
    categories.forEach(cat => {
        const div = document.createElement('div');
        div.className = 'product-item'; // Reuse styling
        div.innerHTML = `
            <div class="product-info">
                <h3>${cat.name}</h3>
                <p>${cat.description || ''}</p>
            </div>
            <div>
                <button onclick="editCategory('${cat._id}', '${cat.name}', '${cat.description || ''}')" style="margin-right: 5px; background: #ffc107; color: black; padding: 5px 10px; border: none; border-radius: 4px; cursor: pointer;">Edit</button>
                <button class="delete-btn" onclick="deleteCategory('${cat._id}')">Delete</button>
            </div>
        `;
        list.appendChild(div);
    });
}

form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        name: document.getElementById('name').value,
        description: document.getElementById('description').value
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
            fetchCategories();
        } else {
            const err = await res.json();
            alert('Error: ' + err.message);
        }
    } catch (e) {
        alert('Request failed');
    }
});

window.editCategory = (id, name, desc) => {
    editingId = id;
    document.getElementById('name').value = name;
    document.getElementById('description').value = desc;
    submitBtn.textContent = 'Update Category';
    cancelEditBtn.style.display = 'inline-block';
};

window.deleteCategory = async (id) => {
    if (!confirm('Delete this category?')) return;
    try {
        await authFetch(`${API_URL}/${id}`, { method: 'DELETE' });
        fetchCategories();
    } catch (e) {
        alert('Delete failed');
    }
};

cancelEditBtn.addEventListener('click', resetForm);

function resetForm() {
    form.reset();
    editingId = null;
    submitBtn.textContent = 'Add Category';
    cancelEditBtn.style.display = 'none';
}

fetchCategories();
