-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 10_Transactions.sql
-- Description: Transaction management demo blocks
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

-- ============================================================
-- SCENARIO 1: FUND TRANSFER (Atomic debit-credit pair)
-- Demonstrates: BEGIN, SAVEPOINT, COMMIT, ROLLBACK
-- ============================================================
DECLARE
    v_from_acct     NUMBER := 1;  -- HDFC Savings
    v_to_acct       NUMBER := 2;  -- SBI Checking
    v_amount        NUMBER := 10000;
    v_from_balance  NUMBER;
    v_to_balance    NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== SCENARIO 1: Fund Transfer ===');

    -- Check balances before transfer
    SELECT CurrentBalance INTO v_from_balance FROM Account WHERE AccountID = v_from_acct;
    SELECT CurrentBalance INTO v_to_balance FROM Account WHERE AccountID = v_to_acct;
    DBMS_OUTPUT.PUT_LINE('Before: Source=' || v_from_balance || ', Dest=' || v_to_balance);

    -- Start atomic operation
    SAVEPOINT before_transfer;

    -- Step 1: Debit source
    UPDATE Account SET CurrentBalance = CurrentBalance - v_amount
    WHERE  AccountID = v_from_acct;

    -- Step 2: Credit destination
    UPDATE Account SET CurrentBalance = CurrentBalance + v_amount
    WHERE  AccountID = v_to_acct;

    -- Step 3: Log both transactions
    INSERT INTO "Transaction" VALUES (seq_transaction_id.NEXTVAL, v_from_acct, 20,
        v_amount, CURRENT_TIMESTAMP, 'Transfer', 'Transfer to SBI Checking', 'Internal');
    INSERT INTO "Transaction" VALUES (seq_transaction_id.NEXTVAL, v_to_acct, 20,
        v_amount, CURRENT_TIMESTAMP, 'Transfer', 'Transfer from HDFC Savings', 'Internal');

    -- Verify consistency
    SELECT CurrentBalance INTO v_from_balance FROM Account WHERE AccountID = v_from_acct;
    SELECT CurrentBalance INTO v_to_balance FROM Account WHERE AccountID = v_to_acct;
    DBMS_OUTPUT.PUT_LINE('After:  Source=' || v_from_balance || ', Dest=' || v_to_balance);

    -- All steps succeeded -> COMMIT
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Transfer COMMITTED successfully');

EXCEPTION
    WHEN OTHERS THEN
        -- Any failure -> ROLLBACK entire transfer
        ROLLBACK TO before_transfer;
        DBMS_OUTPUT.PUT_LINE('Transfer ROLLED BACK: ' || SQLERRM);
END;
/


-- ============================================================
-- SCENARIO 2: SPLIT TRANSACTION (SAVEPOINT for partial rollback)
-- Demonstrates: Multiple SAVEPOINTs within one transaction
-- ============================================================
DECLARE
    v_txn_id        NUMBER := 7;   -- Amazon Purchase (5600)
    v_orig_amount   NUMBER;
    v_split_total   NUMBER := 0;
    TYPE t_cat_arr IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_amt_arr IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_cats   t_cat_arr;
    v_amts   t_amt_arr;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== SCENARIO 2: Split Transaction ===');

    -- Get original amount
    SELECT Amount INTO v_orig_amount FROM "Transaction" WHERE TransactionID = v_txn_id;
    DBMS_OUTPUT.PUT_LINE('Original transaction amount: ' || v_orig_amount);

    -- Define splits
    v_cats(1) := 17;  v_amts(1) := 3600;  -- Shopping
    v_cats(2) := 10;  v_amts(2) := 2000;  -- Entertainment

    SAVEPOINT before_split;

    -- Delete existing splits
    DELETE FROM TransactionSplit WHERE TransactionID = v_txn_id;

    -- Insert each split with its own savepoint
    FOR i IN 1..v_cats.COUNT LOOP
        SAVEPOINT before_split_item;

        INSERT INTO TransactionSplit (SplitID, TransactionID, CategoryID, SplitAmount)
        VALUES (seq_split_id.NEXTVAL, v_txn_id, v_cats(i), v_amts(i));

        v_split_total := v_split_total + v_amts(i);
        DBMS_OUTPUT.PUT_LINE('  Split ' || i || ': Category=' || v_cats(i) || ', Amount=' || v_amts(i));
    END LOOP;

    -- Validate total matches original
    IF v_split_total != v_orig_amount THEN
        DBMS_OUTPUT.PUT_LINE('MISMATCH: Split total=' || v_split_total || ', Expected=' || v_orig_amount);
        ROLLBACK TO before_split;
        DBMS_OUTPUT.PUT_LINE('All splits ROLLED BACK');
    ELSE
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Split total matches. COMMITTED.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO before_split;
        DBMS_OUTPUT.PUT_LINE('Split ROLLED BACK: ' || SQLERRM);
END;
/


-- ============================================================
-- SCENARIO 3: BUDGET RECALCULATION (Atomic spending update)
-- ============================================================
DECLARE
    v_user_id   NUMBER := 1;
    v_cat_id    NUMBER := 4;  -- Food category
    v_spent     NUMBER;
    v_budget    NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== SCENARIO 3: Budget Recalculation ===');

    SAVEPOINT before_budget_check;

    -- Calculate actual spending for Food (including children: Groceries, Restaurants)
    SELECT NVL(SUM(t.Amount), 0)
    INTO   v_spent
    FROM   "Transaction" t
    JOIN   Account a ON t.AccountID = a.AccountID
    WHERE  a.UserID = v_user_id
           AND (t.CategoryID = v_cat_id
                OR t.CategoryID IN (SELECT CategoryID FROM Category WHERE ParentCategoryID = v_cat_id))
           AND t.TransactionType = 'Expense'
           AND EXTRACT(MONTH FROM t.TransactionDate) = EXTRACT(MONTH FROM SYSDATE)
           AND EXTRACT(YEAR  FROM t.TransactionDate) = EXTRACT(YEAR  FROM SYSDATE);

    SELECT BudgetAmount INTO v_budget
    FROM   Budget
    WHERE  UserID = v_user_id AND CategoryID = v_cat_id AND ROWNUM = 1;

    DBMS_OUTPUT.PUT_LINE('Food Budget:    ' || v_budget);
    DBMS_OUTPUT.PUT_LINE('Actual Spent:   ' || v_spent);
    DBMS_OUTPUT.PUT_LINE('Remaining:      ' || (v_budget - v_spent));
    DBMS_OUTPUT.PUT_LINE('Usage:          ' || ROUND(v_spent / v_budget * 100, 1) || '%');

    IF v_spent > v_budget THEN
        DBMS_OUTPUT.PUT_LINE('*** ALERT: OVER BUDGET by ' || (v_spent - v_budget) || ' ***');
    END IF;

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No budget found for this category');
        ROLLBACK TO before_budget_check;
    WHEN OTHERS THEN
        ROLLBACK TO before_budget_check;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/


-- ============================================================
-- SCENARIO 4: RECURRING TRANSACTION BATCH
-- Demonstrates: Batch processing with per-item error handling
-- ============================================================
DECLARE
    v_processed NUMBER := 0;
    v_failed    NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== SCENARIO 4: Recurring Batch Processing ===');

    SAVEPOINT before_batch;

    -- Process all due recurring transactions
    FOR rec IN (SELECT * FROM RecurringTransaction WHERE NextDueDate <= TRUNC(SYSDATE)) LOOP
        BEGIN
            SAVEPOINT before_item;

            -- Create the transaction
            INSERT INTO "Transaction" (TransactionID, AccountID, CategoryID, Amount,
                TransactionDate, TransactionType, Description, PaymentMethod)
            VALUES (seq_transaction_id.NEXTVAL, rec.AccountID, rec.CategoryID, rec.Amount,
                CURRENT_TIMESTAMP, 'Expense', '[BATCH] ' || rec.Description, 'Auto');

            -- Update next due date
            UPDATE RecurringTransaction
            SET    NextDueDate = CASE Frequency
                       WHEN 'Daily'   THEN NextDueDate + 1
                       WHEN 'Weekly'  THEN NextDueDate + 7
                       WHEN 'Monthly' THEN ADD_MONTHS(NextDueDate, 1)
                       WHEN 'Yearly'  THEN ADD_MONTHS(NextDueDate, 12)
                   END
            WHERE  RecurringID = rec.RecurringID;

            v_processed := v_processed + 1;

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO before_item;  -- Only rollback this one item
                v_failed := v_failed + 1;
                DBMS_OUTPUT.PUT_LINE('  Failed: ' || rec.Description || ' - ' || SQLERRM);
        END;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Processed: ' || v_processed || ', Failed: ' || v_failed);

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO before_batch;
        DBMS_OUTPUT.PUT_LINE('Entire batch ROLLED BACK: ' || SQLERRM);
END;
/


-- ============================================================
-- SCENARIO 5: DEBT PAYMENT (Updates both debt and account)
-- ============================================================
DECLARE
    v_debt_id       NUMBER := 1;  -- Education Loan
    v_payment       NUMBER;
    v_acct_id       NUMBER := 1;  -- Pay from HDFC Savings
    v_remaining     NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== SCENARIO 5: Debt Payment ===');

    -- Get EMI amount and remaining balance
    SELECT MonthlyEMI, RemainingBalance INTO v_payment, v_remaining
    FROM   Debt WHERE DebtID = v_debt_id;

    DBMS_OUTPUT.PUT_LINE('EMI Amount:  ' || v_payment);
    DBMS_OUTPUT.PUT_LINE('Before Remaining: ' || v_remaining);

    SAVEPOINT before_payment;

    -- Step 1: Deduct from account
    UPDATE Account
    SET    CurrentBalance = CurrentBalance - v_payment
    WHERE  AccountID = v_acct_id;

    -- Step 2: Reduce debt balance
    UPDATE Debt
    SET    RemainingBalance = RemainingBalance - v_payment
    WHERE  DebtID = v_debt_id;

    -- Step 3: Log the transaction
    INSERT INTO "Transaction" (TransactionID, AccountID, CategoryID, Amount,
        TransactionDate, TransactionType, Description, PaymentMethod)
    VALUES (seq_transaction_id.NEXTVAL, v_acct_id, 19, v_payment,
        CURRENT_TIMESTAMP, 'Expense', 'EMI Payment - Education Loan', 'Auto Debit');

    -- Verify
    SELECT RemainingBalance INTO v_remaining FROM Debt WHERE DebtID = v_debt_id;
    DBMS_OUTPUT.PUT_LINE('After Remaining:  ' || v_remaining);

    IF v_remaining <= 0 THEN
        DBMS_OUTPUT.PUT_LINE('*** LOAN FULLY PAID OFF! ***');
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Payment COMMITTED');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK TO before_payment;
        DBMS_OUTPUT.PUT_LINE('Payment ROLLED BACK: ' || SQLERRM);
END;
/


-- ============================================================
-- CONCURRENCY CONTROL NOTES
-- ============================================================
/*
ISOLATION LEVELS & LOCKING STRATEGY:

1. READ COMMITTED (Oracle Default):
   - Prevents dirty reads
   - Each query sees only committed data
   - Suitable for most FinFlow operations

2. SERIALIZABLE (For critical operations):
   SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
   - Used for fund transfers to prevent phantom reads
   - Ensures account balance is consistent during transfer

3. ROW-LEVEL LOCKING:
   SELECT ... FOR UPDATE is used implicitly when we:
   - UPDATE Account SET CurrentBalance = ...
   - This locks the specific row until COMMIT/ROLLBACK
   - Prevents two concurrent transfers from the same account

4. DEADLOCK PREVENTION:
   - Always access accounts in ascending AccountID order
   - In sp_TransferFunds: lock lower AccountID first
   - Keep transaction duration minimal

5. OPTIMISTIC LOCKING (Alternative approach):
   - Add a VERSION column to Account table
   - Check version hasn't changed before committing
   - Retry if version mismatch detected
*/
