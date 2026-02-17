const voucherForm = document.getElementById('voucherForm');
const voucherList = document.getElementById('voucherList');
const token = localStorage.getItem('token');

// Load vouchers on page load
fetchVouchers();

voucherForm.addEventListener('submit', async (e) => {
    e.preventDefault();

    const code = document.getElementById('code').value.toUpperCase();
    const discountType = document.getElementById('discountType').value;
    const value = parseFloat(document.getElementById('value').value);
    const expirationDate = document.getElementById('expirationDate').value;
    const usageLimitInput = document.getElementById('usageLimit').value;
    const usageLimit = usageLimitInput ? parseInt(usageLimitInput) : null;
    const isActive = document.getElementById('isActive').checked;

    const payload = {
        code,
        discountType,
        value,
        expirationDate,
        usageLimit,
        isActive
    };

    try {
        const response = await fetch(`${CONFIG.API_URL}/vouchers`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.message);
        }

        alert('Voucher Created Successfully!');
        voucherForm.reset();
        fetchVouchers();
    } catch (error) {
        alert('Error creating voucher: ' + error.message);
    }
});

async function fetchVouchers() {
    try {
        const response = await fetch(`${CONFIG.API_URL}/vouchers`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        if (!response.ok) throw new Error('Failed to fetch vouchers');

        const vouchers = await response.json();
        renderVouchers(vouchers);
    } catch (error) {
        console.error(error);
        voucherList.innerHTML = '<p>Error loading vouchers.</p>';
    }
}

function renderVouchers(vouchers) {
    if (vouchers.length === 0) {
        voucherList.innerHTML = '<p>No vouchers found.</p>';
        return;
    }

    voucherList.innerHTML = vouchers.map(voucher => `
        <div class="product-item" style="display: flex; justify-content: space-between; align-items: center;">
            <div class="product-info">
                <h3>${voucher.code} <span class="${voucher.isActive ? 'badge-active' : 'badge-inactive'}">${voucher.isActive ? 'Active' : 'Inactive'}</span></h3>
                <p>
                    <strong>${voucher.discountType === 'FIXED' ? '$' + voucher.value : voucher.value + '%'}</strong> off 
                    | Expires: ${new Date(voucher.expirationDate).toLocaleDateString()}
                    ${voucher.usageLimit ? `| Limit: ${voucher.usedCount}/${voucher.usageLimit}` : '| Unlimited'}
                </p>
            </div>
            <!-- Add delete/edit buttons here if needed -->
        </div>
    `).join('');
}
