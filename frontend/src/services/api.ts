import axios from 'axios';

const API = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:3000/api',
});

API.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export const login = async (username: string, password: string) => {
  const response = await API.post('/auth/login', { username, password });
  return response.data;
};

export const getProfile = async () => {
  const response = await API.get('/profile');
  return response.data;
};

export const updateProfile = async (data: any) => {
  const response = await API.put('/profile', data);
  return response.data;
};