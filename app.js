/* FinFlow - Main App (API-driven) */
let categories = [];
let chartInstances = {};

// === API Helper ===
async function api(url, opts) {
    const res = await fetch(url, opts);
    if (res.status === 401) { handleLogout(); return null; }
    return res.json();
}
async function apiGet(url) { return api(url); }
async function apiPost(url, body) {
    return api(url, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body) });
}
async function apiDelete(url) { return api(url, { method:'DELETE' }); }

// === Format Helpers ===
const fmt = n => '₹' + Number(n||0).toLocaleString('en-IN');
const fmtDate = d => d ? new Date(d).toLocaleDateString('en-IN',{day:'numeric',month:'short',year:'numeric'}) : '';
function toast(msg, type='success') {
    const c = document.getElementById('toastContainer');
    const t = document.createElement('div');
    t.className = 'toast toast-' + type;
    t.textContent = msg;
    c.appendChild(t);
    setTimeout(() => t.remove(), 3000);
}

// === Navigation ===
function navigate(page) {
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    const el = document.getElementById('page-' + page);
    const nav = document.getElementById('nav-' + page);
    if (el) el.classList.add('active');
    if (nav) nav.classList.add('active');
    if (page === 'dashboard') loadDashboard();
    else if (page === 'accounts') loadAccounts();
    else if (page === 'transactions') loadTransactions();
    else if (page === 'budgets') loadBudgets();
    else if (page === 'goals') loadGoals();
    else if (page === 'debts') loadDebts();
    else if (page === 'recurring') loadRecurring();
    else if (page === 'analytics') loadAnalytics();
    else if (page === 'sqlfiles' && typeof renderSQLFileTabs === 'function') renderSQLFileTabs();
}

// === Dashboard ===
async function loadDashboard() {
    const [stats, txns, budgets, goals] = await Promise.all([
        apiGet('/api/stats'), apiGet('/api/transactions'), apiGet('/api/budgets'), apiGet('/api/goals')
    ]);
    if (!stats) return;
    document.querySelector('#statNetWorth .stat-value').textContent = fmt(stats.netWorth);
    document.querySelector('#statIncome .stat-value').textContent = fmt(stats.monthlyIncome);
    document.querySelector('#statExpenses .stat-value').textContent = fmt(stats.monthlyExpenses);
    document.querySelector('#statSavings .stat-value').textContent = (stats.savingsRate||0).toFixed(1) + '%';

    // Recent transactions
    const recent = document.getElementById('recentTransactions');
    recent.innerHTML = (txns||[]).slice(0, 6).map(t => `
        <div class="txn-item">
            <div class="txn-icon" style="background:${t.TransactionType==='Income'?'var(--success-bg)':'var(--danger-bg)'}; color:${t.TransactionType==='Income'?'var(--success)':'var(--danger)'}">
                <i class="fas fa-${t.TransactionType==='Income'?'arrow-down':'arrow-up'}"></i></div>
            <div class="txn-details"><div class="txn-desc">${t.Description||'Transaction'}</div><div class="txn-cat">${t.CategoryName||''}</div></div>
            <div><div class="txn-amount ${t.TransactionType==='Income'?'amount-positive':'amount-negative'}">${t.TransactionType==='Income'?'+':'−'}${fmt(t.Amount)}</div>
            <div class="txn-date">${fmtDate(t.TransactionDate)}</div></div>
        </div>`).join('') || '<p class="text-muted">No transactions yet.</p>';

    // Budget overview
    const bo = document.getElementById('budgetOverviewDash');
    if (budgets && budgets.length) {
        bo.innerHTML = budgets.slice(0,4).map(b => {
            const spent = (txns || []).filter(t => t.CategoryID === b.CategoryID && t.TransactionType === 'Expense' && (t.TransactionDate||'').slice(0,10) >= b.StartDate && (t.TransactionDate||'').slice(0,10) <= b.EndDate).reduce((sum, t) => sum + t.Amount, 0);
            const pct = Math.min(Math.round((spent / b.BudgetAmount) * 100), 100);
            const color = pct >= 90 ? 'var(--danger)' : pct >= 75 ? 'var(--warning)' : 'var(--success)';
            return `<div class="budget-mini"><div class="budget-mini-header"><span>${b.CategoryName}</span><span>${fmt(spent)} / ${fmt(b.BudgetAmount)}</span></div>
            <div class="budget-progress"><div class="budget-progress-bar" style="width:${pct}%;background:${color}"></div></div></div>`;
        }).join('');
    } else { bo.innerHTML = '<p class="text-muted">No budgets set yet.</p>'; }

    // Goals overview
    const go = document.getElementById('goalsOverviewDash');
    if (goals && goals.length) {
        go.innerHTML = goals.filter(g=>g.Status==='Active').slice(0,3).map(g => {
            const pct = Math.round((g.CurrentAmount/g.TargetAmount)*100);
            return `<div class="budget-mini"><div class="budget-mini-header"><span>${g.GoalName}</span><span>${pct}%</span></div>
            <div class="budget-progress"><div class="budget-progress-bar" style="width:${pct}%;background:var(--accent-light)"></div></div></div>`;
        }).join('');
    } else { go.innerHTML = '<p class="text-muted">No goals set yet.</p>'; }

    renderDashboardCharts(txns || []);
    loadNotifications();
}

function renderDashboardCharts(txns) {
    // Income vs Expense chart
    if (chartInstances.ie) chartInstances.ie.destroy();
    const months = {};
    txns.forEach(t => {
        const m = (t.TransactionDate||'').slice(0,7);
        if (!months[m]) months[m] = {income:0,expense:0};
        if (t.TransactionType==='Income') months[m].income += t.Amount;
        else if (t.TransactionType==='Expense') months[m].expense += t.Amount;
    });
    const labels = Object.keys(months).sort().slice(-6);
    const ctx1 = document.getElementById('incomeExpenseChart');
    if (ctx1) chartInstances.ie = new Chart(ctx1, {
        type:'bar', data: {
            labels: labels.map(l => { const d = new Date(l+'-01'); return d.toLocaleDateString('en-IN',{month:'short',year:'2-digit'}); }),
            datasets: [
                { label:'Income', data: labels.map(l=>months[l].income), backgroundColor:'rgba(0,206,201,0.7)' },
                { label:'Expenses', data: labels.map(l=>months[l].expense), backgroundColor:'rgba(255,107,107,0.7)' }
            ]
        }, options: { responsive:true, plugins:{legend:{labels:{color:'#8892b0'}}}, scales:{x:{ticks:{color:'#5a6380'}},y:{ticks:{color:'#5a6380',callback:v=>fmt(v)}}} }
    });

    // Category donut
    if (chartInstances.cat) chartInstances.cat.destroy();
    const catTotals = {};
    txns.filter(t=>t.TransactionType==='Expense').forEach(t => { catTotals[t.CategoryName] = (catTotals[t.CategoryName]||0) + t.Amount; });
    const sorted = Object.entries(catTotals).sort((a,b)=>b[1]-a[1]).slice(0,8);
    const colors = ['#6c5ce7','#00cec9','#ff6b6b','#feca57','#54a0ff','#a29bfe','#fd79a8','#55efc4'];
    const ctx2 = document.getElementById('categoryChart');
    if (ctx2 && sorted.length) chartInstances.cat = new Chart(ctx2, {
        type:'doughnut', data: { labels:sorted.map(s=>s[0]), datasets:[{data:sorted.map(s=>s[1]),backgroundColor:colors}] },
        options: { responsive:true, plugins:{legend:{position:'right',labels:{color:'#8892b0',padding:12}}} }
    });
}

// === Accounts ===
async function loadAccounts() {
    const accounts = await apiGet('/api/accounts');
    const grid = document.getElementById('accountsGrid');
    if (!accounts||!accounts.length) { grid.innerHTML='<p class="text-muted">No accounts yet. Add one!</p>'; return; }
    grid.innerHTML = accounts.map(a => `
        <div class="account-card">
            <div class="acct-status ${a.IsActive?'acct-active':'acct-inactive'}"></div>
            <span class="acct-type acct-${a.AccountType.toLowerCase().replace(' ','')}">${a.AccountType}</span>
            <div class="acct-name">${a.AccountName}</div>
            <div class="acct-balance ${a.CurrentBalance<0?'amount-negative':''}">${fmt(a.CurrentBalance)}</div>
            <button class="btn-danger" onclick="deleteAccount(${a.AccountID})" style="margin-top:0.5rem"><i class="fas fa-trash"></i> Delete</button>
        </div>`).join('');
}
async function deleteAccount(id) { await apiDelete('/api/accounts/'+id); toast('Account deleted'); loadAccounts(); loadDashboard(); }

// === Transactions ===
async function loadTransactions() {
    const [txns, accounts] = await Promise.all([apiGet('/api/transactions'), apiGet('/api/accounts')]);
    categories = await apiGet('/api/categories') || [];
    // Populate filters
    const fa = document.getElementById('filterAccount');
    fa.innerHTML = '<option value="">All Accounts</option>' + (accounts||[]).map(a=>`<option value="${a.AccountID}">${a.AccountName}</option>`).join('');
    const fc = document.getElementById('filterCategory');
    fc.innerHTML = '<option value="">All Categories</option>' + categories.map(c=>`<option value="${c.CategoryID}">${c.CategoryName}</option>`).join('');

    renderTransactions(txns||[]);
}
function renderTransactions(txns) {
    const fa = document.getElementById('filterAccount').value;
    const fc = document.getElementById('filterCategory').value;
    const ft = document.getElementById('filterType').value;
    let filtered = txns;
    if (fa) filtered = filtered.filter(t => t.AccountID == fa);
    if (fc) filtered = filtered.filter(t => t.CategoryID == fc);
    if (ft) filtered = filtered.filter(t => t.TransactionType === ft);
    const body = document.getElementById('transactionsBody');
    body.innerHTML = filtered.map(t => `<tr>
        <td>${fmtDate(t.TransactionDate)}</td><td>${t.Description||'-'}</td><td>${t.CategoryName||'-'}</td>
        <td>${t.AccountName||'-'}</td><td><span class="type-badge type-${t.TransactionType.toLowerCase()}">${t.TransactionType}</span></td>
        <td class="${t.TransactionType==='Income'?'amount-positive':'amount-negative'}">${t.TransactionType==='Income'?'+':'−'}${fmt(t.Amount)}</td>
        <td><button class="btn-icon" onclick="deleteTxn(${t.TransactionID})"><i class="fas fa-trash" style="color:var(--danger)"></i></button></td>
    </tr>`).join('') || '<tr><td colspan="7" class="text-muted">No transactions found.</td></tr>';
}
async function deleteTxn(id) { await apiDelete('/api/transactions/'+id); toast('Deleted'); loadTransactions(); }

// === Budgets ===
async function loadBudgets() {
    const [budgets, txns] = await Promise.all([apiGet('/api/budgets'), apiGet('/api/transactions')]);
    const grid = document.getElementById('budgetsGrid');
    if (!budgets||!budgets.length) { grid.innerHTML='<p class="text-muted">No budgets yet.</p>'; return; }
    grid.innerHTML = budgets.map(b => `
        <div class="budget-card">
            <div class="budget-cat">${b.CategoryName}</div>
            <div class="budget-period">${b.Period} · ${fmtDate(b.StartDate)} – ${fmtDate(b.EndDate)}</div>
            <div class="budget-amounts"><span>Limit: ${fmt(b.BudgetAmount)}</span></div>
            <button class="btn-danger" onclick="deleteBudget(${b.BudgetID})" style="margin-top:0.75rem"><i class="fas fa-trash"></i></button>
        </div>`).join('');
    
    renderBudgetChart(budgets, txns);
}

function renderBudgetChart(budgets, txns) {
    if (chartInstances.budget) chartInstances.budget.destroy();
    const ctx = document.getElementById('budgetCompareChart');
    if (!ctx || !budgets || !budgets.length) return;
    
    const labels = budgets.map(b => b.CategoryName);
    const budgetData = budgets.map(b => b.BudgetAmount);
    const spentData = budgets.map(b => {
        return (txns || []).filter(t => 
            t.CategoryID === b.CategoryID && 
            t.TransactionType === 'Expense' && 
            (t.TransactionDate||'').slice(0,10) >= b.StartDate && 
            (t.TransactionDate||'').slice(0,10) <= b.EndDate
        ).reduce((sum, t) => sum + t.Amount, 0);
    });

    chartInstances.budget = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [
                { label: 'Budget Limit', data: budgetData, backgroundColor: 'rgba(108, 92, 231, 0.7)' },
                { label: 'Actual Spent', data: spentData, backgroundColor: 'rgba(255, 107, 107, 0.7)' }
            ]
        },
        options: {
            responsive: true,
            plugins: { legend: { labels: { color: '#8892b0' } } },
            scales: {
                x: { ticks: { color: '#5a6380' } },
                y: { ticks: { color: '#5a6380', callback: v => '₹' + v } }
            }
        }
    });
}

async function deleteBudget(id) { await apiDelete('/api/budgets/'+id); toast('Deleted'); loadBudgets(); }

// === Goals ===
async function loadGoals() {
    const goals = await apiGet('/api/goals');
    const grid = document.getElementById('goalsGrid');
    if (!goals||!goals.length) { grid.innerHTML='<p class="text-muted">No goals yet.</p>'; return; }
    grid.innerHTML = goals.map(g => {
        const pct = Math.round((g.CurrentAmount/g.TargetAmount)*100);
        return `<div class="goal-card">
            <span class="goal-status status-${g.Status.toLowerCase()}">${g.Status}</span>
            <div class="goal-name">${g.GoalName}</div>
            <div class="goal-amount">${fmt(g.CurrentAmount)} <span style="font-size:0.8rem;color:var(--text-muted)">/ ${fmt(g.TargetAmount)}</span></div>
            <div class="budget-progress"><div class="budget-progress-bar" style="width:${Math.min(pct,100)}%;background:${pct>=100?'var(--success)':'var(--accent-light)'}"></div></div>
            <div class="goal-deadline">Due: ${fmtDate(g.TargetDate)} · ${pct}% complete</div>
            <div style="display:flex; gap:0.5rem; margin-top:0.5rem">
                ${g.Status !== 'Achieved' ? `<button class="btn-primary-sm" onclick="showContributeGoalModal(${g.GoalID}, '${g.GoalName.replace(/'/g, "\\'")}')">Add Funds</button>` : ''}
                <button class="btn-danger" onclick="deleteGoal(${g.GoalID})"><i class="fas fa-trash"></i></button>
            </div>
        </div>`;
    }).join('');
}

async function showContributeGoalModal(id, name) {
    const accounts = await apiGet('/api/accounts');
    if (!accounts || !accounts.length) { toast('Please add a bank account first', 'danger'); return; }
    const acctOpts = accounts.map(a => `<option value="${a.AccountID}">${a.AccountName} (${fmt(a.CurrentBalance)})</option>`).join('');
    
    showModal('Contribute to Goal: ' + name, `
        <div class="form-group"><label>Transfer From Account</label><select id="mContAcct">${acctOpts}</select></div>
        <div class="form-group"><label>Contribution Amount (₹)</label><input type="number" id="mContAmt" value="500" min="1"></div>
        <button class="btn-primary" onclick="submitGoalContribution(${id})">Confirm Contribution</button>`);
}

async function submitGoalContribution(id) {
    const amt = parseFloat(document.getElementById('mContAmt').value);
    const acctId = document.getElementById('mContAcct').value;
    if (!amt || !acctId) return;
    
    await apiPost('/api/goals/' + id + '/contribute', { amount: amt, accountId: acctId });
    closeModal();
    toast('Contribution successful!');
    loadGoals();
    loadAccounts();
    loadTransactions();
    loadDashboard();
}

async function deleteGoal(id) { await apiDelete('/api/goals/'+id); toast('Deleted'); loadGoals(); }

// === Debts ===
async function loadDebts() {
    const debts = await apiGet('/api/debts');
    const grid = document.getElementById('debtsGrid');
    if (!debts||!debts.length) { grid.innerHTML='<p class="text-muted">No debts recorded.</p>'; return; }
    grid.innerHTML = debts.map(d => `
        <div class="debt-card">
            <div class="debt-name">${d.DebtName}</div>
            <div class="debt-row"><span>Principal</span><span>${fmt(d.PrincipalAmount)}</span></div>
            <div class="debt-row"><span>Interest Rate</span><span>${d.InterestRate}%</span></div>
            <div class="debt-row"><span>Monthly EMI</span><span>${fmt(d.MonthlyEMI)}</span></div>
            <div class="debt-row"><span>Remaining</span><span class="amount-negative">${fmt(d.RemainingBalance)}</span></div>
            <div class="debt-row"><span>Duration</span><span>${fmtDate(d.StartDate)} – ${fmtDate(d.EndDate)}</span></div>
            <div style="display:flex; gap:0.5rem; margin-top:0.5rem">
                <button class="btn-primary-sm" onclick="showPayDebtModal(${d.DebtID}, '${d.DebtName.replace(/'/g, "\\'")}', ${d.MonthlyEMI})">Pay EMI</button>
                <button class="btn-danger" onclick="deleteDebt(${d.DebtID})"><i class="fas fa-trash"></i></button>
            </div>
        </div>`).join('');
}

async function showPayDebtModal(id, name, emi) {
    const accounts = await apiGet('/api/accounts');
    if (!accounts || !accounts.length) { toast('Please add a bank account first', 'danger'); return; }
    const acctOpts = accounts.map(a => `<option value="${a.AccountID}">${a.AccountName} (${fmt(a.CurrentBalance)})</option>`).join('');
    
    showModal('Pay Debt: ' + name, `
        <div class="form-group"><label>Pay From Account</label><select id="mPayAcct">${acctOpts}</select></div>
        <div class="form-group"><label>Payment Amount (₹)</label><input type="number" id="mPayAmt" value="${emi}" min="1"></div>
        <button class="btn-primary" onclick="submitDebtPayment(${id})">Confirm Payment</button>`);
}

async function submitDebtPayment(id) {
    const amt = parseFloat(document.getElementById('mPayAmt').value);
    const acctId = document.getElementById('mPayAcct').value;
    if (!amt || !acctId) return;
    
    await apiPost('/api/debts/' + id + '/pay', { amount: amt, accountId: acctId });
    closeModal();
    toast('Payment successful!');
    loadDebts();
    loadAccounts();
    loadTransactions();
    loadDashboard();
}

async function deleteDebt(id) { await apiDelete('/api/debts/'+id); toast('Deleted'); loadDebts(); }

// === Recurring ===
async function loadRecurring() {
    const recs = await apiGet('/api/recurring');
    const grid = document.getElementById('recurringGrid');
    if (!recs||!recs.length) { grid.innerHTML='<p class="text-muted">No recurring payments.</p>'; return; }
    grid.innerHTML = recs.map(r => `
        <div class="recurring-card">
            <div class="recurring-icon" style="background:var(--danger-bg);color:var(--danger)"><i class="fas fa-redo"></i></div>
            <div class="recurring-info">
                <div class="rec-desc">${r.Description||'Payment'}</div>
                <div class="rec-amount">${fmt(r.Amount)}</div>
                <div class="rec-meta">${r.Frequency} · Next: ${fmtDate(r.NextDueDate)} · ${r.AccountName||''}</div>
            </div>
            <button class="btn-icon" onclick="deleteRecurring(${r.RecurringID})"><i class="fas fa-trash" style="color:var(--danger)"></i></button>
        </div>`).join('');
}
async function deleteRecurring(id) { await apiDelete('/api/recurring/'+id); toast('Deleted'); loadRecurring(); }

// === Analytics (simple charts from transaction data) ===
async function loadAnalytics() {
    const txns = await apiGet('/api/transactions');
    if (!txns||!txns.length) return;
    
    const colors = ['#6c5ce7','#00cec9','#ff6b6b','#feca57','#54a0ff','#a29bfe','#fd79a8','#55efc4'];
    
    // 1. Trend chart
    const months = {};
    txns.forEach(t => { 
        const m = (t.TransactionDate||'').slice(0,7); 
        if(!months[m]) months[m]={i:0,e:0}; 
        if(t.TransactionType==='Income') months[m].i+=t.Amount; 
        else if(t.TransactionType==='Expense') months[m].e+=t.Amount; 
    });
    const mkeys = Object.keys(months).sort().slice(-6);
    if (chartInstances.trend) chartInstances.trend.destroy();
    const tc = document.getElementById('trendChart');
    if (tc) chartInstances.trend = new Chart(tc, { 
        type:'line', 
        data:{ labels:mkeys, datasets:[{label:'Income',data:mkeys.map(m=>months[m].i),borderColor:'#00cec9',tension:0.4,fill:false},{label:'Expenses',data:mkeys.map(m=>months[m].e),borderColor:'#ff6b6b',tension:0.4,fill:false}]}, 
        options:{responsive:true,plugins:{legend:{labels:{color:'#8892b0'}}},scales:{x:{ticks:{color:'#5a6380'}},y:{ticks:{color:'#5a6380'}}}} 
    });

    // 2. Expense Distribution
    if (chartInstances.expenseDist) chartInstances.expenseDist.destroy();
    const catTotals = {};
    txns.filter(t=>t.TransactionType==='Expense').forEach(t => { catTotals[t.CategoryName||'Other'] = (catTotals[t.CategoryName||'Other']||0) + t.Amount; });
    const expSorted = Object.entries(catTotals).sort((a,b)=>b[1]-a[1]).slice(0,8);
    const edc = document.getElementById('expenseDistChart');
    if (edc && expSorted.length) chartInstances.expenseDist = new Chart(edc, {
        type:'doughnut', 
        data: { labels:expSorted.map(s=>s[0]), datasets:[{data:expSorted.map(s=>s[1]),backgroundColor:colors}] },
        options: { responsive:true, plugins:{legend:{position:'right',labels:{color:'#8892b0',padding:10}}} }
    });

    // 3. Daily Spending Pattern
    if (chartInstances.dailyPattern) chartInstances.dailyPattern.destroy();
    const days = {0:0,1:0,2:0,3:0,4:0,5:0,6:0};
    const dayCounts = {0:0,1:0,2:0,3:0,4:0,5:0,6:0};
    txns.filter(t=>t.TransactionType==='Expense').forEach(t => { 
        const d = new Date(t.TransactionDate).getDay(); 
        if(!isNaN(d)) { days[d]+=t.Amount; dayCounts[d]++; }
    });
    const dayLabels = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    const dpc = document.getElementById('dailyPatternChart');
    if (dpc) chartInstances.dailyPattern = new Chart(dpc, {
        type:'bar',
        data: { labels: dayLabels, datasets: [{ label: 'Avg Expense (₹)', data: dayLabels.map((_,i) => dayCounts[i]?Math.round(days[i]/dayCounts[i]):0), backgroundColor: 'rgba(162, 155, 254, 0.8)' }] },
        options: { responsive:true, plugins:{legend:{labels:{color:'#8892b0'}}}, scales:{x:{ticks:{color:'#5a6380'}},y:{ticks:{color:'#5a6380'}}} }
    });

    // 4. Savings Trend
    if (chartInstances.savingsTrend) chartInstances.savingsTrend.destroy();
    const stc = document.getElementById('savingsTrendChart');
    if (stc) chartInstances.savingsTrend = new Chart(stc, {
        type: 'bar',
        data: { 
            labels: mkeys, 
            datasets: [{ 
                label: 'Net Savings', 
                data: mkeys.map(m => months[m].i - months[m].e), 
                backgroundColor: mkeys.map(m => (months[m].i - months[m].e) >= 0 ? 'rgba(0, 206, 201, 0.7)' : 'rgba(255, 107, 107, 0.7)') 
            }] 
        },
        options: { responsive:true, plugins:{legend:{labels:{color:'#8892b0'}}}, scales:{x:{ticks:{color:'#5a6380'}},y:{ticks:{color:'#5a6380'}}} }
    });

    // 5. Net Worth Over Time
    const stats = await apiGet('/api/stats');
    if (chartInstances.netWorth) chartInstances.netWorth.destroy();
    const nwc = document.getElementById('netWorthChart');
    if (nwc && stats) {
        let currentNW = stats.netWorth;
        const nwData = [];
        for (let i = mkeys.length - 1; i >= 0; i--) {
            nwData.unshift(currentNW);
            currentNW -= (months[mkeys[i]].i - months[mkeys[i]].e); // rollback savings to find previous month's net worth
        }
        chartInstances.netWorth = new Chart(nwc, {
            type: 'line',
            data: { labels: mkeys, datasets: [{ label: 'Net Worth (₹)', data: nwData, borderColor: '#6c5ce7', backgroundColor: 'rgba(108, 92, 231, 0.1)', tension: 0.4, fill: true }] },
            options: { responsive:true, plugins:{legend:{labels:{color:'#8892b0'}}}, scales:{x:{ticks:{color:'#5a6380'}},y:{ticks:{color:'#5a6380'}}} }
        });
    }
}

// === EMI Calculator ===
function calcEMI() {
    const p = parseFloat(document.getElementById('emiPrincipal').value) || 0;
    const r = parseFloat(document.getElementById('emiRate').value) / 12 / 100;
    const n = parseInt(document.getElementById('emiMonths').value) || 1;
    let emi = r === 0 ? p/n : p * r * Math.pow(1+r,n) / (Math.pow(1+r,n) - 1);
    const total = emi * n;
    const interest = total - p;
    document.getElementById('emiResult').innerHTML = `
        <div class="emi-label">Monthly EMI</div><div class="emi-val">${fmt(Math.round(emi))}</div>
        <div class="emi-detail">Total: ${fmt(Math.round(total))} · Interest: ${fmt(Math.round(interest))}</div>`;
}

// === Modal for adding data ===
function showModal(title, formHTML) {
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalBody').innerHTML = formHTML;
    document.getElementById('modalOverlay').classList.add('active');
}
function closeModal() { document.getElementById('modalOverlay').classList.remove('active'); }

async function showAddAccountModal() {
    showModal('Add Account', `
        <div class="form-group"><label>Account Name</label><input type="text" id="mAcctName" placeholder="HDFC Savings"></div>
        <div class="form-group"><label>Type</label><select id="mAcctType"><option>Savings</option><option>Checking</option><option>CreditCard</option><option>Cash</option><option>Wallet</option></select></div>
        <div class="form-group"><label>Opening Balance</label><input type="number" id="mAcctBal" value="0"></div>
        <button class="btn-primary" onclick="submitAccount()">Add Account</button>`);
}
async function submitAccount() {
    await apiPost('/api/accounts', { AccountName: document.getElementById('mAcctName').value, AccountType: document.getElementById('mAcctType').value, CurrentBalance: parseFloat(document.getElementById('mAcctBal').value)||0 });
    closeModal(); toast('Account added!'); loadAccounts(); loadDashboard();
}

async function showAddTxnModal() {
    const accounts = await apiGet('/api/accounts');
    categories = await apiGet('/api/categories') || [];
    const acctOpts = (accounts||[]).map(a=>`<option value="${a.AccountID}">${a.AccountName}</option>`).join('');
    const catOpts = categories.map(c=>`<option value="${c.CategoryID}">${c.CategoryName} (${c.CategoryType})</option>`).join('');
    showModal('Add Transaction', `
        <div class="form-group"><label>Account</label><select id="mTxnAcct">${acctOpts}</select></div>
        <div class="form-group"><label>Type</label><select id="mTxnType"><option>Expense</option><option>Income</option></select></div>
        <div class="form-group"><label>Category</label><select id="mTxnCat">${catOpts}</select></div>
        <div class="form-group"><label>Amount (₹)</label><input type="number" id="mTxnAmt" min="1"></div>
        <div class="form-group"><label>Description</label><input type="text" id="mTxnDesc" placeholder="Swiggy Order"></div>
        <div class="form-group"><label>Date</label><input type="datetime-local" id="mTxnDate" value="${new Date().toISOString().slice(0,16)}"></div>
        <div class="form-group"><label>Payment Method</label><select id="mTxnPay"><option>UPI</option><option>Cash</option><option>Debit Card</option><option>Credit Card</option><option>Bank Transfer</option><option>Wallet</option></select></div>
        <button class="btn-primary" onclick="submitTxn()">Add Transaction</button>`);
}
async function submitTxn() {
    await apiPost('/api/transactions', {
        AccountID: document.getElementById('mTxnAcct').value,
        CategoryID: document.getElementById('mTxnCat').value,
        Amount: parseFloat(document.getElementById('mTxnAmt').value),
        TransactionDate: document.getElementById('mTxnDate').value,
        TransactionType: document.getElementById('mTxnType').value,
        Description: document.getElementById('mTxnDesc').value,
        PaymentMethod: document.getElementById('mTxnPay').value
    });
    closeModal(); toast('Transaction added!'); loadTransactions(); loadDashboard();
}

async function showAddBudgetModal() {
    categories = await apiGet('/api/categories') || [];
    const catOpts = categories.filter(c=>c.CategoryType==='Expense').map(c=>`<option value="${c.CategoryID}">${c.CategoryName}</option>`).join('');
    const now = new Date();
    const sd = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-01`;
    const ed = new Date(now.getFullYear(), now.getMonth()+1, 0).toISOString().slice(0,10);
    showModal('Set Budget', `
        <div class="form-group"><label>Category</label><select id="mBudCat">${catOpts}</select></div>
        <div class="form-group"><label>Budget Amount (₹)</label><input type="number" id="mBudAmt" min="1"></div>
        <div class="form-group"><label>Start</label><input type="date" id="mBudStart" value="${sd}"></div>
        <div class="form-group"><label>End</label><input type="date" id="mBudEnd" value="${ed}"></div>
        <button class="btn-primary" onclick="submitBudget()">Set Budget</button>`);
}
async function submitBudget() {
    await apiPost('/api/budgets', { CategoryID:document.getElementById('mBudCat').value, BudgetAmount:parseFloat(document.getElementById('mBudAmt').value), StartDate:document.getElementById('mBudStart').value, EndDate:document.getElementById('mBudEnd').value });
    closeModal(); toast('Budget set!'); loadBudgets();
}

async function showAddGoalModal() {
    showModal('New Goal', `
        <div class="form-group"><label>Goal Name</label><input type="text" id="mGoalName" placeholder="Emergency Fund"></div>
        <div class="form-group"><label>Target Amount (₹)</label><input type="number" id="mGoalTarget" min="1"></div>
        <div class="form-group"><label>Current Amount (₹)</label><input type="number" id="mGoalCurrent" value="0"></div>
        <div class="form-group"><label>Target Date</label><input type="date" id="mGoalDate"></div>
        <button class="btn-primary" onclick="submitGoal()">Create Goal</button>`);
}
async function submitGoal() {
    await apiPost('/api/goals', { GoalName:document.getElementById('mGoalName').value, TargetAmount:parseFloat(document.getElementById('mGoalTarget').value), CurrentAmount:parseFloat(document.getElementById('mGoalCurrent').value)||0, TargetDate:document.getElementById('mGoalDate').value });
    closeModal(); toast('Goal created!'); loadGoals();
}

async function showAddDebtModal() {
    showModal('Add Debt', `
        <div class="form-group"><label>Name</label><input type="text" id="mDebtName" placeholder="Education Loan"></div>
        <div class="form-group"><label>Principal (₹)</label><input type="number" id="mDebtPrin" min="1"></div>
        <div class="form-group"><label>Interest Rate (%)</label><input type="number" id="mDebtRate" step="0.1" value="8.5"></div>
        <div class="form-group"><label>Monthly EMI (₹)</label><input type="number" id="mDebtEMI"></div>
        <div class="form-group"><label>Start Date</label><input type="date" id="mDebtStart"></div>
        <div class="form-group"><label>End Date</label><input type="date" id="mDebtEnd"></div>
        <button class="btn-primary" onclick="submitDebt()">Add Debt</button>`);
}
async function submitDebt() {
    const p = parseFloat(document.getElementById('mDebtPrin').value);
    await apiPost('/api/debts', { DebtName:document.getElementById('mDebtName').value, PrincipalAmount:p, InterestRate:parseFloat(document.getElementById('mDebtRate').value), MonthlyEMI:parseFloat(document.getElementById('mDebtEMI').value)||0, StartDate:document.getElementById('mDebtStart').value, EndDate:document.getElementById('mDebtEnd').value, RemainingBalance:p });
    closeModal(); toast('Debt added!'); loadDebts();
}

async function showAddRecurringModal() {
    const accounts = await apiGet('/api/accounts');
    categories = await apiGet('/api/categories') || [];
    const acctOpts = (accounts||[]).map(a=>`<option value="${a.AccountID}">${a.AccountName}</option>`).join('');
    const catOpts = categories.map(c=>`<option value="${c.CategoryID}">${c.CategoryName} (${c.CategoryType})</option>`).join('');
    showModal('Add Recurring Payment', `
        <div class="form-group"><label>Description</label><input type="text" id="mRecDesc" placeholder="Netflix Subscription"></div>
        <div class="form-group"><label>Account</label><select id="mRecAcct">${acctOpts}</select></div>
        <div class="form-group"><label>Category</label><select id="mRecCat">${catOpts}</select></div>
        <div class="form-group"><label>Amount (₹)</label><input type="number" id="mRecAmt" min="1"></div>
        <div class="form-group"><label>Frequency</label><select id="mRecFreq"><option>Daily</option><option>Weekly</option><option>Monthly</option><option>Yearly</option></select></div>
        <div class="form-group"><label>Next Due Date</label><input type="date" id="mRecDate"></div>
        <button class="btn-primary" onclick="submitRecurring()">Add Recurring Payment</button>`);
}

async function submitRecurring() {
    await apiPost('/api/recurring', {
        AccountID: document.getElementById('mRecAcct').value,
        CategoryID: document.getElementById('mRecCat').value,
        Amount: parseFloat(document.getElementById('mRecAmt').value),
        Frequency: document.getElementById('mRecFreq').value,
        NextDueDate: document.getElementById('mRecDate').value,
        Description: document.getElementById('mRecDesc').value
    });
    closeModal(); toast('Recurring payment added!'); loadRecurring();
}

// === Event Listeners ===
document.addEventListener('DOMContentLoaded', () => {
    // Nav
    document.querySelectorAll('.nav-item').forEach(n => n.addEventListener('click', e => { e.preventDefault(); navigate(n.dataset.page); }));
    document.querySelectorAll('[data-page]').forEach(n => { if (!n.classList.contains('nav-item')) n.addEventListener('click', e => { e.preventDefault(); navigate(n.dataset.page); }); });

    // Buttons
    document.getElementById('btnAddAccount')?.addEventListener('click', showAddAccountModal);
    document.getElementById('btnAddTransaction')?.addEventListener('click', showAddTxnModal);
    document.getElementById('btnAddTxn2')?.addEventListener('click', showAddTxnModal);
    document.getElementById('btnAddBudget')?.addEventListener('click', showAddBudgetModal);
    document.getElementById('btnAddGoal')?.addEventListener('click', showAddGoalModal);
    document.getElementById('btnAddDebt')?.addEventListener('click', showAddDebtModal);
    document.getElementById('btnAddRecurring')?.addEventListener('click', showAddRecurringModal);
    document.getElementById('btnCalcEMI')?.addEventListener('click', calcEMI);
    document.getElementById('modalClose')?.addEventListener('click', closeModal);
    document.getElementById('modalOverlay')?.addEventListener('click', e => { if (e.target === e.currentTarget) closeModal(); });
    document.getElementById('menuToggle')?.addEventListener('click', () => document.getElementById('sidebar').classList.toggle('open'));

    // Filters
    ['filterAccount','filterCategory','filterType','filterMonth'].forEach(id => {
        document.getElementById(id)?.addEventListener('change', () => loadTransactions());
    });

    // Notifications
    document.getElementById('btnNotifications')?.addEventListener('click', (e) => {
        e.stopPropagation();
        document.getElementById('notifDropdown').classList.toggle('open');
    });
    document.addEventListener('click', () => document.getElementById('notifDropdown')?.classList.remove('open'));
    document.getElementById('notifDropdown')?.addEventListener('click', e => e.stopPropagation());
});

// === Notifications ===
async function loadNotifications() {
    const [stats, goals, debts, recurring, accounts] = await Promise.all([
        apiGet('/api/stats'), apiGet('/api/goals'), apiGet('/api/debts'),
        apiGet('/api/recurring'), apiGet('/api/accounts')
    ]);
    const notifs = [];
    const now = new Date();

    // Welcome notification
    if (!accounts || accounts.length === 0) {
        notifs.push({ icon: 'fa-hand-wave', color: 'var(--accent-light)', bg: 'rgba(108,92,231,0.15)',
            title: 'Welcome to FinFlow!', desc: 'Start by adding your bank accounts to track finances.', time: 'Just now' });
    }

    // Low balance warnings
    (accounts || []).forEach(a => {
        if (a.AccountType !== 'CreditCard' && a.CurrentBalance < 1000 && a.CurrentBalance >= 0) {
            notifs.push({ icon: 'fa-exclamation-triangle', color: 'var(--warning)', bg: 'var(--warning-bg)',
                title: 'Low Balance', desc: `${a.AccountName} has only ${fmt(a.CurrentBalance)} remaining.`, time: 'Now' });
        }
    });

    // Budget overspend (if expenses > 80% of income)
    if (stats && stats.monthlyIncome > 0 && stats.monthlyExpenses > stats.monthlyIncome * 0.8) {
        notifs.push({ icon: 'fa-chart-line', color: 'var(--danger)', bg: 'var(--danger-bg)',
            title: 'High Spending Alert', desc: `You've spent ${fmt(stats.monthlyExpenses)} this month — ${((stats.monthlyExpenses/stats.monthlyIncome)*100).toFixed(0)}% of income.`, time: 'This month' });
    }

    // Goal reminders
    (goals || []).filter(g => g.Status === 'Active').forEach(g => {
        const pct = Math.round((g.CurrentAmount / g.TargetAmount) * 100);
        const daysLeft = Math.max(0, Math.round((new Date(g.TargetDate) - now) / 86400000));
        if (daysLeft < 30 && pct < 90) {
            notifs.push({ icon: 'fa-bullseye', color: 'var(--warning)', bg: 'var(--warning-bg)',
                title: 'Goal Deadline Near', desc: `"${g.GoalName}" is ${pct}% complete with ${daysLeft} days left.`, time: `${daysLeft}d remaining` });
        } else if (pct >= 90 && pct < 100) {
            notifs.push({ icon: 'fa-bullseye', color: 'var(--success)', bg: 'var(--success-bg)',
                title: 'Almost There!', desc: `"${g.GoalName}" is ${pct}% complete — so close!`, time: 'Keep going' });
        }
    });

    // Debt reminders
    (debts || []).forEach(d => {
        if (d.RemainingBalance > 0) {
            notifs.push({ icon: 'fa-file-invoice-dollar', color: 'var(--info)', bg: 'var(--info-bg)',
                title: 'EMI Due', desc: `${d.DebtName}: ${fmt(d.MonthlyEMI)}/month — ${fmt(d.RemainingBalance)} remaining.`, time: 'Monthly' });
        }
    });

    // Recurring payment reminders
    (recurring || []).forEach(r => {
        const due = new Date(r.NextDueDate);
        const diff = Math.round((due - now) / 86400000);
        if (diff <= 3 && diff >= 0) {
            notifs.push({ icon: 'fa-redo', color: 'var(--accent-light)', bg: 'rgba(162,155,254,0.12)',
                title: 'Upcoming Payment', desc: `${r.Description || 'Recurring'}: ${fmt(r.Amount)} due ${diff === 0 ? 'today' : 'in ' + diff + ' day(s)'}.`, time: fmtDate(r.NextDueDate) });
        }
    });

    // Positive savings message
    if (stats && stats.savingsRate > 30) {
        notifs.push({ icon: 'fa-piggy-bank', color: 'var(--success)', bg: 'var(--success-bg)',
            title: 'Great Savings!', desc: `Your savings rate is ${stats.savingsRate.toFixed(1)}% this month. Keep it up!`, time: 'This month' });
    }

    // Render
    const list = document.getElementById('notifList');
    const badge = document.getElementById('notifBadge');
    badge.textContent = notifs.length;
    badge.style.display = notifs.length > 0 ? 'flex' : 'none';

    if (notifs.length === 0) {
        list.innerHTML = '<p class="text-muted" style="padding:1.5rem;text-align:center"><i class="fas fa-check-circle" style="font-size:1.5rem;display:block;margin-bottom:0.5rem;color:var(--success)"></i>All clear! No notifications.</p>';
    } else {
        list.innerHTML = notifs.map(n => `
            <div class="notif-item">
                <div class="notif-icon" style="background:${n.bg};color:${n.color}"><i class="fas ${n.icon}"></i></div>
                <div class="notif-content">
                    <div class="notif-title">${n.title}</div>
                    <div class="notif-desc">${n.desc}</div>
                    <div class="notif-time">${n.time}</div>
                </div>
            </div>`).join('');
    }
}

function clearNotifications() {
    document.getElementById('notifList').innerHTML = '<p class="text-muted" style="padding:1.5rem;text-align:center"><i class="fas fa-check-circle" style="font-size:1.5rem;display:block;margin-bottom:0.5rem;color:var(--success)"></i>All clear!</p>';
    document.getElementById('notifBadge').style.display = 'none';
    document.getElementById('notifBadge').textContent = '0';
}
