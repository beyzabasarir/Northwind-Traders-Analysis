-- CASE 1: CUSTOMERS 

-- The Marketing Department requested an analysis using the RFM (Recency, Frequency, Monetary) model to better segment customers based on purchasing behaviors.
-- Recency: How recently each customer made a purchase.
-- Frequency: How often each customer makes purchases.
-- Monetary value: The total amount spent by each customer.
-- The RFM model was used to classify customers into segments such as "Top Customers," "High Value Customers," and "At-Risk Customers." This segmentation will enable the marketing team to target different customer groups.


-- 1. RFM Analysis: Segmentation of customers based on purchasing behavior.

CREATE TABLE rfm_analysis AS 

-- Calculation of Recency, Frequency, and Monetary metrics 
WITH rfm_metrics AS (
  SELECT 
    o.customer_id,
    EXTRACT(day FROM AGE(DATE '1998-06-11', MAX(o.order_date))) AS recency,
    COUNT(o.order_id) AS frequency,
    ROUND(SUM(od.quantity * od.unit_price * (1 - od.discount))::numeric, 0) AS monetary
  FROM 
    orders o
  JOIN 
    order_details od ON o.order_id = od.order_id
  GROUP BY 
    o.customer_id
)

-- Assignment of RFM scores and customer segmentation
SELECT 
  customer_id,
  NTILE(5) OVER (ORDER BY recency DESC) AS recency_score,
  NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
  NTILE(5) OVER (ORDER BY monetary ASC) AS monetary_score,
  CASE
    WHEN NTILE(5) OVER (ORDER BY recency DESC) = 5 AND NTILE(5) OVER (ORDER BY frequency ASC) = 5 AND NTILE(5) OVER (ORDER BY monetary ASC) = 5 THEN 'Top Customers'
    WHEN NTILE(5) OVER (ORDER BY recency DESC) = 4 AND NTILE(5) OVER (ORDER BY frequency ASC) >= 4 AND NTILE(5) OVER (ORDER BY monetary ASC) >= 4 THEN 'High Value Customers'
    WHEN NTILE(5) OVER (ORDER BY recency DESC) >= 4 AND NTILE(5) OVER (ORDER BY frequency ASC) >= 3 AND NTILE(5) OVER (ORDER BY monetary ASC) >= 3 THEN 'Loyal Customers'
    WHEN NTILE(5) OVER (ORDER BY recency DESC) >= 3 AND NTILE(5) OVER (ORDER BY frequency ASC) >= 3 AND NTILE(5) OVER (ORDER BY monetary ASC) >= 3 THEN 'Emerging Customers'
    WHEN NTILE(5) OVER (ORDER BY recency DESC) >= 3 AND NTILE(5) OVER (ORDER BY frequency ASC) <= 2 AND NTILE(5) OVER (ORDER BY monetary ASC) <= 2 THEN 'Potential Drop-offs'
    ELSE 'At-Risk Customers'
  END AS customer_segment
FROM 
  rfm_metrics
ORDER BY 
  customer_id;

--Displaying the RFM analysis results

SELECT * FROM rfm_analysis
	
	
	
-- 2. Customers Profile: Analysis of customer purchasing behavior.

-- The Customer Insights Team requested an analysis focused on understanding the ordering behavior of individual customers. The goals of this analysis were:
-- Determining the total number of orders placed by each customer.
-- Calculating the average order value and identifying trends in purchasing patterns.
-- Measuring the average discount percentage applied to each customer's orders.
-- Identifying the preferred product category for each customer based on the most frequently purchased category.
-- This information will be used to design customer retention strategies,

-- Customer-level aggregation of order details
SELECT 
    c.customer_id,
    COUNT(o.order_id) AS total_orders, -- Total number of orders placed by each customer
    ROUND(AVG(CAST((od.unit_price * od.quantity) * (1 - od.discount) AS NUMERIC)), 2) AS avg_order_value, -- Average value per order
    ROUND(CAST(AVG(od.discount) * 100 AS NUMERIC), 2) AS avg_discount_percentage, -- Average discount percentage applied on each order
    MODE() WITHIN GROUP (ORDER BY cat.category_name) AS preferred_category -- Most frequently purchased product category
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_details od ON o.order_id = od.order_id
JOIN products p ON od.product_id = p.product_id
JOIN categories cat ON p.category_id = cat.category_id
GROUP BY c.customer_id
ORDER BY total_orders DESC; -- Sort customers by total number of orders placed


-- CASE 2: SALES 

-- The Sales Department requested an analysis to understand the impact of discounts on total sales revenue. The department wanted to evaluate:
-- The total sales generated with and without discounts.
-- The proportion of sales that occurred with discounts applied across various product categories.
-- The discount percentage for each product category and its contribution to overall revenue.
-- This analysis is relevant for evaluating the effectiveness of discount strategies.

-- 3. Total and discounted sales per category.

-- Sales breakdown by category with and without discounts
SELECT 
    p.category_id, 
    c.category_name, 
    SUM(CASE WHEN od.discount > 0 THEN od.quantity * od.unit_price ELSE 0 END) AS discounted_sales, -- Sales revenue where discounts were applied
    SUM(od.quantity * od.unit_price) AS total_sales, -- Total sales revenue (before discounts)
    ROUND((SUM(CASE WHEN od.discount > 0 THEN od.quantity * od.unit_price ELSE 0 END) / SUM(od.quantity * od.unit_price))::numeric,4 ) AS discount_percentage -- Percentage of total sales attributed to discounted products.
FROM 
    order_details od
JOIN 
    products p ON od.product_id = p.product_id
JOIN 
    categories c ON p.category_id = c.category_id
GROUP BY 
    p.category_id, c.category_name
ORDER BY 
    discount_percentage DESC; -- Sort categories by highest discount percentage of sales
	

-- 4. Sales Trend: Monthly analysis of customer purchasing trends.

-- The Sales Department needed a detailed analysis of monthly sales trends to track how sales quantities fluctuate over time for each customer. The objectives of this analysis included:
-- Breaking down the total quantity of products sold per customer on a monthly basis.
-- Identifying any seasonal trends or irregularities in customer purchasing behavior.

-- Monthly breakdown of sales quantities by customer
SELECT 
    EXTRACT(YEAR FROM o.order_date) AS year, -- Extract the year of the order
    EXTRACT(MONTH FROM o.order_date) AS month, -- Extract the month of the order
    o.customer_id, -- Customer making the purchase
    SUM(od.quantity) AS total_quantity_sold -- Total quantity of products purchased
FROM 
    orders o
JOIN 
    order_details od ON o.order_id = od.order_id
WHERE
    NOT (EXTRACT(YEAR FROM o.order_date) = 1998 AND EXTRACT(MONTH FROM o.order_date) = 5) -- Exclude May 1998 from the analysis
GROUP BY 
    EXTRACT(YEAR FROM o.order_date),
    EXTRACT(MONTH FROM o.order_date),
    o.customer_id
ORDER BY 
    year, month; -- Order results by year and month


-- CASE 3: PRODUCTS 
-- The Product Management Team asked for an analysis of product profitability to better understand which products contribute the most to the company’s bottom line. They were interested in:
-- Total revenue generated by each product.
-- Associated freight costs: How shipping costs affect the profitability of each product.
-- Net profitability: The overall profit of each product after subtracting freight costs.
-- This analysis helps the team decide on product discontinuation, pricing strategies, and inventory prioritization.

-- 5. Products Profitability: Identifying the most profitable products.

WITH product_profitability AS (
  SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    ROUND(SUM(od.quantity * od.unit_price * (1 - od.discount))::numeric, 2) AS total_revenue, -- Total revenue from each product
    ROUND(SUM(o.freight)::numeric, 2) AS total_freight -- Total shipping costs associated with each product
  FROM 
    order_details od
  JOIN 
    products p ON od.product_id = p.product_id
  JOIN 
    categories c ON p.category_id = c.category_id
  JOIN 
    orders o ON od.order_id = o.order_id
  WHERE p.discontinued = 0 -- Include only active products
  GROUP BY 
    p.product_id, p.product_name, c.category_name
)
-- Calculating profit by subtracting freight from revenue
SELECT 
  product_id,
  product_name,
  category_name,
  ROUND(total_revenue - total_freight, 2) AS profit -- Net profit after freight deduction
FROM 
  product_profitability
ORDER BY 
  profit DESC; -- Sort products by highest profit
  

-- CASE 4: SHIPMENT 

-- The Logistics Department requested a review of the shipment performance by different shipping partners. They were particularly focused on:
-- Total orders handled by each shipper.
-- Freight costs: Average and total freight costs per order.
-- Delivery speed: The average time taken to deliver orders from the date of shipment.
-- Customer segmentation: Understanding which customer segments (based on RFM analysis) are using specific shippers.
-- This analysis is intended to inform negotiations with shipping partners, improve delivery efficiency, and align shipping options with the needs of high-value customer segments.

-- 6. Performance evaluation of shippers and delivery times.

-- Analysis of shippers' performance based on orders and RFM segments
SELECT 
    sh.shipper_id,
    sh.company_name,
    COUNT(o.order_id) AS total_orders, -- Total number of orders shipped by each company
    SUM(o.freight) AS total_freight, -- Total shipping cost incurred by each shipper
    AVG(o.freight) AS avg_freight_per_order, -- Average freight cost per order
    AVG(DATE_PART('day', AGE(o.shipped_date, o.order_date))) AS avg_delivery_speed, -- Average number of days to deliver
    rfm.customer_segment AS rfm_segment -- RFM segment of the customers served by each shipper
FROM 
    orders o
JOIN 
    shippers sh ON o.ship_via = sh.shipper_id
JOIN 
    customers c ON o.customer_id = c.customer_id
JOIN 
    rfm_analysis rfm ON c.customer_id = rfm.customer_id
GROUP BY 
   sh.shipper_id, sh.company_name, rfm.customer_segment
ORDER BY 
    total_orders DESC; -- Sort shippers by total number of orders handled
	

-- CASE 5: EMPLOYEEES

-- The Human Resources and Sales Department collaborated to request an analysis of employee sales performance. Their goal was to:
-- Identify top-performing employees based on net sales.
-- Understand how sales are distributed across the workforce.
-- They plan to use this information for performance evaluations, setting sales targets, and designing incentive structures.

--7. Ranking employees by sales performance.

SELECT 
    e.employee_id,
    e.first_name || ' ' || e.last_name AS employee_name, -- Full name of the employee
    SUM(od.unit_price * od.quantity * (1 - od.discount)) AS net_sales -- Total net sales generated by the employee
FROM 
    employees e
JOIN 
    orders o ON e.employee_id = o.employee_id
JOIN 
    order_details od ON o.order_id = od.order_id
GROUP BY 
    e.employee_id, e.first_name, e.last_name
ORDER BY 
    net_sales DESC; -- Rank employees by their net sales
	


