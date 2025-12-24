import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000/api';

// Create axios instance with default config
const apiClient = axios.create({
    baseURL: API_BASE_URL,
    headers: {
        'Content-Type': 'application/json'
    }
});

// Add auth token to requests
apiClient.interceptors.request.use(
    (config) => {
        const token = localStorage.getItem('auth_token');
        if (token) {
            config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
    },
    (error) => Promise.reject(error)
);

// Handle auth errors
apiClient.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.response?.status === 401) {
            localStorage.removeItem('auth_token');
            localStorage.removeItem('user');
            window.location.href = '/login';
        } return Promise.reject(error);
    }
);

export const authService = {
    login: async (username, password, provider = null) => {
        const response = await apiClient.post('/auth/login', { username, password, provider });
        if (response.data.success && response.data.token) {
            localStorage.setItem('auth_token', response.data.token);
            localStorage.setItem('user', JSON.stringify(response.data.user));
        }
        return response.data;
    },

    logout: () => {
        localStorage.removeItem('auth_token');
        localStorage.removeItem('user');
    },

    validate: async () => {
        try {
            const response = await apiClient.get('/auth/validate');
            return response.data.valid;
        } catch {
            return false;
        }
    },

    getCurrentUser: () => {
        const userJson = localStorage.getItem('user');
        return userJson ? JSON.parse(userJson) : null;
    },

    isAuthenticated: () => {
        return !!localStorage.getItem('auth_token');
    },

    getProviders: async () => {
        const response = await apiClient.get('/auth/providers');
        return response.data;
    }
};

export const scanService = {
    scanSingle: async (target) => {
        const response = await apiClient.post('/scan/single', { target });
        return response.data;
    }
};

export const resultsService = {
    getResults: async (params = {}) => {
        const response = await apiClient.get('/results', { params });
        return response.data;
    },

    getResultById: async (id) => {
        const response = await apiClient.get(`/results/${id}`);
        return response.data;
    }
};

export const dashboardService = {
    getStats: async () => {
        const response = await apiClient.get('/dashboard/stats');
        return response.data.statistics;
    }
};

export const computerService = {
    getComputers: async (limit = 100) => {
        const response = await apiClient.get(`/computers?limit=${limit}`);
        return response.data;
    },

    getComputer: async (computerName) => {
        const response = await apiClient.get(`/computers/${computerName}`);
        return response.data;
    },

    registerComputer: async (computerData) => {
        const response = await apiClient.post('/computers', computerData);
        return response.data;
    },

    getComputerMetrics: async (computerName, metricType = 'all') => {
        const response = await apiClient.get(`/computers/${computerName}/metrics?type=${metricType}`);
        return response.data;
    }
};

export default apiClient;
