-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 6_Views.sql
-- Description: All 5 CREATE VIEW statements
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

-- ============================================================
-- VIEW 1: vw_AccountSummary
-- Shows UserName, AccountName, AccountType, CurrentBalance,
-- and total transactions count per account
-- ============================================================
CREATE OR REPLACE VIEW vw_AccountSummary AS
SELECT u.UserID,
       u.Name                    AS UserName,
       a.AccountID,
       a.AccountName,
       a.AccountType,
       a.Currency,
       a.CurrentBalance,
       a.IsActive,
       COUNT(t.TransactionID)    AS TotalTransactions,
       NVL(SUM(CASE WHEN t.TransactionType = 'Income'
                     THEN t.Amount ELSE 0 END), 0)  AS TotalIncome,
       NVL(SUM(CASE WHEN t.TransactionType = 'Expense'
                     THEN t.Amount ELSE 0 END), 0)  AS TotalExpenses
FROM   "User" u
JOIN   Account a          ON u.UserID    = a.UserID
LEFT JOIN "Transaction" t ON a.AccountID = t.AccountID
GROUP  BY u.UserID, u.Name, a.AccountID, a.AccountName,
          a.AccountType, a.Currency, a.CurrentBalance, a.IsActive;

-- Test: SELECT * FROM vw_AccountSummary ORDER BY UserName;


-- ============================================================
-- VIEW 2: vw_MonthlyExpenseBreakdown
-- Shows Month, CategoryName, TotalSpent grouped by month
-- and category for expense analysis
-- ============================================================
CREATE OR REPLACE VIEW vw_MonthlyExpenseBreakdown AS
SELECT TO_CHAR(t.TransactionDate, 'YYYY-MM')    AS TransMonth,
       TO_CHAR(t.TransactionDate, 'Month YYYY') AS MonthLabel,
       c.CategoryID,
       c.CategoryName,
       NVL(p.CategoryName, c.CategoryName)       AS ParentCategory,
       COUNT(t.TransactionID)                    AS TxnCount,
       SUM(t.Amount)                             AS TotalSpent,
       ROUND(AVG(t.Amount), 2)                   AS AvgPerTransaction
FROM   "Transaction" t
JOIN   Category c       ON t.CategoryID = c.CategoryID
LEFT JOIN Category p    ON c.ParentCategoryID = p.CategoryID
WHERE  t.TransactionType = 'Expense'
GROUP  BY TO_CHAR(t.TransactionDate, 'YYYY-MM'),
          TO_CHAR(t.TransactionDate, 'Month YYYY'),
          c.CategoryID, c.CategoryName,
          NVL(p.CategoryName, c.CategoryName);

-- Test: SELECT * FROM vw_MonthlyExpenseBreakdown
--       WHERE TransMonth = '2026-04' ORDER BY TotalSpent DESC;


-- ============================================================
-- VIEW 3: vw_BudgetStatus
-- Shows CategoryName, BudgetAmount, ActualSpent,
-- RemainingBudget, and PercentUsed for current month
-- ============================================================
CREATE OR REPLACE VIEW vw_BudgetStatus AS
SELECT b.BudgetID,
       u.Name                                              AS UserName,
       c.CategoryName,
       b.BudgetAmount,
       b.Period,
       b.StartDate,
       b.EndDate,
       NVL(spent.ActualSpent, 0)                           AS ActualSpent,
       b.BudgetAmount - NVL(spent.ActualSpent, 0)          AS RemainingBudget,
       ROUND(NVL(spent.ActualSpent, 0) / b.BudgetAmount * 100, 1) AS PercentUsed,
       CASE
           WHEN NVL(spent.ActualSpent, 0) > b.BudgetAmount THEN 'OVER BUDGET'
           WHEN NVL(spent.ActualSpent, 0) > b.BudgetAmount * 0.9 THEN 'WARNING'
           WHEN NVL(spent.ActualSpent, 0) > b.BudgetAmount * 0.7 THEN 'ON TRACK'
           ELSE 'UNDER BUDGET'
       END                                                 AS BudgetStatus
FROM   Budget b
JOIN   "User" u     ON b.UserID     = u.UserID
JOIN   Category c   ON b.CategoryID = c.CategoryID
LEFT JOIN (
         -- Sum all expenses in this category AND its child categories
         SELECT b2.BudgetID,
                SUM(t.Amount) AS ActualSpent
         FROM   Budget b2
         JOIN   "Transaction" t ON (
                    t.CategoryID = b2.CategoryID
                    OR t.CategoryID IN (
                        SELECT cat.CategoryID
                        FROM   Category cat
                        WHERE  cat.ParentCategoryID = b2.CategoryID
                    )
                )
         JOIN   Account a ON t.AccountID = a.AccountID
                          AND a.UserID = b2.UserID
         WHERE  t.TransactionType = 'Expense'
                AND t.TransactionDate >= b2.StartDate
                AND t.TransactionDate <= b2.EndDate + 1
         GROUP  BY b2.BudgetID
       ) spent ON b.BudgetID = spent.BudgetID;

-- Test: SELECT * FROM vw_BudgetStatus ORDER BY PercentUsed DESC;


-- ============================================================
-- VIEW 4: vw_GoalProgress
-- Shows GoalName, TargetAmount, CurrentAmount,
-- PercentComplete, and DaysRemaining
-- ============================================================
CREATE OR REPLACE VIEW vw_GoalProgress AS
SELECT g.GoalID,
       u.Name                                              AS UserName,
       g.GoalName,
       g.TargetAmount,
       g.CurrentAmount,
       ROUND(g.CurrentAmount / g.TargetAmount * 100, 1)    AS PercentComplete,
       g.TargetDate,
       GREATEST(TRUNC(g.TargetDate) - TRUNC(SYSDATE), 0)  AS DaysRemaining,
       g.Status,
       CASE
           WHEN g.Status = 'Achieved'  THEN 'Completed!'
           WHEN g.Status = 'Cancelled' THEN 'Cancelled'
           WHEN g.CurrentAmount >= g.TargetAmount THEN 'Ready to Achieve'
           WHEN TRUNC(g.TargetDate) < TRUNC(SYSDATE) THEN 'Overdue'
           ELSE 'In Progress'
       END                                                 AS ProgressStatus,
       CASE
           WHEN g.Status = 'Active'
                AND TRUNC(g.TargetDate) > TRUNC(SYSDATE)
                AND (g.TargetAmount - g.CurrentAmount) > 0
           THEN ROUND(
                    (g.TargetAmount - g.CurrentAmount) /
                    GREATEST(MONTHS_BETWEEN(g.TargetDate, SYSDATE), 1),
                    2)
           ELSE 0
       END                                                 AS MonthlySavingsNeeded
FROM   Goal g
JOIN   "User" u ON g.UserID = u.UserID;

-- Test: SELECT * FROM vw_GoalProgress ORDER BY PercentComplete DESC;


-- ============================================================
-- VIEW 5: vw_TransactionHistory
-- Full transaction details with UserName, AccountName,
-- CategoryName joined in for complete view
-- ============================================================
CREATE OR REPLACE VIEW vw_TransactionHistory AS
SELECT t.TransactionID,
       u.Name                                              AS UserName,
       a.AccountName,
       a.AccountType,
       c.CategoryName,
       NVL(p.CategoryName, c.CategoryName)                 AS ParentCategory,
       t.Amount,
       t.TransactionDate,
       t.TransactionType,
       t.Description,
       t.PaymentMethod,
       CASE t.TransactionType
           WHEN 'Income'  THEN '+'
           WHEN 'Expense' THEN '-'
           ELSE '~'
       END || TO_CHAR(t.Amount, '99,99,999.00')            AS FormattedAmount
FROM   "Transaction" t
JOIN   Account a     ON t.AccountID  = a.AccountID
JOIN   "User" u      ON a.UserID     = u.UserID
JOIN   Category c    ON t.CategoryID = c.CategoryID
LEFT JOIN Category p ON c.ParentCategoryID = p.CategoryID;

-- Test: SELECT * FROM vw_TransactionHistory
--       WHERE UserName = 'Tanmay Agarwal'
--       ORDER BY TransactionDate DESC;


-- ============================================================
-- VERIFICATION
-- ============================================================
SELECT view_name FROM user_views ORDER BY view_name;
-- MySQL: SHOW FULL TABLES WHERE TABLE_TYPE LIKE 'VIEW';
