-- ============================================
-- FINFLOW: Personal Finance Management System
-- File: 2_Normalization.sql
-- Description: Normalization proof (1NF to BCNF)
-- Authors: Suryansh Malik (1024170308), Tanmay Agarwal (1024170309)
-- Course: UCS310 - Database Management System
-- Instructor: Ms. Tanya Garg
-- ============================================

/*
================================================================
  NORMALIZATION PROOF FOR FINFLOW DATABASE
================================================================

================================================================
  SECTION 1: FUNCTIONAL DEPENDENCIES
================================================================

FD1:  UserID        -> Name, Email, Phone, DateOfBirth, CreatedDate
FD2:  Email         -> UserID, Name, Phone, DateOfBirth, CreatedDate  (Candidate Key)
FD3:  AccountID     -> UserID, AccountName, AccountType, Currency, CurrentBalance, IsActive
FD4:  TransactionID -> AccountID, CategoryID, Amount, TransactionDate, TransactionType, Description, PaymentMethod
FD5:  CategoryID    -> CategoryName, ParentCategoryID, CategoryType
FD6:  BudgetID      -> UserID, CategoryID, BudgetAmount, Period, StartDate, EndDate
FD7:  GoalID        -> UserID, GoalName, TargetAmount, CurrentAmount, TargetDate, Status
FD8:  RecurringID   -> AccountID, CategoryID, Amount, Frequency, NextDueDate, Description
FD9:  DebtID        -> UserID, DebtName, PrincipalAmount, InterestRate, MonthlyEMI, StartDate, EndDate, RemainingBalance
FD10: SplitID       -> TransactionID, CategoryID, SplitAmount

================================================================
  SECTION 2: FIRST NORMAL FORM (1NF)
================================================================

REQUIREMENT: All column values must be atomic (indivisible). No repeating
             groups or multi-valued attributes.

PROOF:
  1. Every column in every table stores a single, atomic value.
     - User.Name stores one full name (not first + last in same field)
     - User.Phone stores one phone number (VARCHAR(15))
     - Account.AccountType stores one value from the allowed set

  2. Multi-category transactions are NOT stored as comma-separated values.
     VIOLATION AVOIDED: Instead of storing "Food,Transport,Shopping" in a
     single Transaction.Category column, we created the TransactionSplit
     table where each category gets its own row:
       SplitID=1, TransactionID=7, CategoryID=17, SplitAmount=3600
       SplitID=2, TransactionID=7, CategoryID=10, SplitAmount=2000

  3. No repeating groups exist. Each table has a fixed set of columns.

  4. Every table has a defined Primary Key ensuring unique identification.

  CONCLUSION: ALL TABLES SATISFY 1NF ✓

================================================================
  SECTION 3: SECOND NORMAL FORM (2NF)
================================================================

REQUIREMENT: Must be in 1NF, AND no partial dependencies.
             All non-key attributes must depend on the ENTIRE primary key.

PROOF:
  Since all our primary keys are single-column (surrogate keys like UserID,
  AccountID, TransactionID, etc.), partial dependency is IMPOSSIBLE.
  Partial dependencies only arise with composite primary keys.

  DETAILED ANALYSIS:

  1. USER TABLE: PK = {UserID}
     Name, Email, Phone, DateOfBirth -> ALL depend fully on UserID ✓

  2. ACCOUNT TABLE: PK = {AccountID}
     UserID, AccountName, AccountType, Currency, CurrentBalance, IsActive
     -> ALL depend fully on AccountID ✓
     Note: Category information is NOT stored here (would be partial dep)

  3. TRANSACTION TABLE: PK = {TransactionID}
     AccountID, CategoryID, Amount, TransactionDate, TransactionType,
     Description, PaymentMethod -> ALL depend fully on TransactionID ✓
     Note: CategoryName is NOT stored here (lives in Category table)
     Note: AccountName is NOT stored here (lives in Account table)

  4. CATEGORY TABLE: PK = {CategoryID}
     CategoryName, ParentCategoryID, CategoryType
     -> ALL depend fully on CategoryID ✓

  5. BUDGET TABLE: PK = {BudgetID}
     UserID, CategoryID, BudgetAmount, Period, StartDate, EndDate
     -> ALL depend fully on BudgetID ✓
     Note: We do NOT store UserName or CategoryName here

  6. TRANSACTIONSPLIT TABLE: PK = {SplitID}
     TransactionID, CategoryID, SplitAmount
     -> ALL depend fully on SplitID ✓

  CONCLUSION: ALL TABLES SATISFY 2NF ✓

================================================================
  SECTION 4: THIRD NORMAL FORM (3NF)
================================================================

REQUIREMENT: Must be in 2NF, AND no transitive dependencies.
             Non-key attributes must not depend on other non-key attributes.

PROOF:
  1. USER TABLE:
     No transitive dependency exists.
     Name, Email, Phone, DateOfBirth are all independent facts about the user.
     We do NOT store City and State together (State derivable from City
     would be transitive). Location data is excluded from scope. ✓

  2. ACCOUNT TABLE:
     CurrentBalance is technically derivable from SUM of transactions.
     This is a CONTROLLED DENORMALIZATION for performance reasons.
     JUSTIFICATION: Computing balance from thousands of transactions on
     every query would be prohibitively expensive. Instead, we store the
     balance and maintain consistency through database triggers:
       - trg_UpdateBalance_AfterInsert
       - trg_UpdateBalance_AfterUpdate
       - trg_UpdateBalance_AfterDelete
     This ensures the denormalized value stays synchronized. ✓

  3. TRANSACTION TABLE:
     No transitive dependency. We store CategoryID (FK) not CategoryName.
     If we stored CategoryName alongside CategoryID, then:
       CategoryID -> CategoryName (transitive through non-key)
     This is avoided by proper table separation. ✓

  4. CATEGORY TABLE:
     ParentCategoryID is a self-referencing FK, not a transitive dependency.
     It references another row in the same table. ✓

  5. DEBT TABLE:
     MonthlyEMI could be calculated from PrincipalAmount, InterestRate,
     and tenure (EndDate - StartDate). However, storing it is acceptable
     because:
     a) EMI is fixed at loan origination and does not change
     b) Recalculating would need the original amortization parameters
     c) It represents a contractual value, not a derived metric ✓

  CONCLUSION: ALL TABLES SATISFY 3NF ✓

================================================================
  SECTION 5: BOYCE-CODD NORMAL FORM (BCNF)
================================================================

REQUIREMENT: Must be in 3NF, AND for every non-trivial functional
             dependency X -> Y, X must be a superkey.

PROOF:
  1. USER TABLE:
     FD: UserID -> Name, Email, Phone, DateOfBirth  (UserID is PK/superkey) ✓
     FD: Email -> UserID, Name, Phone, DateOfBirth   (Email is candidate key/UNIQUE) ✓
     Both determinants are candidate keys. BCNF satisfied. ✓

  2. ACCOUNT TABLE:
     FD: AccountID -> all attributes  (AccountID is PK/superkey) ✓
     No other non-trivial FD exists. BCNF satisfied. ✓

  3. TRANSACTION TABLE:
     FD: TransactionID -> all attributes  (TransactionID is PK/superkey) ✓
     BCNF satisfied. ✓

  4. CATEGORY TABLE:
     FD: CategoryID -> CategoryName, ParentCategoryID, CategoryType ✓
     CategoryID is PK. BCNF satisfied. ✓

  5. RECURRING_TRANSACTION TABLE:
     FD: RecurringID -> all attributes ✓
     Frequency determines the LOGIC for calculating NextDueDate
     (Monthly -> add 1 month, Weekly -> add 7 days, etc.)
     However, this is PROCEDURAL logic handled in sp_ProcessRecurringTransactions,
     NOT a stored functional dependency. The Frequency value does not
     determine NextDueDate directly - NextDueDate is computed and updated
     by the procedure. BCNF satisfied. ✓

  6. All remaining tables (Budget, Goal, Debt, TransactionSplit):
     Each has a single-column PK that determines all other attributes.
     No additional non-trivial FDs exist. BCNF satisfied. ✓

  CONCLUSION: ALL TABLES SATISFY BCNF ✓

================================================================
  SECTION 6: SUMMARY
================================================================

  TABLE                  | 1NF | 2NF | 3NF | BCNF |
  -----------------------|-----|-----|-----|------|
  User                   |  ✓  |  ✓  |  ✓  |  ✓   |
  Account                |  ✓  |  ✓  |  ✓* |  ✓   |
  Category               |  ✓  |  ✓  |  ✓  |  ✓   |
  Transaction            |  ✓  |  ✓  |  ✓  |  ✓   |
  Budget                 |  ✓  |  ✓  |  ✓  |  ✓   |
  Goal                   |  ✓  |  ✓  |  ✓  |  ✓   |
  RecurringTransaction   |  ✓  |  ✓  |  ✓  |  ✓   |
  Debt                   |  ✓  |  ✓  |  ✓  |  ✓   |
  TransactionSplit       |  ✓  |  ✓  |  ✓  |  ✓   |

  * Account.CurrentBalance is a controlled denormalization maintained
    via triggers for performance optimization.

================================================================
*/
