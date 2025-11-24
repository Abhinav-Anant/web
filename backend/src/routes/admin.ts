import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { authenticateAdmin } from '../middleware/auth';
import prisma from '../utils/prisma';

const router = express.Router();

router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  
  const admin = await prisma.admin.findUnique({
    where: { username },
    select: { id: true, username: true, passwordHash: true }
  });

  if (!admin) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  const isValid = await bcrypt.compare(password, admin.passwordHash);
  if (!isValid) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  const token = jwt.sign(
    { adminId: admin.id },
    process.env.JWT_SECRET!,
    { expiresIn: '7d' }
  );

  res.json({ token });
});

router.post('/users', authenticateAdmin, async (req, res) => {
  const { username, password, endpointId } = req.body;

  const existing = await prisma.user.findFirst({
    where: { OR: [{ username }, { endpointId }] }
  });

  if (existing) {
    return res.status(400).json({ error: 'Username or endpoint ID already exists' });
  }

  const hashedPassword = await bcrypt.hash(password, 12);
  
  const user = await prisma.user.create({
    data: {
      username,
      passwordHash: hashedPassword,
      endpointId,
    },
    select: { id: true, username: true, endpointId: true, isActive: true }
  });

  res.json(user);
});

router.get('/users', authenticateAdmin, async (req, res) => {
  const users = await prisma.user.findMany({
    select: { id: true, username: true, endpointId: true, isActive: true, createdAt: true }
  });
  res.json(users);
});

export default router;