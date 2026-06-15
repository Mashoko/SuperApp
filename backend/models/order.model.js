const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema({
  product: { type: Object, required: true }, // Denormalized product snapshot
  quantity: { type: Number, required: true },
  total: { type: Number, required: true },
});

const orderSchema = new mongoose.Schema(
  {
    order_id: { type: String, required: true, unique: true },
    user_id: { type: String, required: true, index: true },
    items: [orderItemSchema],
    shipping_address: { type: String, default: '' },
    status: {
      type: String,
      enum: ['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled'],
      default: 'confirmed',
    },
    transaction_id: { type: String, default: null },
    payment_status: { type: String, default: 'pending' },
    total_amount: { type: Number, required: true },
    discount_code: { type: String, default: null },
    discount_amount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

// Virtual for created_at compatibility
orderSchema.virtual('created_at').get(function () {
  return this.createdAt;
});

orderSchema.set('toJSON', { virtuals: true });

module.exports = mongoose.model('Order', orderSchema);
