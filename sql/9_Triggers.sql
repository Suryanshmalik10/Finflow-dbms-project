-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 9_Triggers.sql
-- Description: All 8 triggers + AuditLog table
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

-- NOTE: AuditLog table is created in 3_DDL_CreateTables.sql
-- If running standalone, uncomment:
-- CREATE TABLE AuditLog (
--     LogID NUMBER(10) PRIMARY KEY,
--     TableName VARCHAR2(50) NOT NULL,
--     OperationType VARCHAR2(10) NOT NULL,
--     RecordID NUMBER(10),
--     OldValues CLOB,
--     NewValues CLOB,
--     ChangedBy VARCHAR2(100) DEFAULT USER,
--     ChangeTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

-- ============================================================
-- TRIGGER 1: trg_UpdateBalance_AfterInsert
-- AFTER INSERT on Transaction: adjusts Account.CurrentBalance
-- Income adds to balance, Expense subtracts from balance
-- ============================================================
CREATE OR REPLACE TRIGGER trg_UpdateBalance_AfterInsert
AFTER INSERT ON "Transaction"
FOR EACH ROW
BEGIN
    IF :NEW.TransactionType = 'Income' THEN
        UPDATE Account
        SET    CurrentBalance = CurrentBalance + :NEW.Amount
        WHERE  AccountID = :NEW.AccountID;
    ELSIF :NEW.TransactionType = 'Expense' THEN
        UPDATE Account
        SET    CurrentBalance = CurrentBalance - :NEW.Amount
        WHERE  AccountID = :NEW.AccountID;
    END IF;
    -- Transfer type: handled by sp_TransferFunds (manual balance update)
END;
/
-- MySQL equivalent:
-- CREATE TRIGGER trg_UpdateBalance_AfterInsert
-- AFTER INSERT ON Transaction FOR EACH ROW
-- BEGIN
--     IF NEW.TransactionType = 'Income' THEN
--         UPDATE Account SET CurrentBalance = CurrentBalance + NEW.Amount
--         WHERE AccountID = NEW.AccountID;
--     ELSEIF NEW.TransactionType = 'Expense' THEN
--         UPDATE Account SET CurrentBalance = CurrentBalance - NEW.Amount
--         WHERE AccountID = NEW.AccountID;
--     END IF;
-- END;


-- ============================================================
-- TRIGGER 2: trg_UpdateBalance_AfterUpdate
-- AFTER UPDATE on Transaction: reverses old, applies new amount
-- ============================================================
CREATE OR REPLACE TRIGGER trg_UpdateBalance_AfterUpdate
AFTER UPDATE ON "Transaction"
FOR EACH ROW
BEGIN
    -- Reverse old transaction effect
    IF :OLD.TransactionType = 'Income' THEN
        UPDATE Account SET CurrentBalance = CurrentBalance - :OLD.Amount
        WHERE  AccountID = :OLD.AccountID;
    ELSIF :OLD.TransactionType = 'Expense' THEN
        UPDATE Account SET CurrentBalance = CurrentBalance + :OLD.Amount
        WHERE  AccountID = :OLD.AccountID;
    END IF;

    -- Apply new transaction effect
    IF :NEW.TransactionType = 'Income' THEN
        UPDATE Account SET CurrentBalance = CurrentBalance + :NEW.Amount
        WHERE  AccountID = :NEW.AccountID;
    ELSIF :NEW.TransactionType = 'Expense' THEN
        UPDATE Account SET CurrentBalance = CurrentBalance - :NEW.Amount
        WHERE  AccountID = :NEW.AccountID;
    END IF;
END;
/


-- ============================================================
-- TRIGGER 3: trg_UpdateBalance_AfterDelete
-- AFTER DELETE on Transaction: reverses deleted transaction
-- ============================================================
CREATE OR REPLACE TRIGGER trg_UpdateBalance_AfterDelete
AFTER DELETE ON "Transaction"
FOR EACH ROW
BEGIN
    IF :OLD.TransactionType = 'Income' THEN
        UPDATE Account SET CurrentBalance = CurrentBalance - :OLD.Amount
        WHERE  AccountID = :OLD.AccountID;
    ELSIF :OLD.TransactionType = 'Expense' THEN
        UPDATE Account SET CurrentBalance = CurrentBalance + :OLD.Amount
        WHERE  AccountID = :OLD.AccountID;
    END IF;
END;
/


-- ============================================================
-- TRIGGER 4: trg_CheckBudget_AfterTransaction
-- AFTER INSERT on Transaction: alerts if spending exceeds budget
-- ============================================================
CREATE OR REPLACE TRIGGER trg_CheckBudget_AfterTransaction
AFTER INSERT ON "Transaction"
FOR EACH ROW
DECLARE
    v_user_id       NUMBER(10);
    v_budget_amt    NUMBER(15,2);
    v_total_spent   NUMBER(15,2);
    v_cat_name      VARCHAR2(50);
BEGIN
    -- Only check for expense transactions
    IF :NEW.TransactionType != 'Expense' THEN
        RETURN;
    END IF;

    -- Get the user who owns this account
    SELECT UserID INTO v_user_id
    FROM   Account WHERE AccountID = :NEW.AccountID;

    -- Check if a budget exists for this category (or parent category)
    BEGIN
        SELECT b.BudgetAmount, c.CategoryName
        INTO   v_budget_amt, v_cat_name
        FROM   Budget b
        JOIN   Category c ON b.CategoryID = c.CategoryID
        WHERE  b.UserID = v_user_id
               AND (b.CategoryID = :NEW.CategoryID
                    OR b.CategoryID = (
                        SELECT ParentCategoryID FROM Category
                        WHERE  CategoryID = :NEW.CategoryID
                    ))
               AND b.StartDate <= TRUNC(SYSDATE)
               AND b.EndDate   >= TRUNC(SYSDATE)
               AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN;  -- No budget set, nothing to check
    END;

    -- Calculate total spent in this category for current budget period
    SELECT NVL(SUM(t.Amount), 0)
    INTO   v_total_spent
    FROM   "Transaction" t
    JOIN   Account a ON t.AccountID = a.AccountID
    WHERE  a.UserID = v_user_id
           AND (t.CategoryID = :NEW.CategoryID
                OR t.CategoryID IN (
                    SELECT CategoryID FROM Category
                    WHERE  ParentCategoryID = :NEW.CategoryID
                ))
           AND t.TransactionType = 'Expense'
           AND EXTRACT(MONTH FROM t.TransactionDate) = EXTRACT(MONTH FROM SYSDATE)
           AND EXTRACT(YEAR  FROM t.TransactionDate) = EXTRACT(YEAR  FROM SYSDATE);

    -- Alert if over budget
    IF v_total_spent > v_budget_amt THEN
        DBMS_OUTPUT.PUT_LINE('⚠ BUDGET ALERT: ' || v_cat_name
            || ' spending (' || v_total_spent || ') exceeds budget ('
            || v_budget_amt || ') by ' || (v_total_spent - v_budget_amt));
        -- Could also use: RAISE_APPLICATION_ERROR(-20001, 'Budget exceeded...');
        -- but we choose to warn, not block
    ELSIF v_total_spent > v_budget_amt * 0.9 THEN
        DBMS_OUTPUT.PUT_LINE('⚠ BUDGET WARNING: ' || v_cat_name
            || ' is at ' || ROUND(v_total_spent / v_budget_amt * 100, 0)
            || '% of budget');
    END IF;
END;
/


-- ============================================================
-- TRIGGER 5: trg_PreventNegativeBalance
-- BEFORE UPDATE on Account: blocks negative balance for
-- non-CreditCard accounts
-- ============================================================
CREATE OR REPLACE TRIGGER trg_PreventNegativeBalance
BEFORE UPDATE OF CurrentBalance ON Account
FOR EACH ROW
BEGIN
    -- Allow negative balance only for credit cards
    IF :NEW.AccountType != 'CreditCard' AND :NEW.CurrentBalance < 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
            'ERROR: Cannot set negative balance on ' || :NEW.AccountType
            || ' account "' || :NEW.AccountName || '". '
            || 'Attempted balance: ' || :NEW.CurrentBalance);
    END IF;
END;
/


-- ============================================================
-- TRIGGER 6: trg_ValidateTransactionDate
-- BEFORE INSERT on Transaction: prevents future-dated transactions
-- ============================================================
CREATE OR REPLACE TRIGGER trg_ValidateTransactionDate
BEFORE INSERT ON "Transaction"
FOR EACH ROW
BEGIN
    IF :NEW.TransactionDate > SYSDATE + INTERVAL '1' MINUTE THEN
        RAISE_APPLICATION_ERROR(-20004,
            'ERROR: Transaction date cannot be in the future. '
            || 'Provided: ' || TO_CHAR(:NEW.TransactionDate, 'DD-MON-YYYY HH24:MI')
            || ', Current: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI'));
    END IF;
END;
/


-- ============================================================
-- TRIGGER 7: trg_AutoCategorize
-- BEFORE INSERT on Transaction: auto-sets CategoryID based
-- on Description patterns
-- ============================================================
CREATE OR REPLACE TRIGGER trg_AutoCategorize
BEFORE INSERT ON "Transaction"
FOR EACH ROW
DECLARE
    v_desc_upper VARCHAR2(255);
BEGIN
    -- Only auto-categorize if no category was provided or if
    -- a generic/default category was used
    v_desc_upper := UPPER(:NEW.Description);

    -- Food & Restaurant patterns
    IF REGEXP_LIKE(v_desc_upper, 'SWIGGY|ZOMATO|DOMINOS|PIZZA|MCDONALDS|KFC|BURGER') THEN
        :NEW.CategoryID := 6;  -- Restaurants
    ELSIF REGEXP_LIKE(v_desc_upper, 'BIGBASKET|DMART|GROCER|BLINKIT|ZEPTO|VEGETABLES') THEN
        :NEW.CategoryID := 5;  -- Groceries
    -- Transport patterns
    ELSIF REGEXP_LIKE(v_desc_upper, 'UBER|OLA|RAPIDO|METRO|BUS|CAB|RIDE') THEN
        :NEW.CategoryID := 9;  -- Public Transit
    ELSIF REGEXP_LIKE(v_desc_upper, 'PETROL|DIESEL|FUEL|HP PUMP|INDIAN OIL|BHARAT') THEN
        :NEW.CategoryID := 8;  -- Fuel
    -- Entertainment patterns
    ELSIF REGEXP_LIKE(v_desc_upper, 'NETFLIX|HOTSTAR|PRIME VIDEO|SPOTIFY|YOUTUBE') THEN
        :NEW.CategoryID := 12; -- Subscriptions
    ELSIF REGEXP_LIKE(v_desc_upper, 'PVR|INOX|MOVIE|CINEMA|BOOKMYSHOW') THEN
        :NEW.CategoryID := 11; -- Movies
    -- Shopping patterns
    ELSIF REGEXP_LIKE(v_desc_upper, 'AMAZON|FLIPKART|MYNTRA|AJIO|MEESHO') THEN
        :NEW.CategoryID := 17; -- Shopping
    -- Utility patterns
    ELSIF REGEXP_LIKE(v_desc_upper, 'ELECTRICITY|POWER|BILL|BESCOM|TATA POWER') THEN
        :NEW.CategoryID := 14; -- Electricity
    ELSIF REGEXP_LIKE(v_desc_upper, 'JIO|AIRTEL|WIFI|BROADBAND|INTERNET|FIBER') THEN
        :NEW.CategoryID := 15; -- Internet
    -- Rent pattern
    ELSIF REGEXP_LIKE(v_desc_upper, 'RENT|LEASE|HOUSING|APARTMENT') THEN
        :NEW.CategoryID := 16; -- Rent
    -- Healthcare
    ELSIF REGEXP_LIKE(v_desc_upper, 'DOCTOR|HOSPITAL|PHARMACY|MEDICINE|APOLLO|MEDPLUS') THEN
        :NEW.CategoryID := 18; -- Healthcare
    END IF;
    -- If no pattern matches, keep the original CategoryID
END;
/


-- ============================================================
-- TRIGGER 8: trg_LogAudit
-- AFTER INSERT/UPDATE/DELETE on Transaction: logs changes
-- to AuditLog table
-- ============================================================
CREATE OR REPLACE TRIGGER trg_LogAudit
AFTER INSERT OR UPDATE OR DELETE ON "Transaction"
FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
    v_old_vals  CLOB;
    v_new_vals  CLOB;
    v_record_id NUMBER(10);
BEGIN
    IF INSERTING THEN
        v_operation := 'INSERT';
        v_record_id := :NEW.TransactionID;
        v_old_vals  := NULL;
        v_new_vals  := 'ID=' || :NEW.TransactionID
                    || '|Acct=' || :NEW.AccountID
                    || '|Cat='  || :NEW.CategoryID
                    || '|Amt='  || :NEW.Amount
                    || '|Type=' || :NEW.TransactionType
                    || '|Desc=' || :NEW.Description;
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
        v_record_id := :NEW.TransactionID;
        v_old_vals  := 'ID=' || :OLD.TransactionID
                    || '|Acct=' || :OLD.AccountID
                    || '|Cat='  || :OLD.CategoryID
                    || '|Amt='  || :OLD.Amount
                    || '|Type=' || :OLD.TransactionType
                    || '|Desc=' || :OLD.Description;
        v_new_vals  := 'ID=' || :NEW.TransactionID
                    || '|Acct=' || :NEW.AccountID
                    || '|Cat='  || :NEW.CategoryID
                    || '|Amt='  || :NEW.Amount
                    || '|Type=' || :NEW.TransactionType
                    || '|Desc=' || :NEW.Description;
    ELSIF DELETING THEN
        v_operation := 'DELETE';
        v_record_id := :OLD.TransactionID;
        v_old_vals  := 'ID=' || :OLD.TransactionID
                    || '|Acct=' || :OLD.AccountID
                    || '|Cat='  || :OLD.CategoryID
                    || '|Amt='  || :OLD.Amount
                    || '|Type=' || :OLD.TransactionType
                    || '|Desc=' || :OLD.Description;
        v_new_vals  := NULL;
    END IF;

    INSERT INTO AuditLog (LogID, TableName, OperationType, RecordID,
                          OldValues, NewValues, ChangedBy, ChangeTimestamp)
    VALUES (seq_audit_id.NEXTVAL, 'Transaction', v_operation, v_record_id,
            v_old_vals, v_new_vals, USER, CURRENT_TIMESTAMP);
END;
/


-- ============================================================
-- VERIFICATION: List all triggers
-- ============================================================
SELECT trigger_name, triggering_event, table_name, status
FROM   user_triggers
ORDER  BY table_name, trigger_name;
