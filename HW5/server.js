
const express = require('express');
const db = require('./mysql');

const pool = typeof db.promise === 'function' ? db.promise() : db;

const app = express();
const PORT = 3000;

// Escape special characters before displaying database values in HTML.
function escapeHtml(value) {
    return String(value).replace(/[&<>"']/g, (char) => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;'
    })[char]);
}

// GET route to search books using URL query parameters.
app.get('/', async (req, res) => {
    const { category, author, format = 'json' } = req.query;

    if ([category, author, format].some(
        value => value !== undefined && typeof value !== 'string'
    )) {
        return res.status(400).json({ error: 'Invalid parameters' });
    }

    let sql = 'SELECT * FROM books WHERE 1=1';
    const values = [];

    // Filter by category.
    if (category) {
        sql += ' AND category = ?';
        values.push(category);
    }

    // Filter by author.
    if (author) {
        sql += ' AND author = ?';
        values.push(author);
    }

    try {
        const [books] = await pool.query(sql, values);

        // Return readable HTML when format=text.
        if (format.toLowerCase() === 'text') {
            let html = `
                <html>
                <head><title>Book Results</title></head>
                <body>
                <h1>Book Search Results</h1>
                <table border="1" cellpadding="10">
                <tr>
                    <th>ID</th>
                    <th>Title</th>
                    <th>Author</th>
                    <th>Category</th>
                    <th>Price</th>
                </tr>
            `;

            books.forEach(book => {
                html += `
                    <tr>
                        <td>${escapeHtml(book.bookid)}</td>
                        <td>${escapeHtml(book.title)}</td>
                        <td>${escapeHtml(book.author)}</td>
                        <td>${escapeHtml(book.category)}</td>
                        <td>$${escapeHtml(book.price)}</td>
                    </tr>
                `;
            });

            html += '</table></body></html>';
            return res.send(html);
        }

        // Return JSON by default or when format=json.
        res.json(books);

    } catch (error) {
        console.error('Database error:', error);
        res.status(500).json({
            error: 'Failed to retrieve books'
        });
    }
});

// Start Express server.
app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
});
