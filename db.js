// ============================================
// FINFLOW: Database Module (SQLite via sql.js)
// ============================================
const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'finflow.db');
let db = null;

async function initDB() {
    const SQL = await initSqlJs();

    // Load existing DB or create new
    if (fs.existsSync(DB_PATH)) {
        const buffer = fs.readFileSync(DB_PATH);
        db = new SQL.Database(buffer);
    } else {
        db = new SQL.Database();
    }

    // Enable WAL mode for better performance
    db.run("PRAGMA journal_mode=WAL;");
    db.run("PRAGMA foreign_keys=ON;");

    // Create tables
    db.run(`CREATE TABLE IF NOT EXISTS User (
        UserID INTEGER PRIMARY KEY AUTOINCREMENT,
        Name VARCHAR(100) NOT NULL,
        Email VARCHAR(150) NOT NULL UNIQUE,
        Password VARCHAR(255) NOT NULL,
        Phone VARCHAR(15),
        DateOfBirth DATE,
        CreatedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS Account (
        AccountID INTEGER PRIMARY KEY AUTOINCREMENT,
        UserID INTEGER NOT NULL,
        AccountName VARCHAR(100) NOT NULL,
        AccountType VARCHAR(20) NOT NULL CHECK(AccountType IN ('Savings','Checking','CreditCard','Cash','Wallet')),
        Currency VARCHAR(3) DEFAULT 'INR',
        CurrentBalance DECIMAL(15,2) DEFAULT 0.00,
        IsActive INTEGER DEFAULT 1,
        FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS Category (
        CategoryID INTEGER PRIMARY KEY AUTOINCREMENT,
        CategoryName VARCHAR(50) NOT NULL,
        ParentCategoryID INTEGER,
        CategoryType VARCHAR(10) NOT NULL CHECK(CategoryType IN ('Income','Expense')),
        FOREIGN KEY (ParentCategoryID) REFERENCES Category(CategoryID) ON DELETE SET NULL
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS "Transaction" (
        TransactionID INTEGER PRIMARY KEY AUTOINCREMENT,
        AccountID INTEGER NOT NULL,
        CategoryID INTEGER NOT NULL,
        Amount DECIMAL(15,2) NOT NULL CHECK(Amount > 0),
        TransactionDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        TransactionType VARCHAR(10) NOT NULL CHECK(TransactionType IN ('Income','Expense','Transfer')),
        Description VARCHAR(255),
        PaymentMethod VARCHAR(30),
        FOREIGN KEY (AccountID) REFERENCES Account(AccountID) ON DELETE CASCADE,
        FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID)
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS Budget (
        BudgetID INTEGER PRIMARY KEY AUTOINCREMENT,
        UserID INTEGER NOT NULL,
        CategoryID INTEGER NOT NULL,
        BudgetAmount DECIMAL(15,2) NOT NULL CHECK(BudgetAmount > 0),
        Period VARCHAR(10) NOT NULL CHECK(Period IN ('Monthly','Yearly')),
        StartDate DATE NOT NULL,
        EndDate DATE NOT NULL,
        FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE,
        FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID)
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS Goal (
        GoalID INTEGER PRIMARY KEY AUTOINCREMENT,
        UserID INTEGER NOT NULL,
        GoalName VARCHAR(100) NOT NULL,
        TargetAmount DECIMAL(15,2) NOT NULL,
        CurrentAmount DECIMAL(15,2) DEFAULT 0.00,
        TargetDate DATE NOT NULL,
        Status VARCHAR(15) DEFAULT 'Active' CHECK(Status IN ('Active','Achieved','Cancelled')),
        FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS RecurringTransaction (
        RecurringID INTEGER PRIMARY KEY AUTOINCREMENT,
        AccountID INTEGER NOT NULL,
        CategoryID INTEGER NOT NULL,
        Amount DECIMAL(15,2) NOT NULL CHECK(Amount > 0),
        Frequency VARCHAR(10) NOT NULL CHECK(Frequency IN ('Daily','Weekly','Monthly','Yearly')),
        NextDueDate DATE NOT NULL,
        Description VARCHAR(255),
        FOREIGN KEY (AccountID) REFERENCES Account(AccountID) ON DELETE CASCADE,
        FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID)
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS Debt (
        DebtID INTEGER PRIMARY KEY AUTOINCREMENT,
        UserID INTEGER NOT NULL,
        DebtName VARCHAR(100) NOT NULL,
        PrincipalAmount DECIMAL(15,2) NOT NULL,
        InterestRate DECIMAL(5,2) NOT NULL,
        MonthlyEMI DECIMAL(15,2) NOT NULL,
        StartDate DATE NOT NULL,
        EndDate DATE NOT NULL,
        RemainingBalance DECIMAL(15,2) NOT NULL,
        FOREIGN KEY (UserID) REFERENCES User(UserID) ON DELETE CASCADE
    )`);

    db.run(`CREATE TABLE IF NOT EXISTS AuditLog (
        LogID INTEGER PRIMARY KEY AUTOINCREMENT,
        TableName VARCHAR(50),
        OperationType VARCHAR(10),
        RecordID INTEGER,
        OldValues TEXT,
        NewValues TEXT,
        ChangedBy VARCHAR(100),
        ChangeTimestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`);

    // Indexes
    db.run("CREATE INDEX IF NOT EXISTS idx_account_user ON Account(UserID)");
    db.run("CREATE INDEX IF NOT EXISTS idx_txn_account ON \"Transaction\"(AccountID)");
    db.run("CREATE INDEX IF NOT EXISTS idx_txn_date ON \"Transaction\"(TransactionDate)");
    db.run("CREATE INDEX IF NOT EXISTS idx_budget_user ON Budget(UserID)");
    db.run("CREATE INDEX IF NOT EXISTS idx_goal_user ON Goal(UserID)");
    db.run("CREATE INDEX IF NOT EXISTS idx_debt_user ON Debt(UserID)");

    // Seed categories if empty
    const catCount = db.exec("SELECT COUNT(*) FROM Category");
    if (catCount[0].values[0][0] === 0) {
        seedCategories();
    }

    saveDB();
    console.log('Database initialized successfully');
    return db;
}

function seedCategories() {
    const cats = [
        [1,'Salary',null,'Income'],[2,'Freelance',null,'Income'],[3,'Investments',null,'Income'],
        [4,'Food',null,'Expense'],[5,'Groceries',4,'Expense'],[6,'Restaurants',4,'Expense'],
        [7,'Transport',null,'Expense'],[8,'Fuel',7,'Expense'],[9,'Public Transit',7,'Expense'],
        [10,'Entertainment',null,'Expense'],[11,'Movies',10,'Expense'],[12,'Subscriptions',10,'Expense'],
        [13,'Utilities',null,'Expense'],[14,'Electricity',13,'Expense'],[15,'Internet',13,'Expense'],
        [16,'Rent',null,'Expense'],[17,'Shopping',null,'Expense'],[18,'Healthcare',null,'Expense'],
        [19,'Education',null,'Expense'],[20,'Transfer',null,'Income']
    ];
    const stmt = db.prepare("INSERT OR IGNORE INTO Category VALUES (?,?,?,?)");
    cats.forEach(c => { stmt.bind(c); stmt.step(); stmt.reset(); });
    stmt.free();
}

function saveDB() {
    const data = db.export();
    const buffer = Buffer.from(data);
    fs.writeFileSync(DB_PATH, buffer);
}

function getDB() { return db; }

module.exports = { initDB, getDB, saveDB };
