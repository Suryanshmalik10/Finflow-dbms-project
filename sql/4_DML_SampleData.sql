-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 4_DML_SampleData.sql
-- Description: All INSERT statements with realistic data
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

-- ============================================================
-- INSERT USERS (5 users with Indian names)
-- ============================================================
INSERT INTO "User" (UserID, Name, Email, Phone, DateOfBirth, CreatedDate) VALUES
    (1, 'Tanmay Agarwal', 'tanmay.agarwal@email.com', '9876543210', TO_DATE('2001-05-15','YYYY-MM-DD'), TO_TIMESTAMP('2024-01-10','YYYY-MM-DD'));
INSERT INTO "User" VALUES
    (2, 'Suryansh Malik', 'suryansh.malik@email.com', '9876543211', TO_DATE('2001-08-22','YYYY-MM-DD'), TO_TIMESTAMP('2024-01-12','YYYY-MM-DD'));
INSERT INTO "User" VALUES
    (3, 'Priya Sharma', 'priya.sharma@email.com', '9123456789', TO_DATE('2000-03-10','YYYY-MM-DD'), TO_TIMESTAMP('2024-02-01','YYYY-MM-DD'));
INSERT INTO "User" VALUES
    (4, 'Rahul Verma', 'rahul.verma@email.com', '9988776655', TO_DATE('1999-11-28','YYYY-MM-DD'), TO_TIMESTAMP('2024-02-15','YYYY-MM-DD'));
INSERT INTO "User" VALUES
    (5, 'Ananya Gupta', 'ananya.gupta@email.com', '9112233445', TO_DATE('2002-07-04','YYYY-MM-DD'), TO_TIMESTAMP('2024-03-01','YYYY-MM-DD'));
-- MySQL: Use STR_TO_DATE('2001-05-15','%Y-%m-%d') instead of TO_DATE

-- ============================================================
-- INSERT ACCOUNTS (10 accounts, mix of types)
-- ============================================================
INSERT INTO Account VALUES (1, 1, 'HDFC Savings',     'Savings',    'INR', 185400.00, 1);
INSERT INTO Account VALUES (2, 1, 'SBI Checking',     'Checking',   'INR', 42300.00,  1);
INSERT INTO Account VALUES (3, 1, 'ICICI Credit Card', 'CreditCard','INR', -15600.00, 1);
INSERT INTO Account VALUES (4, 2, 'Axis Savings',     'Savings',    'INR', 230100.00, 1);
INSERT INTO Account VALUES (5, 2, 'Cash Wallet',      'Cash',       'INR', 5400.00,   1);
INSERT INTO Account VALUES (6, 3, 'Kotak Savings',    'Savings',    'INR', 98700.00,  1);
INSERT INTO Account VALUES (7, 3, 'Paytm Wallet',     'Wallet',     'INR', 3200.00,   1);
INSERT INTO Account VALUES (8, 4, 'PNB Savings',      'Savings',    'INR', 156000.00, 1);
INSERT INTO Account VALUES (9, 4, 'HDFC Credit Card', 'CreditCard', 'INR', -28400.00, 1);
INSERT INTO Account VALUES (10, 5, 'BOB Savings',     'Savings',    'INR', 67500.00,  1);

-- ============================================================
-- INSERT CATEGORIES (20 categories with hierarchy)
-- ============================================================
-- Parent categories (no parent)
INSERT INTO Category VALUES (1,  'Salary',         NULL, 'Income');
INSERT INTO Category VALUES (2,  'Freelance',      NULL, 'Income');
INSERT INTO Category VALUES (3,  'Investments',    NULL, 'Income');
INSERT INTO Category VALUES (4,  'Food',           NULL, 'Expense');
INSERT INTO Category VALUES (7,  'Transport',      NULL, 'Expense');
INSERT INTO Category VALUES (10, 'Entertainment',  NULL, 'Expense');
INSERT INTO Category VALUES (13, 'Utilities',      NULL, 'Expense');
INSERT INTO Category VALUES (16, 'Rent',           NULL, 'Expense');
INSERT INTO Category VALUES (17, 'Shopping',       NULL, 'Expense');
INSERT INTO Category VALUES (18, 'Healthcare',     NULL, 'Expense');
INSERT INTO Category VALUES (19, 'Education',      NULL, 'Expense');
INSERT INTO Category VALUES (20, 'Transfer',       NULL, 'Income');

-- Child categories (with parent references)
INSERT INTO Category VALUES (5,  'Groceries',      4,  'Expense');  -- Food -> Groceries
INSERT INTO Category VALUES (6,  'Restaurants',    4,  'Expense');  -- Food -> Restaurants
INSERT INTO Category VALUES (8,  'Fuel',           7,  'Expense');  -- Transport -> Fuel
INSERT INTO Category VALUES (9,  'Public Transit', 7,  'Expense');  -- Transport -> Public Transit
INSERT INTO Category VALUES (11, 'Movies',         10, 'Expense');  -- Entertainment -> Movies
INSERT INTO Category VALUES (12, 'Subscriptions',  10, 'Expense');  -- Entertainment -> Subscriptions
INSERT INTO Category VALUES (14, 'Electricity',    13, 'Expense');  -- Utilities -> Electricity
INSERT INTO Category VALUES (15, 'Internet',       13, 'Expense');  -- Utilities -> Internet

-- ============================================================
-- INSERT TRANSACTIONS (38 transactions across users & months)
-- ============================================================
-- User 1 (Tanmay) - April 2026
INSERT INTO "Transaction" VALUES (1,  1, 1,  75000,  TO_TIMESTAMP('2026-04-01','YYYY-MM-DD'), 'Income',  'Monthly Salary - April',       'Bank Transfer');
INSERT INTO "Transaction" VALUES (2,  1, 5,  4500,   TO_TIMESTAMP('2026-04-02','YYYY-MM-DD'), 'Expense', 'BigBasket Groceries',           'UPI');
INSERT INTO "Transaction" VALUES (3,  1, 6,  1200,   TO_TIMESTAMP('2026-04-03','YYYY-MM-DD'), 'Expense', 'Swiggy Order',                  'UPI');
INSERT INTO "Transaction" VALUES (4,  2, 16, 18000,  TO_TIMESTAMP('2026-04-05','YYYY-MM-DD'), 'Expense', 'Monthly Rent',                  'Bank Transfer');
INSERT INTO "Transaction" VALUES (5,  1, 14, 2800,   TO_TIMESTAMP('2026-04-06','YYYY-MM-DD'), 'Expense', 'Electricity Bill',              'UPI');
INSERT INTO "Transaction" VALUES (6,  1, 8,  3500,   TO_TIMESTAMP('2026-04-07','YYYY-MM-DD'), 'Expense', 'Petrol - HP Pump',              'Debit Card');
INSERT INTO "Transaction" VALUES (7,  3, 17, 5600,   TO_TIMESTAMP('2026-04-08','YYYY-MM-DD'), 'Expense', 'Amazon Purchase',               'Credit Card');
INSERT INTO "Transaction" VALUES (8,  1, 12, 649,    TO_TIMESTAMP('2026-04-10','YYYY-MM-DD'), 'Expense', 'Netflix Subscription',          'UPI');
INSERT INTO "Transaction" VALUES (9,  1, 11, 800,    TO_TIMESTAMP('2026-04-12','YYYY-MM-DD'), 'Expense', 'PVR Movie Tickets',             'UPI');
INSERT INTO "Transaction" VALUES (10, 1, 2,  15000,  TO_TIMESTAMP('2026-04-13','YYYY-MM-DD'), 'Income',  'Freelance Web Dev Project',     'Bank Transfer');
INSERT INTO "Transaction" VALUES (23, 1, 15, 1199,   TO_TIMESTAMP('2026-04-14','YYYY-MM-DD'), 'Expense', 'Jio Fiber Bill',                'UPI');
INSERT INTO "Transaction" VALUES (24, 1, 5,  3200,   TO_TIMESTAMP('2026-04-16','YYYY-MM-DD'), 'Expense', 'Weekly Groceries',              'UPI');
INSERT INTO "Transaction" VALUES (25, 1, 6,  950,    TO_TIMESTAMP('2026-04-17','YYYY-MM-DD'), 'Expense', 'Dominos Pizza',                 'UPI');
INSERT INTO "Transaction" VALUES (27, 1, 18, 1500,   TO_TIMESTAMP('2026-04-18','YYYY-MM-DD'), 'Expense', 'Pharmacy - Medicines',          'UPI');

-- User 2 (Suryansh) - April 2026
INSERT INTO "Transaction" VALUES (11, 4, 1,  85000,  TO_TIMESTAMP('2026-04-01','YYYY-MM-DD'), 'Income',  'Monthly Salary - April',        'Bank Transfer');
INSERT INTO "Transaction" VALUES (12, 4, 5,  3800,   TO_TIMESTAMP('2026-04-04','YYYY-MM-DD'), 'Expense', 'DMart Groceries',               'UPI');
INSERT INTO "Transaction" VALUES (13, 5, 9,  450,    TO_TIMESTAMP('2026-04-05','YYYY-MM-DD'), 'Expense', 'Metro Card Recharge',           'Cash');
INSERT INTO "Transaction" VALUES (14, 4, 18, 2500,   TO_TIMESTAMP('2026-04-09','YYYY-MM-DD'), 'Expense', 'Doctor Visit',                  'UPI');
INSERT INTO "Transaction" VALUES (26, 4, 3,  5000,   TO_TIMESTAMP('2026-04-15','YYYY-MM-DD'), 'Income',  'Mutual Fund Dividend',          'Bank Transfer');

-- User 3 (Priya) - April 2026
INSERT INTO "Transaction" VALUES (15, 6, 1,  55000,  TO_TIMESTAMP('2026-04-01','YYYY-MM-DD'), 'Income',  'Monthly Salary',                'Bank Transfer');
INSERT INTO "Transaction" VALUES (16, 6, 6,  2200,   TO_TIMESTAMP('2026-04-06','YYYY-MM-DD'), 'Expense', 'Zomato Orders',                 'UPI');
INSERT INTO "Transaction" VALUES (17, 7, 9,  600,    TO_TIMESTAMP('2026-04-07','YYYY-MM-DD'), 'Expense', 'Ola Ride',                      'Wallet');
INSERT INTO "Transaction" VALUES (29, 6, 17, 6500,   TO_TIMESTAMP('2026-04-14','YYYY-MM-DD'), 'Expense', 'Myntra Shopping',               'UPI');

-- User 4 (Rahul) - April 2026
INSERT INTO "Transaction" VALUES (18, 8, 1,  65000,  TO_TIMESTAMP('2026-04-01','YYYY-MM-DD'), 'Income',  'Monthly Salary',                'Bank Transfer');
INSERT INTO "Transaction" VALUES (19, 8, 19, 12000,  TO_TIMESTAMP('2026-04-10','YYYY-MM-DD'), 'Expense', 'Online Course - Udemy',         'Debit Card');
INSERT INTO "Transaction" VALUES (20, 9, 17, 8900,   TO_TIMESTAMP('2026-04-11','YYYY-MM-DD'), 'Expense', 'Flipkart Electronics',          'Credit Card');
INSERT INTO "Transaction" VALUES (28, 8, 8,  4200,   TO_TIMESTAMP('2026-04-12','YYYY-MM-DD'), 'Expense', 'Petrol - Indian Oil',           'Debit Card');

-- User 5 (Ananya) - April 2026
INSERT INTO "Transaction" VALUES (21, 10, 1,  45000, TO_TIMESTAMP('2026-04-01','YYYY-MM-DD'), 'Income',  'Monthly Salary',                'Bank Transfer');
INSERT INTO "Transaction" VALUES (22, 10, 12, 199,   TO_TIMESTAMP('2026-04-05','YYYY-MM-DD'), 'Expense', 'Spotify Subscription',          'UPI');
INSERT INTO "Transaction" VALUES (30, 10, 6,  1800,  TO_TIMESTAMP('2026-04-19','YYYY-MM-DD'), 'Expense', 'Restaurant Dinner',             'UPI');

-- User 1 - Historical data (March, Feb, Jan 2026)
INSERT INTO "Transaction" VALUES (31, 1, 1,  75000,  TO_TIMESTAMP('2026-03-01','YYYY-MM-DD'), 'Income',  'Monthly Salary - March',        'Bank Transfer');
INSERT INTO "Transaction" VALUES (32, 1, 5,  5200,   TO_TIMESTAMP('2026-03-05','YYYY-MM-DD'), 'Expense', 'March Groceries',               'UPI');
INSERT INTO "Transaction" VALUES (33, 1, 16, 18000,  TO_TIMESTAMP('2026-03-05','YYYY-MM-DD'), 'Expense', 'March Rent',                    'Bank Transfer');
INSERT INTO "Transaction" VALUES (34, 1, 8,  4100,   TO_TIMESTAMP('2026-03-10','YYYY-MM-DD'), 'Expense', 'Petrol',                        'Debit Card');
INSERT INTO "Transaction" VALUES (35, 1, 1,  75000,  TO_TIMESTAMP('2026-02-01','YYYY-MM-DD'), 'Income',  'Monthly Salary - Feb',          'Bank Transfer');
INSERT INTO "Transaction" VALUES (36, 1, 5,  4800,   TO_TIMESTAMP('2026-02-06','YYYY-MM-DD'), 'Expense', 'Feb Groceries',                 'UPI');
INSERT INTO "Transaction" VALUES (37, 1, 1,  75000,  TO_TIMESTAMP('2026-01-01','YYYY-MM-DD'), 'Income',  'Monthly Salary - Jan',          'Bank Transfer');
INSERT INTO "Transaction" VALUES (38, 1, 6,  3200,   TO_TIMESTAMP('2026-01-10','YYYY-MM-DD'), 'Expense', 'Jan Restaurant',                'UPI');

-- ============================================================
-- INSERT BUDGETS (7 budgets)
-- ============================================================
INSERT INTO Budget VALUES (1, 1, 4,  8000,  'Monthly', TO_DATE('2026-04-01','YYYY-MM-DD'), TO_DATE('2026-04-30','YYYY-MM-DD'));
INSERT INTO Budget VALUES (2, 1, 7,  5000,  'Monthly', TO_DATE('2026-04-01','YYYY-MM-DD'), TO_DATE('2026-04-30','YYYY-MM-DD'));
INSERT INTO Budget VALUES (3, 1, 10, 3000,  'Monthly', TO_DATE('2026-04-01','YYYY-MM-DD'), TO_DATE('2026-04-30','YYYY-MM-DD'));
INSERT INTO Budget VALUES (4, 2, 4,  6000,  'Monthly', TO_DATE('2026-04-01','YYYY-MM-DD'), TO_DATE('2026-04-30','YYYY-MM-DD'));
INSERT INTO Budget VALUES (5, 1, 13, 5000,  'Monthly', TO_DATE('2026-04-01','YYYY-MM-DD'), TO_DATE('2026-04-30','YYYY-MM-DD'));
INSERT INTO Budget VALUES (6, 3, 17, 10000, 'Monthly', TO_DATE('2026-04-01','YYYY-MM-DD'), TO_DATE('2026-04-30','YYYY-MM-DD'));
INSERT INTO Budget VALUES (7, 1, 17, 8000,  'Monthly', TO_DATE('2026-04-01','YYYY-MM-DD'), TO_DATE('2026-04-30','YYYY-MM-DD'));

-- ============================================================
-- INSERT GOALS (6 goals)
-- ============================================================
INSERT INTO Goal VALUES (1, 1, 'Emergency Fund',     300000,  185400,  TO_DATE('2026-12-31','YYYY-MM-DD'), 'Active');
INSERT INTO Goal VALUES (2, 1, 'Goa Vacation',       50000,   32000,   TO_DATE('2026-06-15','YYYY-MM-DD'), 'Active');
INSERT INTO Goal VALUES (3, 2, 'New MacBook Pro',    200000,  200000,  TO_DATE('2026-08-01','YYYY-MM-DD'), 'Achieved');
INSERT INTO Goal VALUES (4, 3, 'Marriage Fund',      500000,  98700,   TO_DATE('2027-12-31','YYYY-MM-DD'), 'Active');
INSERT INTO Goal VALUES (5, 4, 'Home Down Payment',  1000000, 156000,  TO_DATE('2028-06-30','YYYY-MM-DD'), 'Active');
INSERT INTO Goal VALUES (6, 1, 'New Phone',          80000,   0,       TO_DATE('2026-03-01','YYYY-MM-DD'), 'Cancelled');

-- ============================================================
-- INSERT RECURRING TRANSACTIONS (7 entries)
-- ============================================================
INSERT INTO RecurringTransaction VALUES (1, 1, 1,  75000, 'Monthly', TO_DATE('2026-05-01','YYYY-MM-DD'), 'Monthly Salary Credit');
INSERT INTO RecurringTransaction VALUES (2, 2, 16, 18000, 'Monthly', TO_DATE('2026-05-05','YYYY-MM-DD'), 'Apartment Rent');
INSERT INTO RecurringTransaction VALUES (3, 1, 12, 649,   'Monthly', TO_DATE('2026-05-10','YYYY-MM-DD'), 'Netflix Subscription');
INSERT INTO RecurringTransaction VALUES (4, 1, 12, 199,   'Monthly', TO_DATE('2026-05-05','YYYY-MM-DD'), 'Spotify Premium');
INSERT INTO RecurringTransaction VALUES (5, 1, 15, 1199,  'Monthly', TO_DATE('2026-05-14','YYYY-MM-DD'), 'Jio Fiber Internet');
INSERT INTO RecurringTransaction VALUES (6, 4, 1,  85000, 'Monthly', TO_DATE('2026-05-01','YYYY-MM-DD'), 'Monthly Salary Credit');
INSERT INTO RecurringTransaction VALUES (7, 1, 18, 2500,  'Yearly',  TO_DATE('2027-01-15','YYYY-MM-DD'), 'Health Insurance Premium');

-- ============================================================
-- INSERT DEBTS (4 debts)
-- ============================================================
INSERT INTO Debt VALUES (1, 1, 'Education Loan - SBI',  500000,  8.50, 15243, TO_DATE('2024-01-01','YYYY-MM-DD'), TO_DATE('2027-01-01','YYYY-MM-DD'), 320000);
INSERT INTO Debt VALUES (2, 4, 'Car Loan - HDFC',       800000,  9.00, 18300, TO_DATE('2024-06-01','YYYY-MM-DD'), TO_DATE('2029-06-01','YYYY-MM-DD'), 695000);
INSERT INTO Debt VALUES (3, 2, 'Credit Card Debt',      50000,   36.00, 5500, TO_DATE('2026-01-01','YYYY-MM-DD'), TO_DATE('2026-12-01','YYYY-MM-DD'), 28400);
INSERT INTO Debt VALUES (4, 3, 'Personal Loan - Axis',  200000,  12.00, 9500, TO_DATE('2025-03-01','YYYY-MM-DD'), TO_DATE('2027-03-01','YYYY-MM-DD'), 142000);

-- ============================================================
-- INSERT TRANSACTION SPLITS (6 splits)
-- ============================================================
INSERT INTO TransactionSplit VALUES (1, 7,  17, 3600);  -- Amazon split: Shopping
INSERT INTO TransactionSplit VALUES (2, 7,  10, 2000);  -- Amazon split: Entertainment
INSERT INTO TransactionSplit VALUES (3, 20, 17, 5900);  -- Flipkart split: Shopping
INSERT INTO TransactionSplit VALUES (4, 20, 19, 3000);  -- Flipkart split: Education
INSERT INTO TransactionSplit VALUES (5, 29, 17, 4500);  -- Myntra split: Shopping
INSERT INTO TransactionSplit VALUES (6, 29, 4,  2000);  -- Myntra split: Food

COMMIT;

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================
SELECT 'Users: ' || COUNT(*) FROM "User";
SELECT 'Accounts: ' || COUNT(*) FROM Account;
SELECT 'Categories: ' || COUNT(*) FROM Category;
SELECT 'Transactions: ' || COUNT(*) FROM "Transaction";
SELECT 'Budgets: ' || COUNT(*) FROM Budget;
SELECT 'Goals: ' || COUNT(*) FROM Goal;
SELECT 'Recurring: ' || COUNT(*) FROM RecurringTransaction;
SELECT 'Debts: ' || COUNT(*) FROM Debt;
SELECT 'Splits: ' || COUNT(*) FROM TransactionSplit;
