import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link, Navigate, useNavigate } from 'react-router-dom';
import { authService } from './services/api';
import Login from './components/Login';
import Dashboard from './components/Dashboard';
import ScanEndpoint from './components/ScanEndpoint';
import ResultsHistory from './components/ResultsHistory';
import ComputerManagement from './components/ComputerManagement';
import ComputerDetails from './components/ComputerDetails';
import MetricsNavigation from './components/MetricsNavigation';
import * as Metrics from './components/MetricComponents';
import './index.css';

function ProtectedRoute({ children }) {
    return authService.isAuthenticated() ? children : <Navigate to="/login" />;
}

function MainLayout() {
    const navigate = useNavigate();
    const user = authService.getCurrentUser();

    const handleLogout = () => {
        authService.logout();
        navigate('/login');
    };

    return (
        <div className="app-container">
            <header style={{
                background: 'var(--primary-color)',
                color: 'var(--text-light)',
                padding: '15px 30px',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                boxShadow: 'var(--shadow-md)'
            }}>
                <h2 style={{ margin: 0 }}>Enterprise Monitoring System</h2>
                <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                    <span>Welcome, {user?.displayName || user?.username}</span>
                    <button className="btn" onClick={handleLogout} style={{
                        background: 'rgba(255,255,255,0.2)',
                        color: 'var(--text-light)',
                        border: '1px solid rgba(255,255,255,0.3)'
                    }}>
                        Logout
                    </button>
                </div>
            </header>

            <div className="main-content">
                <aside className="sidebar">
                    <nav>
                        <ul className="nav-menu">
                            <li className="nav-item">
                                <Link to="/dashboard" style={{ textDecoration: 'none', color: 'inherit', display: 'flex', alignItems: 'center', gap: '12px' }}>
                                    <span>📊</span> Dashboard
                                </Link>
                            </li>
                            <li className="nav-item">
                                <Link to="/scan" style={{ textDecoration: 'none', color: 'inherit', display: 'flex', alignItems: 'center', gap: '12px' }}>
                                    <span>🔍</span> Scan Endpoint
                                </Link>
                            </li>
                            <li className="nav-item">
                                <Link to="/results" style={{ textDecoration: 'none', color: 'inherit', display: 'flex', alignItems: 'center', gap: '12px' }}>
                                    <span>📝</span> Results History
                                </Link>
                            </li>
                            <li className="nav-item">
                                <Link to="/computers" style={{ textDecoration: 'none', color: 'inherit', display: 'flex', alignItems: 'center', gap: '12px' }}>
                                    <span>💻</span> Computers
                                </Link>
                            </li>
                            <li className="nav-item">
                                <Link to="/metrics" style={{ textDecoration: 'none', color: 'inherit', display: 'flex', alignItems: 'center', gap: '12px' }}>
                                    <span>📈</span> Metrics Explorer
                                </Link>
                            </li>
                        </ul>
                    </nav>
                </aside>

                <main className="content-area">
                    <Routes>
                        <Route path="/dashboard" element={<Dashboard />} />
                        <Route path="/scan" element={<ScanEndpoint />} />
                        <Route path="/results" element={<ResultsHistory />} />
                        <Route path="/computers" element={<ComputerManagement />} />
                        <Route path="/computers/:computerName" element={<ComputerDetails />} />
                        <Route path="/metrics" element={<MetricsNavigation />} />

                        {/* System Health Metrics */}
                        <Route path="/metrics/cpu" element={<Metrics.CPUUsageMetric />} />
                        <Route path="/metrics/memory" element={<Metrics.MemoryMetric />} />
                        <Route path="/metrics/disk" element={<Metrics.DiskSpaceMetric />} />
                        <Route path="/metrics/disk_performance" element={<Metrics.DiskPerformanceMetric />} />
                        <Route path="/metrics/network_adapters" element={<Metrics.NetworkAdaptersMetric />} />
                        <Route path="/metrics/temperature" element={<Metrics.TemperatureMetric />} />
                        <Route path="/metrics/power" element={<Metrics.PowerStatusMetric />} />
                        <Route path="/metrics/bios" element={<Metrics.BiosInfoMetric />} />
                        <Route path="/metrics/motherboard" element={<Metrics.MotherboardMetric />} />
                        <Route path="/metrics/uptime" element={<Metrics.SystemUptimeMetric />} />

                        {/* Security Metrics */}
                        <Route path="/metrics/windows_updates" element={<Metrics.WindowsUpdatesMetric />} />
                        <Route path="/metrics/antivirus" element={<Metrics.AntivirusMetric />} />
                        <Route path="/metrics/firewall" element={<Metrics.FirewallMetric />} />
                        <Route path="/metrics/user_accounts" element={<Metrics.UserAccountsMetric />} />
                        <Route path="/metrics/groups" element={<Metrics.GroupMembershipMetric />} />
                        <Route path="/metrics/login_history" element={<Metrics.LoginHistoryMetric />} />
                        <Route path="/metrics/failed_logins" element={<Metrics.FailedLoginsMetric />} />
                        <Route path="/metrics/bitlocker" element={<Metrics.BitLockerMetric />} />
                        <Route path="/metrics/tpm" element={<Metrics.TPMMetric />} />
                        <Route path="/metrics/secure_boot" element={<Metrics.SecureBootMetric />} />
                        <Route path="/metrics/audit_policies" element={<Metrics.AuditPoliciesMetric />} />
                        <Route path="/metrics/password_policy" element={<Metrics.PasswordPolicyMetric />} />
                        <Route path="/metrics/smb_shares" element={<Metrics.SMBSharesMetric />} />
                        <Route path="/metrics/open_ports" element={<Metrics.OpenPortsMetric />} />
                        <Route path="/metrics/certificates" element={<Metrics.CertificatesMetric />} />

                        {/* Network Metrics */}
                        <Route path="/metrics/network_connections" element={<Metrics.NetworkConnectionsMetric />} />
                        <Route path="/metrics/network_stats" element={<Metrics.NetworkStatsMetric />} />
                        <Route path="/metrics/dns_cache" element={<Metrics.DNSCacheMetric />} />
                        <Route path="/metrics/routing" element={<Metrics.RoutingTableMetric />} />
                        <Route path="/metrics/network_speed" element={<Metrics.NetworkSpeedMetric />} />
                        <Route path="/metrics/wifi" element={<Metrics.WiFiNetworksMetric />} />
                        <Route path="/metrics/vpn" element={<Metrics.VPNConnectionsMetric />} />
                        <Route path="/metrics/proxy" element={<Metrics.ProxySettingsMetric />} />

                        {/* Software & Compliance Metrics */}
                        <Route path="/metrics/software" element={<Metrics.InstalledSoftwareMetric />} />
                        <Route path="/metrics/startup" element={<Metrics.StartupProgramsMetric />} />
                        <Route path="/metrics/services" element={<Metrics.ServicesMetric />} />
                        <Route path="/metrics/tasks" element={<Metrics.ScheduledTasksMetric />} />
                        <Route path="/metrics/browser_extensions" element={<Metrics.BrowserExtensionsMetric />} />
                        <Route path="/metrics/office" element={<Metrics.OfficeVersionMetric />} />
                        <Route path="/metrics/registry" element={<Metrics.RegistrySettingsMetric />} />
                        <Route path="/metrics/gpo" element={<Metrics.GPOAppliedMetric />} />
                        <Route path="/metrics/env_vars" element={<Metrics.EnvironmentVariablesMetric />} />
                        <Route path="/metrics/drivers" element={<Metrics.DriversMetric />} />
                        <Route path="/metrics/features" element={<Metrics.WindowsFeaturesMetric />} />
                        <Route path="/metrics/powershell" element={<Metrics.PowerShellVersionMetric />} />

                        {/* User Experience Metrics */}
                        <Route path="/metrics/login_time" element={<Metrics.LoginTimeMetric />} />
                        <Route path="/metrics/crashes" element={<Metrics.ApplicationCrashesMetric />} />
                        <Route path="/metrics/browser_performance" element={<Metrics.BrowserPerformanceMetric />} />
                        <Route path="/metrics/printing" element={<Metrics.PrintingIssuesMetric />} />
                        <Route path="/metrics/mapped_drives" element={<Metrics.MappedDrivesMetric />} />
                        <Route path="/metrics/printers" element={<Metrics.PrintersMetric />} />
                        <Route path="/metrics/display" element={<Metrics.DisplaySettingsMetric />} />
                        <Route path="/metrics/sound" element={<Metrics.SoundDevicesMetric />} />
                        <Route path="/metrics/usb" element={<Metrics.USBDevicesMetric />} />
                        <Route path="/metrics/bluetooth" element={<Metrics.BluetoothDevicesMetric />} />

                        {/* Event Log Metrics */}
                        <Route path="/metrics/system_events" element={<Metrics.SystemEventsMetric />} />
                        <Route path="/metrics/app_events" element={<Metrics.ApplicationEventsMetric />} />
                        <Route path="/metrics/security_events" element={<Metrics.SecurityEventsMetric />} />
                        <Route path="/metrics/errors" element={<Metrics.ErrorSummaryMetric />} />
                        <Route path="/metrics/warnings" element={<Metrics.WarningSummaryMetric />} />

                        {/* Performance Baseline Metrics */}
                        <Route path="/metrics/baseline" element={<Metrics.PerformanceBaselineMetric />} />
                        <Route path="/metrics/health_history" element={<Metrics.HealthScoreHistoryMetric />} />
                        <Route path="/metrics/compliance" element={<Metrics.ComplianceScoreMetric />} />

                        <Route path="/" element={<Navigate to="/dashboard" />} />
                    </Routes>
                </main>
            </div>
        </div>
    );
}

function App() {
    return (
        <Router>
            <Routes>
                <Route path="/login" element={<Login />} />
                <Route path="/*" element={
                    <ProtectedRoute>
                        <MainLayout />
                    </ProtectedRoute>
                } />
            </Routes>
        </Router>
    );
}

export default App;
