-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 11_Cursors.sql
-- Description: Cursor demonstrations
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

-- ============================================================
-- CURSOR DEMO 1: Process Due Recurring Transactions
-- (Also used inside sp_ProcessRecurringTransactions)
-- Demonstrates explicit cursor with OPEN, FETCH, CLOSE
-- ============================================================
DECLARE
    -- Explicit cursor declaration
    CURSOR cur_due_recurring IS
        SELECT r.RecurringID,
               r.AccountID,
               r.CategoryID,
               r.Amount,
               r.Frequency,
               r.NextDueDate,
               r.Description,
               a.AccountName,
               c.CategoryName
        FROM   RecurringTransaction r
        JOIN   Account a  ON r.AccountID  = a.AccountID
        JOIN   Category c ON r.CategoryID = c.CategoryID
        WHERE  r.NextDueDate <= TRUNC(SYSDATE)
        ORDER  BY r.NextDueDate;

    -- Record variable matching cursor structure
    v_rec cur_due_recurring%ROWTYPE;

    v_count     NUMBER := 0;
    v_new_date  DATE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE('  CURSOR DEMO 1: Due Recurring Transactions');
    DBMS_OUTPUT.PUT_LINE('  Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE('================================================');

    -- Open the cursor
    OPEN cur_due_recurring;

    -- Fetch loop
    LOOP
        FETCH cur_due_recurring INTO v_rec;
        EXIT WHEN cur_due_recurring%NOTFOUND;

        v_count := v_count + 1;

        -- Calculate next due date
        v_new_date := CASE v_rec.Frequency
            WHEN 'Daily'   THEN v_rec.NextDueDate + 1
            WHEN 'Weekly'  THEN v_rec.NextDueDate + 7
            WHEN 'Monthly' THEN ADD_MONTHS(v_rec.NextDueDate, 1)
            WHEN 'Yearly'  THEN ADD_MONTHS(v_rec.NextDueDate, 12)
        END;

        DBMS_OUTPUT.PUT_LINE(v_count || '. ' || v_rec.Description);
        DBMS_OUTPUT.PUT_LINE('   Account:  ' || v_rec.AccountName);
        DBMS_OUTPUT.PUT_LINE('   Category: ' || v_rec.CategoryName);
        DBMS_OUTPUT.PUT_LINE('   Amount:   ' || TO_CHAR(v_rec.Amount, '99,99,999'));
        DBMS_OUTPUT.PUT_LINE('   Due:      ' || TO_CHAR(v_rec.NextDueDate, 'DD-MON-YYYY'));
        DBMS_OUTPUT.PUT_LINE('   Next Due: ' || TO_CHAR(v_new_date, 'DD-MON-YYYY'));
        DBMS_OUTPUT.PUT_LINE('   ---');
    END LOOP;

    -- Close the cursor
    CLOSE cur_due_recurring;

    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No recurring transactions due today.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Total due: ' || v_count || ' items');
    END IF;

    DBMS_OUTPUT.PUT_LINE('================================================');

EXCEPTION
    WHEN OTHERS THEN
        IF cur_due_recurring%ISOPEN THEN
            CLOSE cur_due_recurring;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/


-- ============================================================
-- CURSOR DEMO 2: Category-wise Monthly Report
-- (Also used inside sp_GenerateMonthlyReport)
-- Demonstrates cursor with parameters (parameterized cursor)
-- ============================================================
DECLARE
    -- Parameterized cursor: accepts user_id and month
    CURSOR cur_category_spending (
        p_user_id IN NUMBER,
        p_month   IN DATE
    ) IS
        SELECT c.CategoryName,
               c.CategoryType,
               NVL(SUM(t.Amount), 0) AS TotalAmount,
               COUNT(t.TransactionID) AS TxnCount
        FROM   Category c
        LEFT JOIN "Transaction" t ON t.CategoryID = c.CategoryID
                                  AND t.TransactionDate >= TRUNC(p_month, 'MM')
                                  AND t.TransactionDate <  ADD_MONTHS(TRUNC(p_month, 'MM'), 1)
        LEFT JOIN Account a ON t.AccountID = a.AccountID
                            AND a.UserID = p_user_id
        GROUP  BY c.CategoryName, c.CategoryType
        HAVING NVL(SUM(t.Amount), 0) > 0
        ORDER  BY c.CategoryType, TotalAmount DESC;

    v_total_income  NUMBER := 0;
    v_total_expense NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE('  CURSOR DEMO 2: Category-wise Report');
    DBMS_OUTPUT.PUT_LINE('  User: Tanmay Agarwal | April 2026');
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE(RPAD('Category', 25) || RPAD('Type', 10)
        || RPAD('Amount', 15) || 'Count');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));

    -- Open parameterized cursor
    FOR rec IN cur_category_spending(1, TO_DATE('2026-04-01', 'YYYY-MM-DD')) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.CategoryName, 25) ||
            RPAD(rec.CategoryType, 10) ||
            RPAD(TO_CHAR(rec.TotalAmount, '99,99,999'), 15) ||
            rec.TxnCount
        );

        IF rec.CategoryType = 'Income' THEN
            v_total_income := v_total_income + rec.TotalAmount;
        ELSE
            v_total_expense := v_total_expense + rec.TotalAmount;
        END IF;
    END LOOP;  -- Implicit CLOSE with FOR loop

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 60, '-'));
    DBMS_OUTPUT.PUT_LINE('Total Income:  ' || TO_CHAR(v_total_income, '99,99,999'));
    DBMS_OUTPUT.PUT_LINE('Total Expense: ' || TO_CHAR(v_total_expense, '99,99,999'));
    DBMS_OUTPUT.PUT_LINE('Net Savings:   ' || TO_CHAR(v_total_income - v_total_expense, '99,99,999'));
    DBMS_OUTPUT.PUT_LINE('================================================');
END;
/


-- ============================================================
-- CURSOR DEMO 3: Running Balance Calculation
-- Standalone anonymous block that calculates running balance
-- for an account's transactions ordered by date
-- Demonstrates cursor with running aggregate computation
-- ============================================================
DECLARE
    v_account_id    NUMBER := 1;  -- HDFC Savings
    v_account_name  VARCHAR2(100);
    v_running_bal   NUMBER(15,2) := 0;
    v_row_num       NUMBER := 0;

    -- Cursor: all transactions for an account, ordered by date
    CURSOR cur_running_balance IS
        SELECT t.TransactionID,
               t.TransactionDate,
               t.TransactionType,
               t.Amount,
               t.Description,
               c.CategoryName
        FROM   "Transaction" t
        JOIN   Category c ON t.CategoryID = c.CategoryID
        WHERE  t.AccountID = v_account_id
        ORDER  BY t.TransactionDate, t.TransactionID;

    v_txn cur_running_balance%ROWTYPE;
BEGIN
    -- Get account name
    SELECT AccountName INTO v_account_name
    FROM   Account WHERE AccountID = v_account_id;

    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE('  CURSOR DEMO 3: Running Balance');
    DBMS_OUTPUT.PUT_LINE('  Account: ' || v_account_name);
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE(
        RPAD('#', 4) ||
        RPAD('Date', 14) ||
        RPAD('Type', 10) ||
        RPAD('Amount', 14) ||
        RPAD('Running Bal', 14) ||
        'Description'
    );
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));

    OPEN cur_running_balance;
    LOOP
        FETCH cur_running_balance INTO v_txn;
        EXIT WHEN cur_running_balance%NOTFOUND;

        v_row_num := v_row_num + 1;

        -- Calculate running balance
        IF v_txn.TransactionType = 'Income' THEN
            v_running_bal := v_running_bal + v_txn.Amount;
        ELSIF v_txn.TransactionType = 'Expense' THEN
            v_running_bal := v_running_bal - v_txn.Amount;
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_row_num, 4) ||
            RPAD(TO_CHAR(v_txn.TransactionDate, 'DD-Mon-YY'), 14) ||
            RPAD(v_txn.TransactionType, 10) ||
            RPAD(CASE WHEN v_txn.TransactionType = 'Income'
                      THEN '+' ELSE '-' END
                 || TO_CHAR(v_txn.Amount, '99,999'), 14) ||
            RPAD(TO_CHAR(v_running_bal, '9,99,99,999'), 14) ||
            SUBSTR(v_txn.Description, 1, 30)
        );
    END LOOP;
    CLOSE cur_running_balance;

    DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
    DBMS_OUTPUT.PUT_LINE('Final Running Balance: ' || TO_CHAR(v_running_bal, '9,99,99,999'));
    DBMS_OUTPUT.PUT_LINE('Total Transactions: ' || v_row_num);
    DBMS_OUTPUT.PUT_LINE('================================================');

EXCEPTION
    WHEN OTHERS THEN
        IF cur_running_balance%ISOPEN THEN
            CLOSE cur_running_balance;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/


-- ============================================================
-- CURSOR DEMO 4 (BONUS): REF CURSOR (Dynamic Cursor)
-- Demonstrates sys_refcursor for dynamic result sets
-- ============================================================
DECLARE
    v_cursor    SYS_REFCURSOR;
    v_name      VARCHAR2(100);
    v_balance   NUMBER(15,2);
    v_type      VARCHAR2(20);
    v_user_id   NUMBER := 1;
BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE('  CURSOR DEMO 4: REF CURSOR (Dynamic)');
    DBMS_OUTPUT.PUT_LINE('================================================');

    -- Open a dynamic ref cursor
    OPEN v_cursor FOR
        SELECT a.AccountName, a.CurrentBalance, a.AccountType
        FROM   Account a
        WHERE  a.UserID = v_user_id AND a.IsActive = 1
        ORDER  BY a.CurrentBalance DESC;

    DBMS_OUTPUT.PUT_LINE(RPAD('Account', 25) || RPAD('Type', 15) || 'Balance');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 55, '-'));

    LOOP
        FETCH v_cursor INTO v_name, v_balance, v_type;
        EXIT WHEN v_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(v_name, 25) ||
            RPAD(v_type, 15) ||
            TO_CHAR(v_balance, '99,99,999.00')
        );
    END LOOP;

    CLOSE v_cursor;
    DBMS_OUTPUT.PUT_LINE('================================================');

EXCEPTION
    WHEN OTHERS THEN
        IF v_cursor%ISOPEN THEN CLOSE v_cursor; END IF;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/


-- ============================================================
-- CURSOR DEMO 5 (BONUS): Cursor with BULK COLLECT
-- Demonstrates efficient batch processing
-- ============================================================
DECLARE
    TYPE t_txn_tab IS TABLE OF "Transaction"%ROWTYPE;
    v_txns      t_txn_tab;
    v_total     NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================');
    DBMS_OUTPUT.PUT_LINE('  CURSOR DEMO 5: BULK COLLECT');
    DBMS_OUTPUT.PUT_LINE('================================================');

    -- Fetch all expense transactions at once (efficient for large datasets)
    SELECT * BULK COLLECT INTO v_txns
    FROM   "Transaction"
    WHERE  TransactionType = 'Expense'
    ORDER  BY Amount DESC;

    DBMS_OUTPUT.PUT_LINE('Fetched ' || v_txns.COUNT || ' expense transactions');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Top 5 largest expenses:');

    FOR i IN 1..LEAST(5, v_txns.COUNT) LOOP
        DBMS_OUTPUT.PUT_LINE(
            '  ' || i || '. ' ||
            RPAD(NVL(v_txns(i).Description, 'N/A'), 30) ||
            ' -> ' || TO_CHAR(v_txns(i).Amount, '99,99,999')
        );
        v_total := v_total + v_txns(i).Amount;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Total all expenses: ' ||
        TO_CHAR(v_txns.COUNT, '999') || ' transactions');
    DBMS_OUTPUT.PUT_LINE('================================================');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/
