-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 8_Functions.sql
-- Description: All 5 functions
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

-- ============================================================
-- FUNCTION 1: fn_CalculateNetWorth
-- Returns sum of all account balances minus remaining debts
-- ============================================================
CREATE OR REPLACE FUNCTION fn_CalculateNetWorth (
    p_userID IN NUMBER
) RETURN NUMBER
AS
    v_total_assets  NUMBER(15,2) := 0;
    v_total_debts   NUMBER(15,2) := 0;
    v_net_worth     NUMBER(15,2);
BEGIN
    -- Sum all active account balances
    SELECT NVL(SUM(CurrentBalance), 0)
    INTO   v_total_assets
    FROM   Account
    WHERE  UserID = p_userID
           AND IsActive = 1;

    -- Sum all remaining debt balances
    SELECT NVL(SUM(RemainingBalance), 0)
    INTO   v_total_debts
    FROM   Debt
    WHERE  UserID = p_userID;

    v_net_worth := v_total_assets - v_total_debts;

    RETURN v_net_worth;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in fn_CalculateNetWorth: ' || SQLERRM);
        RETURN NULL;
END fn_CalculateNetWorth;
/

-- Test: SELECT fn_CalculateNetWorth(1) AS NetWorth FROM DUAL;
-- Test: SELECT u.Name, fn_CalculateNetWorth(u.UserID) AS NetWorth
--       FROM "User" u ORDER BY 2 DESC;


-- ============================================================
-- FUNCTION 2: fn_GetSavingsRate
-- Returns (TotalIncome - TotalExpenses) / TotalIncome * 100
-- Handles division by zero gracefully
-- ============================================================
CREATE OR REPLACE FUNCTION fn_GetSavingsRate (
    p_userID IN NUMBER,
    p_month  IN DATE
) RETURN NUMBER
AS
    v_income    NUMBER(15,2) := 0;
    v_expenses  NUMBER(15,2) := 0;
    v_rate      NUMBER(5,2);
    v_start     DATE;
    v_end       DATE;
BEGIN
    v_start := TRUNC(p_month, 'MM');
    v_end   := LAST_DAY(p_month);

    -- Calculate total income for the month
    SELECT NVL(SUM(t.Amount), 0)
    INTO   v_income
    FROM   "Transaction" t
    JOIN   Account a ON t.AccountID = a.AccountID
    WHERE  a.UserID = p_userID
           AND t.TransactionType = 'Income'
           AND t.TransactionDate >= v_start
           AND t.TransactionDate <= v_end + 1;

    -- Calculate total expenses for the month
    SELECT NVL(SUM(t.Amount), 0)
    INTO   v_expenses
    FROM   "Transaction" t
    JOIN   Account a ON t.AccountID = a.AccountID
    WHERE  a.UserID = p_userID
           AND t.TransactionType = 'Expense'
           AND t.TransactionDate >= v_start
           AND t.TransactionDate <= v_end + 1;

    -- Handle division by zero
    IF v_income = 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: No income recorded for this period');
        RETURN 0;
    END IF;

    v_rate := ROUND((v_income - v_expenses) / v_income * 100, 2);
    RETURN v_rate;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN ZERO_DIVIDE THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: Division by zero in savings rate');
        RETURN 0;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in fn_GetSavingsRate: ' || SQLERRM);
        RETURN NULL;
END fn_GetSavingsRate;
/

-- Test: SELECT fn_GetSavingsRate(1, TO_DATE('2026-04-01','YYYY-MM-DD')) FROM DUAL;


-- ============================================================
-- FUNCTION 3: fn_CheckSufficientBalance
-- Returns 1 (TRUE) if account has enough balance, 0 (FALSE) otherwise
-- Oracle doesn't support BOOLEAN return in SQL, so using NUMBER(1)
-- ============================================================
CREATE OR REPLACE FUNCTION fn_CheckSufficientBalance (
    p_accountID IN NUMBER,
    p_amount    IN NUMBER
) RETURN NUMBER  -- 1 = TRUE, 0 = FALSE
AS
    v_balance       NUMBER(15,2);
    v_account_type  VARCHAR2(20);
BEGIN
    SELECT CurrentBalance, AccountType
    INTO   v_balance, v_account_type
    FROM   Account
    WHERE  AccountID = p_accountID
           AND IsActive = 1;

    -- Credit cards can go negative
    IF v_account_type = 'CreditCard' THEN
        RETURN 1;
    END IF;

    -- Check if balance covers the amount
    IF v_balance >= p_amount THEN
        RETURN 1;  -- Sufficient
    ELSE
        RETURN 0;  -- Insufficient
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Account #' || p_accountID || ' not found or inactive');
        RETURN 0;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in fn_CheckSufficientBalance: ' || SQLERRM);
        RETURN 0;
END fn_CheckSufficientBalance;
/

-- Test: SELECT fn_CheckSufficientBalance(1, 5000) AS HasFunds FROM DUAL;
-- Test: SELECT fn_CheckSufficientBalance(1, 999999) AS HasFunds FROM DUAL;


-- ============================================================
-- FUNCTION 4: fn_CalculateEMI
-- Standard EMI formula: P x r x (1+r)^n / ((1+r)^n - 1)
-- where r = annual_rate / 12 / 100
-- ============================================================
CREATE OR REPLACE FUNCTION fn_CalculateEMI (
    p_principal   IN NUMBER,
    p_annualRate  IN NUMBER,
    p_months      IN NUMBER
) RETURN NUMBER
AS
    v_monthly_rate  NUMBER(15,10);
    v_emi           NUMBER(15,2);
    v_power         NUMBER(15,10);
BEGIN
    -- Validate inputs
    IF p_principal <= 0 OR p_months <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Principal and months must be positive');
        RETURN 0;
    END IF;

    -- Handle zero interest rate (simple division)
    IF p_annualRate = 0 THEN
        RETURN ROUND(p_principal / p_months, 2);
    END IF;

    -- Calculate monthly interest rate
    v_monthly_rate := p_annualRate / 12 / 100;

    -- Calculate (1 + r)^n
    v_power := POWER(1 + v_monthly_rate, p_months);

    -- EMI = P × r × (1+r)^n / ((1+r)^n - 1)
    v_emi := p_principal * v_monthly_rate * v_power / (v_power - 1);

    RETURN ROUND(v_emi, 2);

EXCEPTION
    WHEN ZERO_DIVIDE THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Division by zero in EMI calculation');
        RETURN 0;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in fn_CalculateEMI: ' || SQLERRM);
        RETURN NULL;
END fn_CalculateEMI;
/

-- Test: SELECT fn_CalculateEMI(500000, 8.5, 36) AS EMI FROM DUAL;
-- Expected: ~15,769 (approx)
-- Test: SELECT fn_CalculateEMI(800000, 9.0, 60) AS EMI FROM DUAL;


-- ============================================================
-- FUNCTION 5: fn_GetCategoryTotal
-- Sums transaction amounts for a category within date range
-- Includes child categories in the total
-- ============================================================
CREATE OR REPLACE FUNCTION fn_GetCategoryTotal (
    p_categoryID IN NUMBER,
    p_startDate  IN DATE,
    p_endDate    IN DATE
) RETURN NUMBER
AS
    v_total     NUMBER(15,2) := 0;
    e_bad_range EXCEPTION;
BEGIN
    -- Validate date range
    IF p_startDate > p_endDate THEN
        RAISE e_bad_range;
    END IF;

    -- Sum transactions for this category AND its child categories
    SELECT NVL(SUM(t.Amount), 0)
    INTO   v_total
    FROM   "Transaction" t
    WHERE  (t.CategoryID = p_categoryID
            OR t.CategoryID IN (
                SELECT CategoryID FROM Category
                WHERE  ParentCategoryID = p_categoryID
            ))
           AND t.TransactionDate >= p_startDate
           AND t.TransactionDate <= p_endDate + 1
           AND t.TransactionType = 'Expense';

    RETURN v_total;

EXCEPTION
    WHEN e_bad_range THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Start date must be before end date');
        RETURN 0;
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in fn_GetCategoryTotal: ' || SQLERRM);
        RETURN NULL;
END fn_GetCategoryTotal;
/

-- Test: SELECT fn_GetCategoryTotal(4, TO_DATE('2026-04-01','YYYY-MM-DD'),
--                                     TO_DATE('2026-04-30','YYYY-MM-DD')) AS FoodTotal
--       FROM DUAL;
-- This should return total Food + Groceries + Restaurants for April 2026


-- ============================================================
-- VERIFICATION: Test all functions together
-- ============================================================
SELECT u.Name,
       fn_CalculateNetWorth(u.UserID)                                    AS NetWorth,
       fn_GetSavingsRate(u.UserID, TO_DATE('2026-04-01','YYYY-MM-DD'))   AS SavingsRate,
       fn_CalculateEMI(500000, 8.5, 36)                                  AS SampleEMI
FROM   "User" u
ORDER  BY NetWorth DESC;
