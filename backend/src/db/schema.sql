-- Stock Take System for South African Convenience Stores
-- Complete Database Schema

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- CORE ENTITIES
-- =====================================================

-- Companies (stock-taking service providers)
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    registration_number VARCHAR(100),
    vat_number VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users (staff of the stock-taking companies)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

-- Stores (convenience stores / spaza shops / cafes)
CREATE TABLE stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
    has_pos BOOLEAN DEFAULT false,
    pos_type VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- PRODUCT MANAGEMENT
-- =====================================================

-- Product catalog (global for the company)
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
    image_url TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(company_id, barcode),
    UNIQUE(company_id, name)
);

-- =====================================================
-- STOCK TAKES (Core Operation)
-- =====================================================

-- Stock take sessions
CREATE TABLE stock_takes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    conducted_by UUID REFERENCES users(id),
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

-- Individual stock take items (counted products)
CREATE TABLE stock_take_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stock_take_id UUID REFERENCES stock_takes(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    counted_quantity DECIMAL(10,2) NOT NULL,
    cost_price_at_time DECIMAL(10,2) NOT NULL,
    selling_price_at_time DECIMAL(10,2) NOT NULL,
    expiry_date DATE,
    batch_number VARCHAR(100),
    is_spoiled BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stock_take_id, product_id)
);

-- =====================================================
-- SALES DATA (from store owner or POS)
-- =====================================================

-- Sales periods (between stock takes)
CREATE TABLE sales_periods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_sales_revenue DECIMAL(10,2) NOT NULL,
    total_transactions INTEGER,
    payment_type_breakdown JSONB,
    data_source VARCHAR(50) DEFAULT 'store_owner',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (end_date > start_date)
);

-- Detailed sales (if available from POS)
CREATE TABLE sales_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    sale_date DATE NOT NULL,
    quantity_sold DECIMAL(10,2) NOT NULL,
    revenue DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- PURCHASES & SUPPLIERS
-- =====================================================

-- Suppliers
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    payment_terms VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Purchase invoices (stock bought between stock takes)
CREATE TABLE purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES suppliers(id),
    invoice_number VARCHAR(100),
    purchase_date DATE NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    vat_amount DECIMAL(10,2),
    is_fully_received BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Purchase items (line items from invoices)
CREATE TABLE purchase_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    purchase_id UUID REFERENCES purchases(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    quantity_ordered DECIMAL(10,2) NOT NULL,
    quantity_received DECIMAL(10,2),
    cost_price DECIMAL(10,2) NOT NULL,
    total_line_amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- ADJUSTMENTS (Shrinkage, Spoilage, Returns, Theft)
-- =====================================================

-- Adjustment types
CREATE TABLE adjustment_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    affects_inventory BOOLEAN DEFAULT true,
    is_loss BOOLEAN DEFAULT true
);

-- Insert default adjustment types
INSERT INTO adjustment_types (name, affects_inventory, is_loss) VALUES
    ('theft', true, true),
    ('spoilage', true, true),
    ('damage', true, true),
    ('admin_error', true, true),
    ('return_to_supplier', true, false),
    ('promotion_writeoff', true, true),
    ('donation', true, false);

-- Stock adjustments (tracking all inventory changes outside sales)
CREATE TABLE adjustments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    adjustment_type_id INTEGER REFERENCES adjustment_types(id),
    quantity DECIMAL(10,2) NOT NULL,
    value_at_time DECIMAL(10,2),
    adjustment_date DATE NOT NULL,
    approved_by UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- METRICS & CALCULATIONS (Stored for Performance)
-- =====================================================

-- Store metrics snapshots (periodic calculations)
CREATE TABLE store_metrics_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    opening_stock_value DECIMAL(10,2),
    closing_stock_value DECIMAL(10,2),
    avg_inventory_value DECIMAL(10,2),
    total_sales_revenue DECIMAL(10,2),
    total_sales_cost DECIMAL(10,2),
    theoretical_sales_cost DECIMAL(10,2),
    gross_profit DECIMAL(10,2),
    gross_profit_percentage DECIMAL(5,2),
    net_profit DECIMAL(10,2),
    shrinkage_value DECIMAL(10,2),
    shrinkage_percentage DECIMAL(5,2),
    theft_value DECIMAL(10,2),
    spoilage_value DECIMAL(10,2),
    damage_value DECIMAL(10,2),
    admin_error_value DECIMAL(10,2),
    stock_turnover_rate DECIMAL(10,2),
    days_inventory_on_hand INTEGER,
    stock_take_duration_minutes INTEGER,
    items_counted INTEGER,
    variances_found INTEGER,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(store_id, period_start, period_end)
);

-- =====================================================
-- USER PREFERENCES (Metric Toggles)
-- =====================================================

-- Store what metrics each user wants to see
CREATE TABLE user_metric_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(100) NOT NULL,
    metric_key VARCHAR(100) NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    display_order INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, category, metric_key)
);

-- Quick profiles for metric preferences
CREATE TABLE metric_profiles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_default BOOLEAN DEFAULT false
);

-- Insert default profiles
INSERT INTO metric_profiles (name, description, is_default) VALUES
    ('basic', 'For store owners - shows only core metrics', true),
    ('advanced', 'Detailed analytics for managers', false),
    ('stock_taking_company', 'Full metrics for service providers', false),
    ('all_metrics', 'Everything - for analysts', false);

-- =====================================================
-- INDEXES for Performance
-- =====================================================

CREATE INDEX idx_stock_takes_store_date ON stock_takes(store_id, stock_take_date);
CREATE INDEX idx_stock_take_items_product ON stock_take_items(product_id);
CREATE INDEX idx_sales_periods_store_date ON sales_periods(store_id, start_date, end_date);
CREATE INDEX idx_purchases_store_date ON purchases(store_id, purchase_date);
CREATE INDEX idx_adjustments_store_date ON adjustments(store_id, adjustment_date);
CREATE INDEX idx_store_metrics_snapshots_store_period ON store_metrics_snapshots(store_id, period_start, period_end);
CREATE INDEX idx_products_company ON products(company_id);
CREATE INDEX idx_stores_company ON stores(company_id);

-- =====================================================
-- TRIGGERS for updated_at
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_stores_updated_at BEFORE UPDATE ON stores FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_stock_takes_updated_at BEFORE UPDATE ON stock_takes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_metric_preferences_updated_at BEFORE UPDATE ON user_metric_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();