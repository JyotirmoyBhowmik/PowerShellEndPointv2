import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { authService } from '../services/api';

function Login({ onLogin }) {
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [provider, setProvider] = useState('ActiveDirectory');
    const [providers, setProviders] = useState([]);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    useEffect(() => {
        // Fetch available authentication providers
        const fetchProviders = async () => {
            try {
                const response = await authService.getProviders();
                setProviders(response.providers || []);
                // Set default provider to first enabled one
                if (response.providers && response.providers.length > 0) {
                    setProvider(response.providers[0].Name);
                }
            } catch (err) {
                console.error('Failed to fetch auth providers:', err);
                // Fallback to ActiveDirectory if can't fetch
                setProviders([{ Name: 'ActiveDirectory', RequiresCredentials: true }]);
            }
        };

        fetchProviders();
    }, []);

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            const response = await authService.login(username, password, provider);

            if (response.success) {
                // Store token and user info
                localStorage.setItem('token', response.token);
                localStorage.setItem('user', JSON.stringify(response.user));
                localStorage.setItem('authProvider', response.provider || provider);

                if (onLogin) onLogin(response.user);
                navigate('/dashboard');
            } else {
                setError(response.message || 'Login failed');
            }
        } catch (err) {
            setError(err.response?.data?.message || 'Authentication failed. Please check your credentials.');
        } finally {
            setLoading(false);
        }
    };

    const getProviderDisplayName = (providerName) => {
        const names = {
            'Standalone': 'Local Account',
            'ActiveDirectory': 'Active Directory',
            'LDAP': 'LDAP Server',
            'ADFS': 'ADFS',
            'SSO': 'Single Sign-On'
        };
        return names[providerName] || providerName;
    };

    const getUsernamePlaceholder = () => {
        if (provider === 'ActiveDirectory') return 'DOMAIN\\username';
        if (provider === 'LDAP') return 'username or email';
        return 'username';
    };

    return (
        <div style={{
            minHeight: '100vh',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            background: 'linear-gradient(135deg, #1a237e 0%, #534bae 100%)'
        }}>
            <div className="card" style={{ width: '100%', maxWidth: '420px' }}>
                <h2 style={{ marginBottom: '10px', color: 'var(--primary-color)' }}>
                    Enterprise Monitoring System
                </h2>
                <p style={{ marginBottom: '30px', color: 'var(--text-secondary)' }}>
                    Sign in to access the dashboard
                </p>

                {error && (
                    <div style={{
                        padding: '12px',
                        marginBottom: '20px',
                        background: '#f8d7da',
                        color: '#721c24',
                        borderRadius: '6px'
                    }}>
                        {error}
                    </div>
                )}

                <form onSubmit={handleSubmit}>
                    {providers.length > 1 && (
                        <div className="form-group" style={{ marginBottom: '20px' }}>
                            <label className="form-label">Authentication Method</label>
                            <select
                                className="form-control"
                                value={provider}
                                onChange={(e) => setProvider(e.target.value)}
                                disabled={loading}
                            >
                                {providers.map((p) => (
                                    <option key={p.Name} value={p.Name}>
                                        {getProviderDisplayName(p.Name)}
                                    </option>
                                ))}
                            </select>
                        </div>
                    )}

                    <div className="form-group">
                        <label className="form-label">Username</label>
                        <input
                            type="text"
                            className="form-control"
                            placeholder={getUsernamePlaceholder()}
                            value={username}
                            onChange={(e) => setUsername(e.target.value)}
                            required
                            disabled={loading}
                            autoFocus
                        />
                    </div>

                    <div className="form-group">
                        <label className="form-label">Password</label>
                        <input
                            type="password"
                            className="form-control"
                            placeholder="Enter your password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            required
                            disabled={loading}
                        />
                    </div>

                    <button
                        type="submit"
                        className="btn btn-primary"
                        style={{ width: '100%', marginTop: '10px' }}
                        disabled={loading}
                    >
                        {loading ? 'Signing in...' : 'Sign In'}
                    </button>
                </form>

                <div style={{ marginTop: '20px', textAlign: 'center' }}>
                    <small style={{ color: 'var(--text-secondary)' }}>
                        Powered by EMS v2.1 | {provider !== 'Standalone' && `Using ${getProviderDisplayName(provider)}`}
                    </small>
                </div>
            </div>
        </div>
    );
}

export default Login;
