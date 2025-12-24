import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link, Navigate, useNavigate } from 'react-router-dom';
import { authService } from './services/api';
import Login from './components/Login';
import Dashboard from './components/Dashboard';
import ScanEndpoint from './components/ScanEndpoint';
import ResultsHistory from './components/ResultsHistory';
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
                        </ul>
                    </nav>
                </aside>

                <main className="content-area">
                    <Routes>
                        <Route path="/dashboard" element={<Dashboard />} />
                        <Route path="/scan" element={<ScanEndpoint />} />
                        <Route path="/results" element={<ResultsHistory />} />
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
