const mongoose = require('mongoose');

const faqItemSchema = new mongoose.Schema({
    question: { type: String, required: true },
    answer:   { type: String, required: true },
}, { _id: false });

const faqSchema = new mongoose.Schema({
    title: { type: String, required: true, unique: true, trim: true },
    items: [faqItemSchema],
}, {
    timestamps: true
});

module.exports = mongoose.model('Faq', faqSchema);
