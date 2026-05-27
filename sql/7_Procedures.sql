-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 7_Procedures.sql
-- Description: All 5 stored procedures
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

-- ============================================================
-- PROCEDURE 1: sp_TransferFunds
-- Atomically transfers money between two accounts
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_TransferFunds (
    p_fromAcct  IN NUMBER,
    p_toAcct    IN NUMBER,
    p_amount    IN NUMBER
) AS
    v_fromBalance   NUMBER(15,2);
    v_fromActive    NUMBER(1);
    v_toActive      NUMBER(1);
    v_fromType      VARCHAR2(20);
    e_insufficient  EXCEPTION;
    e_inactive      EXCEPTION;
    e_same_account  EXCEPTION;
    e_invalid_amt   EXCEPTION;
BEGIN
    -- Validate amount
    IF p_amount <= 0 THEN
        RAISE e_invalid_amt;
    END IF;

    -- Validate not same account
    IF p_fromAcct = p_toAcct THEN
        RAISE e_same_account;
    END IF;

    -- Check source account exists and is active
    SELECT CurrentBalance, IsActive, AccountType
    INTO   v_fromBalance, v_fromActive, v_fromType
    FROM   Account
    WHERE  AccountID = p_fromAcct;

    IF v_fromActive = 0 THEN
        RAISE e_inactive;
    END IF;

    -- Check destination account is active
    SELECT IsActive INTO v_toActive
    FROM   Account WHERE AccountID = p_toAcct;

    IF v_toActive = 0 THEN
        RAISE e_inactive;
    END IF;

    -- Check sufficient balance (except for credit cards)
    IF v_fromType != 'CreditCard' AND v_fromBalance < p_amount THEN
        RAISE e_insufficient;
    END IF;

    -- Perform atomic transfer
    SAVEPOINT before_transfer;

    -- Debit source account
    UPDATE Account
    SET    CurrentBalance = CurrentBalance - p_amount
    WHERE  AccountID = p_fromAcct;

    -- Credit destination account
    UPDATE Account
    SET    CurrentBalance = CurrentBalance + p_amount
    WHERE  AccountID = p_toAcct;

    -- Log debit transaction
    INSERT INTO "Transaction" (TransactionID, AccountID, CategoryID, Amount,
                               TransactionDate, TransactionType, Description, PaymentMethod)
    VALUES (seq_transaction_id.NEXTVAL, p_fromAcct, 20, p_amount,
            CURRENT_TIMESTAMP, 'Transfer',
            'Transfer OUT to Account #' || p_toAcct, 'Internal Transfer');

    -- Log credit transaction
    INSERT INTO "Transaction" (TransactionID, AccountID, CategoryID, Amount,
                               TransactionDate, TransactionType, Description, PaymentMethod)
    VALUES (seq_transaction_id.NEXTVAL, p_toAcct, 20, p_amount,
            CURRENT_TIMESTAMP, 'Transfer',
            'Transfer IN from Account #' || p_fromAcct, 'Internal Transfer');

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Transferred ' || p_amount || ' from Account #'
                          || p_fromAcct || ' to Account #' || p_toAcct);

EXCEPTION
    WHEN e_invalid_amt THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Transfer amount must be positive');
        ROLLBACK TO before_transfer;
    WHEN e_same_account THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Cannot transfer to the same account');
    WHEN e_inactive THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: One or both accounts are inactive');
        ROLLBACK TO before_transfer;
    WHEN e_insufficient THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Insufficient balance. Available: ' || v_fromBalance);
        ROLLBACK TO before_transfer;
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Account not found');
        ROLLBACK TO before_transfer;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        ROLLBACK TO before_transfer;
        RAISE;
END sp_TransferFunds;
/

-- Test: EXEC sp_TransferFunds(1, 2, 5000);


-- ============================================================
-- PROCEDURE 2: sp_ProcessRecurringTransactions
-- Processes all due recurring transactions using a CURSOR
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_ProcessRecurringTransactions AS
    -- Cursor to fetch all due recurring transactions
    CURSOR cur_recurring IS
        SELECT RecurringID, AccountID, CategoryID, Amount,
               Frequency, NextDueDate, Description
        FROM   RecurringTransaction
        WHERE  NextDueDate <= TRUNC(SYSDATE);

    v_rec           cur_recurring%ROWTYPE;
    v_next_date     DATE;
    v_processed     NUMBER := 0;
    v_failed        NUMBER := 0;
    v_cat_type      VARCHAR2(10);
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Processing Recurring Transactions...');
    DBMS_OUTPUT.PUT_LINE('Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE('========================================');

    OPEN cur_recurring;
    LOOP
        FETCH cur_recurring INTO v_rec;
        EXIT WHEN cur_recurring%NOTFOUND;

        BEGIN
            SAVEPOINT before_recurring;

            -- Determine transaction type from category
            SELECT CategoryType INTO v_cat_type
            FROM   Category WHERE CategoryID = v_rec.CategoryID;

            -- Insert the transaction
            INSERT INTO "Transaction" (TransactionID, AccountID, CategoryID, Amount,
                                       TransactionDate, TransactionType, Description, PaymentMethod)
            VALUES (seq_transaction_id.NEXTVAL, v_rec.AccountID, v_rec.CategoryID,
                    v_rec.Amount, CURRENT_TIMESTAMP,
                    CASE WHEN v_cat_type = 'Income' THEN 'Income' ELSE 'Expense' END,
                    '[AUTO] ' || v_rec.Description, 'Auto Debit');

            -- Update account balance
            IF v_cat_type = 'Income' THEN
                UPDATE Account SET CurrentBalance = CurrentBalance + v_rec.Amount
                WHERE  AccountID = v_rec.AccountID;
            ELSE
                UPDATE Account SET CurrentBalance = CurrentBalance - v_rec.Amount
                WHERE  AccountID = v_rec.AccountID;
            END IF;

            -- Calculate next due date based on frequency
            v_next_date := CASE v_rec.Frequency
                WHEN 'Daily'   THEN v_rec.NextDueDate + 1
                WHEN 'Weekly'  THEN v_rec.NextDueDate + 7
                WHEN 'Monthly' THEN ADD_MONTHS(v_rec.NextDueDate, 1)
                WHEN 'Yearly'  THEN ADD_MONTHS(v_rec.NextDueDate, 12)
            END;

            UPDATE RecurringTransaction
            SET    NextDueDate = v_next_date
            WHERE  RecurringID = v_rec.RecurringID;

            v_processed := v_processed + 1;
            DBMS_OUTPUT.PUT_LINE('  OK: ' || v_rec.Description || ' - ' || v_rec.Amount);

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO before_recurring;
                v_failed := v_failed + 1;
                DBMS_OUTPUT.PUT_LINE('  FAIL: ' || v_rec.Description || ' - ' || SQLERRM);
        END;
    END LOOP;
    CLOSE cur_recurring;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Summary: Processed=' || v_processed || ', Failed=' || v_failed);
    DBMS_OUTPUT.PUT_LINE('========================================');

EXCEPTION
    WHEN OTHERS THEN
        IF cur_recurring%ISOPEN THEN CLOSE cur_recurring; END IF;
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('CRITICAL ERROR: ' || SQLERRM);
        RAISE;
END sp_ProcessRecurringTransactions;
/

-- Test: EXEC sp_ProcessRecurringTransactions;


-- ============================================================
-- PROCEDURE 3: sp_SplitTransaction
-- Splits a transaction across multiple categories
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_SplitTransaction (
    p_transID    IN NUMBER,
    p_categories IN VARCHAR2,  -- Comma-separated category IDs: '4,7,10'
    p_amounts    IN VARCHAR2   -- Comma-separated amounts: '500,300,200'
) AS
    v_orig_amount   NUMBER(15,2);
    v_total_split   NUMBER(15,2) := 0;
    v_cat_id        NUMBER(10);
    v_split_amt     NUMBER(15,2);
    v_pos_cat       NUMBER := 1;
    v_pos_amt       NUMBER := 1;
    v_next_comma    NUMBER;
    v_cat_str       VARCHAR2(4000) := p_categories || ',';
    v_amt_str       VARCHAR2(4000) := p_amounts || ',';
    e_mismatch      EXCEPTION;
BEGIN
    -- Get original transaction amount
    SELECT Amount INTO v_orig_amount
    FROM   "Transaction"
    WHERE  TransactionID = p_transID;

    SAVEPOINT before_split;

    -- Delete existing splits for this transaction
    DELETE FROM TransactionSplit WHERE TransactionID = p_transID;

    -- Parse comma-separated values and insert splits
    WHILE INSTR(v_cat_str, ',', v_pos_cat) > 0 LOOP
        -- Extract category ID
        v_next_comma := INSTR(v_cat_str, ',', v_pos_cat);
        v_cat_id := TO_NUMBER(TRIM(SUBSTR(v_cat_str, v_pos_cat, v_next_comma - v_pos_cat)));
        v_pos_cat := v_next_comma + 1;

        -- Extract amount
        v_next_comma := INSTR(v_amt_str, ',', v_pos_amt);
        v_split_amt := TO_NUMBER(TRIM(SUBSTR(v_amt_str, v_pos_amt, v_next_comma - v_pos_amt)));
        v_pos_amt := v_next_comma + 1;

        -- Validate split amount is positive
        IF v_split_amt <= 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Split amount must be positive');
        END IF;

        -- Insert split row
        INSERT INTO TransactionSplit (SplitID, TransactionID, CategoryID, SplitAmount)
        VALUES (seq_split_id.NEXTVAL, p_transID, v_cat_id, v_split_amt);

        v_total_split := v_total_split + v_split_amt;
    END LOOP;

    -- Validate total split equals original amount
    IF v_total_split != v_orig_amount THEN
        RAISE e_mismatch;
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Transaction #' || p_transID || ' split into '
                          || (v_pos_cat - 2) || ' categories');

EXCEPTION
    WHEN e_mismatch THEN
        ROLLBACK TO before_split;
        DBMS_OUTPUT.PUT_LINE('ERROR: Split total (' || v_total_split
                              || ') does not match transaction amount (' || v_orig_amount || ')');
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Transaction #' || p_transID || ' not found');
    WHEN OTHERS THEN
        ROLLBACK TO before_split;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END sp_SplitTransaction;
/

-- Test: EXEC sp_SplitTransaction(7, '17,10', '3600,2000');


-- ============================================================
-- PROCEDURE 4: sp_UpdateGoalProgress
-- Recalculates goal progress from account balances
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_UpdateGoalProgress (
    p_goalID IN NUMBER
) AS
    v_user_id       NUMBER(10);
    v_old_amount    NUMBER(15,2);
    v_new_amount    NUMBER(15,2);
    v_target        NUMBER(15,2);
    v_status        VARCHAR2(15);
BEGIN
    -- Get goal details
    SELECT UserID, CurrentAmount, TargetAmount, Status
    INTO   v_user_id, v_old_amount, v_target, v_status
    FROM   Goal
    WHERE  GoalID = p_goalID;

    IF v_status = 'Cancelled' THEN
        DBMS_OUTPUT.PUT_LINE('Goal #' || p_goalID || ' is cancelled. No update.');
        RETURN;
    END IF;

    -- Calculate current savings (sum of all savings account balances)
    SELECT NVL(SUM(CurrentBalance), 0)
    INTO   v_new_amount
    FROM   Account
    WHERE  UserID = v_user_id
           AND AccountType = 'Savings'
           AND IsActive = 1;

    -- Update goal
    UPDATE Goal
    SET    CurrentAmount = v_new_amount,
           Status = CASE
                        WHEN v_new_amount >= v_target THEN 'Achieved'
                        ELSE 'Active'
                    END
    WHERE  GoalID = p_goalID;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Goal: #' || p_goalID);
    DBMS_OUTPUT.PUT_LINE('  Previous Amount: ' || v_old_amount);
    DBMS_OUTPUT.PUT_LINE('  Updated Amount:  ' || v_new_amount);
    DBMS_OUTPUT.PUT_LINE('  Target:          ' || v_target);
    DBMS_OUTPUT.PUT_LINE('  Progress:        ' || ROUND(v_new_amount / v_target * 100, 1) || '%');
    IF v_new_amount >= v_target THEN
        DBMS_OUTPUT.PUT_LINE('  *** GOAL ACHIEVED! ***');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Goal #' || p_goalID || ' not found');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END sp_UpdateGoalProgress;
/

-- Test: EXEC sp_UpdateGoalProgress(1);


-- ============================================================
-- PROCEDURE 5: sp_GenerateMonthlyReport
-- Generates a formatted monthly report using CURSOR
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_GenerateMonthlyReport (
    p_userID  IN NUMBER,
    p_month   IN DATE
) AS
    -- Cursor to iterate categories with spending
    CURSOR cur_categories IS
        SELECT c.CategoryID, c.CategoryName, c.CategoryType
        FROM   Category c
        ORDER  BY c.CategoryType, c.CategoryName;

    v_cat           cur_categories%ROWTYPE;
    v_user_name     VARCHAR2(100);
    v_total_income  NUMBER(15,2) := 0;
    v_total_expense NUMBER(15,2) := 0;
    v_cat_total     NUMBER(15,2);
    v_budget_amt    NUMBER(15,2);
    v_month_start   DATE;
    v_month_end     DATE;
BEGIN
    -- Get user name
    SELECT Name INTO v_user_name FROM "User" WHERE UserID = p_userID;

    v_month_start := TRUNC(p_month, 'MM');
    v_month_end   := LAST_DAY(p_month);

    DBMS_OUTPUT.PUT_LINE('╔══════════════════════════════════════════════════╗');
    DBMS_OUTPUT.PUT_LINE('║     FINFLOW MONTHLY FINANCIAL REPORT            ║');
    DBMS_OUTPUT.PUT_LINE('╠══════════════════════════════════════════════════╣');
    DBMS_OUTPUT.PUT_LINE('║ User:   ' || RPAD(v_user_name, 41) || '║');
    DBMS_OUTPUT.PUT_LINE('║ Period: ' || RPAD(TO_CHAR(v_month_start, 'Month YYYY'), 41) || '║');
    DBMS_OUTPUT.PUT_LINE('╠══════════════════════════════════════════════════╣');

    -- INCOME SECTION
    DBMS_OUTPUT.PUT_LINE('║                                                  ║');
    DBMS_OUTPUT.PUT_LINE('║  ── INCOME ──────────────────────────────────── ║');

    OPEN cur_categories;
    LOOP
        FETCH cur_categories INTO v_cat;
        EXIT WHEN cur_categories%NOTFOUND;

        IF v_cat.CategoryType = 'Income' THEN
            SELECT NVL(SUM(t.Amount), 0) INTO v_cat_total
            FROM   "Transaction" t
            JOIN   Account a ON t.AccountID = a.AccountID
            WHERE  a.UserID = p_userID
                   AND t.CategoryID = v_cat.CategoryID
                   AND t.TransactionType = 'Income'
                   AND t.TransactionDate >= v_month_start
                   AND t.TransactionDate <= v_month_end;

            IF v_cat_total > 0 THEN
                DBMS_OUTPUT.PUT_LINE('║    ' || RPAD(v_cat.CategoryName, 30)
                    || LPAD(TO_CHAR(v_cat_total, '99,99,999'), 16) || '  ║');
                v_total_income := v_total_income + v_cat_total;
            END IF;
        END IF;
    END LOOP;
    CLOSE cur_categories;

    DBMS_OUTPUT.PUT_LINE('║    ' || RPAD('', 30, '─') || LPAD('', 16, '─') || '  ║');
    DBMS_OUTPUT.PUT_LINE('║    ' || RPAD('TOTAL INCOME', 30)
        || LPAD(TO_CHAR(v_total_income, '99,99,999'), 16) || '  ║');

    -- EXPENSE SECTION
    DBMS_OUTPUT.PUT_LINE('║                                                  ║');
    DBMS_OUTPUT.PUT_LINE('║  ── EXPENSES ──────────────────────────────────║');

    OPEN cur_categories;
    LOOP
        FETCH cur_categories INTO v_cat;
        EXIT WHEN cur_categories%NOTFOUND;

        IF v_cat.CategoryType = 'Expense' THEN
            SELECT NVL(SUM(t.Amount), 0) INTO v_cat_total
            FROM   "Transaction" t
            JOIN   Account a ON t.AccountID = a.AccountID
            WHERE  a.UserID = p_userID
                   AND t.CategoryID = v_cat.CategoryID
                   AND t.TransactionType = 'Expense'
                   AND t.TransactionDate >= v_month_start
                   AND t.TransactionDate <= v_month_end;

            IF v_cat_total > 0 THEN
                -- Check if budget exists
                BEGIN
                    SELECT BudgetAmount INTO v_budget_amt
                    FROM   Budget
                    WHERE  UserID = p_userID AND CategoryID = v_cat.CategoryID
                           AND StartDate <= v_month_end AND EndDate >= v_month_start
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN v_budget_amt := NULL;
                END;

                DBMS_OUTPUT.PUT_LINE('║    ' || RPAD(v_cat.CategoryName, 30)
                    || LPAD(TO_CHAR(v_cat_total, '99,99,999'), 16) || '  ║');

                IF v_budget_amt IS NOT NULL THEN
                    IF v_cat_total > v_budget_amt THEN
                        DBMS_OUTPUT.PUT_LINE('║      ⚠ OVER BUDGET by '
                            || TO_CHAR(v_cat_total - v_budget_amt, '99,999') || '              ║');
                    END IF;
                END IF;

                v_total_expense := v_total_expense + v_cat_total;
            END IF;
        END IF;
    END LOOP;
    CLOSE cur_categories;

    DBMS_OUTPUT.PUT_LINE('║    ' || RPAD('', 30, '─') || LPAD('', 16, '─') || '  ║');
    DBMS_OUTPUT.PUT_LINE('║    ' || RPAD('TOTAL EXPENSES', 30)
        || LPAD(TO_CHAR(v_total_expense, '99,99,999'), 16) || '  ║');

    -- SUMMARY
    DBMS_OUTPUT.PUT_LINE('║                                                  ║');
    DBMS_OUTPUT.PUT_LINE('╠══════════════════════════════════════════════════╣');
    DBMS_OUTPUT.PUT_LINE('║    ' || RPAD('NET SAVINGS', 30)
        || LPAD(TO_CHAR(v_total_income - v_total_expense, '99,99,999'), 16) || '  ║');
    IF v_total_income > 0 THEN
        DBMS_OUTPUT.PUT_LINE('║    ' || RPAD('SAVINGS RATE', 30)
            || LPAD(TO_CHAR(ROUND((v_total_income - v_total_expense) / v_total_income * 100, 1))
                    || '%', 16) || '  ║');
    END IF;
    DBMS_OUTPUT.PUT_LINE('╚══════════════════════════════════════════════════╝');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: User #' || p_userID || ' not found');
    WHEN OTHERS THEN
        IF cur_categories%ISOPEN THEN CLOSE cur_categories; END IF;
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END sp_GenerateMonthlyReport;
/

-- Test: EXEC sp_GenerateMonthlyReport(1, TO_DATE('2026-04-01','YYYY-MM-DD'));
