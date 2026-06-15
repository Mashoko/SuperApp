const mongoose = require('mongoose');

const shippingAddressSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    label: { type: String, required: true },   // e.g. "Home", "Office"
    address: { type: String, required: true },
    city: { type: String, default: '' },
    phone: { type: String, default: '' },
    isDefault: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model('ShippingAddress', shippingAddressSchema);
