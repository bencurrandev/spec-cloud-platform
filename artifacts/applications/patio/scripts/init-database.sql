-- =============================================================================
-- Patio Application - Database Schema Initialization
-- =============================================================================
-- Purpose: Create tables, indexes, and seed data for Patio application
-- Database: MySQL 8.0
-- Character Set: utf8mb4 (full Unicode support including emojis)
-- =============================================================================

-- Run: mysql -h <server-fqdn> -u <admin-user> -p patiodb < init-database.sql

-- =============================================================================
-- USERS & AUTHENTICATION
-- =============================================================================

CREATE TABLE IF NOT EXISTS users (
    user_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL COMMENT 'bcrypt hash with cost factor 12',
    role ENUM('customer', 'business_owner', 'admin') NOT NULL DEFAULT 'customer',
    mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'MFA required for business_owner and admin per ac-001',
    mfa_secret VARCHAR(255) NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NULL,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    email_verification_token VARCHAR(255) NULL,
    password_reset_token VARCHAR(255) NULL,
    password_reset_expires DATETIME NULL,
    last_login_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL COMMENT 'Soft delete for GDPR compliance',
    
    INDEX idx_email (email),
    INDEX idx_role (role),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='User accounts for customers, business owners, and admins';

-- =============================================================================
-- CITIES & LOCATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS cities (
    city_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    state VARCHAR(50) NOT NULL,
    country VARCHAR(3) NOT NULL DEFAULT 'USA',
    timezone VARCHAR(50) NOT NULL COMMENT 'e.g., America/New_York',
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_city_state (name, state),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Cities where patio bookings are available';

-- =============================================================================
-- PATIOS & LISTINGS
-- =============================================================================

CREATE TABLE IF NOT EXISTS patios (
    patio_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    business_owner_id BIGINT UNSIGNED NOT NULL,
    city_id INT UNSIGNED NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    address VARCHAR(255) NOT NULL,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    capacity INT UNSIGNED NOT NULL COMMENT 'Maximum number of guests',
    amenities JSON NULL COMMENT 'Array of amenities: covered, heating, food_service, bar, pet_friendly, etc.',
    base_price_hourly DECIMAL(10, 2) NOT NULL COMMENT 'Base hourly rate in USD',
    photos JSON NULL COMMENT 'Array of photo URLs from blob storage',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'Admin verification status',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL COMMENT 'Soft delete',
    
    FOREIGN KEY (business_owner_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (city_id) REFERENCES cities(city_id) ON DELETE RESTRICT,
    INDEX idx_city (city_id),
    INDEX idx_business_owner (business_owner_id),
    INDEX idx_is_active (is_active),
    INDEX idx_created_at (created_at),
    INDEX idx_latitude (latitude),
    INDEX idx_longitude (longitude)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Patio listings from business owners';

-- =============================================================================
-- BOOKINGS & RESERVATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS bookings (
    booking_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id BIGINT UNSIGNED NOT NULL,
    patio_id BIGINT UNSIGNED NOT NULL,
    start_datetime DATETIME NOT NULL,
    end_datetime DATETIME NOT NULL,
    duration_hours DECIMAL(5, 2) NOT NULL,
    guest_count INT UNSIGNED NOT NULL,
    base_price DECIMAL(10, 2) NOT NULL COMMENT 'Base price before dynamic pricing',
    final_price DECIMAL(10, 2) NOT NULL COMMENT 'Final price after dynamic pricing',
    pricing_breakdown JSON NOT NULL COMMENT 'JSON: {base, time_multiplier, weather_multiplier, demand_multiplier, total}',
    status ENUM('pending', 'confirmed', 'cancelled', 'completed') NOT NULL DEFAULT 'pending',
    payment_status ENUM('pending', 'paid', 'refunded', 'failed') NOT NULL DEFAULT 'pending',
    payment_transaction_id VARCHAR(255) NULL,
    cancellation_reason TEXT NULL,
    cancelled_at DATETIME NULL,
    special_requests TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (customer_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (patio_id) REFERENCES patios(patio_id) ON DELETE RESTRICT,
    INDEX idx_customer (customer_id),
    INDEX idx_patio (patio_id),
    INDEX idx_start_datetime (start_datetime),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    INDEX idx_patio_datetime (patio_id, start_datetime, end_datetime) COMMENT 'Optimize double-booking prevention'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Customer patio bookings';

-- =============================================================================
-- AVAILABILITY & BLOCKING
-- =============================================================================

CREATE TABLE IF NOT EXISTS availability_blocks (
    block_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    patio_id BIGINT UNSIGNED NOT NULL,
    start_datetime DATETIME NOT NULL,
    end_datetime DATETIME NOT NULL,
    reason ENUM('closed', 'booked', 'maintenance', 'weather', 'other') NOT NULL DEFAULT 'closed',
    notes TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (patio_id) REFERENCES patios(patio_id) ON DELETE CASCADE,
    INDEX idx_patio (patio_id),
    INDEX idx_datetime_range (start_datetime, end_datetime)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Time periods when patio is unavailable';

-- =============================================================================
-- DYNAMIC PRICING
-- =============================================================================

CREATE TABLE IF NOT EXISTS pricing_rules (
    rule_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    patio_id BIGINT UNSIGNED NOT NULL,
    rule_type ENUM('time_based', 'weather_based', 'demand_based') NOT NULL,
    multiplier DECIMAL(5, 2) NOT NULL COMMENT 'e.g., 1.5 = 50% premium, 0.8 = 20% discount',
    conditions JSON NOT NULL COMMENT 'JSON conditions: {day_of_week: [5,6,7], hours: [17-22], weather: sunny, etc.}',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    priority INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Higher priority rules applied first',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (patio_id) REFERENCES patios(patio_id) ON DELETE CASCADE,
    INDEX idx_patio (patio_id),
    INDEX idx_rule_type (rule_type),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Dynamic pricing rules per patio';

-- =============================================================================
-- WEATHER FORECASTS (CACHED)
-- =============================================================================

CREATE TABLE IF NOT EXISTS weather_forecasts (
    forecast_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id INT UNSIGNED NOT NULL,
    forecast_date DATE NOT NULL,
    temperature_high INT NOT NULL COMMENT 'Fahrenheit',
    temperature_low INT NOT NULL COMMENT 'Fahrenheit',
    precipitation_chance INT NOT NULL COMMENT 'Percentage 0-100',
    cloud_cover INT NOT NULL COMMENT 'Percentage 0-100',
    wind_speed INT NOT NULL COMMENT 'MPH',
    conditions VARCHAR(50) NOT NULL COMMENT 'sunny, cloudy, rainy, etc.',
    is_optimal BOOLEAN GENERATED ALWAYS AS (
        temperature_high >= 68 AND precipitation_chance < 20 AND cloud_cover < 40
    ) STORED COMMENT 'Auto-calculated: optimal weather for patio',
    fetched_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (city_id) REFERENCES cities(city_id) ON DELETE CASCADE,
    UNIQUE KEY uk_city_date (city_id, forecast_date),
    INDEX idx_forecast_date (forecast_date),
    INDEX idx_is_optimal (is_optimal),
    INDEX idx_fetched_at (fetched_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Cached weather forecasts (refreshed every 6 hours)';

-- =============================================================================
-- AUDIT LOGGING (per audit-001: 90-day retention)
-- =============================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    log_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NULL,
    event_type VARCHAR(50) NOT NULL COMMENT 'login, logout, booking.created, patio.updated, etc.',
    event_data JSON NULL COMMENT 'Additional event details',
    ip_address VARCHAR(45) NULL COMMENT 'IPv4 or IPv6',
    user_agent TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_user (user_id),
    INDEX idx_event_type (event_type),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audit trail for compliance (90-day retention per audit-001)';

-- =============================================================================
-- SEED DATA: CITIES
-- =============================================================================

INSERT IGNORE INTO cities (name, state, country, timezone, latitude, longitude, is_active) VALUES
('New York', 'NY', 'USA', 'America/New_York', 40.7128, -74.0060, TRUE),
('Chicago', 'IL', 'USA', 'America/Chicago', 41.8781, -87.6298, TRUE),
('Los Angeles', 'CA', 'USA', 'America/Los_Angeles', 34.0522, -118.2437, TRUE);

-- =============================================================================
-- SEED DATA: TEST ADMIN USER
-- =============================================================================
-- Password: Admin123! (bcrypt hash, cost factor 12)
-- NOTE: Change this password immediately after first login in production!

INSERT IGNORE INTO users (email, password_hash, role, mfa_enabled, first_name, last_name, email_verified) VALUES
('admin@patio.local', '$2y$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyiJRlDAZ7uu', 'admin', TRUE, 'Admin', 'User', TRUE);

-- =============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- =============================================================================

-- NOTE: Most indexes are already defined inline in table definitions above.
-- Additional indexes can be added here if needed after performance analysis.

-- Full-text search for patio descriptions (name and description)
ALTER TABLE patios ADD FULLTEXT INDEX ft_name_description (name, description);

-- =============================================================================
-- DATABASE MAINTENANCE EVENTS
-- =============================================================================
-- NOTE: Event Scheduler must be enabled: SET GLOBAL event_scheduler = ON;
-- Azure Database for MySQL Flexible Server may have events disabled by default.
-- Consider using external scheduled jobs (Azure Functions, cron) instead.

-- Auto-delete old audit logs after 90 days (per audit-001)
DROP EVENT IF EXISTS purge_old_audit_logs;
CREATE EVENT purge_old_audit_logs
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
  DELETE FROM audit_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);

-- Auto-delete old weather forecasts after 30 days
DROP EVENT IF EXISTS purge_old_weather_forecasts;
CREATE EVENT purge_old_weather_forecasts
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP
DO
  DELETE FROM weather_forecasts WHERE forecast_date < DATE_SUB(CURDATE(), INTERVAL 30 DAY);

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

SHOW TABLES;
SELECT COUNT(*) as total_cities FROM cities;
SELECT COUNT(*) as total_users FROM users;

-- =============================================================================
-- COMPLETION MESSAGE
-- =============================================================================

SELECT 'Database schema initialized successfully!' AS status;
SELECT 'Next steps: Deploy application code and configure environment variables' AS next_steps;
