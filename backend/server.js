const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// Production database connection
const isProduction = process.env.NODE_ENV === 'production';

const db = new Pool({
    connectionString: process.env.DATABASE_URL || process.env.DB_CONNECTION_STRING,
    ssl: isProduction ? { rejectUnauthorized: false } : false,
});

// Database connection
const db = new Pool({
    host: process.env.DB_HOST || 'postgres',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'stock_take_system',
    user: process.env.DB_USER || 'stock_take_user',
    password: process.env.DB_PASSWORD || 'secure_password_here',
});

// Admin API Key
const ADMIN_API_KEY = process.env.ADMIN_API_KEY || 'your-super-secret-admin-key-2024';

// Test database connection
db.connect((err) => {
    if (err) {
        console.error('❌ Database connection failed:', err);
        process.exit(1);
    }
    console.log('✅ Connected to PostgreSQL');
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
    next();
});

// =====================================================
// HEALTH CHECK
// =====================================================
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        timestamp: new Date(),
        version: '2.0.0',
        services: {
            database: 'connected',
            api: 'running'
        }
    });
});

// =====================================================
// LICENSE VALIDATION (Called by Mobile App)
// =====================================================
app.get('/api/validate-license/:licenseKey', async (req, res) => {
    try {
        const { licenseKey } = req.params;
        const deviceId = req.headers['x-device-id'];
        const ipAddress = req.ip;
        const userAgent = req.headers['user-agent'];
        
        const result = await db.query(
            `SELECT * FROM companies WHERE license_key = $1`,
            [licenseKey]
        );
        
        if (result.rows.length === 0) {
            await db.query(
                `INSERT INTO license_logs (license_key, validation_result, device_id, ip_address, user_agent) 
                 VALUES ($1, 'invalid', $2, $3, $4)`,
                [licenseKey, deviceId, ipAddress, userAgent]
            );
            return res.status(403).json({ 
                valid: false, 
                message: 'Invalid license key. Please contact support.' 
            });
        }
        
        const company = result.rows[0];
        
        if (company.deactivated_by_admin || company.subscription_status === 'suspended') {
            await db.query(
                `INSERT INTO license_logs (company_id, license_key, validation_result, device_id, ip_address, user_agent) 
                 VALUES ($1, $2, 'deactivated', $3, $4, $5)`,
                [company.id, licenseKey, deviceId, ipAddress, userAgent]
            );
            return res.status(403).json({ 
                valid: false, 
                message: company.deactivation_reason || 'Account suspended. Please contact support.',
                support_email: 'support@stocktake.co.za'
            });
        }
        
        if (company.subscription_end && new Date(company.subscription_end) < new Date()) {
            await db.query(
                `INSERT INTO license_logs (company_id, license_key, validation_result, device_id, ip_address, user_agent) 
                 VALUES ($1, $2, 'expired', $3, $4, $5)`,
                [company.id, licenseKey, deviceId, ipAddress, userAgent]
            );
            return res.status(403).json({ 
                valid: false, 
                message: 'Subscription expired on ' + new Date(company.subscription_end).toLocaleDateString() + '. Please renew.',
                support_email: 'support@stocktake.co.za'
            });
        }
        
        await db.query(
            `INSERT INTO license_logs (company_id, license_key, validation_result, device_id, ip_address, user_agent) 
             VALUES ($1, $2, 'valid', $3, $4, $5)`,
            [company.id, licenseKey, deviceId, ipAddress, userAgent]
        );
        
        res.json({
            valid: true,
            company: {
                id: company.id,
                name: company.company_name,
                max_users: company.max_users || 5,
                max_stores: company.max_stores || 10,
                subscription_end: company.subscription_end
            }
        });
    } catch (error) {
        console.error('License validation error:', error);
        res.status(500).json({ error: error.message });
    }
});

// =====================================================
// COMPANY LOGIN ENDPOINT (For Mobile App)
// =====================================================
app.post('/api/company/login', async (req, res) => {
    try {
        const { email, licenseKey } = req.body;
        
        console.log(`Login attempt: ${email}`);
        
        const result = await db.query(
            `SELECT * FROM companies WHERE contact_email = $1 AND license_key = $2`,
            [email, licenseKey]
        );
        
        if (result.rows.length === 0) {
            return res.status(401).json({ 
                success: false, 
                message: 'Invalid email or license key' 
            });
        }
        
        const company = result.rows[0];
        
        if (company.subscription_status === 'suspended' || company.deactivated_by_admin === true) {
            return res.status(403).json({ 
                success: false, 
                message: company.deactivation_reason || 'Account suspended. Please contact support.',
                support_email: 'support@stocktake.co.za'
            });
        }
        
        if (company.subscription_end && new Date(company.subscription_end) < new Date()) {
            return res.status(403).json({ 
                success: false, 
                message: 'Subscription expired. Please renew.',
                support_email: 'support@stocktake.co.za'
            });
        }
        
        await db.query(
            `INSERT INTO license_logs (company_id, license_key, validation_result, device_id) 
             VALUES ($1, $2, 'login', $3)`,
            [company.id, licenseKey, req.headers['user-agent']]
        );
        
        res.json({
            success: true,
            company: {
                id: company.id,
                name: company.company_name,
                email: company.contact_email,
                license_key: company.license_key,
                max_stores: company.max_stores || 10,
                subscription_end: company.subscription_end
            }
        });
        
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// =====================================================
// SUPER ADMIN API ENDPOINTS
// =====================================================

async function verifyAdmin(req, res, next) {
    const apiKey = req.headers['x-admin-key'];
    if (!apiKey || apiKey !== ADMIN_API_KEY) {
        return res.status(401).json({ error: 'Unauthorized. Invalid admin key.' });
    }
    next();
}

app.post('/api/admin/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        
        const result = await db.query('SELECT * FROM admins WHERE email = $1', [email]);
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        const admin = result.rows[0];
        const validPassword = await bcrypt.compare(password, admin.password_hash);
        
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        res.json({
            success: true,
            admin: {
                id: admin.id,
                email: admin.email,
                full_name: admin.full_name,
                role: admin.role
            }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/admin/companies', verifyAdmin, async (req, res) => {
    try {
        const result = await db.query('SELECT * FROM companies ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching companies:', error);
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/admin/companies/:id', verifyAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const result = await db.query('SELECT * FROM companies WHERE id = $1', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Company not found' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching company:', error);
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/admin/companies', verifyAdmin, async (req, res) => {
    try {
        const {
            company_name,
            contact_email,
            contact_person,
            contact_phone,
            address,
            max_users,
            max_stores
        } = req.body;
        
        if (!company_name || !contact_email) {
            return res.status(400).json({ error: 'Company name and contact email are required' });
        }
        
        const existing = await db.query('SELECT * FROM companies WHERE contact_email = $1', [contact_email]);
        if (existing.rows.length > 0) {
            return res.status(400).json({ error: 'A company with this email already exists' });
        }
        
        const license_key = 'LIC-' + crypto.randomBytes(4).toString('hex').toUpperCase() + 
                           '-' + crypto.randomBytes(3).toString('hex').toUpperCase();
        
        const result = await db.query(
            `INSERT INTO companies (company_name, contact_email, contact_person, contact_phone, 
             address, license_key, max_users, max_stores, subscription_status, subscription_start, subscription_end)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'active', CURRENT_DATE, CURRENT_DATE + INTERVAL '365 days')
             RETURNING *`,
            [company_name, contact_email, contact_person || null, contact_phone || null, address || null, 
             license_key, max_users || 5, max_stores || 10]
        );
        
        console.log(`✅ New company created: ${company_name} with license: ${license_key}`);
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creating company:', error);
        res.status(500).json({ error: error.message });
    }
});

// DELETE company (permanent)
app.delete('/api/admin/companies/:id', verifyAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        
        // Check if company exists
        const checkResult = await db.query('SELECT company_name FROM companies WHERE id = $1', [id]);
        if (checkResult.rows.length === 0) {
            return res.status(404).json({ error: 'Company not found' });
        }
        
        // Delete company (cascade will delete all related data)
        await db.query('DELETE FROM companies WHERE id = $1', [id]);
        
        console.log(`🗑️ Company PERMANENTLY DELETED: ${checkResult.rows[0].company_name}`);
        res.json({ 
            success: true, 
            message: 'Company permanently deleted' 
        });
    } catch (error) {
        console.error('Delete company error:', error);
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/admin/companies/:id', verifyAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const {
            company_name,
            contact_email,
            contact_person,
            contact_phone,
            address,
            max_users,
            max_stores
        } = req.body;
        
        const result = await db.query(
            `UPDATE companies 
             SET company_name = COALESCE($1, company_name),
                 contact_email = COALESCE($2, contact_email),
                 contact_person = COALESCE($3, contact_person),
                 contact_phone = COALESCE($4, contact_phone),
                 address = COALESCE($5, address),
                 max_users = COALESCE($6, max_users),
                 max_stores = COALESCE($7, max_stores),
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $8
             RETURNING *`,
            [company_name, contact_email, contact_person, contact_phone, address, max_users, max_stores, id]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Company not found' });
        }
        
        res.json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/admin/companies/:id/deactivate', verifyAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        const { reason } = req.body;
        
        const checkResult = await db.query('SELECT * FROM companies WHERE id = $1', [id]);
        if (checkResult.rows.length === 0) {
            return res.status(404).json({ error: 'Company not found' });
        }
        
        const result = await db.query(
            `UPDATE companies 
             SET subscription_status = 'suspended', 
                 deactivated_by_admin = true,
                 deactivation_reason = $2,
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $1 
             RETURNING *`,
            [id, reason || 'Non-payment']
        );
        
        console.log(`🔴 Company DEACTIVATED: ${result.rows[0].company_name}`);
        res.json({ 
            success: true, 
            message: 'Company deactivated successfully',
            company: result.rows[0] 
        });
    } catch (error) {
        console.error('Deactivate error:', error);
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/admin/companies/:id/reactivate', verifyAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        
        const checkResult = await db.query('SELECT * FROM companies WHERE id = $1', [id]);
        if (checkResult.rows.length === 0) {
            return res.status(404).json({ error: 'Company not found' });
        }
        
        const result = await db.query(
            `UPDATE companies 
             SET subscription_status = 'active', 
                 deactivated_by_admin = false,
                 deactivation_reason = NULL,
                 reactivated_at = CURRENT_TIMESTAMP,
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $1 
             RETURNING *`,
            [id]
        );
        
        console.log(`🟢 Company REACTIVATED: ${result.rows[0].company_name}`);
        res.json({ 
            success: true, 
            message: 'Company reactivated successfully',
            company: result.rows[0] 
        });
    } catch (error) {
        console.error('Reactivate error:', error);
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/admin/companies/:id/regenerate-license', verifyAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        
        const newLicenseKey = 'LIC-' + crypto.randomBytes(4).toString('hex').toUpperCase() + 
                              '-' + crypto.randomBytes(3).toString('hex').toUpperCase();
        
        const result = await db.query(
            `UPDATE companies 
             SET license_key = $1,
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $2 
             RETURNING id, company_name, license_key`,
            [newLicenseKey, id]
        );
        
        console.log(`🔄 License key regenerated for ${result.rows[0].company_name}: ${newLicenseKey}`);
        res.json({ 
            success: true, 
            message: 'License key regenerated successfully',
            company: result.rows[0] 
        });
    } catch (error) {
        console.error('Regenerate license error:', error);
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/admin/companies/:id/stats', verifyAdmin, async (req, res) => {
    try {
        const { id } = req.params;
        
        let storeCount = 0;
        let stockTakeCount = 0;
        let licenseLogs = [];
        
        try {
            const storeResult = await db.query('SELECT COUNT(*) FROM stores WHERE company_id = $1', [id]);
            storeCount = parseInt(storeResult.rows[0].count) || 0;
        } catch (e) {
            console.log('Stores query error:', e.message);
        }
        
        try {
            const stockResult = await db.query(
                `SELECT COUNT(*) FROM stock_takes st 
                 JOIN stores s ON st.store_id = s.id 
                 WHERE s.company_id = $1`,
                [id]
            );
            stockTakeCount = parseInt(stockResult.rows[0].count) || 0;
        } catch (e) {
            console.log('Stock takes query error:', e.message);
        }
        
        try {
            const logResult = await db.query(
                'SELECT * FROM license_logs WHERE company_id = $1 ORDER BY validated_at DESC LIMIT 20',
                [id]
            );
            licenseLogs = logResult.rows;
        } catch (e) {
            console.log('License logs query error:', e.message);
        }
        
        res.json({
            total_stores: storeCount,
            total_users: 0,
            total_stock_takes: stockTakeCount,
            recent_validations: licenseLogs
        });
    } catch (error) {
        console.error('Stats error:', error);
        res.json({
            total_stores: 0,
            total_users: 0,
            total_stock_takes: 0,
            recent_validations: []
        });
    }
});

app.get('/api/admin/license-logs', verifyAdmin, async (req, res) => {
    try {
        const result = await db.query(
            `SELECT l.*, c.company_name 
             FROM license_logs l
             LEFT JOIN companies c ON l.company_id = c.id
             ORDER BY l.validated_at DESC
             LIMIT 100`
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error fetching license logs:', error);
        res.status(500).json({ error: error.message });
    }
});

// =====================================================
// STORES API (Isolated by Company)
// =====================================================

app.get('/api/companies/:companyId/stores', async (req, res) => {
    try {
        const { companyId } = req.params;
        const result = await db.query(
            'SELECT * FROM stores WHERE company_id = $1 AND is_active = true ORDER BY store_name',
            [companyId]
        );
        res.json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to fetch stores' });
    }
});

app.post('/api/stores', async (req, res) => {
    try {
        const { company_id, store_name, owner_name, owner_phone, owner_email, address, suburb, city, province, store_type } = req.body;
        
        if (!company_id) {
            return res.status(400).json({ error: 'company_id is required' });
        }
        
        const result = await db.query(
            `INSERT INTO stores (company_id, store_name, owner_name, owner_phone, owner_email, address, suburb, city, province, store_type) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *`,
            [company_id, store_name, owner_name, owner_phone, owner_email, address, suburb, city, province, store_type]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to create store' });
    }
});

app.put('/api/stores/:storeId', async (req, res) => {
    try {
        const { storeId } = req.params;
        const { store_name, owner_name, owner_phone, owner_email, address, suburb, city, province, store_type } = req.body;
        
        const result = await db.query(
            `UPDATE stores 
             SET store_name = COALESCE($1, store_name),
                 owner_name = COALESCE($2, owner_name),
                 owner_phone = COALESCE($3, owner_phone),
                 owner_email = COALESCE($4, owner_email),
                 address = COALESCE($5, address),
                 suburb = COALESCE($6, suburb),
                 city = COALESCE($7, city),
                 province = COALESCE($8, province),
                 store_type = COALESCE($9, store_type),
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $10
             RETURNING *`,
            [store_name, owner_name, owner_phone, owner_email, address, suburb, city, province, store_type, storeId]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Store not found' });
        }
        
        res.json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to update store' });
    }
});

app.delete('/api/stores/:storeId', async (req, res) => {
    try {
        const { storeId } = req.params;
        
        const result = await db.query(
            'UPDATE stores SET is_active = false, updated_at = CURRENT_TIMESTAMP WHERE id = $1 RETURNING *',
            [storeId]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Store not found' });
        }
        
        res.json({ success: true, message: 'Store deleted successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to delete store' });
    }
});

// =====================================================
// PRODUCTS API (Isolated by Company)
// =====================================================

app.get('/api/companies/:companyId/products', async (req, res) => {
    try {
        const { companyId } = req.params;
        const result = await db.query(
            'SELECT * FROM products WHERE company_id = $1 AND is_active = true ORDER BY name',
            [companyId]
        );
        res.json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to fetch products' });
    }
});

app.post('/api/products', async (req, res) => {
    try {
        const { company_id, barcode, name, category, subcategory, unit, default_cost_price, default_selling_price, vat_rate, is_zero_rated } = req.body;
        
        if (!company_id) {
            return res.status(400).json({ error: 'company_id is required' });
        }
        
        const result = await db.query(
            `INSERT INTO products (company_id, barcode, name, category, subcategory, unit, default_cost_price, default_selling_price, vat_rate, is_zero_rated) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *`,
            [company_id, barcode, name, category, subcategory, unit, default_cost_price, default_selling_price, vat_rate, is_zero_rated]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to create product' });
    }
});

app.put('/api/products/:productId', async (req, res) => {
    try {
        const { productId } = req.params;
        const { barcode, name, category, subcategory, unit, default_cost_price, default_selling_price, vat_rate, is_zero_rated } = req.body;
        
        const result = await db.query(
            `UPDATE products 
             SET barcode = COALESCE($1, barcode),
                 name = COALESCE($2, name),
                 category = COALESCE($3, category),
                 subcategory = COALESCE($4, subcategory),
                 unit = COALESCE($5, unit),
                 default_cost_price = COALESCE($6, default_cost_price),
                 default_selling_price = COALESCE($7, default_selling_price),
                 vat_rate = COALESCE($8, vat_rate),
                 is_zero_rated = COALESCE($9, is_zero_rated),
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $10
             RETURNING *`,
            [barcode, name, category, subcategory, unit, default_cost_price, default_selling_price, vat_rate, is_zero_rated, productId]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Product not found' });
        }
        
        res.json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to update product' });
    }
});

app.delete('/api/products/:productId', async (req, res) => {
    try {
        const { productId } = req.params;
        
        const result = await db.query(
            'UPDATE products SET is_active = false, updated_at = CURRENT_TIMESTAMP WHERE id = $1 RETURNING *',
            [productId]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Product not found' });
        }
        
        res.json({ success: true, message: 'Product deleted successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to delete product' });
    }
});

app.get('/api/products/search', async (req, res) => {
    try {
        const { q, companyId } = req.query;
        const result = await db.query(
            `SELECT * FROM products 
             WHERE company_id = $1 
             AND (barcode ILIKE $2 OR name ILIKE $2) 
             AND is_active = true 
             LIMIT 20`,
            [companyId, `%${q}%`]
        );
        res.json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to search products' });
    }
});

// =====================================================
// STOCK TAKES API
// =====================================================

app.get('/api/stores/:storeId/stocktakes', async (req, res) => {
    try {
        const { storeId } = req.params;
        const result = await db.query(
            `SELECT * FROM stock_takes 
             WHERE store_id = $1 
             ORDER BY stock_take_date DESC`,
            [storeId]
        );
        res.json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to fetch stock takes' });
    }
});

app.post('/api/stocktakes', async (req, res) => {
    try {
        const { store_id, stock_take_date, notes, is_offline } = req.body;
        const result = await db.query(
            `INSERT INTO stock_takes (store_id, stock_take_date, notes, is_offline, status) 
             VALUES ($1, $2, $3, $4, 'in_progress') RETURNING *`,
            [store_id, stock_take_date, notes, is_offline]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to create stock take' });
    }
});

app.post('/api/stocktakes/:stockTakeId/items', async (req, res) => {
    const client = await db.connect();
    try {
        const { stockTakeId } = req.params;
        const { items } = req.body;
        
        await client.query('BEGIN');
        
        for (const item of items) {
            await client.query(
                `INSERT INTO stock_take_items (stock_take_id, product_id, counted_quantity, cost_price_at_time, selling_price_at_time) 
                 VALUES ($1, $2, $3, $4, $5)`,
                [stockTakeId, item.product_id, item.counted_quantity, item.cost_price_at_time, item.selling_price_at_time]
            );
        }
        
        await client.query('COMMIT');
        res.json({ success: true, message: `${items.length} items saved` });
    } catch (error) {
        await client.query('ROLLBACK');
        console.error(error);
        res.status(500).json({ error: 'Failed to save stock take items' });
    } finally {
        client.release();
    }
});

app.put('/api/stocktakes/:stockTakeId/complete', async (req, res) => {
    try {
        const { stockTakeId } = req.params;
        const { end_time, notes } = req.body;
        
        const result = await db.query(
            `UPDATE stock_takes 
             SET status = 'completed', end_time = $2, notes = COALESCE($3, notes), updated_at = CURRENT_TIMESTAMP 
             WHERE id = $1 
             RETURNING *`,
            [stockTakeId, end_time, notes]
        );
        
        res.json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to complete stock take' });
    }
});

app.get('/api/stocktakes/:stockTakeId/items', async (req, res) => {
    try {
        const { stockTakeId } = req.params;
        const result = await db.query(
            'SELECT * FROM stock_take_items WHERE stock_take_id = $1',
            [stockTakeId]
        );
        res.json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to fetch stock take items' });
    }
});

// =====================================================
// SALES & PURCHASES API
// =====================================================

app.post('/api/salesperiods', async (req, res) => {
    try {
        const { store_id, start_date, end_date, total_sales_revenue, total_transactions, payment_type_breakdown, notes } = req.body;
        const result = await db.query(
            `INSERT INTO sales_periods (store_id, start_date, end_date, total_sales_revenue, total_transactions, payment_type_breakdown, notes) 
             VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
            [store_id, start_date, end_date, total_sales_revenue, total_transactions, payment_type_breakdown, notes]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to record sales' });
    }
});

app.post('/api/purchases', async (req, res) => {
    const client = await db.connect();
    try {
        const { store_id, supplier_id, invoice_number, purchase_date, total_amount, vat_amount, items } = req.body;
        
        await client.query('BEGIN');
        
        const purchaseResult = await client.query(
            `INSERT INTO purchases (store_id, supplier_id, invoice_number, purchase_date, total_amount, vat_amount) 
             VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [store_id, supplier_id, invoice_number, purchase_date, total_amount, vat_amount]
        );
        
        for (const item of items) {
            await client.query(
                `INSERT INTO purchase_items (purchase_id, product_id, quantity_ordered, quantity_received, cost_price, total_line_amount) 
                 VALUES ($1, $2, $3, $4, $5, $6)`,
                [purchaseResult.rows[0].id, item.product_id, item.quantity_ordered, item.quantity_received, item.cost_price, item.total_line_amount]
            );
        }
        
        await client.query('COMMIT');
        res.status(201).json(purchaseResult.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        console.error(error);
        res.status(500).json({ error: 'Failed to record purchase' });
    } finally {
        client.release();
    }
});

// =====================================================
// ADJUSTMENTS (Shrinkage, Theft, Spoilage)
// =====================================================

app.post('/api/adjustments', async (req, res) => {
    try {
        const { store_id, product_id, adjustment_type_id, quantity, value_at_time, adjustment_date, notes } = req.body;
        const result = await db.query(
            `INSERT INTO adjustments (store_id, product_id, adjustment_type_id, quantity, value_at_time, adjustment_date, notes) 
             VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
            [store_id, product_id, adjustment_type_id, quantity, value_at_time, adjustment_date, notes]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to record adjustment' });
    }
});

app.get('/api/stores/:storeId/shrinkage', async (req, res) => {
    try {
        const { storeId } = req.params;
        const { start_date, end_date } = req.query;
        
        const result = await db.query(
            `SELECT at.name as type, SUM(a.quantity * a.value_at_time) as total_value
             FROM adjustments a
             JOIN adjustment_types at ON a.adjustment_type_id = at.id
             WHERE a.store_id = $1 
             AND a.adjustment_date BETWEEN $2 AND $3
             AND at.is_loss = true
             GROUP BY at.name
             ORDER BY total_value DESC`,
            [storeId, start_date, end_date]
        );
        
        res.json(result.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to fetch shrinkage data' });
    }
});

// =====================================================
// METRICS & CALCULATIONS
// =====================================================

app.get('/api/stores/:storeId/metrics', async (req, res) => {
    try {
        const { storeId } = req.params;
        const { start_date, end_date } = req.query;
        
        if (!start_date || !end_date) {
            return res.status(400).json({ error: 'start_date and end_date are required' });
        }
        
        const openingStockTake = await db.query(
            `SELECT * FROM stock_takes 
             WHERE store_id = $1 AND stock_take_date <= $2 AND status = 'completed'
             ORDER BY stock_take_date DESC LIMIT 1`,
            [storeId, start_date]
        );
        
        const closingStockTake = await db.query(
            `SELECT * FROM stock_takes 
             WHERE store_id = $1 AND stock_take_date <= $2 AND status = 'completed'
             ORDER BY stock_take_date DESC LIMIT 1`,
            [storeId, end_date]
        );
        
        let openingValue = 0;
        let closingValue = 0;
        
        if (openingStockTake.rows[0]) {
            const items = await db.query(
                'SELECT SUM(counted_quantity * cost_price_at_time) as value FROM stock_take_items WHERE stock_take_id = $1',
                [openingStockTake.rows[0].id]
            );
            openingValue = parseFloat(items.rows[0].value) || 0;
        }
        
        if (closingStockTake.rows[0]) {
            const items = await db.query(
                'SELECT SUM(counted_quantity * cost_price_at_time) as value FROM stock_take_items WHERE stock_take_id = $1',
                [closingStockTake.rows[0].id]
            );
            closingValue = parseFloat(items.rows[0].value) || 0;
        }
        
        const sales = await db.query(
            'SELECT SUM(total_sales_revenue) as revenue FROM sales_periods WHERE store_id = $1 AND start_date >= $2 AND end_date <= $3',
            [storeId, start_date, end_date]
        );
        const revenue = parseFloat(sales.rows[0].revenue) || 0;
        
        const purchases = await db.query(
            'SELECT SUM(total_amount) as total FROM purchases WHERE store_id = $1 AND purchase_date BETWEEN $2 AND $3',
            [storeId, start_date, end_date]
        );
        const purchaseValue = parseFloat(purchases.rows[0].total) || 0;
        
        const shrinkageData = await db.query(
            `SELECT SUM(a.quantity * a.value_at_time) as total 
             FROM adjustments a
             WHERE a.store_id = $1 
             AND a.adjustment_date BETWEEN $2 AND $3
             AND a.adjustment_type_id IN (SELECT id FROM adjustment_types WHERE is_loss = true)`,
            [storeId, start_date, end_date]
        );
        const shrinkage = parseFloat(shrinkageData.rows[0].total) || 0;
        
        const theoreticalCOGS = openingValue + purchaseValue - closingValue;
        const grossProfit = revenue - theoreticalCOGS;
        const grossProfitPercentage = revenue > 0 ? (grossProfit / revenue) * 100 : 0;
        const shrinkagePercentage = theoreticalCOGS > 0 ? (shrinkage / theoreticalCOGS) * 100 : 0;
        const avgInventory = (openingValue + closingValue) / 2;
        const turnoverRate = avgInventory > 0 ? theoreticalCOGS / avgInventory : 0;
        
        const metrics = {
            period: { start_date, end_date },
            stock: {
                opening_value: openingValue,
                closing_value: closingValue,
                average_inventory: avgInventory
            },
            sales: {
                revenue: revenue,
                theoretical_cogs: theoreticalCOGS
            },
            profit: {
                gross_profit_rand: grossProfit,
                gross_profit_percentage: grossProfitPercentage,
                net_profit: grossProfit - (purchaseValue * 0.15)
            },
            shrinkage: {
                total_rand: shrinkage,
                percentage: shrinkagePercentage,
                meets_target: shrinkagePercentage <= 2.0
            },
            turnover: {
                rate: turnoverRate,
                days_inventory: turnoverRate > 0 ? 365 / turnoverRate : 0
            },
            vat: {
                estimated_output_vat: revenue * 0.15,
                estimated_input_vat: purchaseValue * 0.15,
                estimated_vat_payable: (revenue * 0.15) - (purchaseValue * 0.15)
            }
        };
        
        res.json(metrics);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to calculate metrics' });
    }
});

// =====================================================
// COMPANY PROFILE API
// =====================================================

app.get('/api/companies/:companyId/profile', async (req, res) => {
    try {
        const { companyId } = req.params;
        const result = await db.query(
            'SELECT id, company_name, contact_email, phone, website, address, vat_number, registration_number, company_logo, primary_color, secondary_color FROM companies WHERE id = $1',
            [companyId]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Company not found' });
        }
        
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error fetching profile:', error);
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/companies/:companyId/profile', async (req, res) => {
    try {
        const { companyId } = req.params;
        const { company_name, contact_email, phone, website, address, vat_number, registration_number, company_logo, primary_color, secondary_color } = req.body;
        
        const result = await db.query(
            `UPDATE companies 
             SET company_name = COALESCE($1, company_name),
                 contact_email = COALESCE($2, contact_email),
                 phone = COALESCE($3, phone),
                 website = COALESCE($4, website),
                 address = COALESCE($5, address),
                 vat_number = COALESCE($6, vat_number),
                 registration_number = COALESCE($7, registration_number),
                 company_logo = COALESCE($8, company_logo),
                 primary_color = COALESCE($9, primary_color),
                 secondary_color = COALESCE($10, secondary_color),
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $11
             RETURNING *`,
            [company_name, contact_email, phone, website, address, vat_number, registration_number, company_logo, primary_color, secondary_color, companyId]
        );
        
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error updating profile:', error);
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/companies/:companyId/stats', async (req, res) => {
    try {
        const { companyId } = req.params;
        
        const storeResult = await db.query('SELECT COUNT(*) FROM stores WHERE company_id = $1 AND is_active = true', [companyId]);
        const productResult = await db.query('SELECT COUNT(*) FROM products WHERE company_id = $1 AND is_active = true', [companyId]);
        const stockTakeResult = await db.query(
            `SELECT COUNT(*) FROM stock_takes st 
             JOIN stores s ON st.store_id = s.id 
             WHERE s.company_id = $1`,
            [companyId]
        );
        
        res.json({
            total_stores: parseInt(storeResult.rows[0].count),
            total_products: parseInt(productResult.rows[0].count),
            total_stock_takes: parseInt(stockTakeResult.rows[0].count)
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to fetch stats' });
    }
});

// =====================================================
// ERROR HANDLING & STARTUP
// =====================================================

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Route not found' });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ 
        error: 'Something went wrong!',
        message: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
});

// Start server
app.listen(port, () => {
    console.log(`🚀 Stock Take System API running on port ${port}`);
    console.log(`📊 Health check: http://localhost:${port}/health`);
    console.log(`🏢 API base: http://localhost:${port}/api`);
    console.log(`👑 Admin API: http://localhost:${port}/api/admin`);
    console.log(`🔑 Admin API Key: ${ADMIN_API_KEY}`);
});

module.exports = { app, db };