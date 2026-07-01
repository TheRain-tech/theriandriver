/**
 * approve_test_driver.js
 *
 * Approves a driver account in therain-production Firestore so they can
 * go online and receive rides during end-to-end testing.
 *
 * Usage (requires firebase-admin installed and a service account):
 *   node scripts/approve_test_driver.js <driverUid>
 *
 * Or use the Firebase Console directly:
 *   Firestore → drivers/{driverUid} → Edit these fields:
 *     verificationStatus  : "approved"
 *     accountStatus       : "active"
 *     canReceiveRides     : true
 *
 *   Firestore → driver_verifications/{driverUid} → Edit/create:
 *     status              : "approved"
 *     driverId            : "<driverUid>"
 *     reviewedAt          : (server timestamp)
 *     reviewedBy          : "manual-test"
 */

const admin = require('firebase-admin');

const driverUid = process.argv[2];
if (!driverUid) {
  console.error('Usage: node scripts/approve_test_driver.js <driverUid>');
  process.exit(1);
}

// Initialize with application default credentials (run: firebase login first,
// or set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path).
admin.initializeApp({
  projectId: 'therain-production',
});

const db = admin.firestore();

async function approveDriver(uid) {
  const driverRef = db.collection('drivers').doc(uid);
  const verificationRef = db.collection('driver_verifications').doc(uid);
  const usersRef = db.collection('users').doc(uid);

  const driverSnap = await driverRef.get();
  if (!driverSnap.exists) {
    console.error(`No driver document found for uid: ${uid}`);
    process.exit(1);
  }

  const batch = db.batch();

  batch.set(driverRef, {
    verificationStatus: 'approved',
    accountStatus: 'active',
    canReceiveRides: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  batch.set(verificationRef, {
    driverId: uid,
    status: 'approved',
    reviewedBy: 'manual-test',
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  batch.set(usersRef, {
    status: 'active',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await batch.commit();
  console.log(`✅ Driver ${uid} approved successfully.`);
  console.log('   verificationStatus: approved');
  console.log('   accountStatus: active');
  console.log('   canReceiveRides: true');
}

approveDriver(driverUid).catch((err) => {
  console.error('Error approving driver:', err.message);
  process.exit(1);
});
