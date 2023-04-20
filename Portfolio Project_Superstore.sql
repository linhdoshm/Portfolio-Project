SELECT * INTO Location
FROM
	(SELECT concat(Postal_Code, '-', ROW_NUMBER() OVER(PARTITION BY Postal_Code ORDER BY Postal_Code)) Loc_ID, *
	FROM
		(SELECT DISTINCT Country, City, State, Postal_Code
		FROM Superstore) l1) l2;

SELECT * INTO Product
FROM
	(SELECT DISTINCT Product_ID, Product_Name, Category, Sub_Category
    FROM Superstore) P;

SELECT * INTO Customer
FROM
	(SELECT DISTINCT Customer_ID, Customer_Name, Segment AS Customer_Type
    FROM Superstore) C;

SELECT * INTO Orders
FROM
	(SELECT DISTINCT Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID
    FROM Superstore) O;

SELECT * INTO OrderItem
FROM
	(SELECT DISTINCT Order_ID, Loc_ID, Product_ID, Sales, Quantity, Discount, Profit
    FROM
        (SELECT s.*, l.Loc_ID
        FROM Superstore s, [Location] l
        WHERE s.Country = l.Country
            AND s.City = l.City
            AND s.State = l.State
            AND s.Postal_Code = l.Postal_Code) t) I;

Create table RFM (
	R int,
    F int,
    M int,
	Customer_Segment nvarchar(50)
);

INSERT INTO RFM (R, F, M, Customer_Segment)
SELECT r.val, f.val, m.val,
	CASE
		WHEN r.val = 1 THEN 'Lost'
		WHEN r.val = 2 THEN 'Potential churn'
		WHEN r.val IN (3,4) AND f.val IN (3,4) AND m.val IN (3, 4) THEN 'Loyal Customers'
		WHEN m.val = 4 AND f.val in (1,2) THEN 'Big Spenders'
		WHEN r.val = 4 AND f.val < 3 THEN 'New Customers'
	ELSE 'Promising'
	END
FROM (SELECT 1 AS val UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) AS r
CROSS JOIN (SELECT 1 AS val UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) AS f
CROSS JOIN (SELECT 1 AS val UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) AS m;

SELECT * FROM RFM

-- Customer Segment by RFM
CREATE OR ALTER VIEW Customer_Segmentation AS

With a AS
(SELECT c.*,
	DATEDIFF(day, MAX(o.Order_Date),
		(SELECT MAX(Order_Date) from Orders)) Recency,
	COUNT(distinct o.Order_ID) Frequency, sum(t.Sales) Monetory
		FROM Customer c, Orders o, OrderItem t
		WHERE c.Customer_ID = o.Customer_ID
			AND o.Order_ID = t.Order_ID
		GROUP BY c.Customer_ID, c.Customer_Name, c.Customer_Type),
b AS
(Select Customer_ID, Customer_Name, Customer_Type,
	NTILE(4) OVER(ORDER BY Recency DESC) R,
	NTILE(4) OVER(ORDER BY Frequency) F,
	NTILE(4) OVER(ORDER BY Monetory) M
FROM a)

	SELECT b.Customer_ID, b.Customer_Name, b.Customer_Type, RFM.Customer_Segment
	FROM b, RFM
	WHERE b.R = RFM.R
	AND b.F = RFM.F
	AND b.M = RFM.M;

Select * from Customer_Segmentation;