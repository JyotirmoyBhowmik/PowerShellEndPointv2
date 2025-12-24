import React, { useState, useEffect } from 'react';
import { dashboardService } from '../services/api';

function Dashboard() {
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        loadStats();
        const interval = setInterval(loadStats, 30000); // Refresh every 30 seconds
        return () => clearInterval(interval);
    }, []);

    const loadStats = async () => {
        try {
            const data = await dashboardService.getStats();
            setStats(data);
        } catch (error) {
            console.error('Failed to load stats:', error);
        } finally {
            setLoading(false);
        }
    };

    if (loading) {
        return <div className="spinner"></div>;
    }

    return (
        <div>
            <h1 style={{ marginBottom: '30px' }}>Dashboard</h1>

            {stats && (
                <>
                    <div className="stat-cards">
                        <div className="stat-card">
                            <div className="stat-label">Total Scans</div>
                            <div className="stat-value">{stats.total_scans || 0}</div>
                            <div style={{ fontSize: '0.85rem', marginTop: '8px' }}>
                                {stats.scans_last_24h || 0} in last 24h
                            </div>
                        </div>

                        <div className="stat-card" style={{ background: 'linear-gradient(135deg, #4caf50, #81c784)' }}>
                            <div className="stat-label">Healthy Endpoints</div>
                            <div className="stat-value">{stats.excellent_health || 0}</div>
                            <div style={{ fontSize: '0.85rem', marginTop: '8px' }}>
                                Health Score ≥ 90
                            </div>
                        </div>

                        <div className="stat-card" style={{ background: 'linear-gradient(135deg, #f44336, #e57373)' }}>
                            <div className="stat-label">Critical Alerts</div>
                            <div className="stat-value">{stats.total_critical_alerts || 0}</div>
                            <div style={{ fontSize: '0.85rem', marginTop: '8px' }}>
                                Requires attention
                            </div>
                        </div>

                        <div className="stat-card" style={{ background: 'linear-gradient(135deg, #2196f3, #64b5f6)' }}>
                            <div className="stat-label">Unique Endpoints</div>
                            <div className="stat-value">{stats.unique_endpoints || 0}</div>
                            <div style={{ fontSize: '0.85rem', marginTop: '8px' }}>
                                Monitored devices
                            </div>
                        </div>
                    </div>

                    <div className="card">
                        <h3 style={{ marginBottom: '20px' }}>System Health Overview</h3>
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '20px' }}>
                            <div>
                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                                    <span>Excellent</span>
                                    <strong style={{ color: 'var(--success-color)' }}>
                                        {stats.excellent_health || 0}
                                    </strong>
                                </div>
                                <div className="health-score-bar">
                                    <div className="health-score-fill health-excellent"
                                        style={{ width: `${((stats.excellent_health || 0) / (stats.total_scans || 1)) * 100}%` }}>
                                    </div>
                                </div>
                            </div>

                            <div>
                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                                    <span>Good</span>
                                    <strong style={{ color: 'var(--info-color)' }}>
                                        {stats.good_health || 0}
                                    </strong>
                                </div>
                                <div className="health-score-bar">
                                    <div className="health-score-fill health-good"
                                        style={{ width: `${((stats.good_health || 0) / (stats.total_scans || 1)) * 100}%` }}>
                                    </div>
                                </div>
                            </div>

                            <div>
                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                                    <span>Fair</span>
                                    <strong style={{ color: 'var(--warning-color)' }}>
                                        {stats.fair_health || 0}
                                    </strong>
                                </div>
                                <div className="health-score-bar">
                                    <div className="health-score-fill health-fair"
                                        style={{ width: `${((stats.fair_health || 0) / (stats.total_scans || 1)) * 100}%` }}>
                                    </div>
                                </div>
                            </div>

                            <div>
                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                                    <span>Poor</span>
                                    <strong style={{ color: 'var(--error-color)' }}>
                                        {stats.poor_health || 0}
                                    </strong>
                                </div>
                                <div className="health-score-bar">
                                    <div className="health-score-fill health-poor"
                                        style={{ width: `${((stats.poor_health || 0) / (stats.total_scans || 1)) * 100}%` }}>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginTop: '20px' }}>
                        <div className="card">
                            <h3 style={{ marginBottom: '15px' }}>Scan Status</h3>
                            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid var(--border-color)' }}>
                                <span>Completed</span>
                                <span className="badge badge-success">{stats.completed_scans || 0}</span>
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid var(--border-color)' }}>
                                <span>Failed</span>
                                <span className="badge badge-danger">{stats.failed_scans || 0}</span>
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0' }}>
                                <span>In Progress</span>
                                <span className="badge badge-info">{stats.in_progress_scans || 0}</span>
                            </div>
                        </div>

                        <div className="card">
                            <h3 style={{ marginBottom: '15px' }}>Performance Metrics</h3>
                            <div style={{ padding: '10px 0', borderBottom: '1px solid var(--border-color)' }}>
                                <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '5px' }}>
                                    Average Scan Time
                                </div>
                                <div style={{ fontSize: '1.5rem', fontWeight: '600', color: 'var(--primary-color)' }}>
                                    {stats.avg_scan_time ? `${stats.avg_scan_time.toFixed(2)}s` : 'N/A'}
                                </div>
                            </div>
                            <div style={{ padding: '10px 0', marginTop: '10px' }}>
                                <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '5px' }}>
                                    Last Scan
                                </div>
                                <div style={{ fontSize: '1rem', color: 'var(--text-primary)' }}>
                                    {stats.last_scan_time ? new Date(stats.last_scan_time).toLocaleString() : 'N/A'}
                                </div>
                            </div>
                        </div>
                    </div>
                </>
            )}
        </div>
    );
}

export default Dashboard;
