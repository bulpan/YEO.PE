const express = require('express');
const router = express.Router();
const inquiryService = require('../services/inquiryService');
const { authenticate: authenticateToken } = require('../middleware/auth');

// Create Inquiry
router.post('/', authenticateToken, async (req, res) => {
    try {
        console.log('[DEBUG] POST /inquiries Request:', { body: req.body, user: req.user });
        const { category, content } = req.body;
        if (!category || !content) {
            return res.status(400).json({ error: 'Category and content are required' });
        }

        const inquiry = await inquiryService.createInquiry(req.user.userId, category, content);
        res.status(201).json(inquiry);
    } catch (error) {
        console.error('Error creating inquiry:', error.message, error.stack);
        res.status(500).json({ error: 'Failed to create inquiry' });
    }
});

// Get My Inquiries
router.get('/my', authenticateToken, async (req, res) => {
    try {
        const inquiries = await inquiryService.getUserInquiries(req.user.userId);
        res.json(inquiries);
    } catch (error) {
        console.error('Error fetching my inquiries:', error);
        res.status(500).json({ error: 'Failed to fetch inquiries' });
    }
});

// Get Unread Count (for badge)
router.get('/unread-count', authenticateToken, async (req, res) => {
    try {
        const count = await inquiryService.getUnreadCount(req.user.userId);
        res.json({ count });
    } catch (error) {
        console.error('Error fetching unread count:', error);
        res.status(500).json({ error: 'Failed to fetch unread count' });
    }
});


// Get Inquiry Detail
router.get('/:id', authenticateToken, async (req, res) => {
    try {
        const inquiry = await inquiryService.getInquiryDetail(req.user.userId, req.params.id);
        if (!inquiry) {
            return res.status(404).json({ error: 'Inquiry not found' });
        }
        res.json(inquiry);
    } catch (error) {
        console.error('Error fetching inquiry detail:', error);
        res.status(500).json({ error: 'Failed to fetch inquiry detail' });
    }
});

module.exports = router;
