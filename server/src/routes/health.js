import { Router } from 'express';
import { getDb } from '../db.js';

const router = Router();

router.get('/', async (req, res) => {
  let dbStatus = 'disconnected';
  try {
    const db = getDb();
    await db.command({ ping: 1 });
    dbStatus = 'connected';
  } catch (err) {
    dbStatus = 'error';
  }

  res.status(200).json({
    status: 'ok',
    uptime: Math.round(process.uptime()),
    db: dbStatus,
    timestamp: new Date().toISOString(),
  });
});

export default router;
