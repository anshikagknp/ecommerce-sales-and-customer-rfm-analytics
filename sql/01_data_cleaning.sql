-- Audit raw data for invalid records (cancellations, negative/zero quantities and prices)
SELECT 
    COUNT(*) AS total_raw_rows,
    COUNT(CASE WHEN invoice_no LIKE 'C%' THEN 1 END) AS cancelled_invoices,
    COUNT(CASE WHEN quantity <= 0 THEN 1 END) AS non_positive_quantity,
    COUNT(CASE WHEN unit_price <= 0 THEN 1 END) AS non_positive_price,
    COUNT(CASE 
        WHEN invoice_no NOT LIKE 'C%' 
         AND quantity > 0 
         AND unit_price > 0 
        THEN 1 
    END) AS valid_clean_rows
FROM raw_retail;

-- Create a clean view of valid transactions for downstream analysis
DROP VIEW IF EXISTS clean_retail;

CREATE VIEW clean_retail AS
SELECT 
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    ROUND((quantity * unit_price), 2) AS total_revenue,
    customer_id,
    country
FROM raw_retail
WHERE invoice_no NOT LIKE 'C%'
  AND quantity > 0
  AND unit_price > 0;

-- Verify clean row count
SELECT COUNT(*) AS clean_row_count FROM clean_retail;
