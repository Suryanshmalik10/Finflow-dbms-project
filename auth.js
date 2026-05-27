/* FinFlow Auth Module */
let currentUser = null;

function showAuthTab(tab) {
    document.getElementById('loginForm').style.display = tab === 'login' ? 'flex' : 'none';
    document.getElementById('registerForm').style.display = tab === 'register' ? 'flex' : 'none';
    document.getElementById('tabLogin').classList.toggle('active', tab === 'login');
    document.getElementById('tabRegister').classList.toggle('active', tab === 'register');
    document.getElementById('loginError').textContent = '';
    document.getElementById('regError').textContent = '';
}

async function handleLogin(e) {
    e.preventDefault();
    const email = document.getElementById('loginEmail').value;
    const password = document.getElementById('loginPassword').value;
    try {
        const res = await fetch('/api/login', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
        });
        const data = await res.json();
        if (!res.ok) { document.getElementById('loginError').textContent = data.error; return; }
        currentUser = data.user;
        enterDashboard();
    } catch (err) { document.getElementById('loginError').textContent = 'Connection error'; }
}

async function handleRegister(e) {
    e.preventDefault();
    const name = document.getElementById('regName').value;
    const email = document.getElementById('regEmail').value;
    const password = document.getElementById('regPassword').value;
    try {
        const res = await fetch('/api/register', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, email, password })
        });
        const data = await res.json();
        if (!res.ok) { document.getElementById('regError').textContent = data.error; return; }
        currentUser = data.user;
        enterDashboard();
    } catch (err) { document.getElementById('regError').textContent = 'Connection error'; }
}

async function handleLogout() {
    await fetch('/api/logout', { method: 'POST' });
    currentUser = null;
    document.getElementById('authPage').classList.add('active');
    document.getElementById('loginEmail').value = '';
    document.getElementById('loginPassword').value = '';
    showAuthTab('login');
}

function enterDashboard() {
    document.getElementById('authPage').classList.remove('active');
    document.getElementById('userName').textContent = currentUser.name;
    document.getElementById('userAvatar').textContent = currentUser.name.split(' ').map(w => w[0]).join('').slice(0, 2);
    document.getElementById('welcomeMsg').textContent = `Welcome back, ${currentUser.name.split(' ')[0]}! Here's your financial overview.`;
    loadDashboard();
}

async function checkAuth() {
    try {
        const res = await fetch('/api/me');
        const data = await res.json();
        if (data.authenticated) { currentUser = data.user; enterDashboard(); }
    } catch (e) { /* stay on auth page */ }
}

document.addEventListener('DOMContentLoaded', checkAuth);
