// Deleting an account (Google Play requires this in the app and on the web).
// Removes everything we hold for the person except payment records, which tax law requires us to keep.
import { Router } from "express";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { query } from "../db.js";
import { wrap } from "../errors.js";
import { requireAuth } from "../auth.js";
import { adminApp } from "../firebase.js";

/** The parts that live in Firebase, behind an interface so tests don't need Google. */
export interface AccountServices {
  /** Deletes the course registration unless money was paid (then it's kept, marked deleted). Returns true if kept. */
  removeRegistration(uid: string): Promise<boolean>;
  removeMentorApplications(uid: string): Promise<void>;
  deleteSignIn(uid: string): Promise<void>;
}

const firebaseServices: AccountServices = {
  async removeRegistration(uid) {
    const db = getFirestore(adminApp());
    const ref = db.collection("registrations").doc(uid);
    const d = await ref.get();
    if (!d.exists) return false;
    if (Number(d.get("amountPaid") ?? 0) > 0) {
      // Paid: keep the minimum for tax and refund records, drop the rest
      await ref.update({ accountDeleted: true, accountDeletedAt: FieldValue.serverTimestamp(), phone: FieldValue.delete(), experience: FieldValue.delete(), notes: FieldValue.delete() });
      return true;
    }
    await ref.delete();
    return false;
  },
  async removeMentorApplications(uid) {
    const db = getFirestore(adminApp());
    const apps = await db.collection("mentorApplications").where("uid", "==", uid).get();
    for (const a of apps.docs) {
      await db.collection("mentorProfiles").doc(a.id).delete().catch(() => undefined);
      await a.ref.delete();
    }
  },
  async deleteSignIn(uid) {
    await getAuth(adminApp()).deleteUser(uid).catch((e: { code?: string }) => {
      if (e?.code !== "auth/user-not-found") throw e;
    });
  },
};

let services: AccountServices | null = null;
export function setAccountServices(s: AccountServices | null) { services = s; }
const firebase = () => services ?? firebaseServices;

export const accountRouter = Router();

accountRouter.delete("/me", requireAuth, wrap(async (req, res) => {
  const uid = req.user!.uid;
  // Our database first: if anything fails, the person can still sign in and try again
  await query("DELETE FROM candidates WHERE uid = ?", [uid]);
  await query("DELETE FROM device_tokens WHERE uid = ?", [uid]);
  await query("DELETE FROM jobs WHERE posted_by_uid = ?", [uid]);
  await query("UPDATE job_reports SET reporter_uid = NULL WHERE reporter_uid = ?", [uid]);
  const [{ n }] = await query<{ n: number }>("SELECT COUNT(*) AS n FROM payments WHERE uid = ? AND status = 'paid'", [uid]);
  await query("DELETE FROM payments WHERE uid = ? AND status <> 'paid'", [uid]);
  // Mock interviews: unpaid bookings and feedback go; paid bookings stay as payment records, without notes
  await query("UPDATE interview_slots SET status = 'open', booking_id = NULL, held_until = NULL WHERE booking_id IN (SELECT id FROM (SELECT id FROM mock_bookings WHERE uid = ? AND status IN ('created','confirmed')) x)", [uid]);
  await query("DELETE FROM mock_bookings WHERE uid = ? AND paid_at IS NULL", [uid]);
  await query("DELETE s FROM mock_scorecards s JOIN mock_bookings b ON b.id = s.booking_id WHERE b.uid = ?", [uid]);
  await query("UPDATE mock_bookings SET focus = NULL, share_profile = 0, status = IF(status = 'confirmed', 'refund_due', status) WHERE uid = ?", [uid]);
  const [{ m }] = await query<{ m: number }>("SELECT COUNT(*) AS m FROM mock_bookings WHERE uid = ?", [uid]);
  await query("DELETE FROM interviewers WHERE uid = ?", [uid]);
  // Short courses: unpaid attempts go; paid enrolments are kept as payment records
  await query("DELETE FROM workshop_enrollments WHERE uid = ? AND paid_at IS NULL", [uid]);
  const [{ w }] = await query<{ w: number }>("SELECT COUNT(*) AS w FROM workshop_enrollments WHERE uid = ?", [uid]);

  const s = firebase();
  const keptRegistration = await s.removeRegistration(uid);
  await s.removeMentorApplications(uid);
  await s.deleteSignIn(uid);

  const kept = Number(n) > 0 || Number(m) > 0 || Number(w) > 0 || keptRegistration;
  res.json({
    ok: true,
    keptPaymentRecords: kept,
    message: kept
      ? "Your account is deleted. We keep the record of your payments because tax law requires it; everything else is gone."
      : "Your account and all your data are deleted.",
  });
}));
