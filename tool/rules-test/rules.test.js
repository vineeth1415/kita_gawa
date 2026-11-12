// Security-rule tests for the Kitagawa inventory app.
//
// These assert the role boundaries at the database, not in the UI: a phone
// with a modified app, or a raw REST call, must hit exactly the same walls a
// user sees. Run with:  npm test   (the Firestore emulator must be running)

import { readFileSync } from 'node:fs';
import { test, before, after, beforeEach, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, addDoc,
} from 'firebase/firestore';

let testEnv;

const TODAY = '2026-05-10';

const USERS = {
  admin:  { uid: 'u-admin',  role: 'admin',   displayName: 'Admin' },
  viewer: { uid: 'u-viewer', role: 'read_only', displayName: 'Priya' },
  store:  { uid: 'u-store1', role: 'store',   displayName: 'Ravi'  },
  store2: { uid: 'u-store2', role: 'store',   displayName: 'Meera' },
  audit:  { uid: 'u-audit',  role: 'auditor', displayName: 'Sana'  },
  gone:   { uid: 'u-gone',   role: 'store',   displayName: 'Old',  active: false },
};

function ctx(who) {
  return testEnv.authenticatedContext(USERS[who].uid).firestore();
}

function movement(overrides = {}) {
  return {
    itemId: 'BOLT-01',
    itemCode: 'BOLT-01',
    itemName: 'Hex Bolt',
    businessDate: TODAY,
    shiftId: TODAY,
    type: 'inward',
    delta: 5,
    resultingStock: 15,
    referenceNumber: 'INV2024001',
    userId: USERS.store.uid,
    userName: 'Ravi',
    userRole: 'store',
    lateEntry: false,
    createdAt: new Date(),
    ...overrides,
  };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'kitagawa-rules-test',
    firestore: {
      rules: readFileSync('../../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => { await testEnv?.cleanup(); });

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Seed profiles, items, an open day and audit-off settings with rules
  // bypassed, so each test starts from a known world.
  await testEnv.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    for (const [, u] of Object.entries(USERS)) {
      await setDoc(doc(db, 'users', u.uid), {
        username: u.displayName.toLowerCase(),
        displayName: u.displayName,
        role: u.role,
        active: u.active !== false,
        createdAt: new Date(),
        createdBy: 'seed',
      });
    }
    await setDoc(doc(db, 'items', 'BOLT-01'), {
      code: 'BOLT-01', name: 'Hex Bolt', description: '',
      currentStock: 10, createdAt: new Date(), updatedAt: new Date(),
    });
    await setDoc(doc(db, 'shifts', TODAY), {
      businessDate: TODAY, status: 'open',
      openedAt: new Date(), openedBy: USERS.store.uid, openedByName: 'Ravi',
    });
    await setDoc(doc(db, 'settings', 'workingDay'), { businessDate: TODAY });
    await setDoc(doc(db, 'settings', 'app'), { auditEnabled: false });
  });
});

describe('unauthenticated and role-less access', () => {
  test('a signed-out client can read nothing', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'items', 'BOLT-01')));
    await assertFails(getDoc(doc(db, 'shifts', TODAY)));
  });

  test('a bare auth account with no profile is inert', async () => {
    // This is the self-registration hole: anyone can create an auth account,
    // but without a users/{uid} document it can do nothing at all.
    const db = testEnv.authenticatedContext('u-stranger').firestore();
    await assertFails(getDoc(doc(db, 'items', 'BOLT-01')));
    await assertFails(addDoc(collection(db, 'movements'), movement()));
  });

  test('a deactivated account loses access', async () => {
    const db = ctx('gone');
    await assertFails(getDoc(doc(db, 'items', 'BOLT-01')));
    await assertFails(addDoc(collection(db, 'movements'), movement({
      userId: USERS.gone.uid,
    })));
  });
});

describe('movements: store moves stock both ways, against the open day', () => {
  const dispatch = { type: 'dispatch', delta: -5, resultingStock: 5 };

  test('store may book stock IN', async () => {
    await assertSucceeds(addDoc(collection(ctx('store'), 'movements'), movement()));
  });

  test('store may dispatch', async () => {
    await assertSucceeds(addDoc(collection(ctx('store'), 'movements'), movement(dispatch)));
  });

  test('the second store login has the same powers', async () => {
    await assertSucceeds(addDoc(collection(ctx('store2'), 'movements'), movement({
      userId: USERS.store2.uid, userName: 'Meera',
    })));
    await assertSucceeds(addDoc(collection(ctx('store2'), 'movements'), movement({
      ...dispatch, userId: USERS.store2.uid, userName: 'Meera',
    })));
  });

  test('the sign must agree with the direction', async () => {
    await assertFails(addDoc(collection(ctx('store'), 'movements'), movement({
      type: 'inward', delta: -5, resultingStock: 5,
    })));
    await assertFails(addDoc(collection(ctx('store'), 'movements'), movement({
      type: 'dispatch', delta: 5, resultingStock: 15,
    })));
  });

  test('the read-only login may not move stock at all', async () => {
    await assertFails(addDoc(collection(ctx('viewer'), 'movements'), movement({
      userId: USERS.viewer.uid, userRole: 'read_only',
    })));
    await assertFails(addDoc(collection(ctx('viewer'), 'movements'), movement({
      ...dispatch, userId: USERS.viewer.uid, userRole: 'read_only',
    })));
  });

  test('nothing may be recorded when no day has been started', async () => {
    await testEnv.withSecurityRulesDisabled(async (c) => {
      await deleteDoc(doc(c.firestore(), 'shifts', TODAY));
    });
    await assertFails(addDoc(collection(ctx('store'), 'movements'), movement({ shiftId: null })));
    await assertFails(addDoc(collection(ctx('store'), 'movements'), movement({ ...dispatch, shiftId: null })));
  });

  test('nothing may be recorded against a closed day', async () => {
    await testEnv.withSecurityRulesDisabled(async (c) => {
      await updateDoc(doc(c.firestore(), 'shifts', TODAY), { status: 'closed' });
    });
    await assertFails(addDoc(collection(ctx('store'), 'movements'), movement()));
    await assertFails(addDoc(collection(ctx('store'), 'movements'), movement(dispatch)));
  });

  test('a movement cannot be attributed to someone else', async () => {
    await assertFails(addDoc(collection(ctx('store'), 'movements'), movement({
      userId: USERS.store2.uid,
    })));
  });
});

describe('movements: reference number is enforced server side', () => {
  for (const bad of ['ABC', 'A'.repeat(17), 'INV 2024', 'INV-2024', '']) {
    test(`rejects reference ${JSON.stringify(bad)}`, async () => {
      await assertFails(addDoc(collection(ctx('store'), 'movements'), movement({
        referenceNumber: bad,
      })));
    });
  }

  test('rejects a lowercase reference (the client uppercases first)', async () => {
    await assertFails(addDoc(collection(ctx('store'), 'movements'), movement({
      referenceNumber: 'inv2024001',
    })));
  });

  test('accepts the 4 and 16 character boundaries', async () => {
    await assertSucceeds(addDoc(collection(ctx('store'), 'movements'), movement({
      referenceNumber: 'ABCD',
    })));
    await assertSucceeds(addDoc(collection(ctx('store'), 'movements'), movement({
      referenceNumber: 'A234567890123456',
    })));
  });

  test('rejects a malformed business date and negative resulting stock', async () => {
    await assertFails(addDoc(collection(ctx('store'), 'movements'), movement({
      businessDate: '10-05-2026',
    })));
    await assertFails(addDoc(collection(ctx('store'), 'movements'), movement({
      resultingStock: -1,
    })));
  });
});

describe('the ledger is append-only', () => {
  let movementId;
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (c) => {
      const ref = await addDoc(collection(c.firestore(), 'movements'), movement());
      movementId = ref.id;
    });
  });

  for (const who of ['admin', 'viewer', 'store', 'audit']) {
    test(`${who} cannot rewrite history`, async () => {
      const db = ctx(who);
      await assertFails(updateDoc(doc(db, 'movements', movementId), { delta: 999 }));
      await assertFails(deleteDoc(doc(db, 'movements', movementId)));
    });
  }
});

describe('audit is gated by the global toggle', () => {
  test('auditor cannot start a session while audit is off', async () => {
    await assertFails(addDoc(collection(ctx('audit'), 'auditSessions'), {
      status: 'open', businessDate: TODAY,
      startedBy: USERS.audit.uid, startedByName: 'Sana',
    }));
  });

  test('auditor cannot post an adjustment while audit is off', async () => {
    await assertFails(addDoc(collection(ctx('audit'), 'movements'), movement({
      type: 'audit_adjustment', delta: -2, resultingStock: 8,
      userId: USERS.audit.uid, userRole: 'auditor', referenceNumber: 'AUDABC123',
    })));
  });

  test('with audit on, the auditor can work', async () => {
    await testEnv.withSecurityRulesDisabled(async (c) => {
      await setDoc(doc(c.firestore(), 'settings', 'app'), { auditEnabled: true });
    });
    await assertSucceeds(addDoc(collection(ctx('audit'), 'auditSessions'), {
      status: 'open', businessDate: TODAY,
      startedBy: USERS.audit.uid, startedByName: 'Sana',
    }));
    await assertSucceeds(addDoc(collection(ctx('audit'), 'movements'), movement({
      type: 'audit_adjustment', delta: -2, resultingStock: 8,
      userId: USERS.audit.uid, userRole: 'auditor', referenceNumber: 'AUDABC123',
    })));
  });

  test('only an admin flips the toggle', async () => {
    await assertFails(setDoc(doc(ctx('audit'), 'settings', 'app'), { auditEnabled: true }));
    await assertFails(setDoc(doc(ctx('store'), 'settings', 'app'), { auditEnabled: true }));
    await assertFails(setDoc(doc(ctx('viewer'), 'settings', 'app'), { auditEnabled: true }));
    await assertSucceeds(setDoc(doc(ctx('admin'), 'settings', 'app'), { auditEnabled: true }));
  });
});

describe('working day, shifts and reports', () => {
  test('only the store or admin starts a day', async () => {
    await assertFails(setDoc(doc(ctx('viewer'), 'shifts', '2026-05-11'), {
      businessDate: '2026-05-11', status: 'open',
      openedBy: USERS.viewer.uid, openedByName: 'Priya',
    }));
    await assertSucceeds(setDoc(doc(ctx('store'), 'shifts', '2026-05-11'), {
      businessDate: '2026-05-11', status: 'open',
      openedBy: USERS.store.uid, openedByName: 'Ravi',
    }));
  });

  test('only the store or admin moves the working-day pointer', async () => {
    await assertFails(setDoc(doc(ctx('viewer'), 'settings', 'workingDay'), { businessDate: '2026-05-11' }));
    await assertFails(setDoc(doc(ctx('audit'), 'settings', 'workingDay'), { businessDate: '2026-05-11' }));
    await assertSucceeds(setDoc(doc(ctx('store2'), 'settings', 'workingDay'), { businessDate: '2026-05-11' }));
    await assertSucceeds(setDoc(doc(ctx('admin'), 'settings', 'workingDay'), { businessDate: null }));
  });

  test('everyone active reads the working-day pointer', async () => {
    for (const who of ['admin', 'viewer', 'store', 'audit']) {
      await assertSucceeds(getDoc(doc(ctx(who), 'settings', 'workingDay')));
    }
    await assertFails(getDoc(doc(ctx('gone'), 'settings', 'workingDay')));
  });

  test('only the store or admin seals a report', async () => {
    await assertFails(setDoc(doc(ctx('viewer'), 'shiftReports', TODAY), { businessDate: TODAY }));
    await assertSucceeds(setDoc(doc(ctx('store'), 'shiftReports', TODAY), { businessDate: TODAY }));
  });

  test('a sealed report cannot be altered or removed', async () => {
    await testEnv.withSecurityRulesDisabled(async (c) => {
      await setDoc(doc(c.firestore(), 'shiftReports', TODAY), {
        businessDate: TODAY, totals: { inwardQty: 5 },
      });
    });
    for (const who of ['admin', 'store', 'viewer']) {
      await assertFails(updateDoc(doc(ctx(who), 'shiftReports', TODAY), {
        'totals.inwardQty': 0,
      }));
      await assertFails(deleteDoc(doc(ctx(who), 'shiftReports', TODAY)));
    }
  });

  test('everyone can read reports', async () => {
    await testEnv.withSecurityRulesDisabled(async (c) => {
      await setDoc(doc(c.firestore(), 'shiftReports', TODAY), { businessDate: TODAY });
    });
    for (const who of ['admin', 'viewer', 'store', 'audit']) {
      await assertSucceeds(getDoc(doc(ctx(who), 'shiftReports', TODAY)));
    }
  });
});

describe('items', () => {
  test('only an admin defines items', async () => {
    await assertFails(setDoc(doc(ctx('store'), 'items', 'NEW-01'), {
      code: 'NEW-01', name: 'New', description: '', currentStock: 0,
    }));
    await assertFails(setDoc(doc(ctx('viewer'), 'items', 'NEW-01'), {
      code: 'NEW-01', name: 'New', description: '', currentStock: 0,
    }));
    await assertSucceeds(setDoc(doc(ctx('admin'), 'items', 'NEW-01'), {
      code: 'NEW-01', name: 'New', description: '', currentStock: 0,
    }));
  });

  test('the store may move stock but not rename an item', async () => {
    await assertSucceeds(updateDoc(doc(ctx('store'), 'items', 'BOLT-01'), {
      currentStock: 15, updatedAt: new Date(),
    }));
    await assertFails(updateDoc(doc(ctx('store'), 'items', 'BOLT-01'), {
      name: 'Renamed by a non-admin',
    }));
    await assertFails(deleteDoc(doc(ctx('store'), 'items', 'BOLT-01')));
  });

  test('stock cannot be pushed negative', async () => {
    await assertFails(updateDoc(doc(ctx('store'), 'items', 'BOLT-01'), {
      currentStock: -5, updatedAt: new Date(),
    }));
  });
});

describe('users', () => {
  test('a user reads only their own profile', async () => {
    await assertSucceeds(getDoc(doc(ctx('store'), 'users', USERS.store.uid)));
    await assertFails(getDoc(doc(ctx('store'), 'users', USERS.store2.uid)));
    await assertSucceeds(getDoc(doc(ctx('admin'), 'users', USERS.store.uid)));
  });

  test('nobody can promote themselves', async () => {
    await assertFails(updateDoc(doc(ctx('store'), 'users', USERS.store.uid), {
      role: 'admin',
    }));
  });

  test('a deactivated user cannot switch themselves back on', async () => {
    // The whole point of deactivation: the flag the rules read is not one
    // the account it locks out can reach.
    await assertFails(updateDoc(doc(ctx('gone'), 'users', USERS.gone.uid), {
      active: true,
    }));
  });

  test('only an admin deactivates someone', async () => {
    await assertFails(updateDoc(doc(ctx('store2'), 'users', USERS.store.uid), {
      active: false,
    }));
    await assertSucceeds(updateDoc(doc(ctx('admin'), 'users', USERS.store.uid), {
      active: false, deactivatedAt: new Date(), deactivatedBy: USERS.admin.uid,
    }));
  });

  test('an admin can switch a deactivated account back on', async () => {
    await assertSucceeds(updateDoc(doc(ctx('admin'), 'users', USERS.gone.uid), {
      active: true, deactivatedAt: null, deactivatedBy: null,
    }));
  });

  test('only an admin creates a profile', async () => {
    await assertFails(setDoc(doc(ctx('store'), 'users', 'u-new'), {
      username: 'new', displayName: 'New', role: 'store', active: true,
    }));
    await assertSucceeds(setDoc(doc(ctx('admin'), 'users', 'u-new'), {
      username: 'new', displayName: 'New', role: 'store', active: true,
    }));
  });
});
