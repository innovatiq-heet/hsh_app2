import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const targetBase = path.resolve(__dirname, '../../mobile-api');

if (!fs.existsSync(targetBase)) {
  console.error('Target mobile-api directory not found at:', targetBase);
  process.exit(1);
}

const geofenceModuleDir = path.join(targetBase, 'src/modules/geofence');
if (!fs.existsSync(geofenceModuleDir)) {
  fs.mkdirSync(geofenceModuleDir, { recursive: true });
}

// 1. geofence.service.ts
const serviceContent = `import fs from 'fs';
import path from 'path';
import { updateStudentPolicies } from '../screentime/screentime.service.js';

export interface GeofencePolicy {
  id: string;
  name: string;
  startTime: string; // "22:00"
  endTime: string;   // "06:00"
  isActive: boolean;
  enforcePhoneLock: boolean;
  checkIntervalMinutes: number;
  repeatDays: string[];
}

export interface GeofenceBreachEvent {
  id: string;
  studentId: string;
  studentName: string;
  room: string;
  phone: string;
  latitude: number;
  longitude: number;
  distanceMeters: number;
  actionTaken: string;
  isResolved: boolean;
  timestamp: string;
}

// In-memory defaults
let activePolicy: GeofencePolicy = {
  id: 'default_curfew',
  name: 'Hostel Night Curfew',
  startTime: '22:00',
  endTime: '06:00',
  isActive: true,
  enforcePhoneLock: false,
  checkIntervalMinutes: 10,
  repeatDays: ['Daily'],
};

let breachLogs: GeofenceBreachEvent[] = [];

// Storage directory & persistence helper
const STORAGE_FILE = path.resolve('storage/geofence_store.json');

function loadPersistedData() {
  try {
    if (fs.existsSync(STORAGE_FILE)) {
      const content = fs.readFileSync(STORAGE_FILE, 'utf-8');
      const data = JSON.parse(content);
      if (data.policy) activePolicy = { ...activePolicy, ...data.policy };
      if (Array.isArray(data.breaches)) breachLogs = data.breaches;
    }
  } catch (err: any) {
    console.error('Failed to load geofence storage:', err?.message);
  }
}

function persistData() {
  try {
    const dir = path.dirname(STORAGE_FILE);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(
      STORAGE_FILE,
      JSON.stringify({ policy: activePolicy, breaches: breachLogs }, null, 2),
      'utf-8'
    );
  } catch (err: any) {
    console.error('Failed to persist geofence storage:', err?.message);
  }
}

// Load once on startup
loadPersistedData();

/**
 * Get active curfew policy
 */
export async function getCurfewPolicy(): Promise<GeofencePolicy> {
  return activePolicy;
}

/**
 * Save or update curfew policy
 */
export async function updateCurfewPolicy(
  newPolicy: Partial<GeofencePolicy>
): Promise<GeofencePolicy> {
  activePolicy = {
    ...activePolicy,
    ...newPolicy,
  };
  persistData();
  return activePolicy;
}

/**
 * Record a location breach reported by student phone
 */
export async function recordBreach(data: {
  studentId: string;
  studentName: string;
  room: string;
  phone: string;
  latitude: number;
  longitude: number;
  distanceMeters: number;
}): Promise<GeofenceBreachEvent> {
  const event: GeofenceBreachEvent = {
    id: \`breach_\${Date.now()}\`,
    studentId: data.studentId || 'UNKNOWN',
    studentName: data.studentName || 'Student',
    room: data.room || 'N/A',
    phone: data.phone || '',
    latitude: data.latitude,
    longitude: data.longitude,
    distanceMeters: data.distanceMeters || 0,
    actionTaken: 'none',
    isResolved: false,
    timestamp: new Date().toISOString(),
  };

  // Prepend to breach logs
  breachLogs.unshift(event);
  if (breachLogs.length > 500) breachLogs = breachLogs.slice(0, 500);

  // If automatic curfew lock is enforced, lock student's device immediately
  if (activePolicy.enforcePhoneLock && data.studentId) {
    try {
      await updateStudentPolicies(data.studentId, { is_locked: true });
      event.actionTaken = 'phoneLocked';
    } catch (e: any) {
      console.warn(\`Could not auto-lock phone for \${data.studentId}: \${e?.message}\`);
    }
  }

  persistData();
  return event;
}

/**
 * Get all active and recent breach events
 */
export async function getBreaches(): Promise<GeofenceBreachEvent[]> {
  return breachLogs;
}

/**
 * Record administrator action on a breach event (Lock, Warning, Call, Gate Pass)
 */
export async function recordAdminAction(
  breachId: string,
  studentId: string,
  action: string
): Promise<{ success: boolean; event?: GeofenceBreachEvent }> {
  const index = breachLogs.findIndex((b) => b.id === breachId);
  let event: GeofenceBreachEvent | undefined;

  if (index !== -1) {
    breachLogs[index].actionTaken = action;
    breachLogs[index].isResolved = true;
    event = breachLogs[index];
  }

  // If action is remote lock, invoke screen time locking on student phone
  if ((action === 'phoneLocked' || action === 'remoteLockPhone') && studentId) {
    try {
      await updateStudentPolicies(studentId, { is_locked: true });
    } catch (e: any) {
      console.warn(\`Could not remote-lock phone for \${studentId}: \${e?.message}\`);
    }
  }

  persistData();
  return { success: true, event };
}
`;

fs.writeFileSync(path.join(geofenceModuleDir, 'geofence.service.ts'), serviceContent, 'utf-8');
console.log('✅ Created geofence.service.ts');

// 2. geofence.controller.ts
const controllerContent = `import { Request, Response, NextFunction } from 'express';
import * as geofenceService from './geofence.service.js';

export async function getPolicy(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<Response | void> {
  try {
    const policy = await geofenceService.getCurfewPolicy();
    return res.status(200).json({
      status: 'success',
      data: policy,
    });
  } catch (error) {
    next(error);
  }
}

export async function updatePolicy(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<Response | void> {
  try {
    const updated = await geofenceService.updateCurfewPolicy(req.body);
    return res.status(200).json({
      status: 'success',
      data: updated,
    });
  } catch (error) {
    next(error);
  }
}

export async function getBreaches(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<Response | void> {
  try {
    const list = await geofenceService.getBreaches();
    return res.status(200).json({
      status: 'success',
      data: list,
    });
  } catch (error) {
    next(error);
  }
}

export async function reportBreach(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<Response | void> {
  try {
    const event = await geofenceService.recordBreach(req.body);
    return res.status(201).json({
      status: 'success',
      data: event,
    });
  } catch (error) {
    next(error);
  }
}

export async function recordAdminAction(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<Response | void> {
  try {
    const { breachId, studentId, action } = req.body;
    const result = await geofenceService.recordAdminAction(breachId, studentId, action);
    return res.status(200).json({
      status: 'success',
      data: result,
    });
  } catch (error) {
    next(error);
  }
}
`;

fs.writeFileSync(path.join(geofenceModuleDir, 'geofence.controller.ts'), controllerContent, 'utf-8');
console.log('✅ Created geofence.controller.ts');

// 3. geofence.routes.ts
const routesContent = `import { Router } from 'express';
import {
  getPolicy,
  updatePolicy,
  getBreaches,
  reportBreach,
  recordAdminAction,
} from './geofence.controller.js';

const router = Router();

// Curfew Policy configuration
router.get('/policy', getPolicy);
router.post('/policy', updatePolicy);

// Breach events & real-time movement alerts
router.get('/breaches', getBreaches);
router.post('/breach', reportBreach);

// Operator 1-tap actions (lock phone, call, warning, gate pass)
router.post('/admin-action', recordAdminAction);

export default router;
`;

fs.writeFileSync(path.join(geofenceModuleDir, 'geofence.routes.ts'), routesContent, 'utf-8');
console.log('✅ Created geofence.routes.ts');

// 4. Update src/routes/index.ts
const routesIndexPath = path.join(targetBase, 'src/routes/index.ts');
let routesIndexContent = fs.readFileSync(routesIndexPath, 'utf-8');

if (!routesIndexContent.includes("geofenceRouter")) {
  // Add import
  routesIndexContent = routesIndexContent.replace(
    "import screentimeRouter from '../modules/screentime/screentime.routes.js';",
    "import screentimeRouter from '../modules/screentime/screentime.routes.js';\nimport geofenceRouter from '../modules/geofence/geofence.routes.js';"
  );
  // Add router mount
  routesIndexContent = routesIndexContent.replace(
    "router.use('/screen-time', screentimeRouter);",
    "router.use('/screen-time', screentimeRouter);\nrouter.use('/geofence', geofenceRouter);"
  );

  fs.writeFileSync(routesIndexPath, routesIndexContent, 'utf-8');
  console.log('✅ Attached geofenceRouter in src/routes/index.ts');
} else {
  // If literal \\n exists, clean it up
  routesIndexContent = routesIndexContent.replace('\\\\n', '\n').replace('\\\\n', '\n');
  routesIndexContent = routesIndexContent.split('\\n').join('\n');
  fs.writeFileSync(routesIndexPath, routesIndexContent, 'utf-8');
  console.log('✅ Cleaned up formatted newlines in src/routes/index.ts');
}

console.log('\\n🚀 All mobile-api Geofence routes and services installed successfully!');
