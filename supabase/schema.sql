-- Supabase Schema for Asset Management System
-- Run this in Supabase SQL Editor to create all tables

-- Enable Row Level Security
ALTER DATABASE postgres SET "app.jwt_secret" TO 'your-jwt-secret';

-- Create custom types
CREATE TYPE asset_status AS ENUM ('active', 'maintenance', 'inactive', 'disposed');

-- Locations table
CREATE TABLE IF NOT EXISTS locations (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Categories table
CREATE TABLE IF NOT EXISTS categories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(10) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Staff table
CREATE TABLE IF NOT EXISTS staff (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    staff_id VARCHAR(50) NOT NULL UNIQUE,
    position VARCHAR(255),
    phone_number VARCHAR(20),
    email VARCHAR(255),
    location_id BIGINT REFERENCES locations(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Assets table
CREATE TABLE IF NOT EXISTS assets (
    id BIGSERIAL PRIMARY KEY,
    asset_name VARCHAR(255) NOT NULL UNIQUE,
    serial_number VARCHAR(255) UNIQUE,
    category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
    status asset_status DEFAULT 'active',
    staff_id BIGINT REFERENCES staff(id) ON DELETE SET NULL,
    purchase_date DATE,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Licenses table
CREATE TABLE IF NOT EXISTS licenses (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    license_key VARCHAR(255) NOT NULL UNIQUE,
    type VARCHAR(100),
    purchased_date DATE,
    expiration_date DATE,
    seats_total INTEGER DEFAULT 1,
    seats_used INTEGER DEFAULT 0,
    cost DECIMAL(10, 2),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Asset-License pivot table (many-to-many)
CREATE TABLE IF NOT EXISTS asset_licenses (
    id BIGSERIAL PRIMARY KEY,
    asset_id BIGINT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    license_id BIGINT NOT NULL REFERENCES licenses(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(asset_id, license_id)
);

-- Asset History table (audit log)
CREATE TABLE IF NOT EXISTS asset_history (
    id BIGSERIAL PRIMARY KEY,
    asset_id BIGINT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    field_name VARCHAR(100) NOT NULL,
    old_value TEXT,
    new_value TEXT,
    change_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_assets_category ON assets(category_id);
CREATE INDEX IF NOT EXISTS idx_assets_staff ON assets(staff_id);
CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status);
CREATE INDEX IF NOT EXISTS idx_staff_location ON staff(location_id);
CREATE INDEX IF NOT EXISTS idx_asset_history_asset ON asset_history(asset_id);
CREATE INDEX IF NOT EXISTS idx_licenses_expiration ON licenses(expiration_date);

-- Enable Row Level Security on all tables
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE asset_licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE asset_history ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users (full access)
-- Locations
CREATE POLICY "Enable all operations for authenticated users" ON locations
    FOR ALL USING (auth.role() = 'authenticated');

-- Categories
CREATE POLICY "Enable all operations for authenticated users" ON categories
    FOR ALL USING (auth.role() = 'authenticated');

-- Staff
CREATE POLICY "Enable all operations for authenticated users" ON staff
    FOR ALL USING (auth.role() = 'authenticated');

-- Assets
CREATE POLICY "Enable all operations for authenticated users" ON assets
    FOR ALL USING (auth.role() = 'authenticated');

-- Licenses
CREATE POLICY "Enable all operations for authenticated users" ON licenses
    FOR ALL USING (auth.role() = 'authenticated');

-- Asset Licenses
CREATE POLICY "Enable all operations for authenticated users" ON asset_licenses
    FOR ALL USING (auth.role() = 'authenticated');

-- Asset History
CREATE POLICY "Enable all operations for authenticated users" ON asset_history
    FOR ALL USING (auth.role() = 'authenticated');

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all tables
CREATE TRIGGER update_locations_updated_at BEFORE UPDATE ON locations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_staff_updated_at BEFORE UPDATE ON staff
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_assets_updated_at BEFORE UPDATE ON assets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_licenses_updated_at BEFORE UPDATE ON licenses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to generate next asset name (KLSB-CODE-XXX)
CREATE OR REPLACE FUNCTION get_next_asset_name(category_code VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    prefix VARCHAR;
    max_num INTEGER;
    next_num INTEGER;
BEGIN
    prefix := 'KLSB-' || category_code || '-';

    SELECT COALESCE(MAX(
        CAST(SUBSTRING(asset_name FROM LENGTH(prefix) + 1) AS INTEGER)
    ), 0) INTO max_num
    FROM assets
    WHERE asset_name LIKE prefix || '%';

    next_num := max_num + 1;

    RETURN prefix || LPAD(next_num::TEXT, 3, '0');
END;
$$ LANGUAGE plpgsql;

-- Sample data (optional - comment out if not needed)
/*
INSERT INTO locations (name) VALUES
    ('HQ Office'),
    ('Branch A'),
    ('Branch B');

INSERT INTO categories (name, code, description) VALUES
    ('Laptop', 'LAP', 'Portable computers'),
    ('Desktop', 'DES', 'Desktop workstations'),
    ('Monitor', 'MON', 'Display screens'),
    ('Printer', 'PRT', 'Printing devices'),
    ('Network', 'NET', 'Network equipment');
*/
