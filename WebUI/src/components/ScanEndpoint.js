import React, { useState } from 'react';
import { scanService } from '../services/api';

function ScanEndpoint() {
    const [target, setTarget] = useState('');
    const [scanning, setScanning] = useState(false);
    const [result, setResult] = useState(null);
    const [error, setError] = useState('');

    const handleScan = async (e) => {
        e.preventDefault();
        setError('');
        setResult(null);
        setScanning(true);

        try {
            const data = await scanService.scanSingle(target);

            if (data.success) {
                setResult(data.results[0]);
            } else {
                setError(data.message || 'Scan failed');
            }
        } catch (err) {
            setError(err.response?.data?.message || 'Network error');
        } finally {
            setScanning(false);
        }
    };

    const getHealthColor = (score) => {
        if (score >= 90) return 'var(--success-color)';
        if (score >= 70) return 'var(--info-color)';
        if (score >= 50) return 'var(--warning-color)';
        return 'var(--error-color)';
    };

    return (
        <div>
            <h1 style={{ marginBottom: '30px' }}>Scan Endpoint</h1>

            <div className="card">
                <form onSubmit={handleScan}>
                    <div className="form-group">
                        <label className="form-label">Target (Hostname, IP, or User ID)</label>
                        <input
                            type="text"
                            className="form-control"
                            placeholder="e.g., WKSTN-HO-01 or jsmith"
                            value={target}
                            onChange={(e) => setTarget(e.target.value)}
                            required
                            disabled={scanning}
                        />
                    </div>

                    <button
                        type="submit"
                        className="btn btn-primary"
                        disabled={scanning}
                    >
                        {scanning ? 'Scanning...' : 'Start Scan'}
                    </button>
                </form>

                {error && (
                    <div style={{
                        marginTop: '20px',
                        padding: '12px',
                        background: '#f8d7da',
                        color: '#721c24',
                        borderRadius: '6px'
                    }}>
                        {error}
                    </div>
                )}
            </div>

            {scanning && (
                <div className="card" style={{ textAlign: 'center' }}>
                    <div className="spinner"></div>
                    <p style={{ marginTop: '10px', color: 'var(--text-secondary)' }}>
                        Scanning endpoint... This may take a moment.
                    </p>
                </div>
            )}

            {result && (
                <div className="card">
                    <h2 style={{ marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '15px' }}>
                        Scan Results
                        <span style={{
                            fontSize: '2rem',
                            fontWeight: '700',
                            color: getHealthColor(result.HealthScore)
                        }}>
                            {result.HealthScore}
                        </span>
                    </h2>

                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '15px', marginBottom: '20px' }}>
                        <div>
                            <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Hostname</div>
                            <div style={{ fontWeight: '600' }}>{result.Hostname}</div>
                        </div>
                        <div>
                            <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>IP Address</div>
                            <div style={{ fontWeight: '600' }}>{result.IPAddress || 'N/A'}</div>
                        </div>
                        <div>
                            <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Topology</div>
                            <div style={{ fontWeight: '600' }}>{result.Topology}</div>
                        </div>
                        <div>
                            <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Scan Time</div>
                            <div style={{ fontWeight: '600' }}>{result.ExecutionTimeSeconds}s</div>
                        </div>
                    </div>

                    <div style={{ marginTop: '20px' }}>
                        <h3 style={{ marginBottom: '15px' }}>Alert Summary</h3>
                        <div style={{ display: 'flex', gap: '20px' }}>
                            <div>
                                <span className="badge badge-danger" style={{ fontSize: '1rem', padding: '8px 16px' }}>
                                    {result.CriticalAlerts || 0} Critical
                                </span>
                            </div>
                            <div>
                                <span className="badge badge-warning" style={{ fontSize: '1rem', padding: '8px 16px' }}>
                                    {result.WarningAlerts || 0} Warnings
                                </span>
                            </div>
                            <div>
                                <span className="badge badge-info" style={{ fontSize: '1rem', padding: '8px 16px' }}>
                                    {result.InfoAlerts || 0} Info
                                </span>
                            </div>
                        </div>
                    </div>

                    {result.Diagnostics && result.Diagnostics.length > 0 && (
                        <div style={{ marginTop: '30px' }}>
                            <h3 style={{ marginBottom: '15px' }}>Diagnostic Details</h3>
                            <div className="table-container">
                                <table>
                                    <thead>
                                        <tr>
                                            <th>Category</th>
                                            <th>Check</th>
                                            <th>Status</th>
                                            <th>Severity</th>
                                            <th>Message</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {result.Diagnostics.map((diag, idx) => (
                                            <tr key={idx}>
                                                <td>{diag.Category}</td>
                                                <td><code>{diag.CheckName}</code></td>
                                                <td>{diag.Status}</td>
                                                <td>
                                                    <span className={`badge badge-${diag.Severity === 'Critical' ? 'danger' :
                                                            diag.Severity === 'Warning' ? 'warning' : 'info'
                                                        }`}>
                                                        {diag.Severity}
                                                    </span>
                                                </td>
                                                <td>{diag.Message}</td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    )}
                </div>
            )}
        </div>
    );
}

export default ScanEndpoint;
