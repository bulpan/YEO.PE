const { pool } = require('../config/database');

class InquiryService {
    // User: Create Inquiry
    async createInquiry(userId, category, content) {
        const query = `
      INSERT INTO yeope_schema.inquiries (user_id, category, content)
      VALUES ($1, $2, $3)
      RETURNING *
    `;
        const result = await pool.query(query, [userId, category, content]);
        return result.rows[0];
    }

    // User: Get My Inquiries
    async getUserInquiries(userId) {
        const query = `
      SELECT * FROM yeope_schema.inquiries
      WHERE user_id = $1
      ORDER BY created_at DESC
    `;
        const result = await pool.query(query, [userId]);
        return result.rows;
    }

    // User: Get Specific Inquiry (Mark as read if answered)
    async getInquiryDetail(userId, inquiryId) {
        // Transaction to ensure atomicity of read status update
        const client = await pool.connect();
        try {
            await client.query('BEGIN');

            const query = `
        SELECT * FROM yeope_schema.inquiries
        WHERE id = $1 AND user_id = $2
      `;
            const result = await client.query(query, [inquiryId, userId]);

            if (result.rows.length === 0) {
                await client.query('ROLLBACK');
                return null;
            }

            const inquiry = result.rows[0];

            // If answered and not read, mark as read
            if (inquiry.status === 'answered' && !inquiry.is_read_by_user) {
                await client.query(`
          UPDATE yeope_schema.inquiries 
          SET is_read_by_user = TRUE 
          WHERE id = $1
        `, [inquiryId]);
                inquiry.is_read_by_user = true; // Return updated state
            }

            await client.query('COMMIT');
            return inquiry;
        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        } finally {
            client.release();
        }
    }

    // Admin: Get All Inquiries
    async getAllInquiries(status = 'all', limit = 50, offset = 0) {
        let query = `
      SELECT i.*, u.nickname, u.id as user_id_val 
      FROM yeope_schema.inquiries i
      LEFT JOIN yeope_schema.users u ON i.user_id = u.id
    `;
        const params = [];

        if (status !== 'all') {
            query += ` WHERE i.status = $1`;
            params.push(status);
        }

        query += ` ORDER BY i.created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
        params.push(limit, offset);

        const result = await pool.query(query, params);

        // Get total count for pagination
        let countQuery = `SELECT COUNT(*) FROM yeope_schema.inquiries`;
        const countParams = [];
        if (status !== 'all') {
            countQuery += ` WHERE status = $1`;
            countParams.push(status);
        }
        const countResult = await pool.query(countQuery, countParams);

        return {
            inquiries: result.rows,
            total: parseInt(countResult.rows[0].count)
        };
    }

    // Admin: Answer Inquiry
    async answerInquiry(inquiryId, answer) {
        const query = `
      UPDATE yeope_schema.inquiries 
      SET answer = $1, status = 'answered', answered_at = NOW()
      WHERE id = $2
      RETURNING *
    `;
        const result = await pool.query(query, [answer, inquiryId]);
        return result.rows[0];
    }

    // User: Get Unread Count for Badge
    async getUnreadCount(userId) {
        const query = `
        SELECT COUNT(*) FROM yeope_schema.inquiries 
        WHERE user_id = $1 AND status = 'answered' AND is_read_by_user = FALSE
      `;
        const result = await pool.query(query, [userId]);
        return parseInt(result.rows[0].count);
    }
}

module.exports = new InquiryService();
