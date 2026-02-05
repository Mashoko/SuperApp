const API_URL = 'http://localhost:5000/api/products';
const productForm = document.getElementById('productForm');
const productList = document.getElementById('productList');

// Fetch and display products
async function fetchProducts() {
    try {
        const response = await fetch(API_URL);
        const products = await response.json();
        renderProducts(products);
    } catch (error) {
        console.error('Error fetching products:', error);
        productList.innerHTML = '<p>Error loading products.</p>';
    }
}

// Render products to the list
function renderProducts(products) {
    productList.innerHTML = '';
    products.forEach(product => {
        const div = document.createElement('div');
        div.className = 'product-item';
        div.innerHTML = `
            <div class="product-info">
                <h3>${product.name}</h3>
                <p>$${product.price} - ${product.category || 'No Category'}</p>
            </div>
            <button class="delete-btn" onclick="deleteProduct('${product._id}')">Delete</button>
        `;
        productList.appendChild(div);
    });

    if (products.length === 0) {
        productList.innerHTML = '<p>No products found.</p>';
    }
}

// Add new product
productForm.addEventListener('submit', async (e) => {
    e.preventDefault();

    const newProduct = {
        name: document.getElementById('name').value,
        price: parseFloat(document.getElementById('price').value),
        category: document.getElementById('category').value,
        imageUrl: document.getElementById('imageUrl').value,
        description: document.getElementById('description').value
    };

    try {
        const response = await fetch(API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(newProduct)
        });

        if (response.ok) {
            alert('Product added successfully!');
            productForm.reset();
            fetchProducts();
        } else {
            const errorData = await response.json();
            alert('Error adding product: ' + errorData.message);
        }
    } catch (error) {
        console.error('Error adding product:', error);
        alert('Failed to connect to server.');
    }
});

// Delete product
window.deleteProduct = async (id) => {
    if (!confirm('Are you sure you want to delete this product?')) return;

    try {
        const response = await fetch(`${API_URL}/${id}`, {
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

// Initial load
fetchProducts();
