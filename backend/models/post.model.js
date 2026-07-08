const mongoose = require('mongoose');

const postSchema = new mongoose.Schema({
    type: {
        type: String,
        enum: ['photo', 'video', 'text', 'audio'],
        required: true,
    },
    caption: {
        type: String,
        required: false,
    },
    mediaUrl: {
        type: String,
        required: false,
    },
    audioTitle: {
        type: String,
        required: false,
    },
    durationSeconds: {
        type: Number,
        required: false,
    },
    authorUserId: {
        type: String,
        required: true,
    },
    authorName: {
        type: String,
        required: true,
    },
    likedBy: {
        type: [String],
        default: [],
    },
    commentCount: {
        type: Number,
        default: 0,
    },
    isDeleted: {
        type: Boolean,
        default: false,
    },
}, {
    timestamps: true,
});

module.exports = mongoose.model('Post', postSchema);
