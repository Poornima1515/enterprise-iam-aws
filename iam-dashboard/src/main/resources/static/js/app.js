const API = '';
let currentUser = null;

// ===== FETCH HELPER — always include credentials for session cookies =====
async function apiFetch(url, options = {}) {
    const defaults = {
        credentials: 'include',   // CRITICAL: sends session cookie with every request
        headers: { 'Content-Type': 'application/json', ...options.headers }
    };
    return fetch(API + url, { ...defaults, ...options });
}

// ===== ROLE-BASED NAVIGATION CONFIG =====
const ROLE_MENUS = {
    Admin: [
        { id: 'dashboard', icon: '📊', label: 'Dashboard' },
        { id: 'users',     icon: '👥', label: 'IAM Users' },
        { id: 'groups',    icon: '🏷️', label: 'IAM Groups' },
        { id: 'roles',     icon: '🎭', label: 'IAM Roles' },
        { id: 'workflow',  icon: '⚙️', label: 'Employee Workflow' },
        { id: 'audit',     icon: '📋', label: 'Audit Logs' },
    ],
    Developer: [
        { id: 'ec2', icon: '🖥️', label: 'EC2 Status' },
    ],
    Tester: [
        { id: 'ec2', icon: '🖥️', label: 'EC2 Status (Read)' },
    ],
    DatabaseAdmin: [
        { id: 'ec2', icon: '🗄️', label: 'My Access Info' },
    ],
    Auditor: [
        { id: 'audit', icon: '📋', label: 'Audit Logs' },
    ]
};

const ROLE_WELCOME = {
    Admin:         'Full system access',
    Developer:     'EC2 start/stop access',
    Tester:        'Read-only access',
    DatabaseAdmin: 'RDS management access',
    Auditor:       'CloudTrail read access'
};

// ===== GROUP BADGE =====
function getGroupBadge(group) {
    const map = {
        Admin: 'badge-red', Developer: 'badge-blue',
        Tester: 'badge-green', DatabaseAdmin: 'badge-purple',
        Auditor: 'badge-orange', 'No Group': 'badge-gray'
    };
    return `<span class="badge ${map[group] || 'badge-gray'}">${group}</span>`;
}

// ===== LOGIN =====
async function doLogin() {
    const keyId = document.getElementById('login-key-id').value.trim();
    const secret = document.getElementById('login-secret').value.trim();
    const btn = document.getElementById('login-btn');
    const errBox = document.getElementById('login-error');

    errBox.style.display = 'none';

    if (!keyId || !secret) {
        showLoginError('Please enter both Access Key ID and Secret Access Key');
        return;
    }

    btn.disabled = true;
    btn.textContent = '⏳ Signing in...';

    try {
        const res = await apiFetch('/api/auth/login', {
            method: 'POST',
            body: JSON.stringify({ accessKeyId: keyId, secretAccessKey: secret })
        });
        const data = await res.json();

        if (data.success) {
            currentUser = {
                username: data.username,
                role: data.role,
                displayName: data.displayName
            };
            showApp();
        } else {
            showLoginError(data.message || 'Login failed. Check your credentials.');
        }
    } catch (err) {
        showLoginError('Cannot connect to server. Make sure the app is running on port 8080.');
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
    if (e.key === 'Enter' && document.getElementById('login-page').style.display !== 'none') {
        doLogin();
    }
});

// ===== SHOW APP AFTER LOGIN =====
function showApp() {
    document.getElementById('login-page').style.display = 'none';
    document.getElementById('app-page').style.display = 'flex';

    document.getElementById('sidebar-username').textContent = currentUser.displayName;
    const badge = document.getElementById('sidebar-role-badge');
    badge.textContent = currentUser.role;
    badge.className = `role-badge role-${currentUser.role}`;
    document.getElementById('header-user').textContent =
        currentUser.displayName + ' (' + currentUser.role + ')';

    buildNav(currentUser.role);

    const firstPage = ROLE_MENUS[currentUser.role]?.[0]?.id || 'dashboard';
    navigateTo(firstPage);
}

// ===== BUILD SIDEBAR NAV =====
function buildNav(role) {
    const nav = document.getElementById('sidebar-nav');
    const menus = ROLE_MENUS[role] || [];

    nav.innerHTML = menus.map(m => `
        <a class="nav-item" onclick="navigateTo('${m.id}')" id="nav-${m.id}">
            ${m.icon} ${m.label}
        </a>
    `).join('');

    nav.innerHTML += `
        <div style="padding:15px 24px;margin-top:10px;border-top:1px solid rgba(255,255,255,0.1)">
            <p style="font-size:11px;color:rgba(255,255,255,0.4)">Your Access Level</p>
            <p style="font-size:12px;color:rgba(255,255,255,0.7);margin-top:4px">
                ${ROLE_WELCOME[role] || ''}
            </p>
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

    const titles = {
        dashboard: 'Dashboard', users: 'IAM Users', groups: 'IAM Groups',
        roles: 'IAM Roles', workflow: 'Employee Workflow', audit: 'Audit Logs',
        ec2: 'EC2 Status', denied: 'Access Denied'
    };
    document.getElementById('page-title').textContent = titles[page] || page;

    if (page === 'dashboard') loadDashboard();
    if (page === 'users') loadUsers();
    if (page === 'groups') loadGroups();
    if (page === 'roles') loadRoles();
    if (page === 'audit') loadAudit();
    if (page === 'ec2') loadEc2();
}

// ===== LOGOUT =====
async function doLogout() {
    await apiFetch('/api/auth/logout', { method: 'POST' });
    currentUser = null;
    document.getElementById('app-page').style.display = 'none';
    document.getElementById('login-page').style.display = 'flex';
    document.getElementById('login-key-id').value = '';
    document.getElementById('login-secret').value = '';
    document.getElementById('login-error').style.display = 'none';
}

// ===== DASHBOARD (Admin) =====
async function loadDashboard() {
    try {
        const res = await apiFetch('/api/dashboard');
        if (res.status === 403) {
            document.getElementById('page-dashboard').innerHTML =
                '<div class="denied-box"><div class="denied-icon">🚫</div><h2>Access Denied</h2><p>Admin role required</p></div>';
            return;
        }
        const data = await res.json();

        document.getElementById('stat-users').textContent = data.stats.userCount;
        document.getElementById('stat-groups').textContent = data.stats.groupCount;
        document.getElementById('stat-policies').textContent = data.stats.policyCount;
        document.getElementById('stat-roles').textContent = data.stats.roleCount;
        document.getElementById('stat-mfa').textContent = data.stats.mfaCount;

        const ct = data.cloudtrail;
        document.getElementById('cloudtrail-status').innerHTML = `
            <div class="status-row"><span class="status-label">Trail</span>
                <span class="status-value">${ct.trailName || 'IAM-Project-Trail'}</span></div>
            <div class="status-row"><span class="status-label">Status</span>
                <span class="status-value">
                    <span class="badge ${ct.isLogging ? 'badge-green' : 'badge-red'}">
                        ${ct.isLogging ? '● Active' : '● Stopped'}
                    </span></span></div>
            <div class="status-row"><span class="status-label">Last Delivery</span>
                <span class="status-value" style="font-size:11px">
                    ${ct.latestDeliveryTime || 'N/A'}</span></div>`;

        const ec2 = data.ec2;
        const sc = ec2.state === 'running' ? 'badge-green' :
                   ec2.state === 'stopped' ? 'badge-red' : 'badge-yellow';
        document.getElementById('ec2-status-dash').innerHTML = `
            <div class="status-row"><span class="status-label">Instance</span>
                <span class="status-value" style="font-size:11px">${ec2.instanceId}</span></div>
            <div class="status-row"><span class="status-label">State</span>
                <span class="status-value"><span class="badge ${sc}">${ec2.state}</span></span></div>
            <div class="status-row"><span class="status-label">Type</span>
                <span class="status-value">${ec2.instanceType || 'N/A'}</span></div>`;

        const tbody = document.getElementById('recent-events');
        tbody.innerHTML = (!data.recentEvents || data.recentEvents.length === 0)
            ? '<tr><td colspan="3" style="text-align:center;color:#888">No events found</td></tr>'
            : data.recentEvents.map(e => `
                <tr><td><span class="badge badge-blue">${e.eventName}</span></td>
                    <td>${e.username}</td>
                    <td style="font-size:12px">${new Date(e.eventTime).toLocaleString()}</td>
                </tr>`).join('');

    } catch (err) {
        console.error('Dashboard error:', err);
    }
}

// ===== USERS (Admin) =====
async function loadUsers() {
    try {
        const res = await apiFetch('/api/users');
        if (res.status === 403) return;
        const users = await res.json();
        document.getElementById('users-table').innerHTML = users.map(u => `
            <tr>
                <td><strong>${u.username}</strong></td>
                <td>${getGroupBadge(u.groups)}</td>
                <td><span class="badge ${u.mfaActive ? 'badge-green' : 'badge-red'}">
                    ${u.mfaActive ? '🔐 MFA ON' : '⚠️ MFA OFF'}</span></td>
                <td style="font-size:12px">${new Date(u.createDate).toLocaleDateString()}</td>
            </tr>`).join('');
    } catch (err) { console.error(err); }
}

// ===== GROUPS (Admin) =====
async function loadGroups() {
    try {
        const res = await apiFetch('/api/groups');
        if (res.status === 403) return;
        const groups = await res.json();
        document.getElementById('groups-table').innerHTML = groups.map(g => `
            <tr>
                <td>${getGroupBadge(g.groupName)}</td>
                <td style="font-size:12px">${g.policies}</td>
                <td><strong>${g.memberCount}</strong></td>
            </tr>`).join('');
    } catch (err) { console.error(err); }
}

// ===== ROLES (Admin) =====
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

// ===== AUDIT (Admin + Auditor) =====
async function loadAudit() {
    try {
        const limitEl = document.getElementById('audit-limit');
        const limit = limitEl ? limitEl.value : 20;
        const res = await apiFetch(`/api/audit?limit=${limit}`);
        if (res.status === 403) return;
        const events = await res.json();
        document.getElementById('audit-table').innerHTML = events.length === 0
            ? '<tr><td colspan="4" style="text-align:center;color:#888">No events found</td></tr>'
            : events.map((e, i) => `
                <tr>
                    <td style="color:#888">${i + 1}</td>
                    <td><span class="badge badge-blue">${e.eventName}</span></td>
                    <td>${e.username}</td>
                    <td style="font-size:12px">${new Date(e.eventTime).toLocaleString()}</td>
                </tr>`).join('');
    } catch (err) { console.error(err); }
}

// ===== EC2 (Developer + Tester + DatabaseAdmin) =====
async function loadEc2() {
    try {
        const res = await apiFetch('/api/ec2/status');
        if (res.status === 403) {
            document.getElementById('ec2-status-full').innerHTML =
                '<p style="color:#e94560;padding:10px">❌ Access denied for your role</p>';
            return;
        }
        const ec2 = await res.json();
        const sc = ec2.state === 'running' ? 'badge-green' :
                   ec2.state === 'stopped' ? 'badge-red' : 'badge-yellow';

        document.getElementById('ec2-status-full').innerHTML = `
            <div class="status-row"><span class="status-label">Name</span>
                <span class="status-value">EC2-ProjectServer</span></div>
            <div class="status-row"><span class="status-label">Instance ID</span>
                <span class="status-value">${ec2.instanceId}</span></div>
            <div class="status-row"><span class="status-label">State</span>
                <span class="status-value"><span class="badge ${sc}">${ec2.state}</span></span></div>
            <div class="status-row"><span class="status-label">Type</span>
                <span class="status-value">${ec2.instanceType || 'N/A'}</span></div>
            <div class="status-row"><span class="status-label">Private IP</span>
                <span class="status-value">${ec2.privateIp || 'N/A'}</span></div>`;

        const noteEl = document.getElementById('ec2-access-note');
        if (currentUser?.role === 'Developer') {
            noteEl.innerHTML = '💡 As Developer, you can Start/Stop this instance using AWS CLI or Console.';
        } else if (currentUser?.role === 'Tester') {
            noteEl.innerHTML = '👁️ As Tester, you have read-only view. No modifications allowed.';
        } else if (currentUser?.role === 'DatabaseAdmin') {
            noteEl.innerHTML = '🗄️ Your access is scoped to RDS. EC2 access is view-only here.';
        }
    } catch (err) { console.error(err); }
}

// ===== WORKFLOW (Admin only) =====
async function onboardEmployee() {
    const username = document.getElementById('onboard-username').value.trim();
    const department = document.getElementById('onboard-dept').value;
    const employeeId = document.getElementById('onboard-empid').value.trim();
    const resultBox = document.getElementById('onboard-result');

    if (!username || !employeeId) {
        showResult(resultBox, 'error', 'Please fill in all fields');
        return;
    }

    try {
        const res = await apiFetch('/api/workflow/onboard', {
            method: 'POST',
            body: JSON.stringify({ username, department, employeeId })
        });
        if (res.status === 403) {
            showResult(resultBox, 'error', 'Only Admin can onboard employees');
            return;
        }
        const data = await res.json();
        showResult(resultBox, data.status, data.message);
        if (data.status === 'success') {
            document.getElementById('onboard-username').value = '';
            document.getElementById('onboard-empid').value = '';
        }
    } catch (err) {
        showResult(resultBox, 'error', 'Request failed: ' + err.message);
    }
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
            method: 'POST',
            body: JSON.stringify({ username, oldGroup, newGroup })
        });
        if (res.status === 403) {
            showResult(resultBox, 'error', 'Only Admin can promote employees');
            return;
        }
        const data = await res.json();
        showResult(resultBox, data.status, data.message);
    } catch (err) {
        showResult(resultBox, 'error', 'Request failed: ' + err.message);
    }
}

async function offboardEmployee() {
    const username = document.getElementById('offboard-username').value.trim();
    const resultBox = document.getElementById('offboard-result');

    if (!username) { showResult(resultBox, 'error', 'Enter a username'); return; }
    if (!confirm(`⚠️ Offboard "${username}"? This permanently deletes the user.`)) return;

    try {
        const res = await apiFetch('/api/workflow/offboard', {
            method: 'POST',
            body: JSON.stringify({ username })
        });
        if (res.status === 403) {
            showResult(resultBox, 'error', 'Only Admin can offboard employees');
            return;
        }
        const data = await res.json();
        showResult(resultBox, data.status, data.message);
        if (data.status === 'success') document.getElementById('offboard-username').value = '';
    } catch (err) {
        showResult(resultBox, 'error', 'Request failed: ' + err.message);
    }
}

// ===== HELPERS =====
function showResult(box, status, msg) {
    box.className = 'result-box ' + status;
    box.textContent = (status === 'success' ? '✅ ' : '❌ ') + msg;
}
