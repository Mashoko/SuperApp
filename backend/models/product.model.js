const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
    },
    description: {
        type: String,
        required: false,
    },
    price: {
        type: Number,
        required: true,
    },
    imageUrl: {
        type: String,
        required: false,
    },
    category: {
        type: String,
        required: false,
    },
    stock: {
        type: Number,
        default: 0
    },
    discountPrice: {
        type: Number,
        required: false
    },
    isAvailable: {
        type: Boolean,
        default: true
    },
    averageRating: {
        type: Number,
        default: 0,
        min: 0,
        max: 5
    },
    reviewCount: {
        type: Number,
        default: 0
    },
    isTrending: {
        type: Boolean,
        default: false
    },
    storeName: {
        type: String,
        required: false
    },
    verifiedSeller: {
        type: Boolean,
        default: false
    },
    deliveryAvailable: {
        type: Boolean,
        default: false
    },
    isDeleted: {
        type: Boolean,
        default: false
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
});

module.exports = mongoose.model('Product', productSchema);
