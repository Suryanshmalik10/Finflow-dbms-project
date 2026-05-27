-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 3_DDL_CreateTables.sql
-- Description: All CREATE TABLE, INDEX statements
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

-- ============================================================
-- DROP TABLES (Reverse dependency order to avoid FK errors)
-- ============================================================
DROP TABLE IF EXISTS AuditLog;
DROP TABLE IF EXISTS TransactionSplit;
DROP TABLE IF EXISTS RecurringTransaction;
DROP TABLE IF EXISTS Debt;
DROP TABLE IF EXISTS Goal;
DROP TABLE IF EXISTS Budget;
DROP TABLE IF EXISTS Transaction;
-- MySQL: DROP TABLE IF EXISTS `Transaction`;
DROP TABLE IF EXISTS Account;
DROP TABLE IF EXISTS Category;
DROP TABLE IF EXISTS "User";
-- MySQL: DROP TABLE IF EXISTS `User`;

-- ============================================================
-- Oracle Sequences (AUTO_INCREMENT equivalent)
-- MySQL/PostgreSQL use AUTO_INCREMENT / SERIAL instead
-- ============================================================
DROP SEQUENCE IF EXISTS seq_user_id;
DROP SEQUENCE IF EXISTS seq_account_id;
DROP SEQUENCE IF EXISTS seq_category_id;
DROP SEQUENCE IF EXISTS seq_transaction_id;
DROP SEQUENCE IF EXISTS seq_budget_id;
DROP SEQUENCE IF EXISTS seq_goal_id;
DROP SEQUENCE IF EXISTS seq_recurring_id;
DROP SEQUENCE IF EXISTS seq_debt_id;
DROP SEQUENCE IF EXISTS seq_split_id;
DROP SEQUENCE IF EXISTS seq_audit_id;

CREATE SEQUENCE seq_user_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_account_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_category_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_transaction_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_budget_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_goal_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_recurring_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_debt_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_split_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_audit_id START WITH 1 INCREMENT BY 1;

-- ============================================================
-- TABLE 1: User
-- Central entity storing user profiles
-- ============================================================
CREATE TABLE "User" (
    UserID          NUMBER(10)      DEFAULT seq_user_id.NEXTVAL PRIMARY KEY,
    Name            VARCHAR2(100)   NOT NULL,
    Email           VARCHAR2(150)   NOT NULL UNIQUE,
    Phone           VARCHAR2(15),
    DateOfBirth     DATE,
    CreatedDate     TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);
-- MySQL equivalent:
-- CREATE TABLE User (
--     UserID INT PRIMARY KEY AUTO_INCREMENT,
--     Name VARCHAR(100) NOT NULL,
--     Email VARCHAR(150) NOT NULL UNIQUE,
--     Phone VARCHAR(15),
--     DateOfBirth DATE,
--     CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
-- );

-- ============================================================
-- TABLE 2: Account
-- Represents financial accounts (Savings, Checking, etc.)
-- ============================================================
CREATE TABLE Account (
    AccountID       NUMBER(10)      DEFAULT seq_account_id.NEXTVAL PRIMARY KEY,
    UserID          NUMBER(10)      NOT NULL,
    AccountName     VARCHAR2(100)   NOT NULL,
    AccountType     VARCHAR2(20)    NOT NULL,
    Currency        VARCHAR2(3)     DEFAULT 'INR',
    CurrentBalance  NUMBER(15,2)    DEFAULT 0.00,
    IsActive        NUMBER(1)       DEFAULT 1,  -- Oracle has no BOOLEAN; 1=TRUE, 0=FALSE
    CONSTRAINT fk_account_user FOREIGN KEY (UserID)
        REFERENCES "User"(UserID) ON DELETE CASCADE,
    CONSTRAINT chk_account_type CHECK (
        AccountType IN ('Savings', 'Checking', 'CreditCard', 'Cash', 'Wallet')
    )
);
-- MySQL: IsActive BOOLEAN DEFAULT TRUE

-- ============================================================
-- TABLE 3: Category
-- Hierarchical income/expense categories (self-referencing)
-- ============================================================
CREATE TABLE Category (
    CategoryID          NUMBER(10)      DEFAULT seq_category_id.NEXTVAL PRIMARY KEY,
    CategoryName        VARCHAR2(50)    NOT NULL,
    ParentCategoryID    NUMBER(10),
    CategoryType        VARCHAR2(10)    NOT NULL,
    CONSTRAINT fk_category_parent FOREIGN KEY (ParentCategoryID)
        REFERENCES Category(CategoryID) ON DELETE SET NULL,
    CONSTRAINT chk_category_type CHECK (
        CategoryType IN ('Income', 'Expense')
    )
);

-- ============================================================
-- TABLE 4: Transaction
-- Records every financial activity
-- ============================================================
CREATE TABLE "Transaction" (
    TransactionID   NUMBER(10)      DEFAULT seq_transaction_id.NEXTVAL PRIMARY KEY,
    AccountID       NUMBER(10)      NOT NULL,
    CategoryID      NUMBER(10)      NOT NULL,
    Amount          NUMBER(15,2)    NOT NULL,
    TransactionDate TIMESTAMP       DEFAULT CURRENT_TIMESTAMP NOT NULL,
    TransactionType VARCHAR2(10)    NOT NULL,
    Description     VARCHAR2(255),
    PaymentMethod   VARCHAR2(30),
    CONSTRAINT fk_txn_account FOREIGN KEY (AccountID)
        REFERENCES Account(AccountID) ON DELETE CASCADE,
    CONSTRAINT fk_txn_category FOREIGN KEY (CategoryID)
        REFERENCES Category(CategoryID) ON DELETE RESTRICT,
    CONSTRAINT chk_txn_amount CHECK (Amount > 0),
    CONSTRAINT chk_txn_type CHECK (
        TransactionType IN ('Income', 'Expense', 'Transfer')
    )
);
-- MySQL: use backticks for `Transaction` (reserved word)

-- ============================================================
-- TABLE 5: Budget
-- Per-category spending limits
-- ============================================================
CREATE TABLE Budget (
    BudgetID        NUMBER(10)      DEFAULT seq_budget_id.NEXTVAL PRIMARY KEY,
    UserID          NUMBER(10)      NOT NULL,
    CategoryID      NUMBER(10)      NOT NULL,
    BudgetAmount    NUMBER(15,2)    NOT NULL,
    Period          VARCHAR2(10)    NOT NULL,
    StartDate       DATE            NOT NULL,
    EndDate         DATE            NOT NULL,
    CONSTRAINT fk_budget_user FOREIGN KEY (UserID)
        REFERENCES "User"(UserID) ON DELETE CASCADE,
    CONSTRAINT fk_budget_category FOREIGN KEY (CategoryID)
        REFERENCES Category(CategoryID) ON DELETE RESTRICT,
    CONSTRAINT chk_budget_amount CHECK (BudgetAmount > 0),
    CONSTRAINT chk_budget_period CHECK (
        Period IN ('Monthly', 'Yearly')
    ),
    CONSTRAINT chk_budget_dates CHECK (StartDate <= EndDate)
);

-- ============================================================
-- TABLE 6: Goal
-- Financial targets with deadlines
-- ============================================================
CREATE TABLE Goal (
    GoalID          NUMBER(10)      DEFAULT seq_goal_id.NEXTVAL PRIMARY KEY,
    UserID          NUMBER(10)      NOT NULL,
    GoalName        VARCHAR2(100)   NOT NULL,
    TargetAmount    NUMBER(15,2)    NOT NULL,
    CurrentAmount   NUMBER(15,2)    DEFAULT 0.00,
    TargetDate      DATE            NOT NULL,
    Status          VARCHAR2(15)    DEFAULT 'Active',
    CONSTRAINT fk_goal_user FOREIGN KEY (UserID)
        REFERENCES "User"(UserID) ON DELETE CASCADE,
    CONSTRAINT chk_goal_status CHECK (
        Status IN ('Active', 'Achieved', 'Cancelled')
    )
);

-- ============================================================
-- TABLE 7: RecurringTransaction
-- Automated recurring payments (salary, rent, etc.)
-- ============================================================
CREATE TABLE RecurringTransaction (
    RecurringID     NUMBER(10)      DEFAULT seq_recurring_id.NEXTVAL PRIMARY KEY,
    AccountID       NUMBER(10)      NOT NULL,
    CategoryID      NUMBER(10)      NOT NULL,
    Amount          NUMBER(15,2)    NOT NULL,
    Frequency       VARCHAR2(10)    NOT NULL,
    NextDueDate     DATE            NOT NULL,
    Description     VARCHAR2(255),
    CONSTRAINT fk_recurring_account FOREIGN KEY (AccountID)
        REFERENCES Account(AccountID) ON DELETE CASCADE,
    CONSTRAINT fk_recurring_category FOREIGN KEY (CategoryID)
        REFERENCES Category(CategoryID) ON DELETE RESTRICT,
    CONSTRAINT chk_recurring_amount CHECK (Amount > 0),
    CONSTRAINT chk_recurring_freq CHECK (
        Frequency IN ('Daily', 'Weekly', 'Monthly', 'Yearly')
    )
);

-- ============================================================
-- TABLE 8: Debt
-- Loans with EMI calculations
-- ============================================================
CREATE TABLE Debt (
    DebtID              NUMBER(10)      DEFAULT seq_debt_id.NEXTVAL PRIMARY KEY,
    UserID              NUMBER(10)      NOT NULL,
    DebtName            VARCHAR2(100)   NOT NULL,
    PrincipalAmount     NUMBER(15,2)    NOT NULL,
    InterestRate        NUMBER(5,2)     NOT NULL,
    MonthlyEMI          NUMBER(15,2)    NOT NULL,
    StartDate           DATE            NOT NULL,
    EndDate             DATE            NOT NULL,
    RemainingBalance    NUMBER(15,2)    NOT NULL,
    CONSTRAINT fk_debt_user FOREIGN KEY (UserID)
        REFERENCES "User"(UserID) ON DELETE CASCADE,
    CONSTRAINT chk_debt_dates CHECK (StartDate <= EndDate)
);

-- ============================================================
-- TABLE 9: TransactionSplit
-- Splits a single transaction across multiple categories
-- ============================================================
CREATE TABLE TransactionSplit (
    SplitID         NUMBER(10)      DEFAULT seq_split_id.NEXTVAL PRIMARY KEY,
    TransactionID   NUMBER(10)      NOT NULL,
    CategoryID      NUMBER(10)      NOT NULL,
    SplitAmount     NUMBER(15,2)    NOT NULL,
    CONSTRAINT fk_split_txn FOREIGN KEY (TransactionID)
        REFERENCES "Transaction"(TransactionID) ON DELETE CASCADE,
    CONSTRAINT fk_split_category FOREIGN KEY (CategoryID)
        REFERENCES Category(CategoryID) ON DELETE RESTRICT,
    CONSTRAINT chk_split_amount CHECK (SplitAmount > 0)
);

-- ============================================================
-- TABLE 10: AuditLog (for trigger trg_LogAudit)
-- Tracks all changes to Transaction table
-- ============================================================
CREATE TABLE AuditLog (
    LogID           NUMBER(10)      DEFAULT seq_audit_id.NEXTVAL PRIMARY KEY,
    TableName       VARCHAR2(50)    NOT NULL,
    OperationType   VARCHAR2(10)    NOT NULL,  -- INSERT, UPDATE, DELETE
    RecordID        NUMBER(10),
    OldValues       CLOB,
    NewValues       CLOB,
    ChangedBy       VARCHAR2(100)   DEFAULT USER,
    ChangeTimestamp  TIMESTAMP       DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- INDEXES for performance optimization
-- ============================================================

-- Account lookups by user
CREATE INDEX idx_account_userid ON Account(UserID);

-- Transaction lookups by account, date, and category
CREATE INDEX idx_txn_accountid ON "Transaction"(AccountID);
CREATE INDEX idx_txn_date ON "Transaction"(TransactionDate);
CREATE INDEX idx_txn_categoryid ON "Transaction"(CategoryID);

-- Budget lookups by user and category
CREATE INDEX idx_budget_user_cat ON Budget(UserID, CategoryID);

-- Goal lookups by user
CREATE INDEX idx_goal_userid ON Goal(UserID);

-- Recurring lookups by next due date
CREATE INDEX idx_recurring_duedate ON RecurringTransaction(NextDueDate);

-- Debt lookups by user
CREATE INDEX idx_debt_userid ON Debt(UserID);

-- Audit log lookups
CREATE INDEX idx_audit_timestamp ON AuditLog(ChangeTimestamp);

-- ============================================================
-- VERIFICATION: Display all created objects
-- ============================================================
SELECT table_name FROM user_tables ORDER BY table_name;
-- MySQL: SHOW TABLES;
