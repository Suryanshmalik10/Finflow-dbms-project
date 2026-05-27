// ============================================
// FINFLOW: Express Server with Auth & API
// ============================================
const express = require('express');
const session = require('express-session');
const bcrypt = require('bcryptjs');
const path = require('path');
const { initDB, getDB, saveDB } = require('./db');

const app = express();
const PORT = 3000;

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname)));
app.use(session({
    secret: 'finflow-secret-key-2026',
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 24 * 60 * 60 * 1000 } // 24 hours
}));

// Auth middleware
function requireAuth(req, res, next) {
    if (!req.session.userId) return res.status(401).json({ error: 'Not authenticated' });
    next();
}

// Helper: run query and return results as array of objects
function queryAll(sql, params = []) {
    const db = getDB();
    const stmt = db.prepare(sql);
    if (params.length) stmt.bind(params);
    const rows = [];
    while (stmt.step()) rows.push(stmt.getAsObject());
    stmt.free();
    return rows;
}

function queryOne(sql, params = []) {
    const rows = queryAll(sql, params);
    return rows.length > 0 ? rows[0] : null;
}

function runSQL(sql, params = []) {
    const db = getDB();
    db.run(sql, params);
    saveDB();
}

// ==================== AUTH ROUTES ====================

app.post('/api/register', (req, res) => {
    try {
        const { name, email, password } = req.body;
        if (!name || !email || !password) return res.status(400).json({ error: 'All fields required' });
        if (password.length < 4) return res.status(400).json({ error: 'Password must be at least 4 characters' });

        const existing = queryOne("SELECT UserID FROM User WHERE Email = ?", [email]);
        if (existing) return res.status(400).json({ error: 'Email already registered' });

        const hash = bcrypt.hashSync(password, 10);
        runSQL("INSERT INTO User (Name, Email, Password) VALUES (?, ?, ?)", [name, email, hash]);

        const user = queryOne("SELECT UserID, Name, Email FROM User WHERE Email = ?", [email]);
        req.session.userId = user.UserID;
        req.session.userName = user.Name;

        res.json({ success: true, user: { id: user.UserID, name: user.Name, email: user.Email } });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/login', (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) return res.status(400).json({ error: 'Email and password required' });

        const user = queryOne("SELECT * FROM User WHERE Email = ?", [email]);
        if (!user) return res.status(401).json({ error: 'Invalid email or password' });

        if (!bcrypt.compareSync(password, user.Password)) {
            return res.status(401).json({ error: 'Invalid email or password' });
        }

        req.session.userId = user.UserID;
        req.session.userName = user.Name;
        res.json({ success: true, user: { id: user.UserID, name: user.Name, email: user.Email } });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/logout', (req, res) => {
    req.session.destroy();
    res.json({ success: true });
});

app.get('/api/me', (req, res) => {
    if (!req.session.userId) return res.json({ authenticated: false });
    const user = queryOne("SELECT UserID, Name, Email FROM User WHERE UserID = ?", [req.session.userId]);
    res.json({ authenticated: true, user: { id: user.UserID, name: user.Name, email: user.Email } });
});

// ==================== CATEGORIES (shared) ====================

app.get('/api/categories', requireAuth, (req, res) => {
    res.json(queryAll("SELECT * FROM Category ORDER BY CategoryType, CategoryName"));
});

// ==================== ACCOUNTS ====================

app.get('/api/accounts', requireAuth, (req, res) => {
    res.json(queryAll("SELECT * FROM Account WHERE UserID = ?", [req.session.userId]));
});

app.post('/api/accounts', requireAuth, (req, res) => {
    try {
        const { AccountName, AccountType, Currency, CurrentBalance } = req.body;
        if (!AccountName || !AccountType) return res.status(400).json({ error: 'Name and type required' });
        runSQL("INSERT INTO Account (UserID, AccountName, AccountType, Currency, CurrentBalance) VALUES (?,?,?,?,?)",
            [req.session.userId, AccountName, AccountType, Currency || 'INR', CurrentBalance || 0]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/accounts/:id', requireAuth, (req, res) => {
    runSQL("DELETE FROM Account WHERE AccountID = ? AND UserID = ?", [req.params.id, req.session.userId]);
    res.json({ success: true });
});

// ==================== TRANSACTIONS ====================

app.get('/api/transactions', requireAuth, (req, res) => {
    res.json(queryAll(`
        SELECT t.*, a.AccountName, c.CategoryName
        FROM "Transaction" t
        JOIN Account a ON t.AccountID = a.AccountID
        JOIN Category c ON t.CategoryID = c.CategoryID
        WHERE a.UserID = ?
        ORDER BY t.TransactionDate DESC`, [req.session.userId]));
});

app.post('/api/transactions', requireAuth, (req, res) => {
    try {
        const { AccountID, CategoryID, Amount, TransactionDate, TransactionType, Description, PaymentMethod } = req.body;
        if (!AccountID || !CategoryID || !Amount || !TransactionType) return res.status(400).json({ error: 'Missing fields' });

        // Verify account belongs to user
        const acct = queryOne("SELECT * FROM Account WHERE AccountID = ? AND UserID = ?", [AccountID, req.session.userId]);
        if (!acct) return res.status(403).json({ error: 'Account not found' });

        runSQL(`INSERT INTO "Transaction" (AccountID, CategoryID, Amount, TransactionDate, TransactionType, Description, PaymentMethod)
                VALUES (?,?,?,?,?,?,?)`,
            [AccountID, CategoryID, Amount, TransactionDate || new Date().toISOString(), TransactionType, Description || '', PaymentMethod || 'UPI']);

        // Update account balance
        if (TransactionType === 'Income') {
            runSQL("UPDATE Account SET CurrentBalance = CurrentBalance + ? WHERE AccountID = ?", [Amount, AccountID]);
        } else if (TransactionType === 'Expense') {
            runSQL("UPDATE Account SET CurrentBalance = CurrentBalance - ? WHERE AccountID = ?", [Amount, AccountID]);
        }

        // Audit log
        runSQL("INSERT INTO AuditLog (TableName, OperationType, ChangedBy) VALUES ('Transaction','INSERT',?)", [req.session.userName]);

        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/transactions/:id', requireAuth, (req, res) => {
    try {
        const txn = queryOne(`SELECT t.* FROM "Transaction" t JOIN Account a ON t.AccountID = a.AccountID
                              WHERE t.TransactionID = ? AND a.UserID = ?`, [req.params.id, req.session.userId]);
        if (!txn) return res.status(404).json({ error: 'Not found' });

        // Reverse balance effect
        if (txn.TransactionType === 'Income') {
            runSQL("UPDATE Account SET CurrentBalance = CurrentBalance - ? WHERE AccountID = ?", [txn.Amount, txn.AccountID]);
        } else if (txn.TransactionType === 'Expense') {
            runSQL("UPDATE Account SET CurrentBalance = CurrentBalance + ? WHERE AccountID = ?", [txn.Amount, txn.AccountID]);
        }

        runSQL('DELETE FROM "Transaction" WHERE TransactionID = ?', [req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ==================== BUDGETS ====================

app.get('/api/budgets', requireAuth, (req, res) => {
    res.json(queryAll(`SELECT b.*, c.CategoryName FROM Budget b
                       JOIN Category c ON b.CategoryID = c.CategoryID
                       WHERE b.UserID = ?`, [req.session.userId]));
});

app.post('/api/budgets', requireAuth, (req, res) => {
    try {
        const { CategoryID, BudgetAmount, Period, StartDate, EndDate } = req.body;
        if (!CategoryID || !BudgetAmount) return res.status(400).json({ error: 'Missing fields' });
        const sd = StartDate || new Date().toISOString().slice(0, 10);
        const ed = EndDate || new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).toISOString().slice(0, 10);
        runSQL("INSERT INTO Budget (UserID, CategoryID, BudgetAmount, Period, StartDate, EndDate) VALUES (?,?,?,?,?,?)",
            [req.session.userId, CategoryID, BudgetAmount, Period || 'Monthly', sd, ed]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/budgets/:id', requireAuth, (req, res) => {
    runSQL("DELETE FROM Budget WHERE BudgetID = ? AND UserID = ?", [req.params.id, req.session.userId]);
    res.json({ success: true });
});

// ==================== GOALS ====================

app.get('/api/goals', requireAuth, (req, res) => {
    res.json(queryAll("SELECT * FROM Goal WHERE UserID = ?", [req.session.userId]));
});

app.post('/api/goals', requireAuth, (req, res) => {
    try {
        const { GoalName, TargetAmount, CurrentAmount, TargetDate } = req.body;
        if (!GoalName || !TargetAmount || !TargetDate) return res.status(400).json({ error: 'Missing fields' });
        runSQL("INSERT INTO Goal (UserID, GoalName, TargetAmount, CurrentAmount, TargetDate) VALUES (?,?,?,?,?)",
            [req.session.userId, GoalName, TargetAmount, CurrentAmount || 0, TargetDate]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.put('/api/goals/:id', requireAuth, (req, res) => {
    try {
        const { CurrentAmount, Status } = req.body;
        if (CurrentAmount !== undefined) {
            runSQL("UPDATE Goal SET CurrentAmount = ? WHERE GoalID = ? AND UserID = ?",
                [CurrentAmount, req.params.id, req.session.userId]);
        }
        if (Status) {
            runSQL("UPDATE Goal SET Status = ? WHERE GoalID = ? AND UserID = ?",
                [Status, req.params.id, req.session.userId]);
        }
        saveDB();
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/goals/:id', requireAuth, (req, res) => {
    runSQL("DELETE FROM Goal WHERE GoalID = ? AND UserID = ?", [req.params.id, req.session.userId]);
    res.json({ success: true });
});

app.post('/api/goals/:id/contribute', requireAuth, (req, res) => {
    try {
        const { amount, accountId } = req.body;
        if (!amount || !accountId || amount <= 0) return res.status(400).json({ error: 'Invalid amount or account' });

        const goal = queryOne("SELECT * FROM Goal WHERE GoalID = ? AND UserID = ?", [req.params.id, req.session.userId]);
        if (!goal) return res.status(404).json({ error: 'Goal not found' });

        const acct = queryOne("SELECT * FROM Account WHERE AccountID = ? AND UserID = ?", [accountId, req.session.userId]);
        if (!acct) return res.status(404).json({ error: 'Account not found' });

        if (acct.AccountType !== 'CreditCard' && acct.CurrentBalance < amount) {
            return res.status(400).json({ error: 'Insufficient balance' });
        }

        // Increase goal amount (don't let it easily exceed target unless necessary, but we can allow it, let's just add it)
        const newAmount = goal.CurrentAmount + amount;
        
        // Auto-complete status if reached
        let statusUpdate = "";
        let params = [newAmount, req.params.id];
        if (newAmount >= goal.TargetAmount && goal.Status !== 'Achieved') {
            statusUpdate = ", Status = 'Achieved'";
        }
        
        runSQL(`UPDATE Goal SET CurrentAmount = ? ${statusUpdate} WHERE GoalID = ?`, params);

        // Find a default category
        let catId = 20; // Usually 'Transfer'
        const cat = queryOne("SELECT CategoryID FROM Category WHERE CategoryID = 20");
        if (!cat) {
            const expCat = queryOne("SELECT CategoryID FROM Category WHERE CategoryType = 'Expense' LIMIT 1");
            catId = expCat ? expCat.CategoryID : 1;
        }

        // Log the transaction
        runSQL(`INSERT INTO "Transaction" (AccountID, CategoryID, Amount, TransactionType, Description, PaymentMethod)
                VALUES (?,?,?,?,?,?)`,
            [accountId, catId, amount, 'Transfer', 'Goal Contribution: ' + goal.GoalName, 'Internal']);

        // Deduct from account balance
        runSQL("UPDATE Account SET CurrentBalance = CurrentBalance - ? WHERE AccountID = ?", [amount, accountId]);

        res.json({ success: true, newAmount });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ==================== DEBTS ====================

app.get('/api/debts', requireAuth, (req, res) => {
    res.json(queryAll("SELECT * FROM Debt WHERE UserID = ?", [req.session.userId]));
});

app.post('/api/debts', requireAuth, (req, res) => {
    try {
        const { DebtName, PrincipalAmount, InterestRate, MonthlyEMI, StartDate, EndDate, RemainingBalance } = req.body;
        if (!DebtName || !PrincipalAmount) return res.status(400).json({ error: 'Missing fields' });
        runSQL("INSERT INTO Debt (UserID, DebtName, PrincipalAmount, InterestRate, MonthlyEMI, StartDate, EndDate, RemainingBalance) VALUES (?,?,?,?,?,?,?,?)",
            [req.session.userId, DebtName, PrincipalAmount, InterestRate || 0, MonthlyEMI || 0,
             StartDate || new Date().toISOString().slice(0, 10), EndDate || '2030-01-01', RemainingBalance || PrincipalAmount]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/debts/:id', requireAuth, (req, res) => {
    runSQL("DELETE FROM Debt WHERE DebtID = ? AND UserID = ?", [req.params.id, req.session.userId]);
    res.json({ success: true });
});

app.post('/api/debts/:id/pay', requireAuth, (req, res) => {
    try {
        const { amount, accountId } = req.body;
        if (!amount || !accountId || amount <= 0) return res.status(400).json({ error: 'Invalid amount or account' });

        const debt = queryOne("SELECT * FROM Debt WHERE DebtID = ? AND UserID = ?", [req.params.id, req.session.userId]);
        if (!debt) return res.status(404).json({ error: 'Debt not found' });

        const acct = queryOne("SELECT * FROM Account WHERE AccountID = ? AND UserID = ?", [accountId, req.session.userId]);
        if (!acct) return res.status(404).json({ error: 'Account not found' });

        // Deduct from debt remaining balance
        const newBalance = Math.max(0, debt.RemainingBalance - amount);
        runSQL("UPDATE Debt SET RemainingBalance = ? WHERE DebtID = ?", [newBalance, req.params.id]);

        // Find a default expense category
        const cat = queryOne("SELECT CategoryID FROM Category WHERE CategoryType = 'Expense' LIMIT 1");
        const catId = cat ? cat.CategoryID : 1;

        // Log the expense transaction
        runSQL(`INSERT INTO "Transaction" (AccountID, CategoryID, Amount, TransactionType, Description, PaymentMethod)
                VALUES (?,?,?,?,?,?)`,
            [accountId, catId, amount, 'Expense', 'Payment: ' + debt.DebtName, 'Bank Transfer']);

        // Deduct from account balance
        runSQL("UPDATE Account SET CurrentBalance = CurrentBalance - ? WHERE AccountID = ?", [amount, accountId]);

        res.json({ success: true, newBalance });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ==================== RECURRING ====================

app.get('/api/recurring', requireAuth, (req, res) => {
    res.json(queryAll(`SELECT r.*, a.AccountName, c.CategoryName FROM RecurringTransaction r
                       JOIN Account a ON r.AccountID = a.AccountID
                       JOIN Category c ON r.CategoryID = c.CategoryID
                       WHERE a.UserID = ?`, [req.session.userId]));
});

app.post('/api/recurring', requireAuth, (req, res) => {
    try {
        const { AccountID, CategoryID, Amount, Frequency, NextDueDate, Description } = req.body;
        if (!AccountID || !CategoryID || !Amount) return res.status(400).json({ error: 'Missing fields' });
        runSQL("INSERT INTO RecurringTransaction (AccountID, CategoryID, Amount, Frequency, NextDueDate, Description) VALUES (?,?,?,?,?,?)",
            [AccountID, CategoryID, Amount, Frequency || 'Monthly', NextDueDate || new Date().toISOString().slice(0, 10), Description || '']);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/recurring/:id', requireAuth, (req, res) => {
    try {
        // Verify ownership through account
        const rec = queryOne(`SELECT r.* FROM RecurringTransaction r
                              JOIN Account a ON r.AccountID = a.AccountID
                              WHERE r.RecurringID = ? AND a.UserID = ?`, [req.params.id, req.session.userId]);
        if (!rec) return res.status(404).json({ error: 'Not found' });
        runSQL("DELETE FROM RecurringTransaction WHERE RecurringID = ?", [req.params.id]);
        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ==================== DASHBOARD STATS ====================

app.get('/api/stats', requireAuth, (req, res) => {
    const uid = req.session.userId;
    const now = new Date();
    const monthStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;

    const totalBalance = queryOne("SELECT COALESCE(SUM(CurrentBalance),0) as val FROM Account WHERE UserID=? AND IsActive=1", [uid]);
    const totalDebt = queryOne("SELECT COALESCE(SUM(RemainingBalance),0) as val FROM Debt WHERE UserID=?", [uid]);
    const monthIncome = queryOne(`SELECT COALESCE(SUM(t.Amount),0) as val FROM "Transaction" t
                                  JOIN Account a ON t.AccountID=a.AccountID
                                  WHERE a.UserID=? AND t.TransactionType='Income' AND t.TransactionDate>=?`, [uid, monthStart]);
    const monthExpense = queryOne(`SELECT COALESCE(SUM(t.Amount),0) as val FROM "Transaction" t
                                   JOIN Account a ON t.AccountID=a.AccountID
                                   WHERE a.UserID=? AND t.TransactionType='Expense' AND t.TransactionDate>=?`, [uid, monthStart]);

    res.json({
        netWorth: (totalBalance?.val || 0) - (totalDebt?.val || 0),
        totalBalance: totalBalance?.val || 0,
        totalDebt: totalDebt?.val || 0,
        monthlyIncome: monthIncome?.val || 0,
        monthlyExpenses: monthExpense?.val || 0,
        savingsRate: monthIncome?.val > 0 ? ((monthIncome.val - monthExpense.val) / monthIncome.val * 100) : 0
    });
});

// ==================== TRANSFER ====================

app.post('/api/transfer', requireAuth, (req, res) => {
    try {
        const { fromAccountID, toAccountID, amount } = req.body;
        if (!fromAccountID || !toAccountID || !amount || amount <= 0) return res.status(400).json({ error: 'Invalid transfer' });
        if (fromAccountID === toAccountID) return res.status(400).json({ error: 'Same account' });

        const from = queryOne("SELECT * FROM Account WHERE AccountID=? AND UserID=?", [fromAccountID, req.session.userId]);
        const to = queryOne("SELECT * FROM Account WHERE AccountID=? AND UserID=?", [toAccountID, req.session.userId]);
        if (!from || !to) return res.status(404).json({ error: 'Account not found' });
        if (from.AccountType !== 'CreditCard' && from.CurrentBalance < amount) {
            return res.status(400).json({ error: 'Insufficient balance' });
        }

        runSQL("UPDATE Account SET CurrentBalance = CurrentBalance - ? WHERE AccountID = ?", [amount, fromAccountID]);
        runSQL("UPDATE Account SET CurrentBalance = CurrentBalance + ? WHERE AccountID = ?", [amount, toAccountID]);
        runSQL(`INSERT INTO "Transaction" (AccountID,CategoryID,Amount,TransactionType,Description,PaymentMethod) VALUES (?,20,?,'Transfer',?,?)`,
            [fromAccountID, amount, 'Transfer to ' + to.AccountName, 'Internal']);
        runSQL(`INSERT INTO "Transaction" (AccountID,CategoryID,Amount,TransactionType,Description,PaymentMethod) VALUES (?,20,?,'Transfer',?,?)`,
            [toAccountID, amount, 'Transfer from ' + from.AccountName, 'Internal']);

        res.json({ success: true });
    } catch (e) { res.status(500).json({ error: e.message }); }
});

// ==================== START ====================

async function start() {
    await initDB();
    app.listen(PORT, () => {
        console.log(`\n  FinFlow server running at http://localhost:${PORT}\n`);
    });
}

start().catch(console.error);
