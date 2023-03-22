-- 1. Commission Budget for 2022 --
    -- 1.1. Create view to determine Occupancy of each mall
    -- Giả định: Occ các dự án mới: VMM 85%, VCP 90% 

CREATE OR ALTER VIEW Mall_Occ AS
Select
    Mall,
    round(sum(Area),2) as NLA,
    round(sum(Leased_Area),2) as Leased_Area,
    CASE
        WHEN Mall in 
                (SELECT Mall_name
                FROM Mall
                WHERE
                    Mall_status = N'Dự án mới')
                    AND Mall LIKE 'Vincom Plaza%'
            THEN 0.9
        WHEN Mall in 
                (SELECT Mall_name
                FROM Mall
                WHERE
                    Mall_status = N'Dự án mới')
                    AND Mall LIKE '%Mega Mall%'
            THEN 0.85
        ELSE sum(Leased_Area)/sum(Area)
        END AS Occ
FROM Zre04a1
GROUP BY Mall
;

    -- 1.2. Caculate Commission for each position
    -- Giả định: 1) Tất cả là 'Khách lẻ'; 2) GĐKD được hưởng Commission trên tất cả deal trừ deal do Nhóm 1 thực hiện
CREATE OR ALTER VIEW Commission AS
WITH 
-- Determine B1_Commission_rate for PTGĐ
subb1_PTGD AS
    (SELECT *
    FROM Commission_Structure_B1
    WHERE
        Tenant_type = N'Khách lẻ'
        AND position like N'Phó%'),
-- Determine B1_Commission_rate for GĐKD
subb1_GDKD AS
    (SELECT *
    FROM Commission_Structure_B1
    WHERE
        Tenant_type = N'Khách lẻ'
        AND position like N'Giám%'),
-- Determine B1_Commission_rate for TPKD
subb1_TPKD AS
    (SELECT *
    FROM Commission_Structure_B1
    WHERE
        Tenant_type = N'Khách lẻ'
        AND position = N'Trưởng phòng Kinh doanh'),
-- Determine B1_Commission_rate for CVKD
subb1_CVKD AS
    (SELECT *
    FROM Commission_Structure_B1
    WHERE
        Tenant_type = N'Khách lẻ'
        AND position = N'Chuyên viên Kinh doanh'),    
-- Determine B1_Commission_rate for HTKD
subb1_admin AS
    (SELECT *
    FROM Commission_Structure_B1
    WHERE
        Tenant_type = N'Khách lẻ'
        AND position = N'Hỗ trợ Kinh doanh'),
-- Determine B1_Commission_rate for QTDA & MKT
subb1_MKT_QTDA AS
    (SELECT
        Mall_status,
        Mall_group,
        SUM(Commission_rate) AS Commission_rate
    FROM Commission_Structure_B1
    WHERE
        Tenant_type = N'Khách lẻ'
        AND (position = N'Quản trị dự án'
        OR position = 'Marketing')
    GROUP BY
        Mall_status,
        Tenant_type,
        Mall_group),

-- Determine Mall_status, Mall_group_for_Commission, Occ, Monthly Revenue, B2_Commission_rate for each deal
KPIs AS
    (SELECT
        KPI.ID,
        KPI.Sales_Team,
        KPI.Mall,
        Mall2.Mall_status,
        Mall2.Mall_group_for_Commission,
        Mall_Occ.Occ,
        KPI.RO,
        KPI.Lease_Area,
        KPI.Rental,
        KPI.Service_fee,
        KPI.Start_date,
        round((KPI.Rental + KPI.Service_fee)*KPI.Lease_Area,0) AS Monthly_Revenue,
        b2.Commission_rate AS B2_commission_rate
    FROM 
        ((KPI
        LEFT JOIN
                (SELECT Site_Code, Mall_Name, Mall_status, Mall_group_for_Commission
                FROM Mall
                WHERE FC_Mall_Name not in ('BT2')) AS Mall2
            ON KPI.Mall = Mall2.Site_Code)
        LEFT JOIN Mall_occ ON Mall2.Mall_Name = Mall_occ.Mall)
        LEFT JOIN Commission_Structure_B2 as b2
            ON 
                Mall2.Mall_group_for_Commission = b2.Mall_group 
                AND Mall_occ.Occ >= b2.Min_Occ
                AND Mall_Occ.Occ < b2.Max_Occ)

-- Caculate Commission for each position with each deal
    SELECT 
        KPIs.*,
        Monthly_Revenue*B2_commission_rate*subb1_PTGD.Commission_rate AS PTGD_Commission,
        CASE
            WHEN Sales_Team like 'Nhóm 1%' then 0
            ELSE Monthly_Revenue*B2_commission_rate*subb1_GDKD.Commission_rate 
            END AS GDKD_Commission,
        Monthly_Revenue*B2_commission_rate*subb1_TPKD.Commission_rate AS TPKD_Commission,
        Monthly_Revenue*B2_commission_rate*subb1_CVKD.Commission_rate AS CVKD_Commission,
        Monthly_Revenue*B2_commission_rate*subb1_admin.Commission_rate AS Admin_Commission,
        Monthly_Revenue*B2_commission_rate*subb1_MKT_QTDA.Commission_rate AS MKT_QTDA_Commission
    FROM 
        ((((((KPIs
        LEFT JOIN subb1_TPKD 
            ON KPIs.Mall_status = subb1_TPKD.Mall_status AND KPIs.Mall_group_for_Commission = subb1_TPKD.Mall_group)
        LEFT JOIN subb1_CVKD 
            ON KPIs.Mall_status = subb1_CVKD.Mall_status AND KPIs.Mall_group_for_Commission = subb1_CVKD.Mall_group)
        LEFT JOIN subb1_admin 
            ON KPIs.Mall_status = subb1_admin.Mall_status AND KPIs.Mall_group_for_Commission = subb1_admin.Mall_group)
        LEFT JOIN subb1_MKT_QTDA
            ON KPIs.Mall_status = subb1_MKT_QTDA.Mall_status AND KPIs.Mall_group_for_Commission = subb1_MKT_QTDA.Mall_group)
        LEFT JOIN subb1_PTGD
            ON KPIs.Mall_status = subb1_PTGD.Mall_status AND KPIs.Mall_group_for_Commission = subb1_PTGD.Mall_group)
        LEFT JOIN subb1_GDKD
            ON KPIs.Mall_status = subb1_GDKD.Mall_status AND KPIs.Mall_group_for_Commission = subb1_GDKD.Mall_group)
;

-- Caculate Commission for each position
SELECT
    round(sum(PTGD_Commission),0) AS PTGD_Commission,
    round(sum(GDKD_Commission),0) AS GDKD_Commission,
    round(sum(TPKD_Commission),0) AS TPKD_Commission,
    round(sum(CVKD_Commission),0) AS CVKD_Commission,
    round(sum(Admin_Commission),0) AS Admin_Commission,
    round(sum(MKT_QTDA_Commission),0) AS MKT_QTDA_Commission
FROM Commission
;

-- 2. Sales Performance
    -- Create view to caculate Area & Revenue
CREATE OR ALTER VIEW KPI_full AS
SELECT *,
       Lease_Area * (Rental + Service_fee) AS Monthly_Revenue,
       Lease_Area * (Rental + Service_fee) * (12-MONTH(Start_date))+1+CAST((1-DAY(Start_date)) as float)/DAY(EOMONTH(Start_date, 0)) as Yearly_Revenue
FROM KPI
;
CREATE OR ALTER VIEW Completed_full AS
SELECT *,
       Lease_Area * (Rental + Service_fee) AS Monthly_Revenue,
       Lease_Area * (Rental + Service_fee) * (12-MONTH(Start_date))+1+CAST((1-DAY(Start_date)) as float)/DAY(EOMONTH(Start_date, 0)) as Yearly_Revenue
FROM Completed
;

-- Group by team
WITH 
a AS
    (SELECT Sales_Team,
            sum(Lease_Area) AS Area_Completed,
            sum(Yearly_revenue) AS Yearly_Revenue_Completed
    FROM Completed_full
    GROUP BY Sales_Team),
b AS
    (SELECT Sales_Team,
            sum(Lease_Area) AS Area_KPI,
            sum(Yearly_revenue) as Yearly_Revenue_KPI
    FROM KPI_full
    GROUP BY Sales_Team)

-- Inner Join KPI & Completed
    SELECT
        a.Sales_Team,
        b.Area_KPI,
        a.Area_Completed,
        a.Area_Completed/b.Area_KPI AS '% Completed Area',
        b.Yearly_Revenue_KPI,
        a.Yearly_Revenue_Completed,
        a.Yearly_Revenue_Completed/b.Yearly_Revenue_KPI AS '% Completed Revenue'
    FROM a, b
    WHERE a.Sales_Team = b.Sales_Team
    ORDER BY '% Completed Revenue' DESC
;