-- ============================================================
-- COMPREHENSIVE DATA RESTORE SCRIPT
-- Merges all data from database.sql and database_update.sql
-- ============================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

DROP DATABASE IF EXISTS food_delivery;
CREATE DATABASE food_delivery CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE food_delivery;

-- USERS
CREATE TABLE users (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    phone       VARCHAR(20)  NOT NULL UNIQUE,
    email       VARCHAR(100) NOT NULL UNIQUE,
    password    VARCHAR(255) NOT NULL,
    role        ENUM('customer','restaurant','delivery_boy','admin') NOT NULL DEFAULT 'customer',
    fcm_token   TEXT,
    is_active   TINYINT(1) NOT NULL DEFAULT 1,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_role (role)
) ENGINE=InnoDB;

-- RESTAURANTS
CREATE TABLE restaurants (
    id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id        INT UNSIGNED NOT NULL,
    name           VARCHAR(150) NOT NULL,
    address        TEXT NOT NULL,
    lat            DECIMAL(10,8),
    lng            DECIMAL(11,8),
    cuisine        VARCHAR(100),
    opening_time   TIME NOT NULL DEFAULT '09:00:00',
    closing_time   TIME NOT NULL DEFAULT '22:00:00',
    status         ENUM('pending','approved','suspended','closed') NOT NULL DEFAULT 'pending',
    image          VARCHAR(255),
    image_url      VARCHAR(500) NULL DEFAULT NULL,
    rating_avg     DECIMAL(3,2) NOT NULL DEFAULT 0.00,
    rating_count   INT UNSIGNED NOT NULL DEFAULT 0,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_rest_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- DELIVERY BOYS
CREATE TABLE delivery_boys (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         INT UNSIGNED NOT NULL UNIQUE,
    status          ENUM('available','busy','offline') NOT NULL DEFAULT 'offline',
    current_lat     DECIMAL(10,8),
    current_lng     DECIMAL(11,8),
    total_earnings  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    rating_avg      DECIMAL(3,2)  NOT NULL DEFAULT 0.00,
    rating_count    INT UNSIGNED  NOT NULL DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_db_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ADDRESSES
CREATE TABLE addresses (
    id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id       INT UNSIGNED NOT NULL,
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city          VARCHAR(100) NOT NULL,
    lat           DECIMAL(10,8),
    lng           DECIMAL(11,8),
    is_default    TINYINT(1) NOT NULL DEFAULT 0,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_addr_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- CATEGORIES
CREATE TABLE categories (
    id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    restaurant_id INT UNSIGNED NOT NULL,
    name          VARCHAR(100) NOT NULL,
    sort_order    INT UNSIGNED NOT NULL DEFAULT 0,
    CONSTRAINT fk_cat_rest FOREIGN KEY (restaurant_id) REFERENCES restaurants(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- MENU ITEMS
CREATE TABLE menu_items (
    id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    restaurant_id INT UNSIGNED NOT NULL,
    category_id   INT UNSIGNED,
    name          VARCHAR(150) NOT NULL,
    description   TEXT,
    price         DECIMAL(8,2) NOT NULL,
    image         VARCHAR(255),
    image_url      VARCHAR(500) NULL DEFAULT NULL,
    is_available  TINYINT(1) NOT NULL DEFAULT 1,
    is_veg        TINYINT(1) NOT NULL DEFAULT 0,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_item_rest FOREIGN KEY (restaurant_id) REFERENCES restaurants(id) ON DELETE CASCADE,
    CONSTRAINT fk_item_cat  FOREIGN KEY (category_id)   REFERENCES categories(id)  ON DELETE SET NULL
) ENGINE=InnoDB;

-- COUPONS
CREATE TABLE coupons (
    id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code              VARCHAR(50)  NOT NULL UNIQUE,
    discount_type     ENUM('flat','percent') NOT NULL DEFAULT 'flat',
    discount_value    DECIMAL(8,2) NOT NULL,
    min_order_amount  DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    valid_from        DATE NOT NULL,
    valid_until       DATE NOT NULL,
    usage_limit       INT UNSIGNED NOT NULL DEFAULT 100,
    used_count        INT UNSIGNED NOT NULL DEFAULT 0,
    is_active         TINYINT(1)   NOT NULL DEFAULT 1,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ORDERS
CREATE TABLE orders (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         INT UNSIGNED NOT NULL,
    restaurant_id   INT UNSIGNED NOT NULL,
    delivery_boy_id INT UNSIGNED,
    address_id      INT UNSIGNED,
    payment_method  ENUM('cod','upi') NOT NULL DEFAULT 'cod',
    payment_status  ENUM('pending','successful','failed','refunded') NOT NULL DEFAULT 'pending',
    order_status    ENUM('pending','accepted','rejected','assigned','reached_restaurant','out_for_delivery','delivered','cancelled') NOT NULL DEFAULT 'pending',
    otp             VARCHAR(6),
    subtotal        DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    delivery_charge DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    tax             DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    tip_amount      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_amount    DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    coupon_code     VARCHAR(50),
    coupon_discount DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    special_notes   TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    delivered_at    TIMESTAMP NULL DEFAULT NULL,
    CONSTRAINT fk_ord_user   FOREIGN KEY (user_id)         REFERENCES users(id)          ON DELETE RESTRICT,
    CONSTRAINT fk_ord_rest   FOREIGN KEY (restaurant_id)   REFERENCES restaurants(id)    ON DELETE RESTRICT,
    CONSTRAINT fk_ord_db     FOREIGN KEY (delivery_boy_id) REFERENCES delivery_boys(id)  ON DELETE SET NULL,
    CONSTRAINT fk_ord_addr   FOREIGN KEY (address_id)      REFERENCES addresses(id)      ON DELETE SET NULL
) ENGINE=InnoDB;

-- ORDER ITEMS
CREATE TABLE order_items (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id     INT UNSIGNED NOT NULL,
    menu_item_id INT UNSIGNED,
    quantity     INT UNSIGNED NOT NULL DEFAULT 1,
    price        DECIMAL(8,2) NOT NULL,
    name         VARCHAR(150) NOT NULL,
    CONSTRAINT fk_oi_order FOREIGN KEY (order_id)     REFERENCES orders(id)     ON DELETE CASCADE,
    CONSTRAINT fk_oi_item  FOREIGN KEY (menu_item_id) REFERENCES menu_items(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- REVIEWS
CREATE TABLE reviews (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id    INT UNSIGNED NOT NULL,
    user_id     INT UNSIGNED NOT NULL,
    rating      TINYINT UNSIGNED NOT NULL,
    comment     TEXT,
    review_for  ENUM('restaurant','delivery_boy') NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rev_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    CONSTRAINT fk_rev_user  FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE,
    UNIQUE KEY uq_order_review (order_id, review_for)
) ENGINE=InnoDB;

-- CHAT MESSAGES
CREATE TABLE chat_messages (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    order_id    INT UNSIGNED NOT NULL,
    sender_id   INT UNSIGNED NOT NULL,
    sender_role ENUM('customer','delivery_boy') NOT NULL DEFAULT 'customer',
    message     TEXT NOT NULL,
    is_read     TINYINT(1) NOT NULL DEFAULT 0,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cm_order  FOREIGN KEY (order_id)  REFERENCES orders(id) ON DELETE CASCADE,
    CONSTRAINT fk_cm_sender FOREIGN KEY (sender_id) REFERENCES users(id)  ON DELETE CASCADE
) ENGINE=InnoDB;

-- SETTINGS
CREATE TABLE settings (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    value       TEXT,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- --------------------------------------------------------
-- COMPREHENSIVE DATA INSERTS
-- --------------------------------------------------------

-- Users from both sets
INSERT INTO users (id, name, phone, email, password, role) VALUES
(1, 'Admin User', '9000000000', 'admin@foodapp.com', 'Admin@123', 'admin'),
(2, 'Rahul Sharma', '9876543210', 'rahul@example.com', 'Test@123', 'customer'),
(3, 'Spice Garden Owner', '9123456780', 'spicegarden@example.com', 'Test@123', 'restaurant'),
(4, 'Ravi Kumar', '9111222333', 'ravi@example.com', 'Test@123', 'delivery_boy'),
(101, 'Aarav Sharma',  'aarav@example.com',  '9876543211', 'Test@123', 'customer'),
(102, 'Priya Mehta',   'priya@example.com',  '9876543212', 'Test@123', 'customer'),
(301, 'Vikram Singh',  'vikram.del@example.com', '9811111111', 'Test@123', 'delivery_boy'),
(302, 'Arjun Das',     'arjun.del@example.com',  '9811111112', 'Test@123', 'delivery_boy');

-- Restaurants
INSERT INTO restaurants (id, user_id, name, address, lat, lng, cuisine, status, rating_avg) VALUES
(1, 3, 'Spice Garden', '12, MG Road, Bengaluru', 12.9716, 77.5946, 'Indian', 'approved', 4.50),
(2, 3, 'Pizza Paradise', '12 Indiranagar, Bengaluru', 12.9719, 77.6407, 'Italian', 'approved', 4.00);

-- Delivery Boy Profiles
INSERT INTO delivery_boys (user_id, status) VALUES 
(4, 'available'),
(301, 'available'),
(302, 'offline');

-- Categories
INSERT INTO categories (restaurant_id, name) VALUES
(1, 'Starters'), (1, 'Main Course'), (1, 'Breads'), (1, 'Beverages'),
(2, 'Pizzas'), (2, 'Sides');

-- Menu Items
INSERT INTO menu_items (restaurant_id, category_id, name, description, price, is_available, is_veg) VALUES
(1, 1, 'Veg Spring Rolls', 'Crispy rolls with vegetables', 120.00, 1, 1),
(1, 1, 'Chicken Tikka', 'Tandoori chicken', 220.00, 1, 0),
(1, 2, 'Butter Paneer Masala', 'Rich tomato gravy', 260.00, 1, 1),
(2, 5, 'Margherita Pizza', 'Classic cheese pizza', 299.00, 1, 1),
(2, 5, 'Pepperoni Pizza', 'Beef pepperoni', 499.00, 1, 0);

-- Addresses
INSERT INTO addresses (user_id, address_line1, city, lat, lng, is_default) VALUES
(2, '45, Indiranagar, Bengaluru', 'Bengaluru', 12.9784, 77.6408, 1),
(101, '23 HSR Layout', 'Bengaluru', 12.9125, 77.6406, 1);

-- Settings
INSERT INTO settings (setting_key, value) VALUES
('delivery_charge', '40.00'),
('tax_percent', '5.00'),
('restaurant_visibility_radius', '15'),
('app_name', 'FoodDash'),
('currency_symbol', '₹');
