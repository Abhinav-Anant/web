import express from 'express';
import { authenticateToken } from '../middleware/auth';
import { getProfile, updateProfile } from '../services/controldService';
import { AuthRequest } from '../types';

const router = express.Router();

router.get('/', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const profile = await getProfile(req.user!.endpointId);
    res.json(profile);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.put('/', authenticateToken, async (req: AuthRequest, res) => {
  try {
    const profile = await updateProfile(req.user!.endpointId, req.body);
    res.json(profile);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export default router;