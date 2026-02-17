const API_URL = CONFIG.API_URL + '/products';
const token = localStorage.getItem('token');

if (!token) {
    window.location.href = 'login.html';
}

const productForm = document.getElementById('productForm');
const productList = document.getElementById('productList');
let editingProductId = null;
const submitBtn = document.getElementById('submitBtn');
const cancelEditBtn = document.getElementById('cancelEdit');

// Logout function
// Logout function is globally defined in index.html

// Helper for authenticated fetch
async function authFetch(url, options = {}) {
    const headers = {
        ...options.headers,
        'Authorization': `Bearer ${token}`
    };

    const response = await fetch(url, { ...options, headers });

    if (response.status === 401) {
        logout();
        return null;
    }

    return response;
}

// Fetch and display products
// function fetchProducts defined below due to hoisting preference or re-definition
// We will replace the original function completely.

// Render products to the list
function renderProducts(products) {
    productList.innerHTML = '';
    products.forEach(product => {
        const div = document.createElement('div');
        div.className = 'product-item';
        div.innerHTML = `
            <div class="product-info">
                <h3>${product.name} ${product.isAvailable ? '' : '(Unavailable)'}</h3>
                <p>
                    $${product.price} 
                    ${product.discountPrice ? `<span style="text-decoration: line-through; color: #999;">$${product.discountPrice}</span>` : ''} 
                    - Stock: ${product.stock}
                </p>
                <p>${product.category || 'No Category'}</p>
            </div>
            <div>
                <button onclick="populateEditForm('${product._id}')" style="margin-right: 5px; background: #ffc107; color: black; padding: 5px 10px; border: none; border-radius: 4px; cursor: pointer;">Edit</button>
                <button class="delete-btn" onclick="deleteProduct('${product._id}')">Delete</button>
            </div>
        `;
        productList.appendChild(div);
    });

    if (products.length === 0) {
        productList.innerHTML = '<p>No products found.</p>';
    }
}

// Add new product
// Add or Update product
productForm.addEventListener('submit', async (e) => {
    e.preventDefault();

    const productData = {
        name: document.getElementById('name').value,
        price: parseFloat(document.getElementById('price').value),
        category: document.getElementById('category').value,
        imageUrl: document.getElementById('imageUrl').value,
        description: document.getElementById('description').value,
        stock: parseInt(document.getElementById('stock').value),
        discountPrice: document.getElementById('discountPrice').value ? parseFloat(document.getElementById('discountPrice').value) : null,
        isAvailable: document.getElementById('isAvailable').checked
    };

    try {
        let response;
        if (editingProductId) {
            // Update existing
            response = await authFetch(`${API_URL}/${editingProductId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(productData)
            });
        } else {
            // Create new
            response = await authFetch(API_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(productData)
            });
        }

        if (response.ok) {
            alert(editingProductId ? 'Product updated!' : 'Product added!');
            resetForm();
            fetchProducts();
        } else {
            const errorData = await response.json();
            alert('Error: ' + errorData.message);
        }
    } catch (error) {
        console.error('Error saving product:', error);
        alert('Failed to connect to server.');
    }
});

// Edit Product Setup
window.populateEditForm = (id) => {
    // We need to fetch the single product or find it in the list.
    // simpler: assume we have the full list in memory or re-fetch.
    // For now, let's find it in the rendered DOM or just fetch it.
    // Ideally, pass the object, but stringifying in onclick is messy.
    // Let's just fetch all again or save 'products' globally?
    // Optimization: Save products globally.
};

// Re-write fetch to save global products
let allProducts = [];
async function fetchProducts() {
    try {
        const response = await authFetch(API_URL);
        const data = await response.json();
        allProducts = data.products || [];
        renderProducts(allProducts);
    } catch (error) {
        console.error('Error fetching products:', error);
        productList.innerHTML = '<p>Error loading products.</p>';
    }
}

window.populateEditForm = (id) => {
    const product = allProducts.find(p => p._id === id);
    if (!product) return;

    document.getElementById('name').value = product.name;
    document.getElementById('price').value = product.price;
    document.getElementById('category').value = product.category || '';
    document.getElementById('imageUrl').value = product.imageUrl || '';
    document.getElementById('description').value = product.description || '';

    // New fields
    document.getElementById('stock').value = product.stock || 0;
    document.getElementById('discountPrice').value = product.discountPrice || '';
    document.getElementById('isAvailable').checked = product.isAvailable !== undefined ? product.isAvailable : true;

    // Update Image Preview
    const previewBox = document.getElementById('previewBox');
    if (product.imageUrl) {
        previewBox.innerHTML = `<img src="${product.imageUrl}" onerror="this.onerror=null;this.parentElement.innerHTML='❌';">`;
    } else {
        previewBox.innerHTML = `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M21 19V5C21 3.9 20.1 3 19 3H5C3.9 3 3 3.9 3 5V19C3 20.1 3.9 21 5 21H19C20.1 21 21 20.1 21 19ZM8.5 13.5L11 16.51L14.5 12L19 18H5L8.5 13.5Z" fill="currentColor"/></svg>`;
    }

    editingProductId = id;
    submitBtn.textContent = 'Update Product';
    cancelEditBtn.style.display = 'inline-block';

    // Scroll to form
    window.scrollTo({ top: 0, behavior: 'smooth' });
};

cancelEditBtn.addEventListener('click', resetForm);

function resetForm() {
    productForm.reset();
    editingProductId = null;
    submitBtn.textContent = 'Add Product';
    cancelEditBtn.style.display = 'none';
    document.getElementById('imageUrl').value = '';
    document.getElementById('uploadStatus').textContent = 'No file selected';
    document.getElementById('previewBox').innerHTML = `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M21 19V5C21 3.9 20.1 3 19 3H5C3.9 3 3 3.9 3 5V19C3 20.1 3.9 21 5 21H19C20.1 21 21 20.1 21 19ZM8.5 13.5L11 16.51L14.5 12L19 18H5L8.5 13.5Z" fill="currentColor"/></svg>`;
}

// Delete product
window.deleteProduct = async (id) => {
    if (!confirm('Are you sure you want to delete this product?')) return;

    try {
        const response = await authFetch(`${API_URL}/${id}`, {
            method: 'DELETE'
        });

        if (response.ok) {
            fetchProducts();
        } else {
            alert('Error deleting product');
        }
    } catch (error) {
        console.error('Error deleting product:', error);
    }
};


// Populate Categories Dropdown
// Populate Categories Dropdown
async function loadCategories() {
    try {
        console.log('Fetching categories...');
        const response = await authFetch(CONFIG.API_URL + '/categories');
        // Note: Using full URL to avoid any relative path issues

        if (!response.ok) throw new Error('Failed to fetch categories');

        const categories = await response.json();
        console.log('Categories loaded:', categories);

        const select = document.getElementById('category');
        select.innerHTML = '<option value="">Select Category</option>';

        if (categories.length === 0) {
            console.warn('No categories found in database');
        }

        categories.forEach(cat => {
            const option = document.createElement('option');
            option.value = cat.name;
            option.textContent = cat.name;
            select.appendChild(option);
        });
    } catch (e) {
        console.error('Failed to load categories', e);
        // alert('Failed to load categories: ' + e.message); // Optional: alert user
    }
}

// Initial load
loadCategories();
fetchProducts();
