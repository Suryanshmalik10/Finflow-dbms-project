-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 1_ER_Diagram.sql
-- Description: Entity-Relationship Diagram in Mermaid format
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

/*
============================================================
  FINFLOW ER DIAGRAM (Mermaid Syntax)
  Copy the block below into https://mermaid.live to render
============================================================

erDiagram
    USER {
        INT UserID PK
        VARCHAR Name
        VARCHAR Email UK
        VARCHAR Phone
        DATE DateOfBirth
        TIMESTAMP CreatedDate
    }

    ACCOUNT {
        INT AccountID PK
        INT UserID FK
        VARCHAR AccountName
        VARCHAR AccountType
        VARCHAR Currency
        DECIMAL CurrentBalance
        BOOLEAN IsActive
    }

    CATEGORY {
        INT CategoryID PK
        VARCHAR CategoryName
        INT ParentCategoryID FK
        VARCHAR CategoryType
    }

    TRANSACTION {
        INT TransactionID PK
        INT AccountID FK
        INT CategoryID FK
        DECIMAL Amount
        TIMESTAMP TransactionDate
        VARCHAR TransactionType
        VARCHAR Description
        VARCHAR PaymentMethod
    }

    BUDGET {
        INT BudgetID PK
        INT UserID FK
        INT CategoryID FK
        DECIMAL BudgetAmount
        VARCHAR Period
        DATE StartDate
        DATE EndDate
    }

    GOAL {
        INT GoalID PK
        INT UserID FK
        VARCHAR GoalName
        DECIMAL TargetAmount
        DECIMAL CurrentAmount
        DATE TargetDate
        VARCHAR Status
    }

    RECURRING_TRANSACTION {
        INT RecurringID PK
        INT AccountID FK
        INT CategoryID FK
        DECIMAL Amount
        VARCHAR Frequency
        DATE NextDueDate
        VARCHAR Description
    }

    DEBT {
        INT DebtID PK
        INT UserID FK
        VARCHAR DebtName
        DECIMAL PrincipalAmount
        DECIMAL InterestRate
        DECIMAL MonthlyEMI
        DATE StartDate
        DATE EndDate
        DECIMAL RemainingBalance
    }

    TRANSACTION_SPLIT {
        INT SplitID PK
        INT TransactionID FK
        INT CategoryID FK
        DECIMAL SplitAmount
    }

    AUDIT_LOG {
        INT LogID PK
        VARCHAR TableName
        VARCHAR OperationType
        INT RecordID
        CLOB OldValues
        CLOB NewValues
        VARCHAR ChangedBy
        TIMESTAMP ChangeTimestamp
    }

    USER ||--o{ ACCOUNT : "owns (1:M)"
    USER ||--o{ BUDGET : "sets (1:M)"
    USER ||--o{ GOAL : "defines (1:M)"
    USER ||--o{ DEBT : "has (1:M)"
    ACCOUNT ||--o{ TRANSACTION : "contains (1:M)"
    ACCOUNT ||--o{ RECURRING_TRANSACTION : "schedules (1:M)"
    CATEGORY ||--o{ TRANSACTION : "classifies (1:M)"
    CATEGORY ||--o{ BUDGET : "targets (1:M)"
    CATEGORY ||--o{ RECURRING_TRANSACTION : "categorizes (1:M)"
    CATEGORY ||--o{ TRANSACTION_SPLIT : "allocates (1:M)"
    CATEGORY |o--o{ CATEGORY : "parent-child (0..1:M)"
    TRANSACTION ||--o{ TRANSACTION_SPLIT : "splits into (1:M)"

*/

-- ============================================================
-- TEXTUAL ER DESCRIPTION
-- ============================================================

-- ENTITIES & RELATIONSHIPS:
--
-- 1. USER (1) ────── (M) ACCOUNT
--    A user can own multiple financial accounts.
--    Each account belongs to exactly one user.
--
-- 2. USER (1) ────── (M) BUDGET
--    A user can set multiple budgets for different categories.
--    Each budget is created by exactly one user.
--
-- 3. USER (1) ────── (M) GOAL
--    A user can define multiple financial goals.
--    Each goal belongs to exactly one user.
--
-- 4. USER (1) ────── (M) DEBT
--    A user can have multiple debts/loans.
--    Each debt record belongs to exactly one user.
--
-- 5. ACCOUNT (1) ────── (M) TRANSACTION
--    Each account can have many transactions.
--    Each transaction belongs to exactly one account.
--
-- 6. ACCOUNT (1) ────── (M) RECURRING_TRANSACTION
--    Each account can have multiple recurring payments.
--    Each recurring entry is linked to one account.
--
-- 7. CATEGORY (1) ────── (M) TRANSACTION
--    A category can classify many transactions.
--    Each transaction belongs to one category.
--
-- 8. CATEGORY (1) ────── (M) BUDGET
--    A category can be targeted by many budgets.
--    Each budget targets one specific category.
--
-- 9. CATEGORY (1) ────── (M) RECURRING_TRANSACTION
--    A category can be linked to many recurring items.
--    Each recurring transaction has one category.
--
-- 10. CATEGORY (1) ────── (M) TRANSACTION_SPLIT
--     A category can appear in many split allocations.
--     Each split row references one category.
--
-- 11. CATEGORY (0..1) ────── (M) CATEGORY  [Self-Referencing]
--     A category can optionally have a parent category.
--     A parent category can have many child categories.
--     Example: Food -> Groceries, Food -> Restaurants
--
-- 12. TRANSACTION (1) ────── (M) TRANSACTION_SPLIT
--     A transaction can be split across multiple categories.
--     Each split row belongs to exactly one transaction.
--
-- PARTICIPATION CONSTRAINTS:
--   - USER participation in ACCOUNT is optional (user may have 0 accounts)
--   - ACCOUNT participation in TRANSACTION is optional (account may have 0 txns)
--   - CATEGORY participation in TRANSACTION is optional (unused categories allowed)
--   - All FK references use mandatory participation on the child side
--
-- KEY ATTRIBUTES:
--   - Primary Keys: UserID, AccountID, CategoryID, TransactionID,
--                   BudgetID, GoalID, RecurringID, DebtID, SplitID, LogID
--   - Candidate Key: User.Email (UNIQUE, can identify a user)
--   - Foreign Keys: Marked with FK in the Mermaid diagram above
