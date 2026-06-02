select * from Album
select * from Artist
select * from Customer
select * from Employee
select * from Genre
select * from Invoice
select * from InvoiceLine
select * from MediaType
select * from Playlist
select * from PlaylistTrack
select * from Track

-- Q1: How big is the business? Get a high-level snapshot.
SELECT
    MIN(InvoiceDate) AS first_sale,
    MAX(InvoiceDate) AS last_sale,
    COUNT(*) AS total_invoices,
    ROUND(SUM(Total), 2) AS total_revenue,
    ROUND(AVG(Total), 2) AS avg_invoice_value
FROM Invoice;

-- Q2: Which music genres make the most money?
WITH genre_revenue AS (
    SELECT
        g.Name AS genre,
        ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue,
        COUNT(DISTINCT i.CustomerId) AS unique_customers,
        COUNT(il.TrackId) AS tracks_sold
    FROM InvoiceLine il
    JOIN Invoice i  ON il.InvoiceId = i.InvoiceId
    JOIN Track t  ON il.TrackId = t.TrackId
    JOIN Genre g  ON t.GenreId = g.GenreId
    GROUP BY g.Name
)
SELECT TOP 10
    genre,
    revenue,
    unique_customers,
    tracks_sold,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 1) AS pct_of_total_revenue
FROM genre_revenue
ORDER BY revenue DESC;

-- Q3: Who are our highest-value customers in the last 90 days?
WITH date_bounds AS (
    -- Dynamically find the 90-day window based on the latest invoice
    SELECT
        MAX(InvoiceDate) AS latest_date,
        DATEADD(DAY, -90, MAX(InvoiceDate)) AS cutoff_date
    FROM Invoice
),
spend_in_window AS (
    SELECT
        c.FirstName + ' ' + c.LastName AS customer_name,
        c.Country,
        COUNT(DISTINCT i.InvoiceId) AS number_of_orders,
        ROUND(SUM(i.Total), 2) AS revenue_90d
    FROM Invoice i 
    JOIN Customer c  ON i.CustomerId = c.CustomerId
    CROSS JOIN date_bounds db
    WHERE i.InvoiceDate >= db.cutoff_date
    GROUP BY c.CustomerId, c.FirstName, c.LastName, c.Country
)
SELECT TOP 15
    RANK() OVER (ORDER BY revenue_90d DESC) AS customer_rank,
    customer_name,
    country,
    number_of_orders,
    revenue_90d
FROM spend_in_window
ORDER BY revenue_90d DESC;

-- Q4: Which artists keep customers coming back?
WITH purchases_per_artist_per_customer AS (
    -- Count how many distinct invoices each customer has for each artist
    SELECT
        ar.Name AS artist,
        i.CustomerId,
        COUNT(DISTINCT i.InvoiceId) AS invoice_count
    FROM InvoiceLine il
    JOIN Invoice i  ON il.InvoiceId = i.InvoiceId
    JOIN Track t  ON il.TrackId = t.TrackId
    JOIN Album al ON t.AlbumId = al.AlbumId
    JOIN Artist ar ON al.ArtistId = ar.ArtistId
    GROUP BY ar.ArtistId, ar.Name, i.CustomerId
),
artist_buyer_summary AS (
    SELECT
        artist,
        COUNT(*) AS total_buyers,
        SUM(CASE WHEN invoice_count >= 2 THEN 1 ELSE 0 END) AS repeat_buyers
    FROM purchases_per_artist_per_customer
    GROUP BY artist
)
SELECT TOP 15
    artist,
    total_buyers,
    repeat_buyers,
    ROUND(100.0 * repeat_buyers / total_buyers, 1) AS repeat_buyer_rate_pct
FROM artist_buyer_summary
WHERE total_buyers >= 5
ORDER BY repeat_buyer_rate_pct DESC;

-- Q5: Is revenue growing month over month? By how much?
WITH monthly_revenue AS (
    SELECT
        FORMAT(InvoiceDate, 'yyyy-MM') AS month,
        ROUND(SUM(Total), 2) AS revenue
    FROM Invoice
    GROUP BY FORMAT(InvoiceDate, 'yyyy-MM')
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(
        100.0
        * (revenue - LAG(revenue) OVER (ORDER BY month))
        / LAG(revenue) OVER (ORDER BY month),
        1
    ) AS mom_growth_pct,
    ROUND(SUM(revenue) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS cumulative_revenue
FROM monthly_revenue
ORDER BY month;

-- Q6: Which countries generate the most revenue — and how concentrated is it?
WITH revenue_by_country AS (
    SELECT
        c.Country,
        ROUND(SUM(i.Total), 2) AS revenue
    FROM Invoice i
    JOIN Customer c ON i.CustomerId = c.CustomerId
    GROUP BY c.Country
)
SELECT
    country,
    revenue,
    RANK() OVER (ORDER BY revenue DESC) AS country_rank,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 1) AS pct_of_total,
    ROUND(
        SUM(revenue) OVER (
            ORDER BY revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / SUM(revenue) OVER () * 100,
        1
    ) AS cumulative_pct
FROM revenue_by_country
ORDER BY revenue DESC;

-- Q7: Are all customers worth the same, or do a few drive most revenue?
WITH customer_lifetime_value AS (
    SELECT
        c.CustomerId,
        c.FirstName + ' ' + c.LastName AS customer_name,
        COUNT(DISTINCT i.InvoiceId) AS total_orders,
        ROUND(SUM(i.Total), 2) AS lifetime_revenue
    FROM Invoice i
    JOIN Customer c ON i.CustomerId = c.CustomerId
    GROUP BY c.CustomerId, c.FirstName, c.LastName
),
customers_with_decile AS (
    -- Assign each customer to a decile bucket (1 = lowest spenders, 10 = highest)
    SELECT
        customer_name,
        lifetime_revenue,
        NTILE(10) OVER (ORDER BY lifetime_revenue) AS decile
    FROM customer_lifetime_value
)
SELECT
    decile,
    COUNT(*) AS number_of_customers,
    ROUND(MIN(lifetime_revenue), 2) AS min_spend,
    ROUND(MAX(lifetime_revenue), 2) AS max_spend,
    ROUND(AVG(lifetime_revenue), 2) AS avg_spend,
    ROUND(SUM(lifetime_revenue), 2) AS total_revenue_from_decile
FROM customers_with_decile
GROUP BY decile
ORDER BY decile;

-- Q8: Which support reps are managing the most valuable customers?
WITH rep_performance AS (
    SELECT
        e.FirstName + ' ' + e.LastName AS rep_name,
        e.Title,
        COUNT(DISTINCT c.CustomerId)    AS customers_assigned,
        COUNT(DISTINCT i.InvoiceId) AS total_invoices,
        ROUND(SUM(i.Total), 2) AS total_revenue,
        ROUND(AVG(i.Total), 2) AS avg_invoice_value
    FROM Employee e
    JOIN Customer c ON e.EmployeeId = c.SupportRepId
    JOIN Invoice i ON c.CustomerId = i.CustomerId
    GROUP BY e.EmployeeId, e.FirstName, e.LastName, e.Title
)
SELECT
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    rep_name,
    customers_assigned,
    total_invoices,
    total_revenue,
    avg_invoice_value
FROM rep_performance
ORDER BY total_revenue DESC;