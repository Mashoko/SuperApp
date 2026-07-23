const API_URL = CONFIG.API_URL + '/faqs';
const token = localStorage.getItem('token');
const form = document.getElementById('faqForm');
const list = document.getElementById('faqList');
const submitBtn = document.getElementById('submitBtn');
const cancelEditBtn = document.getElementById('cancelEdit');
const formTitle = document.getElementById('formTitle');
const itemsList = document.getElementById('itemsList');
const addItemBtn = document.getElementById('addItemBtn');

let editingId = null;

async function authFetch(url, options = {}) {
    const headers = { ...options.headers, 'Authorization': `Bearer ${token}` };
    const response = await fetch(url, { ...options, headers });
    if (response.status === 401) window.logout();
    return response;
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function addItemRow(question = '', answer = '') {
    const row = document.createElement('div');
    row.className = 'faq-item-row';
    row.style.cssText = 'display:flex; gap:8px; margin-bottom:8px;';
    row.innerHTML = `
        <input type="text" class="item-question" placeholder="Question" value="${escapeHtml(question)}" style="flex:1;">
        <input type="text" class="item-answer" placeholder="Answer" value="${escapeHtml(answer)}" style="flex:2;">
        <button type="button" class="delete-btn remove-item-btn">×</button>
    `;
    row.querySelector('.remove-item-btn').addEventListener('click', () => row.remove());
    itemsList.appendChild(row);
}

addItemBtn.addEventListener('click', () => addItemRow());

async function fetchFaqs() {
    try {
        const res = await authFetch(API_URL);
        const faqs = await res.json();
        renderFaqs(faqs);
    } catch (e) {
        console.error(e);
        list.innerHTML = '<p>Error loading FAQ categories.</p>';
    }
}

function renderFaqs(faqs) {
    list.innerHTML = '';
    faqs.forEach(faq => {
        const div = document.createElement('div');
        div.className = 'product-item';
        div.innerHTML = `
            <div class="product-info">
                <h3>${escapeHtml(faq.title)}</h3>
                <p>${faq.items.length} question${faq.items.length === 1 ? '' : 's'}</p>
            </div>
            <div>
                <button class="btn-edit">Edit</button>
                <button class="delete-btn">Delete</button>
            </div>
        `;
        div.querySelector('.btn-edit').addEventListener('click', () => editFaq(faq));
        div.querySelector('.delete-btn').addEventListener('click', () => deleteFaq(faq._id));
        list.appendChild(div);
    });
}

form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const items = Array.from(itemsList.querySelectorAll('.faq-item-row')).map(row => ({
        question: row.querySelector('.item-question').value,
        answer: row.querySelector('.item-answer').value,
    })).filter(item => item.question.trim() && item.answer.trim());

    const data = {
        title: document.getElementById('title').value,
        items,
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
            fetchFaqs();
        } else {
            const err = await res.json();
            alert('Error: ' + err.message);
        }
    } catch (e) {
        alert('Request failed');
    }
});

function editFaq(faq) {
    editingId = faq._id;
    document.getElementById('title').value = faq.title;
    itemsList.innerHTML = '';
    faq.items.forEach(item => addItemRow(item.question, item.answer));
    formTitle.textContent = 'Edit FAQ Category';
    submitBtn.textContent = 'Update Category';
    cancelEditBtn.style.display = 'inline-block';
}

async function deleteFaq(id) {
    if (!confirm('Delete this FAQ category and all its questions?')) return;
    try {
        await authFetch(`${API_URL}/${id}`, { method: 'DELETE' });
        fetchFaqs();
    } catch (e) {
        alert('Delete failed');
    }
}

cancelEditBtn.addEventListener('click', resetForm);

function resetForm() {
    form.reset();
    itemsList.innerHTML = '';
    editingId = null;
    formTitle.textContent = 'Add New FAQ Category';
    submitBtn.textContent = 'Add Category';
    cancelEditBtn.style.display = 'none';
    addItemRow();
}

resetForm();
fetchFaqs();
