const API = '';
let currentUser = null;
let auditData = [];
let allUsers = [];
let feedInterval = null;
let sessionInterval = null;
let sessionSeconds = 28800;
let confirmCallback = null;

// ===== FETCH HELPER =====
async function apiFetch(url, options = {}) {
    const defaults = {
        credentials: 'include',
        headers: { 'Content-Type': 'application/json', ...options.headers }
    };
    return fetch(API + url, { ...defaults, ...options });
}

// ===== TOAST NOTIFICATIONS =====
function showToast(message, type = 'info', duration = 4000) {
    const container = document.getElementById('toast-container');
    const icons = { success: '✅', error: '❌', info: 'ℹ️', warning: '⚠️' };
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `<span>${icons[type]}</span><span>${message}</span>`;
    toast.onclick = () => removeToast(toast);
    container.appendChild(toast);
    setTimeout(() => removeToast(toast), duration);
}

function removeToast(toast) {
    toast.classList.add('toast-out');
    setTimeout(() => toast.remove(), 400);
}

// ===== CONFIRM MODAL =====
function showConfirm(title, message, okText = 'Confirm') {
    return new Promise(resolve => {
        document.getElementById('confirm-title').textContent = title;
        document.getElementById('confirm-message').textContent = message;
        document.getElementById('confirm-ok').textContent = okText;
        document.getElementById('confirm-modal').classList.add('open');
        confirmCallback = resolve;
    });
}

function closeConfirm(result) {
    document.getElementById('confirm-modal').classList.remove('open');
    if (confirmCallback) { confirmCallback(result); confirmCallback = null; }
}

// ===== POLICY MODAL =====
function showModal(title, content) {
    document.getElementById('modal-title').textContent = title;
    document.getElementById('modal-body').innerHTML = content;
    document.getElementById('policy-modal').classList.add('open');
}

function closeModal() {
    document.getElementById('policy-modal').classList.remove('open');
}

// ===== THEME TOGGLE =====
function toggleTheme() {
    const html = document.documentElement;
    const isDark = html.getAttribute('data-theme') === 'dark';
    html.setAttribute('data-theme', isDark ? 'light' : 'dark');
    document.querySelector('.theme-toggle').textContent = isDark ? '🌙' : '☀️';
    showToast(`Switched to ${isDark ? 'Light' : 'Dark'} mode`, 'info', 2000);
}

// ===== SIDEBAR TOGGLE =====
function toggleSidebar() {
    document.querySelector('.sidebar').classList.toggle('collapsed');
    document.querySelector('.main-content').classList.toggle('expanded');
}

// ===== PASSWORD TOGGLE =====
function togglePassword() {
    const input = document.getElementById('login-secret');
    input.type = input.type === 'password' ? 'text' : 'password';
}

// ===== SESSION TIMER =====
function startSessionTimer() {
    sessionSeconds = 28800;
    clearInterval(sessionInterval);
    sessionInterval = setInterval(() => {
        sessionSeconds--;
        const h = Math.floor(sessionSeconds / 3600);
        const m = Math.floor((sessionSeconds % 3600) / 60);
        const el = document.getElementById('session-timer');
        if (el) el.textContent = `Session: ${h}h ${m}m remaining`;
        if (sessionSeconds <= 300 && sessionSeconds % 60 === 0) {
            showToast(`Session expires in ${Math.ceil(sessionSeconds/60)} minutes`, 'warning', 5000);
        }
        if (sessionSeconds <= 0) { doLogout(); }
    }, 1000);
}

// ===== ROLE-BASED NAV =====
const ROLE_MENUS = {
    Admin: [
        { id: 'dashboard', icon: '📊', label: 'Dashboard' },
        { id: 'users',     icon: '👥', label: 'IAM Users' },
        { id: 'groups',    icon: '🏷️', label: 'IAM Groups' },
        { id: 'roles',     icon: '🎭', label: 'IAM Roles' },
        { id: 'matrix',    icon: '🔐', label: 'Permission Matrix' },
        { id: 'workflow',  icon: '⚙️', label: 'Employee Workflow' },
        { id: 'audit',     icon: '📋', label: 'Audit Logs' },
    ],
    Developer: [{ id: 'ec2', icon: '🖥️', label: 'EC2 Status' }],
    Tester:    [{ id: 'ec2', icon: '🖥️', label: 'EC2 Status (Read)' }],
    DatabaseAdmin: [{ id: 'ec2', icon: '🗄️', label: 'My Access Info' }],
    Auditor:   [{ id: 'audit', icon: '📋', label: 'Audit Logs' }]
};

const ROLE_WELCOME = {
    Admin: 'Full system access', Developer: 'EC2 start/stop access',
    Tester: 'Read-only access', DatabaseAdmin: 'RDS management access',
    Auditor: 'CloudTrail read access'
};

function getGroupBadge(group) {
    const map = { Admin:'badge-red', Developer:'badge-blue', Tester:'badge-green',
                  DatabaseAdmin:'badge-purple', Auditor:'badge-orange', 'No Group':'badge-gray' };
    return `<span class="badge ${map[group]||'badge-gray'}">${group}</span>`;
}

// ===== LOGIN =====
async function doLogin() {
    const keyId = document.getElementById('login-key-id').value.trim();
    const secret = document.getElementById('login-secret').value.trim();
    const btn = document.getElementById('login-btn');
    const errBox = document.getElementById('login-error');
    errBox.style.display = 'none';

    if (!keyId || !secret) { showLoginError('Please enter both Access Key ID and Secret Access Key'); return; }

    btn.disabled = true;
    btn.textContent = '⏳ Authenticating...';

    try {
        const res = await apiFetch('/api/auth/login', {
            method: 'POST',
            body: JSON.stringify({ accessKeyId: keyId, secretAccessKey: secret })
        });
        const data = await res.json();

        if (data.success) {
            currentUser = { username: data.username, role: data.role, displayName: data.displayName };
            showToast(`Welcome back, ${data.displayName}! Logged in as ${data.role}`, 'success');
            showApp();
        } else {
            showLoginError(data.message || 'Login failed. Check your credentials.');
        }
    } catch (err) {
        showLoginError('Cannot connect to server. Make sure the app is running.');
    }

    btn.disabled = false;
    btn.textContent = '🔑 Sign In';
}

function showLoginError(msg) {
    const err = document.getElementById('login-error');
    err.textContent = '❌ ' + msg;
    err.style.display = 'block';
}

document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && document.getElementById('login-page').style.display !== 'none') doLogin();
    // Keyboard shortcuts
    if (currentUser && e.altKey) {
        const shortcuts = { d:'dashboard', u:'users', g:'groups', r:'roles', w:'workflow', a:'audit' };
        if (shortcuts[e.key]) { e.preventDefault(); navigateTo(shortcuts[e.key]); }
        if (e.key === 'l') { e.preventDefault(); doLogout(); }
    }
});

// ===== SHOW APP =====
function showApp() {
    document.getElementById('login-page').style.display = 'none';
    document.getElementById('app-page').style.display = 'flex';

    document.getElementById('sidebar-username').textContent = currentUser.displayName;
    const badge = document.getElementById('sidebar-role-badge');
    badge.textContent = currentUser.role;
    badge.className = `role-badge role-${currentUser.role}`;
    document.getElementById('header-user').textContent = `${currentUser.displayName} (${currentUser.role})`;

    buildNav(currentUser.role);
    startSessionTimer();

    const firstPage = ROLE_MENUS[currentUser.role]?.[0]?.id || 'dashboard';
    navigateTo(firstPage);

    // Start live feed refresh every 30 seconds for admin
    if (currentUser.role === 'Admin') {
        clearInterval(feedInterval);
        feedInterval = setInterval(loadLiveFeed, 30000);
    }
}

function buildNav(role) {
    const nav = document.getElementById('sidebar-nav');
    const menus = ROLE_MENUS[role] || [];
    nav.innerHTML = menus.map(m => `
        <a class="nav-item" onclick="navigateTo('${m.id}')" id="nav-${m.id}">
            ${m.icon} ${m.label}
        </a>`).join('');

    nav.innerHTML += `
        <div style="padding:15px 24px;margin-top:10px;border-top:1px solid rgba(255,255,255,0.08)">
            <p style="font-size:10px;color:rgba(255,255,255,0.35);text-transform:uppercase;letter-spacing:0.5px">Access Level</p>
            <p style="font-size:12px;color:rgba(255,255,255,0.65);margin-top:4px">${ROLE_WELCOME[role]||''}</p>
            <p style="font-size:10px;color:rgba(255,255,255,0.25);margin-top:8px">Alt+D/U/G/R/W/A shortcuts</p>
        </div>`;
}

// ===== NAVIGATION =====
function navigateTo(page) {
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));

    const pageEl = document.getElementById('page-' + page);
    if (pageEl) pageEl.classList.add('active');
    const navEl = document.getElementById('nav-' + page);
    if (navEl) navEl.classList.add('active');

    const titles = { dashboard:'Dashboard', users:'IAM Users', groups:'IAM Groups',
        roles:'IAM Roles', matrix:'Permission Matrix', workflow:'Employee Workflow',
        audit:'Audit Logs', ec2:'EC2 Status', denied:'Access Denied' };
    document.getElementById('page-title').textContent = titles[page] || page;

    if (page === 'dashboard') loadDashboard();
    if (page === 'users')     loadUsers();
    if (page === 'groups')    loadGroups();
    if (page === 'roles')     loadRoles();
    if (page === 'matrix')    loadPermissionMatrix();
    if (page === 'audit')     loadAudit();
    if (page === 'ec2')       loadEc2();
}

// ===== LOGOUT =====
async function doLogout() {
    clearInterval(feedInterval);
    clearInterval(sessionInterval);
    await apiFetch('/api/auth/logout', { method: 'POST' });
    currentUser = null;
    document.getElementById('app-page').style.display = 'none';
    document.getElementById('login-page').style.display = 'flex';
    document.getElementById('login-key-id').value = '';
    document.getElementById('login-secret').value = '';
    document.getElementById('login-error').style.display = 'none';
    showToast('Logged out successfully', 'info', 2000);
}

// ===== ANIMATED COUNTER =====
function animateCounter(el, target) {
    let current = 0;
    const step = Math.ceil(target / 20);
    const timer = setInterval(() => {
        current = Math.min(current + step, target);
        el.textContent = current;
        if (current >= target) clearInterval(timer);
    }, 60);
}

// ===== SECURITY SCORE =====
function updateSecurityScore(stats, cloudtrailLogging) {
    let score = 0;
    const factors = [];

    const mfaPercent = stats.userCount > 0 ? (stats.mfaCount / stats.userCount) * 100 : 0;
    if (mfaPercent === 100) {
        score += 30; factors.push({ icon: '🔐', label: 'MFA 100%', ok: true });
    } else {
        score += Math.floor(mfaPercent * 0.3);
        factors.push({ icon: '⚠️', label: `MFA ${Math.round(mfaPercent)}%`, ok: false });
    }

    if (cloudtrailLogging) { score += 25; factors.push({ icon: '📋', label: 'CloudTrail ON', ok: true }); }
    else { factors.push({ icon: '❌', label: 'CloudTrail OFF', ok: false }); }

    if (stats.policyCount >= 5) { score += 20; factors.push({ icon: '📜', label: '5 Policies', ok: true }); }
    if (stats.groupCount >= 5)  { score += 15; factors.push({ icon: '👥', label: '5 Groups', ok: true }); }
    if (stats.roleCount >= 5)   { score += 10; factors.push({ icon: '🎭', label: '5 Roles', ok: true }); }

    const scoreEl = document.getElementById('score-path');
    const valueEl = document.getElementById('score-value');
    const labelEl = document.getElementById('score-label');
    const factorsEl = document.getElementById('score-factors');

    if (scoreEl) {
        setTimeout(() => {
            scoreEl.setAttribute('stroke-dasharray', `${score}, 100`);
            scoreEl.style.stroke = score >= 80 ? '#06d6a0' : score >= 60 ? '#fb8500' : '#e94560';
        }, 300);
    }
    if (valueEl) valueEl.textContent = score;
    if (labelEl) {
        labelEl.textContent = score >= 80 ? 'Excellent security posture' :
                              score >= 60 ? 'Good — some improvements possible' :
                              'Needs attention — review security settings';
    }
    if (factorsEl) {
        factorsEl.innerHTML = factors.map(f => `
            <div class="score-factor">
                <span>${f.icon}</span>
                <span style="color:${f.ok ? '#6ee7b7' : '#fca5a5'}">${f.label}</span>
            </div>`).join('');
    }
}

// ===== LIVE SECURITY FEED — uses /api/feed for instant updates =====
async function loadLiveFeed() {
    try {
        const res = await apiFetch('/api/feed');
        if (res.status === 403) return;
        const events = await res.json();
        const feed = document.getElementById('live-feed');
        if (!feed) return;

        const blockedEvents = ['TerminateInstances','DeleteObject','DeleteBucket',
                               'DeleteUser','DeleteRole','StopLogging'];
        const warningEvents = ['CreateUser','AddUserToGroup','RemoveUserFromGroup',
                               'CreateAccessKey','UpdateAccessKey','DeactivateMFADevice'];
        const successEvents = ['StartInstances','StopInstances','PutObject','GetObject',
                                'ConsoleLogin','AssumeRole'];

        if (!events || events.length === 0) {
            feed.innerHTML = `<div style="text-align:center;color:#888;padding:30px">
                <div style="font-size:32px;margin-bottom:10px">🛡️</div>
                <div>No recent security events</div>
                <div style="font-size:11px;margin-top:6px">Perform an action to see it appear here</div>
            </div>`;
            return;
        }

        feed.innerHTML = events.map(e => {
            const isBlocked = blockedEvents.some(b => e.eventName.includes(b));
            const isWarning = warningEvents.some(w => e.eventName.includes(w));
            const type = isBlocked ? 'blocked' : isWarning ? 'warning' : 'success';
            const icon = isBlocked ? '🚫' : isWarning ? '⚠️' : '✅';
            const source = e.eventSource === 'dashboard.local' ? '📍 Dashboard' : '☁️ CloudTrail';
            const time = new Date(e.eventTime);
            const timeAgo = isNaN(time) ? 'just now' : getTimeAgo(time);
            return `
                <div class="feed-item ${type}">
                    <span class="feed-icon">${icon}</span>
                    <div class="feed-content">
                        <div class="feed-event">${e.eventName}</div>
                        <div class="feed-meta">by <strong>${e.username}</strong> · ${source}</div>
                    </div>
                    <span class="feed-time">${timeAgo}</span>
                </div>`;
        }).join('');
    } catch (err) { console.error('Feed error:', err); }
}

function getTimeAgo(date) {
    const seconds = Math.floor((new Date() - date) / 1000);
    if (seconds < 60) return `${seconds}s ago`;
    if (seconds < 3600) return `${Math.floor(seconds/60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds/3600)}h ago`;
    return `${Math.floor(seconds/86400)}d ago`;
}

// ===== DASHBOARD =====
async function loadDashboard() {
    try {
        const res = await apiFetch('/api/dashboard');
        if (res.status === 403) return;
        const data = await res.json();

        // Animate counters
        const targets = {
            'stat-users': data.stats.userCount, 'stat-groups': data.stats.groupCount,
            'stat-policies': data.stats.policyCount, 'stat-roles': data.stats.roleCount,
            'stat-mfa': data.stats.mfaCount
        };
        Object.entries(targets).forEach(([id, val]) => {
            const el = document.getElementById(id);
            if (el) animateCounter(el, val);
        });

        // Security score
        updateSecurityScore(data.stats, data.cloudtrail?.isLogging);

        // CloudTrail status
        const ct = data.cloudtrail;
        document.getElementById('cloudtrail-status').innerHTML = `
            <div class="status-row"><span class="status-label">Trail Name</span>
                <span class="status-value">${ct.trailName || 'IAM-Project-Trail'}</span></div>
            <div class="status-row"><span class="status-label">Status</span>
                <span class="status-value"><span class="badge ${ct.isLogging?'badge-green':'badge-red'}">
                    ${ct.isLogging ? '● Active' : '● Stopped'}</span></span></div>
            <div class="status-row"><span class="status-label">Last Delivery</span>
                <span class="status-value" style="font-size:11px">${ct.latestDeliveryTime||'N/A'}</span></div>`;

        // EC2 status
        const ec2 = data.ec2;
        const sc = ec2.state==='running' ? 'badge-green' : ec2.state==='stopped' ? 'badge-red' : 'badge-yellow';
        document.getElementById('ec2-status-dash').innerHTML = `
            <div class="status-row"><span class="status-label">Instance</span>
                <span class="status-value" style="font-size:11px">${ec2.instanceId}</span></div>
            <div class="status-row"><span class="status-label">State</span>
                <span class="status-value"><span class="badge ${sc}">${ec2.state}</span></span></div>
            <div class="status-row"><span class="status-label">Type</span>
                <span class="status-value">${ec2.instanceType||'N/A'}</span></div>`;

        // Load live feed
        loadLiveFeed();

    } catch (err) { console.error('Dashboard error:', err); }
}

// ===== USERS =====
async function loadUsers() {
    try {
        const res = await apiFetch('/api/users');
        if (res.status === 403) return;
        allUsers = await res.json();
        renderUsers(allUsers);
    } catch (err) { console.error(err); }
}

function renderUsers(users) {
    document.getElementById('users-table').innerHTML = users.map(u => {
        const statusBadge = u.status === 'Active'
            ? '<span class="badge badge-green">● Active</span>'
            : u.status === 'Keys Only'
            ? '<span class="badge badge-yellow">🔑 Keys Only</span>'
            : '<span class="badge badge-red">⛔ Disabled</span>';
        return `<tr>
            <td><strong>${u.username}</strong></td>
            <td>${getGroupBadge(u.groups)}</td>
            <td><span class="badge ${u.mfaActive ? 'badge-green' : 'badge-red'}">
                ${u.mfaActive ? '🔐 MFA ON' : '⚠️ MFA OFF'}</span></td>
            <td style="font-size:12px">${new Date(u.createDate).toLocaleDateString()}</td>
            <td>${statusBadge}</td>
        </tr>`;
    }).join('');
}

function filterUsers() {
    const q = document.getElementById('user-search').value.toLowerCase();
    renderUsers(allUsers.filter(u =>
        u.username.toLowerCase().includes(q) || u.groups.toLowerCase().includes(q)));
}

// ===== GROUPS =====
async function loadGroups() {
    try {
        const res = await apiFetch('/api/groups');
        if (res.status === 403) return;
        const groups = await res.json();
        document.getElementById('groups-table').innerHTML = groups.map(g => `
            <tr>
                <td>${getGroupBadge(g.groupName)}</td>
                <td style="font-size:12px">${g.policies}</td>
                <td><strong>${g.memberCount}</strong> member(s)</td>
            </tr>`).join('');
    } catch (err) { console.error(err); }
}

// ===== ROLES =====
async function loadRoles() {
    try {
        const res = await apiFetch('/api/roles');
        if (res.status === 403) return;
        const roles = await res.json();
        document.getElementById('roles-table').innerHTML = roles.map(r => `
            <tr>
                <td><strong>${r.roleName}</strong></td>
                <td style="font-size:11px;color:#888">${r.arn}</td>
                <td style="font-size:12px">${new Date(r.createDate).toLocaleDateString()}</td>
            </tr>`).join('');
    } catch (err) { console.error(err); }
}

// ===== PERMISSION MATRIX =====
function loadPermissionMatrix() {
    const roles = ['Admin', 'Developer', 'Tester', 'DatabaseAdmin', 'Auditor'];

    const matrix = [
        { section: 'EC2 — Elastic Compute Cloud' },
        { action: 'Describe/List Instances',      perms: ['✅','✅','👁️','❌','❌'], detail: 'ec2:Describe*' },
        { action: 'Start Instance',               perms: ['✅','✅','❌','❌','❌'], detail: 'ec2:StartInstances' },
        { action: 'Stop Instance',                perms: ['✅','✅','❌','❌','❌'], detail: 'ec2:StopInstances' },
        { action: 'Terminate Instance',           perms: ['✅','❌','❌','❌','❌'], detail: 'ec2:TerminateInstances — Explicit DENY on Developer' },
        { action: 'Launch New Instance',          perms: ['✅','❌','❌','❌','❌'], detail: 'ec2:RunInstances' },
        { section: 'S3 — Simple Storage Service' },
        { action: 'List Bucket',                  perms: ['✅','✅','👁️','❌','❌'], detail: 's3:ListBucket' },
        { action: 'Download (GetObject)',         perms: ['✅','✅','👁️','❌','❌'], detail: 's3:GetObject' },
        { action: 'Upload (PutObject)',           perms: ['✅','✅','❌','❌','❌'], detail: 's3:PutObject' },
        { action: 'Delete Object',               perms: ['✅','❌','❌','❌','❌'], detail: 's3:DeleteObject — Explicit DENY on Developer' },
        { action: 'Delete Bucket',               perms: ['✅','❌','❌','❌','❌'], detail: 's3:DeleteBucket — Explicit DENY' },
        { section: 'RDS — Relational Database Service' },
        { action: 'Describe DB Instances',       perms: ['✅','❌','❌','✅','❌'], detail: 'rds:DescribeDBInstances' },
        { action: 'Start/Stop DB',               perms: ['✅','❌','❌','✅','❌'], detail: 'rds:StartDBInstance, rds:StopDBInstance' },
        { action: 'Create Snapshot',             perms: ['✅','❌','❌','✅','❌'], detail: 'rds:CreateDBSnapshot' },
        { action: 'Delete DB Instance',          perms: ['✅','❌','❌','✅','❌'], detail: 'rds:DeleteDBInstance' },
        { section: 'CloudTrail & CloudWatch' },
        { action: 'View CloudTrail Logs',        perms: ['✅','❌','❌','❌','👁️'], detail: 'cloudtrail:LookupEvents, cloudtrail:DescribeTrails' },
        { action: 'Stop CloudTrail Logging',     perms: ['✅','❌','❌','❌','❌'], detail: 'cloudtrail:StopLogging — Explicit DENY on Auditor' },
        { action: 'View CloudWatch Metrics',     perms: ['✅','❌','❌','❌','👁️'], detail: 'cloudwatch:GetMetricData, cloudwatch:ListMetrics' },
        { section: 'IAM — Identity & Access Management' },
        { action: 'List Users/Groups',           perms: ['✅','❌','❌','❌','👁️'], detail: 'iam:ListUsers, iam:ListGroups' },
        { action: 'Create IAM User',             perms: ['✅','❌','❌','❌','❌'], detail: 'iam:CreateUser' },
        { action: 'Delete IAM User',             perms: ['✅','❌','❌','❌','❌'], detail: 'iam:DeleteUser — Explicit DENY' },
        { action: 'Manage Policies',             perms: ['✅','❌','❌','❌','❌'], detail: 'iam:CreatePolicy, iam:AttachGroupPolicy' },
    ];

    let html = '<thead><tr><th class="row-header">Action / Resource</th>';
    roles.forEach(r => html += `<th>${getGroupBadge(r)}</th>`);
    html += '</tr></thead><tbody>';

    matrix.forEach(row => {
        if (row.section) {
            html += `<tr class="section-header"><td colspan="${roles.length + 1}">${row.section}</td></tr>`;
        } else {
            html += '<tr>';
            html += `<td class="action-label">${row.action}</td>`;
            row.perms.forEach((perm, i) => {
                const detail = `<strong>${row.action}</strong><br><br>
                    <strong>Role:</strong> ${roles[i]}<br>
                    <strong>Permission:</strong> ${perm === '✅' ? 'ALLOWED' : perm === '❌' ? 'DENIED' : perm === '👁️' ? 'READ ONLY' : 'LIMITED'}<br><br>
                    <strong>AWS Action:</strong><br>
                    <pre>${row.detail || 'N/A'}</pre>`;
                html += `<td onclick="showModal('${row.action} — ${roles[i]}', \`${detail}\`)">${perm}</td>`;
            });
            html += '</tr>';
        }
    });

    html += '</tbody>';
    document.getElementById('permission-matrix').innerHTML = html;
}

// ===== AUDIT LOGS =====
async function loadAudit() {
    try {
        const limit = document.getElementById('audit-limit')?.value || 20;
        const res = await apiFetch(`/api/audit?limit=${limit}`);
        if (res.status === 403) return;
        auditData = await res.json();
        renderAudit(auditData);
    } catch (err) { console.error(err); }
}

function renderAudit(events) {
    document.getElementById('audit-table').innerHTML = events.length === 0
        ? '<tr><td colspan="5" style="text-align:center;color:#888;padding:30px">No events found</td></tr>'
        : events.map((e, i) => {
            const isDeny = e.eventName.includes('Delete') || e.eventName.includes('Terminate');
            return `<tr>
                <td style="color:#888">${i + 1}</td>
                <td><span class="badge ${isDeny ? 'badge-red' : 'badge-blue'}">${e.eventName}</span></td>
                <td>${e.username}</td>
                <td style="font-size:12px">${new Date(e.eventTime).toLocaleString()}</td>
                <td style="font-size:11px;color:#888">${e.eventSource}</td>
            </tr>`;
        }).join('');
}

function filterAudit() {
    const q = document.getElementById('audit-search').value.toLowerCase();
    renderAudit(auditData.filter(e =>
        e.eventName.toLowerCase().includes(q) || e.username.toLowerCase().includes(q)));
}

function exportAuditCSV() {
    if (!auditData.length) { showToast('No audit data to export', 'warning'); return; }
    const headers = ['#', 'Event Name', 'Username', 'Time', 'Source'];
    const rows = auditData.map((e, i) => [i+1, e.eventName, e.username,
        new Date(e.eventTime).toLocaleString(), e.eventSource]);
    const csv = [headers, ...rows].map(r => r.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `audit-logs-${new Date().toISOString().split('T')[0]}.csv`;
    a.click(); URL.revokeObjectURL(url);
    showToast('Audit logs exported as CSV', 'success');
}

// ===== EC2 =====
async function loadEc2() {
    try {
        const res = await apiFetch('/api/ec2/status');
        if (res.status === 403) {
            document.getElementById('ec2-status-full').innerHTML =
                '<p style="color:#e94560;padding:10px">❌ Access denied for your role</p>';
            return;
        }
        const ec2 = await res.json();
        const sc = ec2.state==='running' ? 'badge-green' : ec2.state==='stopped' ? 'badge-red' : 'badge-yellow';
        document.getElementById('ec2-status-full').innerHTML = `
            <div class="status-row"><span class="status-label">Name</span>
                <span class="status-value">EC2-ProjectServer</span></div>
            <div class="status-row"><span class="status-label">Instance ID</span>
                <span class="status-value">${ec2.instanceId}</span></div>
            <div class="status-row"><span class="status-label">State</span>
                <span class="status-value"><span class="badge ${sc}">${ec2.state}</span></span></div>
            <div class="status-row"><span class="status-label">Instance Type</span>
                <span class="status-value">${ec2.instanceType||'N/A'}</span></div>
            <div class="status-row"><span class="status-label">Private IP</span>
                <span class="status-value">${ec2.privateIp||'N/A'}</span></div>`;

        const notes = {
            Developer: '💡 As Developer: you can Start/Stop this instance via AWS CLI. You cannot terminate it.',
            Tester: '👁️ As Tester: read-only view. No modifications allowed.',
            DatabaseAdmin: '🗄️ As DatabaseAdmin: your access is scoped to RDS only.'
        };
        const noteEl = document.getElementById('ec2-access-note');
        if (notes[currentUser?.role]) noteEl.innerHTML = notes[currentUser.role];
    } catch (err) { console.error(err); }
}

// ===== WORKFLOW =====
async function onboardEmployee() {
    const username = document.getElementById('onboard-username').value.trim();
    const department = document.getElementById('onboard-dept').value;
    const employeeId = document.getElementById('onboard-empid').value.trim();
    const resultBox = document.getElementById('onboard-result');

    if (!username || !employeeId) { showResult(resultBox, 'error', 'Please fill in all fields'); return; }

    try {
        const res = await apiFetch('/api/workflow/onboard', {
            method: 'POST', body: JSON.stringify({ username, department, employeeId })
        });
        if (res.status === 403) { showResult(resultBox, 'error', 'Only Admin can onboard employees'); return; }
        const data = await res.json();

        if (data.status === 'success') {
            showResult(resultBox, 'success', data.message);
            showToast(`${username} successfully onboarded into ${department}`, 'success');

            // Show credentials in modal — IMPORTANT: shown only once
            showModal(`🔑 Credentials for ${username}`,
                `<div style="background:rgba(233,69,96,0.1);border:1px solid rgba(233,69,96,0.3);
                    border-radius:8px;padding:12px;margin-bottom:16px;font-size:12px;color:#e94560">
                    ⚠️ <strong>Copy these credentials now — Secret Key is shown only ONCE!</strong>
                </div>
                <table style="width:100%;font-size:13px;border-collapse:collapse">
                    <tr style="border-bottom:1px solid var(--border)">
                        <td style="padding:8px;color:var(--text-muted);white-space:nowrap">Username</td>
                        <td style="padding:8px;font-weight:600">${username}</td>
                    </tr>
                    <tr style="border-bottom:1px solid var(--border)">
                        <td style="padding:8px;color:var(--text-muted)">Department</td>
                        <td style="padding:8px"><span class="badge ${getBadgeClass(department)}">${department}</span></td>
                    </tr>
                    <tr style="border-bottom:1px solid var(--border)">
                        <td style="padding:8px;color:var(--text-muted)">Employee ID</td>
                        <td style="padding:8px">${data.employeeId || employeeId}</td>
                    </tr>
                    <tr style="border-bottom:1px solid var(--border)">
                        <td style="padding:8px;color:var(--text-muted)">Console URL</td>
                        <td style="padding:8px;font-size:11px">https://745416886767.signin.aws.amazon.com/console</td>
                    </tr>
                    <tr style="border-bottom:1px solid var(--border)">
                        <td style="padding:8px;color:var(--text-muted)">Temp Password</td>
                        <td style="padding:8px"><code style="background:var(--status-bg);padding:3px 8px;border-radius:4px">${data.tempPassword}</code></td>
                    </tr>
                    <tr style="border-bottom:1px solid var(--border)">
                        <td style="padding:8px;color:var(--text-muted)">Access Key ID</td>
                        <td style="padding:8px"><code style="background:var(--status-bg);padding:3px 8px;border-radius:4px;font-size:11px">${data.accessKeyId}</code></td>
                    </tr>
                    <tr>
                        <td style="padding:8px;color:var(--text-muted)">Secret Access Key</td>
                        <td style="padding:8px"><code style="background:rgba(233,69,96,0.1);color:#e94560;padding:3px 8px;border-radius:4px;font-size:11px">${data.secretAccessKey}</code></td>
                    </tr>
                </table>
                <div style="margin-top:16px;padding:12px;background:var(--status-bg);border-radius:8px;font-size:12px;color:var(--text-muted)">
                    <strong>Next steps for ${username}:</strong><br>
                    1. Login at console URL with temp password<br>
                    2. Reset password on first login<br>
                    3. Set up MFA (Google Authenticator)<br>
                    4. Configure AWS CLI: <code>aws configure --profile ${username}</code>
                </div>`
            );

            // Refresh the live feed immediately
            setTimeout(loadLiveFeed, 500);

            document.getElementById('onboard-username').value = '';
            document.getElementById('onboard-empid').value = '';
        } else {
            showResult(resultBox, 'error', data.message);
            showToast(`Onboard failed: ${data.message}`, 'error');
        }
    } catch (err) { showResult(resultBox, 'error', err.message); }
}

function getBadgeClass(group) {
    const map = { Admin:'badge-red', Developer:'badge-blue', Tester:'badge-green',
                  DatabaseAdmin:'badge-purple', Auditor:'badge-orange' };
    return map[group] || 'badge-gray';
}

async function promoteEmployee() {
    const username = document.getElementById('promote-username').value.trim();
    const oldGroup = document.getElementById('promote-old').value;
    const newGroup = document.getElementById('promote-new').value;
    const resultBox = document.getElementById('promote-result');

    if (!username) { showResult(resultBox, 'error', 'Enter a username'); return; }
    if (oldGroup === newGroup) { showResult(resultBox, 'error', 'Groups must be different'); return; }

    try {
        const res = await apiFetch('/api/workflow/promote', {
            method: 'POST', body: JSON.stringify({ username, oldGroup, newGroup })
        });
        if (res.status === 403) { showResult(resultBox, 'error', 'Only Admin can promote employees'); return; }
        const data = await res.json();
        showResult(resultBox, data.status, data.message);
        if (data.status === 'success') {
            showToast(`${username} promoted: ${oldGroup} → ${newGroup}`, 'success');
            setTimeout(loadLiveFeed, 500);
        }
        else showToast(`Promotion failed: ${data.message}`, 'error');
    } catch (err) { showResult(resultBox, 'error', err.message); }
}

async function offboardEmployee() {
    const username = document.getElementById('offboard-username').value.trim();
    const resultBox = document.getElementById('offboard-result');

    if (!username) { showResult(resultBox, 'error', 'Enter a username'); return; }

    const confirmed = await showConfirm(
        'Confirm Offboarding',
        `Are you sure you want to offboard "${username}"? This will permanently delete the user and revoke all AWS access.`,
        '🗑️ Yes, Offboard'
    );

    if (!confirmed) return;

    try {
        const res = await apiFetch('/api/workflow/offboard', {
            method: 'POST', body: JSON.stringify({ username })
        });
        if (res.status === 403) { showResult(resultBox, 'error', 'Only Admin can offboard employees'); return; }
        const data = await res.json();
        showResult(resultBox, data.status, data.message);
        if (data.status === 'success') {
            showToast(`${username} successfully offboarded`, 'success');
            document.getElementById('offboard-username').value = '';
            setTimeout(loadLiveFeed, 500);
        } else {
            showToast(`Offboard failed: ${data.message}`, 'error');
        }
    } catch (err) { showResult(resultBox, 'error', err.message); }
}

// ===== HELPERS =====
function showResult(box, status, msg) {
    box.className = 'result-box ' + status;
    box.textContent = (status === 'success' ? '✅ ' : '❌ ') + msg;
}

// ===== ON PAGE LOAD — restore session =====
window.onload = async function () {
    try {
        const res = await apiFetch('/api/auth/me');
        const data = await res.json();
        if (data.loggedIn) {
            currentUser = { username: data.username, role: data.role, displayName: data.displayName };
            showApp();
            showToast(`Session restored — Welcome back, ${data.displayName}!`, 'info', 3000);
        }
    } catch (err) {
        console.log('No active session, showing login page');
    }
};
