-- Create Schema / Database for SkyConnect Airlines
CREATE DATABASE IF NOT EXISTS skyconnect_analytics;

-- Switch to the newly created schema
USE skyconnect_analytics;
CREATE TABLE IF NOT EXISTS customer_loyalty_history (
    loyalty_number          INT NOT NULL,
    country                 VARCHAR(50) NOT NULL,
    province                VARCHAR(50) NOT NULL,
    city                    VARCHAR(50) NOT NULL,
    postal_code             VARCHAR(20) NOT NULL,
    gender                  VARCHAR(10) NOT NULL,
    education               VARCHAR(50) NOT NULL,
    salary                  DECIMAL(12, 2) NULL, 
    marital_status          VARCHAR(20) NOT NULL,
    loyalty_card            VARCHAR(20) NOT NULL,
    customer_loyalty_value  DECIMAL(12, 2) NOT NULL,
    enrollment_type         VARCHAR(30) NOT NULL,
    enrollment_year         INT NOT NULL,
    enrollment_month        INT NOT NULL,
    cancellation_year       INT NULL, -- Null for active members
    cancellation_month      INT NULL, -- Null for active members
    PRIMARY KEY (loyalty_number)
);

CREATE TABLE IF NOT EXISTS customer_flight_activity (
    loyalty_number                 INT NOT NULL,
    year                           INT NOT NULL,
    month                          INT NOT NULL,
    total_flights                  INT NOT NULL DEFAULT 0,
    distance                       INT NOT NULL DEFAULT 0,
    points_accumulated             INT NOT NULL DEFAULT 0,
    points_redeemed                INT NOT NULL DEFAULT 0,
    dollar_cost_points_redeemed    DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (loyalty_number, year, month),
    CONSTRAINT fk_flight_customer 
        FOREIGN KEY (loyalty_number) 
        REFERENCES customer_loyalty_history (loyalty_number) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE
);

-- Customer Status query
SELECT 
    loyalty_number,
    cancellation_year,
    cancellation_month,
    CASE 
        WHEN cancellation_year IS NOT NULL THEN 'Cancelled'
        ELSE 'Active'
    END AS customer_status
FROM customer_loyalty_history;

-- Membership Duration  
SELECT 
    loyalty_number,
    loyalty_card,
    enrollment_year,
    enrollment_month,
    cancellation_year,
    cancellation_month,
    CASE 
        WHEN cancellation_year IS NOT NULL THEN (cancellation_year - enrollment_year)
        ELSE (2018 - enrollment_year)
    END AS membership_duration_years
FROM customer_loyalty_history;

-- Salary Band
SELECT 
    loyalty_number,
    loyalty_card,
    education,
    salary,
    CASE 
        WHEN salary IS NULL THEN 'Unknown / Missing'
        WHEN salary < 50000 THEN 'Low (< $50k)'
        WHEN salary BETWEEN 50000 AND 85000 THEN 'Medium ($50k - $85k)'
        WHEN salary > 85000 THEN 'High (> $85k)'
    END AS salary_band
FROM customer_loyalty_history;

-- Customer Value Segment  
SELECT 
    loyalty_number,
    loyalty_card,
    province,
    salary,
    customer_loyalty_value AS clv,
    CASE 
        WHEN customer_loyalty_value >= 10000 THEN 'Premium Customer'
        WHEN customer_loyalty_value BETWEEN 6000 AND 9999.99 THEN 'High Value Customer'
        WHEN customer_loyalty_value BETWEEN 3500 AND 5999.99 THEN 'Medium Value Customer'
        ELSE 'Standard Customer'
    END AS customer_value_segment
FROM customer_loyalty_history;

-- Flight Frequency Category 
SELECT 
    l.loyalty_number,
    l.loyalty_card,
    COALESCE(f.total_flights, 0) AS total_flights,
    COALESCE(f.total_distance, 0) AS total_distance,
    CASE 
        WHEN COALESCE(f.total_flights, 0) = 0 THEN 'Inactive'
        WHEN COALESCE(f.total_flights, 0) BETWEEN 1 AND 3 THEN 'Occasional Traveler'
        WHEN COALESCE(f.total_flights, 0) BETWEEN 4 AND 6 THEN 'Regular Traveler'
        WHEN COALESCE(f.total_flights, 0) BETWEEN 7 AND 10 THEN 'Frequent Flyer'
        ELSE 'Elite Traveler'
    END AS flight_frequency_category
FROM customer_loyalty_history l
LEFT JOIN (
    SELECT 
        loyalty_number,
        SUM(total_flights) AS total_flights,
        SUM(distance) AS total_distance
    FROM customer_flight_activity
    GROUP BY loyalty_number
) f ON l.loyalty_number = f.loyalty_number;

-- Redemption Category 
SELECT 
    l.loyalty_number,
    l.loyalty_card,
    COALESCE(f.points_accumulated, 0) AS points_accumulated,
    COALESCE(f.points_redeemed, 0) AS points_redeemed,
    COALESCE(f.dollar_cost_points_redeemed, 0.00) AS dollar_cost_points_redeemed,
    CASE 
        WHEN COALESCE(f.points_redeemed, 0) = 0 THEN 'Never Redeemed'
        WHEN COALESCE(f.points_redeemed, 0) BETWEEN 1 AND 450 THEN 'Low Redemption'
        WHEN COALESCE(f.points_redeemed, 0) BETWEEN 451 AND 650 THEN 'Moderate Redemption'
        ELSE 'High Redemption'
    END AS redemption_category
FROM customer_loyalty_history l
LEFT JOIN (
    SELECT 
        loyalty_number,
        SUM(points_accumulated) AS points_accumulated,
        SUM(points_redeemed) AS points_redeemed,
        SUM(dollar_cost_points_redeemed) AS dollar_cost_points_redeemed
    FROM customer_flight_activity
    GROUP BY loyalty_number
) f ON l.loyalty_number = f.loyalty_number;

-- Engagement Score
SELECT 
    l.loyalty_number,
    l.loyalty_card,
    l.customer_loyalty_value AS clv,
    COALESCE(f.total_flights, 0) AS total_flights,
    COALESCE(f.points_redeemed, 0) AS points_redeemed,
    ROUND(
        (LEAST(COALESCE(f.total_flights, 0), 12) / 12.0 * 40.0) + 
        (LEAST(l.customer_loyalty_value, 15000) / 15000.0 * 40.0) + 
        (CASE WHEN COALESCE(f.points_redeemed, 0) > 0 THEN 20.0 ELSE 0.0 END), 
    2) AS engagement_score,
    
    -- Engagement Level Band
    CASE 
        WHEN ROUND(
            (LEAST(COALESCE(f.total_flights, 0), 12) / 12.0 * 40.0) + 
            (LEAST(l.customer_loyalty_value, 15000) / 15000.0 * 40.0) + 
            (CASE WHEN COALESCE(f.points_redeemed, 0) > 0 THEN 20.0 ELSE 0.0 END), 
        2) >= 70.0 THEN 'High Engagement'
        WHEN ROUND(
            (LEAST(COALESCE(f.total_flights, 0), 12) / 12.0 * 40.0) + 
            (LEAST(l.customer_loyalty_value, 15000) / 15000.0 * 40.0) + 
            (CASE WHEN COALESCE(f.points_redeemed, 0) > 0 THEN 20.0 ELSE 0.0 END), 
        2) BETWEEN 40.0 AND 69.99 THEN 'Moderate Engagement'
        ELSE 'Low Engagement'
    END AS engagement_level

FROM customer_loyalty_history l
LEFT JOIN (
    SELECT 
        loyalty_number,
        SUM(total_flights) AS total_flights,
        SUM(points_redeemed) AS points_redeemed
    FROM customer_flight_activity
    GROUP BY loyalty_number
) f ON l.loyalty_number = f.loyalty_number;

