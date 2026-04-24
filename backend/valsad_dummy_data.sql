-- ============================================================
-- VALSAD, GUJARAT - ADDITIONAL DUMMY DATA
-- ============================================================

USE food_delivery;

-- 1. Create Users
-- Passwords: 'Password@123' (hashed using $2y$10$e0MYzXyjpJS7Pd0RVvHwHeFOnNVsP6n9n9p8EHB6nH/iGjU/YyKGu)
INSERT INTO `users` (`name`, `email`, `phone`, `password`, `role`) VALUES
('Amit Patel', 'amit@valsad.com', '9988776655', '$2y$10$e0MYzXyjpJS7Pd0RVvHwHeFOnNVsP6n9n9p8EHB6nH/iGjU/YyKGu', 'customer'),
('Sneha Desai', 'sneha@valsad.com', '9988776654', '$2y$10$e0MYzXyjpJS7Pd0RVvHwHeFOnNVsP6n9n9p8EHB6nH/iGjU/YyKGu', 'customer'),
('Gujarati Delights Owner', 'delights@valsad.com', '9123456701', '$2y$10$e0MYzXyjpJS7Pd0RVvHwHeFOnNVsP6n9n9p8EHB6nH/iGjU/YyKGu', 'restaurant'),
('Valsad Fast Food Owner', 'fastfood@valsad.com', '9123456702', '$2y$10$e0MYzXyjpJS7Pd0RVvHwHeFOnNVsP6n9n9p8EHB6nH/iGjU/YyKGu', 'restaurant'),
('Karan Rider', 'karan@valsad.com', '9000111222', '$2y$10$e0MYzXyjpJS7Pd0RVvHwHeFOnNVsP6n9n9p8EHB6nH/iGjU/YyKGu', 'delivery_boy'),
('Vijay Rider', 'vijay@valsad.com', '9000111223', '$2y$10$e0MYzXyjpJS7Pd0RVvHwHeFOnNVsP6n9n9p8EHB6nH/iGjU/YyKGu', 'delivery_boy');

-- Get IDs (assuming auto-increment starts after existing data)
SET @amit_id = (SELECT id FROM users WHERE email='amit@valsad.com');
SET @sneha_id = (SELECT id FROM users WHERE email='sneha@valsad.com');
SET @delights_owner_id = (SELECT id FROM users WHERE email='delights@valsad.com');
SET @fastfood_owner_id = (SELECT id FROM users WHERE email='fastfood@valsad.com');
SET @karan_id = (SELECT id FROM users WHERE email='karan@valsad.com');
SET @vijay_id = (SELECT id FROM users WHERE email='vijay@valsad.com');

-- 2. Create Restaurants
INSERT INTO `restaurants` (`user_id`, `name`, `address`, `lat`, `lng`, `cuisine`, `status`, `rating_avg`, `rating_count`) VALUES
(@delights_owner_id, 'Gujarati Delights', 'Station Road, Valsad, Gujarat', 20.61500000, 72.93000000, 'Gujarati', 'approved', 4.80, 10),
(@fastfood_owner_id, 'Valsad Fast Food', 'Tithal Road, Valsad, Gujarat', 20.60500000, 72.92000000, 'Fast Food', 'approved', 4.50, 15);

SET @delights_id = (SELECT id FROM restaurants WHERE user_id=@delights_owner_id);
SET @fastfood_id = (SELECT id FROM restaurants WHERE user_id=@fastfood_owner_id);

-- 3. Create Delivery Boys
INSERT INTO `delivery_boys` (`user_id`, `status`, `current_lat`, `current_lng`) VALUES
(@karan_id, 'available', 20.61000000, 72.92500000),
(@vijay_id, 'available', 20.60000000, 72.91000000);

-- 4. Create Addresses
INSERT INTO `addresses` (`user_id`, `address_line1`, `address_line2`, `city`, `lat`, `lng`, `is_default`) VALUES
(@amit_id, 'Flat 402, Sea View Apartments', 'Tithal Road', 'Valsad', 20.60800000, 72.90000000, 1),
(@sneha_id, 'Plot 15, Halar Row Houses', 'Halar', 'Valsad', 20.61800000, 72.94000000, 1);

-- 5. Create Categories
INSERT INTO `categories` (`restaurant_id`, `name`, `sort_order`) VALUES
(@delights_id, 'Main Thali', 1),
(@delights_id, 'Farsan', 2),
(@fastfood_id, 'Burgers', 1),
(@fastfood_id, 'Sides', 2);

SET @cat_thali = (SELECT id FROM categories WHERE restaurant_id=@delights_id AND name='Main Thali');
SET @cat_farsan = (SELECT id FROM categories WHERE restaurant_id=@delights_id AND name='Farsan');
SET @cat_burger = (SELECT id FROM categories WHERE restaurant_id=@fastfood_id AND name='Burgers');

-- 6. Create Menu Items
INSERT INTO `menu_items` (`restaurant_id`, `category_id`, `name`, `description`, `price`, `is_available`, `is_veg`) VALUES
(@delights_id, @cat_thali, 'Special Gujarati Thali', 'Unlimited Gujarati Thali with Rotli, Dal, Rice, 3 Sabzi, Sweet, and Chaas', 250.00, 1, 1),
(@delights_id, @cat_farsan, 'Khaman Dhokla', 'Soft and spongy steamed gram flour snack', 80.00, 1, 1),
(@fastfood_id, @cat_burger, 'Aloo Tikki Burger', 'Classic spiced potato patty burger with mayo and lettuce', 70.00, 1, 1),
(@fastfood_id, @cat_burger, 'Cheese Maharaja Burger', 'Double patty burger with extra cheese and secret sauce', 150.00, 1, 1);

SELECT 'Valsad Dummy Data Successfully Added!' AS message;
