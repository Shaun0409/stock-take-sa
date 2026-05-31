-- Create companies table
CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name VARCHAR(255) NOT NULL,
    contact_email VARCHAR(255) UNIQUE NOT NULL,
    contact_person VARCHAR(255),
    contact_phone VARCHAR(20),
    address TEXT,
    license_key VARCHAR(100) UNIQUE,
    subscription_status VARCHAR(50) DEFAULT 'active',
    deactivated_by_admin BOOLEAN DEFAULT false,
    deactivation_reason TEXT,
    subscription_start DATE,
    subscription_end DATE,
    max_users INTEGER DEFAULT 5,
    max_stores INTEGER DEFAULT 10,
    reactivated_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create stores table
CREATE TABLE IF NOT EXISTS stores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    store_name VARCHAR(255) NOT NULL,
    owner_name VARCHAR(255),
    owner_phone VARCHAR(20),
    owner_email VARCHAR(255),
    address TEXT,
    suburb VARCHAR(100),
    city VARCHAR(100),
    province VARCHAR(50),
    store_type VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create products table
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    barcode VARCHAR(100),
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    subcategory VARCHAR(100),
    unit VARCHAR(20) DEFAULT 'each',
    default_cost_price DECIMAL(10,2),
    default_selling_price DECIMAL(10,2),
    vat_rate DECIMAL(5,2) DEFAULT 15.00,
    is_zero_rated BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create stock_takes table
CREATE TABLE IF NOT EXISTS stock_takes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    conducted_by UUID,
    stock_take_date DATE NOT NULL,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    status VARCHAR(50) DEFAULT 'draft',
    notes TEXT,
    is_offline BOOLEAN DEFAULT false,
    synced_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create stock_take_items table
CREATE TABLE IF NOT EXISTS stock_take_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_take_id UUID REFERENCES stock_takes(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    counted_quantity DECIMAL(10,2) NOT NULL,
    cost_price_at_time DECIMAL(10,2) NOT NULL,
    selling_price_at_time DECIMAL(10,2) NOT NULL,
    expiry_date DATE,
    batch_number VARCHAR(100),
    is_spoiled BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create license_logs table
CREATE TABLE IF NOT EXISTS license_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    license_key VARCHAR(100),
    validation_result VARCHAR(50),
    device_id VARCHAR(255),
    ip_address VARCHAR(45),
    user_agent TEXT,
    validated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'field_staff',
    phone_number VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Insert sample companies
INSERT INTO companies (company_name, contact_email, license_key, subscription_status) 
VALUES 
    ('Corner Cafe Group', 'admin@cornercafe.co.za', 'LIC-ABC-123-XYZ', 'active'),
    ('Sea Point Retail', 'admin@seapoint.co.za', 'LIC-DEF-456-UVW', 'active'),
    ('Durban Superette Group', 'admin@durban.co.za', 'LIC-GHI-789-RST', 'suspended');

-- Insert sample stores
INSERT INTO stores (company_id, store_name, owner_name, suburb, city, province) 
SELECT id, 'Corner Cafe Soweto', 'Thabo Mbeki', 'Soweto', 'Johannesburg', 'Gauteng'
FROM companies WHERE company_name = 'Corner Cafe Group';

INSERT INTO stores (company_id, store_name, owner_name, suburb, city, province) 
SELECT id, 'Sea Point Tuck Shop', 'Ahmed Patel', 'Sea Point', 'Cape Town', 'Western Cape'
FROM companies WHERE company_name = 'Sea Point Retail';

INSERT INTO stores (company_id, store_name, owner_name, suburb, city, province) 
SELECT id, 'Durban Superette', 'Priya Naidoo', 'Umhlanga', 'Durban', 'KwaZulu-Natal'
FROM companies WHERE company_name = 'Durban Superette Group';

-- Insert sample products
INSERT INTO products (company_id, name, category, default_cost_price, default_selling_price, barcode) 
SELECT id, 'Sunshine Brown Bread 700g', 'Bakery', 8.50, 12.99, '6001234567890'
FROM companies WHERE company_name = 'Corner Cafe Group';

INSERT INTO products (company_id, name, category, default_cost_price, default_selling_price, barcode) 
SELECT id, 'Clover Full Cream Milk 1L', 'Dairy', 11.00, 16.99, '6009876543210'
FROM companies WHERE company_name = 'Corner Cafe Group';

INSERT INTO products (company_id, name, category, default_cost_price, default_selling_price, barcode) 
SELECT id, 'Coca-Cola 2L', 'Beverages', 12.00, 18.99, '6004567890123'
FROM companies WHERE company_name = 'Corner Cafe Group';