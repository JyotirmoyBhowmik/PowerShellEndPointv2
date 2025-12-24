import React, { useState, useEffect } from 'react';
import { resultsService } from '../services/api';

function ResultsHistory() {
    const [results, setResults] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('');

    useEffect(() => {
        loadResults();
    }, []);

    const loadResults = async () => {
        try {
            const data = await resultsService.getResults({ limit: 100 });
            setResults(data.results || []);
        } catch (error) {
            console.error('Failed to load results:', error);
        } finally {
            setLoading(false);
        }
    };

    const filteredResults = results.filter(r =>
        r.hostname.toLowerCase().includes(filter.toLowerCase()) ||
        (r.user_id_resolved && r.user_id_resolved.toLowerCase().includes(filter.toLowerCase()))
    );

    const getHealthBadge = (score) => {
        if (score >= 90) return 'badge-success';
        if (score >= 70) return 'badge-info';
        if (score >= 50) return 'badge-warning';
        return 'badge-danger';
    };

    const getStatusBadge = (status) => {
        switch (status) {
            case 'completed': return 'badge-success';
            case 'failed': return 'badge-danger';
            case 'in_progress': return 'badge-info';
            default: return 'badge-info';
        }
    };

    if (loading) {
        return <div className="spinner"></div>;
    }

    return (
        <div>
            <h1 style={{ marginBottom: '30px' }}>Scan Results History</h1>

            <div className="card" style={{ marginBottom: '20px' }}>
                <div style={{ display: 'flex', gap: '15px', alignItems: 'center' }}>
                    <div className="form-group" style={{ flex: 1, marginBottom: 0 }}>
                        <input
                            type="text"
                            className="form-control"
                            placeholder="Filter by hostname or user..."
                            value={filter}
                            onChange={(e) => setFilter(e.target.value)}
                        />
                    </div>
                    <button className="btn btn-primary" onClick={loadResults}>
                        Refresh
                    </button>
                </div>
            </div>

            <div className="card">
                <h3 style={{ marginBottom: '20px' }}>
                    {filteredResults.length} Results
                </h3>

                <div className="table-container">
                    <table>
                        <thead>
                            <tr>
                                <th>Timestamp</th>
                                <th>Hostname</th>
                                <th>IP Address</th>
                                <th>User</th>
                                <th>Health Score</th>
                                <th>Status</th>
                                <th>Alerts</th>
                                <th>Topology</th>
                            </tr>
                        </thead>
                        <tbody>
                            {filteredResults.length === 0 ? (
                                <tr>
                                    <td colSpan="8" style={{ textAlign: 'center', color: 'var(--text-secondary)' }}>
                                        No results found
                                    </td>
                                </tr>
                            ) : (
                                filteredResults.map((result, idx) => (
                                    <tr key={idx}>
                                        <td>{new Date(result.scan_timestamp).toLocaleString()}</td>
                                        <td><strong>{result.hostname}</strong></td>
                                        <td>{result.ip_address || 'N/A'}</td>
                                        <td>{result.user_id_resolved || '-'}</td>
                                        <td>
                                            <span className={`badge ${getHealthBadge(result.health_score)}`}>
                                                {result.health_score}
                                            </span>
                                        </td>
                                        <td>
                                            <span className={`badge ${getStatusBadge(result.status)}`}>
                                                {result.status}
                                            </span>
                                        </td>
                                        <td>
                                            <span style={{ color: 'var(--error-color)', fontWeight: '600', marginRight: '10px' }}>
                                                {result.critical_count || 0} C
                                            </span>
                                            <span style={{ color: 'var(--warning-color)', fontWeight: '600' }}>
                                                {result.warning_count || 0} W
                                            </span>
                                        </td>
                                        <td>{result.topology}</td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
}

export default ResultsHistory;
