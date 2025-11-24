import axios from 'axios';

const CONTROLD_API = axios.create({
  baseURL: 'https://api.controld.com',
  headers: {
    'X-API-Key': process.env.CONTROLD_API_KEY,
    'Content-Type': 'application/json',
  },
});

export const getProfile = async (endpointId: string) => {
  try {
    const response = await CONTROLD_API.get(`/profiles/${endpointId}`);
    return response.data.body;
  } catch (error: any) {
    throw new Error(error.response?.data?.message || 'Failed to fetch profile');
  }
};

export const updateProfile = async (endpointId: string, data: any) => {
  try {
    const response = await CONTROLD_API.put(`/profiles/${endpointId}`, data);
    return response.data.body;
  } catch (error: any) {
    throw new Error(error.response?.data?.message || 'Failed to update profile');
  }
};