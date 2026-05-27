-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 5_Queries.sql
-- Description: All 10+ SELECT queries with comments
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

-- ============================================================
-- QUERY 1: Multi-table JOIN
-- Show each user's accounts with total transaction count
-- and total spent per account
-- ============================================================
SELECT u.Name                                              AS UserName,
       a.AccountName,
       a.AccountType,
       a.CurrentBalance,
       COUNT(t.TransactionID)                              AS TxnCount,
       NVL(SUM(CASE WHEN t.TransactionType = 'Expense'
                     THEN t.Amount ELSE 0 END), 0)         AS TotalSpent
FROM   "User" u
JOIN   Account a          ON u.UserID    = a.UserID
LEFT JOIN "Transaction" t ON a.AccountID = t.AccountID
GROUP  BY u.Name, a.AccountName, a.AccountType, a.CurrentBalance
ORDER  BY u.Name, TotalSpent DESC;
-- MySQL: Use IFNULL instead of NVL


-- ============================================================
-- QUERY 2: Complex JOIN with Budget comparison
-- For each category, show budgeted amount vs actual spending
-- for the current month
-- ============================================================
SELECT c.CategoryName,
       b.BudgetAmount,
       NVL(SUM(t.Amount), 0)                              AS ActualSpent,
       b.BudgetAmount - NVL(SUM(t.Amount), 0)             AS RemainingBudget,
       ROUND(NVL(SUM(t.Amount), 0) / b.BudgetAmount * 100, 1) AS PercentUsed
FROM   Budget b
JOIN   Category c          ON b.CategoryID = c.CategoryID
LEFT JOIN "Transaction" t  ON t.CategoryID = c.CategoryID
                           AND t.TransactionType = 'Expense'
                           AND EXTRACT(MONTH FROM t.TransactionDate) = EXTRACT(MONTH FROM SYSDATE)
                           AND EXTRACT(YEAR  FROM t.TransactionDate) = EXTRACT(YEAR  FROM SYSDATE)
WHERE  b.UserID = 1
GROUP  BY c.CategoryName, b.BudgetAmount
ORDER  BY PercentUsed DESC;


-- ============================================================
-- QUERY 3: Subquery
-- Find users whose total spending exceeds the average
-- across all users
-- ============================================================
SELECT u.Name,
       user_totals.TotalSpent
FROM   "User" u
JOIN   (
         SELECT a.UserID,
                SUM(t.Amount) AS TotalSpent
         FROM   Account a
         JOIN   "Transaction" t ON a.AccountID = t.AccountID
         WHERE  t.TransactionType = 'Expense'
         GROUP  BY a.UserID
       ) user_totals ON u.UserID = user_totals.UserID
WHERE  user_totals.TotalSpent > (
         SELECT AVG(sub.TotalSpent)
         FROM   (
                  SELECT SUM(t2.Amount) AS TotalSpent
                  FROM   Account a2
                  JOIN   "Transaction" t2 ON a2.AccountID = t2.AccountID
                  WHERE  t2.TransactionType = 'Expense'
                  GROUP  BY a2.UserID
                ) sub
       )
ORDER  BY user_totals.TotalSpent DESC;


-- ============================================================
-- QUERY 4: Correlated Subquery
-- For each account, find the transaction with the highest amount
-- ============================================================
SELECT a.AccountName,
       t.Description,
       t.Amount,
       t.TransactionDate,
       t.TransactionType
FROM   "Transaction" t
JOIN   Account a ON t.AccountID = a.AccountID
WHERE  t.Amount = (
         SELECT MAX(t2.Amount)
         FROM   "Transaction" t2
         WHERE  t2.AccountID = t.AccountID
       )
ORDER  BY t.Amount DESC;


-- ============================================================
-- QUERY 5: Aggregate with GROUP BY & HAVING
-- Show categories where total monthly spending exceeds
-- the budget limit
-- ============================================================
SELECT c.CategoryName,
       b.BudgetAmount,
       SUM(t.Amount)                                       AS TotalSpent,
       SUM(t.Amount) - b.BudgetAmount                     AS OverBudget
FROM   "Transaction" t
JOIN   Category c ON t.CategoryID = c.CategoryID
JOIN   Budget b   ON b.CategoryID = c.CategoryID
WHERE  t.TransactionType = 'Expense'
       AND EXTRACT(MONTH FROM t.TransactionDate) = EXTRACT(MONTH FROM SYSDATE)
       AND EXTRACT(YEAR  FROM t.TransactionDate) = EXTRACT(YEAR  FROM SYSDATE)
GROUP  BY c.CategoryName, b.BudgetAmount
HAVING SUM(t.Amount) > b.BudgetAmount
ORDER  BY OverBudget DESC;


-- ============================================================
-- QUERY 6: Date-range analysis
-- Monthly income vs expense summary for User 1
-- over the last 6 months
-- ============================================================
SELECT TO_CHAR(t.TransactionDate, 'YYYY-MM')              AS Month,
       SUM(CASE WHEN t.TransactionType = 'Income'
                THEN t.Amount ELSE 0 END)                  AS TotalIncome,
       SUM(CASE WHEN t.TransactionType = 'Expense'
                THEN t.Amount ELSE 0 END)                  AS TotalExpenses,
       SUM(CASE WHEN t.TransactionType = 'Income'
                THEN t.Amount ELSE 0 END)
     - SUM(CASE WHEN t.TransactionType = 'Expense'
                THEN t.Amount ELSE 0 END)                  AS NetSavings
FROM   "Transaction" t
JOIN   Account a ON t.AccountID = a.AccountID
WHERE  a.UserID = 1
       AND t.TransactionDate >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -6)
GROUP  BY TO_CHAR(t.TransactionDate, 'YYYY-MM')
ORDER  BY Month;
-- MySQL: DATE_FORMAT(t.TransactionDate, '%Y-%m')
--        DATE_SUB(CURDATE(), INTERVAL 6 MONTH)


-- ============================================================
-- QUERY 7: Hierarchical query
-- Show categories with their parent category names (self-join)
-- ============================================================
SELECT child.CategoryID,
       child.CategoryName                                  AS SubCategory,
       NVL(parent.CategoryName, '-- Top Level --')         AS ParentCategory,
       child.CategoryType
FROM   Category child
LEFT JOIN Category parent ON child.ParentCategoryID = parent.CategoryID
ORDER  BY NVL(parent.CategoryName, child.CategoryName),
          child.CategoryName;

-- Alternative: Oracle CONNECT BY hierarchical query
SELECT LPAD(' ', 2 * (LEVEL - 1)) || CategoryName         AS CategoryHierarchy,
       CategoryType,
       LEVEL                                               AS DepthLevel
FROM   Category
START WITH ParentCategoryID IS NULL
CONNECT BY PRIOR CategoryID = ParentCategoryID
ORDER SIBLINGS BY CategoryName;


-- ============================================================
-- QUERY 8: Net worth calculation
-- Sum all account balances minus remaining debt for each user
-- ============================================================
SELECT u.Name,
       NVL(acct.TotalBalance, 0)                           AS TotalAssets,
       NVL(debt.TotalDebt, 0)                              AS TotalLiabilities,
       NVL(acct.TotalBalance, 0) - NVL(debt.TotalDebt, 0) AS NetWorth
FROM   "User" u
LEFT JOIN (
         SELECT UserID, SUM(CurrentBalance) AS TotalBalance
         FROM   Account
         WHERE  IsActive = 1
         GROUP  BY UserID
       ) acct ON u.UserID = acct.UserID
LEFT JOIN (
         SELECT UserID, SUM(RemainingBalance) AS TotalDebt
         FROM   Debt
         GROUP  BY UserID
       ) debt ON u.UserID = debt.UserID
ORDER  BY NetWorth DESC;


-- ============================================================
-- QUERY 9: Top-N query
-- Top 5 expense categories by total amount
-- ============================================================
SELECT CategoryName,
       TotalSpent,
       TxnCount
FROM (
    SELECT c.CategoryName,
           SUM(t.Amount)           AS TotalSpent,
           COUNT(t.TransactionID)  AS TxnCount
    FROM   "Transaction" t
    JOIN   Category c ON t.CategoryID = c.CategoryID
    WHERE  t.TransactionType = 'Expense'
    GROUP  BY c.CategoryName
    ORDER  BY TotalSpent DESC
)
WHERE ROWNUM <= 5;
-- MySQL: Use LIMIT 5 instead of ROWNUM
-- PostgreSQL: Use FETCH FIRST 5 ROWS ONLY


-- ============================================================
-- QUERY 10: Transaction frequency analysis
-- Number of transactions per day of the week
-- ============================================================
SELECT TO_CHAR(TransactionDate, 'Day')                     AS DayOfWeek,
       COUNT(*)                                            AS TxnCount,
       SUM(Amount)                                         AS TotalAmount,
       ROUND(AVG(Amount), 2)                               AS AvgAmount
FROM   "Transaction"
GROUP  BY TO_CHAR(TransactionDate, 'Day'),
          TO_CHAR(TransactionDate, 'D')
ORDER  BY TO_CHAR(TransactionDate, 'D');
-- MySQL: DAYNAME(TransactionDate), DAYOFWEEK(TransactionDate)


-- ============================================================
-- QUERY 11 (BONUS): Account balance reconciliation
-- Compare stored balance vs calculated balance from transactions
-- ============================================================
SELECT a.AccountName,
       a.CurrentBalance                                    AS StoredBalance,
       NVL(SUM(CASE WHEN t.TransactionType = 'Income'
                     THEN t.Amount
                     WHEN t.TransactionType = 'Expense'
                     THEN -t.Amount
                     ELSE 0 END), 0)                       AS CalculatedBalance,
       a.CurrentBalance -
       NVL(SUM(CASE WHEN t.TransactionType = 'Income'
                     THEN t.Amount
                     WHEN t.TransactionType = 'Expense'
                     THEN -t.Amount
                     ELSE 0 END), 0)                       AS Discrepancy
FROM   Account a
LEFT JOIN "Transaction" t ON a.AccountID = t.AccountID
GROUP  BY a.AccountName, a.CurrentBalance
ORDER  BY ABS(a.CurrentBalance -
              NVL(SUM(CASE WHEN t.TransactionType = 'Income'
                           THEN t.Amount
                           WHEN t.TransactionType = 'Expense'
                           THEN -t.Amount
                           ELSE 0 END), 0)) DESC;


-- ============================================================
-- QUERY 12 (BONUS): Debt-to-income ratio per user
-- ============================================================
SELECT u.Name,
       NVL(inc.MonthlyIncome, 0)                           AS MonthlyIncome,
       NVL(d.TotalEMI, 0)                                 AS TotalMonthlyEMI,
       CASE WHEN NVL(inc.MonthlyIncome, 0) > 0
            THEN ROUND(NVL(d.TotalEMI, 0) / inc.MonthlyIncome * 100, 1)
            ELSE 0
       END                                                 AS DebtToIncomeRatio
FROM   "User" u
LEFT JOIN (
         SELECT a.UserID, SUM(t.Amount) AS MonthlyIncome
         FROM   Account a
         JOIN   "Transaction" t ON a.AccountID = t.AccountID
         WHERE  t.TransactionType = 'Income'
                AND EXTRACT(MONTH FROM t.TransactionDate) = EXTRACT(MONTH FROM SYSDATE)
         GROUP  BY a.UserID
       ) inc ON u.UserID = inc.UserID
LEFT JOIN (
         SELECT UserID, SUM(MonthlyEMI) AS TotalEMI
         FROM   Debt
         GROUP  BY UserID
       ) d ON u.UserID = d.UserID
ORDER  BY DebtToIncomeRatio DESC;
