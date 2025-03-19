USE AdventureWorks2022;

WITH YearsCTE (TerritoryName, CategoryName, OrderMonth, OrderYear, TotalSales) AS (
    SELECT 
        te.Name AS TerritoryName,
        ca.Name AS CategoryName,
        MONTH(he.OrderDate) AS OrderMonth,
        YEAR(he.OrderDate) AS OrderYear,
        SUM(sa.LineTotal) AS TotalSales
    FROM Sales.SalesTerritory te
    INNER JOIN Sales.SalesOrderHeader he ON he.TerritoryID = te.TerritoryID
    INNER JOIN Sales.SalesOrderDetail sa ON sa.SalesOrderID = he.SalesOrderID
    INNER JOIN Production.Product pr ON pr.ProductID = sa.ProductID
    INNER JOIN Production.ProductSubcategory su ON su.ProductSubcategoryID = pr.ProductSubcategoryID
    INNER JOIN Production.ProductCategory ca ON su.ProductCategoryID = ca.ProductCategoryID
    GROUP BY te.Name, ca.Name, MONTH(he.OrderDate), YEAR(he.OrderDate)
),

QuartersCTE (OrderYear, TerritoryName, TotalSales, YearQuarter) AS (
    SELECT 
        OrderYear,
        TerritoryName,
        SUM(TotalSales) AS TotalSales,
        CASE
            WHEN OrderMonth BETWEEN 1 AND 3 THEN 1
            WHEN OrderMonth BETWEEN 4 AND 6 THEN 2
            WHEN OrderMonth BETWEEN 7 AND 9 THEN 3
            WHEN OrderMonth BETWEEN 10 AND 12 THEN 4
        END AS YearQuarter
    FROM YearsCTE
    GROUP BY OrderYear, TerritoryName, 
        CASE
            WHEN OrderMonth BETWEEN 1 AND 3 THEN 1
            WHEN OrderMonth BETWEEN 4 AND 6 THEN 2
            WHEN OrderMonth BETWEEN 7 AND 9 THEN 3
            WHEN OrderMonth BETWEEN 10 AND 12 THEN 4
        END
),

CategoryQuartersCTE (OrderYear, CategoryName, TerritoryName, TotalSales, YearQuarter) AS (
    SELECT 
        OrderYear,
        CategoryName,
        TerritoryName,
        SUM(TotalSales) AS TotalSales,
        CASE
            WHEN OrderMonth BETWEEN 1 AND 3 THEN 1
            WHEN OrderMonth BETWEEN 4 AND 6 THEN 2
            WHEN OrderMonth BETWEEN 7 AND 9 THEN 3
            WHEN OrderMonth BETWEEN 10 AND 12 THEN 4
        END AS YearQuarter
    FROM YearsCTE
    GROUP BY OrderYear, CategoryName, TerritoryName, 
        CASE
            WHEN OrderMonth BETWEEN 1 AND 3 THEN 1
            WHEN OrderMonth BETWEEN 4 AND 6 THEN 2
            WHEN OrderMonth BETWEEN 7 AND 9 THEN 3
            WHEN OrderMonth BETWEEN 10 AND 12 THEN 4
        END
),

ProductsCTE (ProductID, Category, ProductName, TerritoryName, Year, TotalQuarter, YearQuarter) AS (
    SELECT 
        sa.ProductID,
        ca.Name AS Category,
        pr.Name AS ProductName,
        te.Name AS TerritoryName,
        YEAR(he.OrderDate) AS Year,
        SUM(sa.LineTotal) AS TotalQuarter,
        CASE
            WHEN MONTH(he.OrderDate) BETWEEN 1 AND 3 THEN 1
            WHEN MONTH(he.OrderDate) BETWEEN 4 AND 6 THEN 2
            WHEN MONTH(he.OrderDate) BETWEEN 7 AND 9 THEN 3
            WHEN MONTH(he.OrderDate) BETWEEN 10 AND 12 THEN 4
        END AS YearQuarter
    FROM Sales.SalesOrderDetail sa
    INNER JOIN Production.Product pr ON pr.ProductID = sa.ProductID
    INNER JOIN Sales.SalesOrderHeader he ON he.SalesOrderID = sa.SalesOrderID
    INNER JOIN Sales.SalesTerritory te ON te.TerritoryID = he.TerritoryID
    INNER JOIN Production.ProductSubcategory su ON su.ProductSubcategoryID = pr.ProductSubcategoryID
    INNER JOIN Production.ProductCategory ca ON su.ProductCategoryID = ca.ProductCategoryID
    GROUP BY sa.ProductID, ca.Name, pr.Name, te.Name, YEAR(he.OrderDate),
        CASE
            WHEN MONTH(he.OrderDate) BETWEEN 1 AND 3 THEN 1
            WHEN MONTH(he.OrderDate) BETWEEN 4 AND 6 THEN 2
            WHEN MONTH(he.OrderDate) BETWEEN 7 AND 9 THEN 3
            WHEN MONTH(he.OrderDate) BETWEEN 10 AND 12 THEN 4
        END
),

PercentageCTE AS (
    SELECT 
        pr.ProductName,
        pr.Category,
        SUM(pr.TotalQuarter) OVER(PARTITION BY pr.TerritoryName, pr.ProductName) AS TotalSalesProduct,
        pr.TerritoryName,
        SUM(pr.TotalQuarter) OVER(PARTITION BY pr.TerritoryName, pr.Category) AS CategoryTotal,
        pr.YearQuarter,
		pr.TotalQuarter AS CurrentQuarterSales,
        CASE 
            WHEN SUM(pr.TotalQuarter) OVER(PARTITION BY pr.TerritoryName, pr.Category) = 0 THEN 0 
            ELSE (SUM(pr.TotalQuarter) OVER(PARTITION BY pr.TerritoryName, pr.ProductName) * 100.0) 
                 / NULLIF(SUM(pr.TotalQuarter) OVER(PARTITION BY pr.TerritoryName, pr.Category), 0) 
        END AS PercentageOfTotalSalesInRegion,
        CASE 
            WHEN SUM(pr.TotalQuarter) OVER(PARTITION BY pr.TerritoryName) = 0 THEN 0 
            ELSE (SUM(pr.TotalQuarter) OVER(PARTITION BY pr.TerritoryName, pr.ProductName) * 100.0) 
                 / NULLIF(SUM(pr.TotalQuarter) OVER(PARTITION BY pr.TerritoryName), 0) 
        END AS PercentageOfCategoryInRegion

    FROM ProductsCTE pr
    LEFT JOIN QuartersCTE qu 
        ON qu.TerritoryName = pr.TerritoryName 
        AND qu.OrderYear = pr.Year 
        AND qu.YearQuarter = pr.YearQuarter
    LEFT JOIN CategoryQuartersCTE ca 
        ON ca.TerritoryName = pr.TerritoryName 
        AND ca.OrderYear = pr.Year 
        AND ca.YearQuarter = pr.YearQuarter 
        AND ca.CategoryName = pr.Category
)

SELECT DISTINCT TOP 20 *
FROM PercentageCTE 
ORDER BY PercentageOfTotalSalesInRegion DESC