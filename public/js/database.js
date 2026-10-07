/* ===== Firestore Database Utilities ===== */

import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  query,
  where,
  getDocs,
  addDoc,
  onSnapshot,
  serverTimestamp,
} from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";
import { db } from "./firebase-init.js";

/**
 * Create or update user registration record
 * @param {string} uid - User UID
 * @param {object} data - Registration data
 * @returns {Promise<void>}
 */
export async function createRegistration(uid, data) {
  try {
    const registrationData = {
      name: data.name,
      email: data.email,
      phone: data.phone,
      level: data.level, // Class 10, Class 12, College, Other
      experience: data.experience, // Beginner, Intermediate, Advanced
      batch: data.batch || "Batch 1",
      status: "registered", // registered, paid, verified, completed
      emailVerified: false,
      phoneVerified: false,
      amountPaid: 0,
      paymentId: null,
      payStatus: "pending",
      plan: null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    await setDoc(doc(db, "registrations", uid), registrationData);
    return registrationData;
  } catch (error) {
    throw new Error(`Failed to create registration: ${error.message}`);
  }
}

/**
 * Get user registration record
 * @param {string} uid - User UID
 * @returns {Promise<object>} Registration data
 */
export async function getRegistration(uid) {
  try {
    const docSnap = await getDoc(doc(db, "registrations", uid));
    if (docSnap.exists()) {
      return { uid: docSnap.id, ...docSnap.data() };
    }
    return null;
  } catch (error) {
    throw new Error(`Failed to get registration: ${error.message}`);
  }
}

/**
 * Update user registration record
 * @param {string} uid - User UID
 * @param {object} data - Data to update
 * @returns {Promise<void>}
 */
export async function updateRegistration(uid, data) {
  try {
    const updateData = {
      ...data,
      updatedAt: serverTimestamp(),
    };
    await updateDoc(doc(db, "registrations", uid), updateData);
  } catch (error) {
    throw new Error(`Failed to update registration: ${error.message}`);
  }
}

/**
 * Update payment status for user
 * @param {string} uid - User UID
 * @param {object} paymentData - Payment information
 * @returns {Promise<void>}
 */
export async function updatePaymentStatus(uid, paymentData) {
  try {
    const updateData = {
      paymentId: paymentData.paymentId,
      amountPaid: paymentData.amountPaid,
      payStatus: "completed",
      status: "paid",
      updatedAt: serverTimestamp(),
    };

    if (paymentData.plan) {
      updateData.plan = paymentData.plan;
    }

    await updateDoc(doc(db, "registrations", uid), updateData);
  } catch (error) {
    throw new Error(`Failed to update payment status: ${error.message}`);
  }
}

/**
 * Get all registrations (admin only)
 * @returns {Promise<array>} Array of registrations
 */
export async function getAllRegistrations() {
  try {
    const querySnapshot = await getDocs(collection(db, "registrations"));
    return querySnapshot.docs.map((doc) => ({
      uid: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    throw new Error(`Failed to get registrations: ${error.message}`);
  }
}

/**
 * Get registrations by status
 * @param {string} status - Registration status
 * @returns {Promise<array>} Array of registrations
 */
export async function getRegistrationsByStatus(status) {
  try {
    const q = query(
      collection(db, "registrations"),
      where("status", "==", status)
    );
    const querySnapshot = await getDocs(q);
    return querySnapshot.docs.map((doc) => ({
      uid: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    throw new Error(`Failed to get registrations: ${error.message}`);
  }
}

/**
 * Get paid registrations
 * @returns {Promise<array>} Array of paid registrations
 */
export async function getPaidRegistrations() {
  try {
    const q = query(
      collection(db, "registrations"),
      where("payStatus", "==", "completed")
    );
    const querySnapshot = await getDocs(q);
    return querySnapshot.docs.map((doc) => ({
      uid: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    throw new Error(`Failed to get paid registrations: ${error.message}`);
  }
}

/**
 * Listen to user registration changes
 * @param {string} uid - User UID
 * @param {function} callback - Callback function
 * @returns {function} Unsubscribe function
 */
export function watchRegistration(uid, callback) {
  return onSnapshot(doc(db, "registrations", uid), (doc) => {
    if (doc.exists()) {
      callback({ uid: doc.id, ...doc.data() });
    } else {
      callback(null);
    }
  });
}

/**
 * Create mentor application
 * @param {object} data - Application data
 * @returns {Promise<string>} Document ID
 */
export async function createMentorApplication(data) {
  try {
    const appData = {
      name: data.name,
      email: data.email,
      phone: data.phone,
      city: data.city,
      company: data.company,
      role: data.role,
      experience: data.experience,
      linkedin: data.linkedin,
      portfolio: data.portfolio,
      skills: data.skills || [],
      course: data.course || "Flutter in 10 Days",
      availability: data.availability || [],
      mode: data.mode,
      teaching: data.teaching,
      video: data.video,
      pitch: data.pitch,
      consent: data.consent || false,
      status: "new",
      createdAt: serverTimestamp(),
    };

    const docRef = await addDoc(collection(db, "mentorApplications"), appData);
    return docRef.id;
  } catch (error) {
    throw new Error(`Failed to create mentor application: ${error.message}`);
  }
}

/**
 * Get approved mentors
 * @returns {Promise<array>} Array of approved mentors
 */
export async function getApprovedMentors() {
  try {
    const q = query(
      collection(db, "mentorApplications"),
      where("status", "==", "approved")
    );
    const querySnapshot = await getDocs(q);
    return querySnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    throw new Error(`Failed to get mentors: ${error.message}`);
  }
}

/**
 * Create a course
 * @param {object} courseData - Course data
 * @returns {Promise<string>} Document ID
 */
export async function createCourse(courseData) {
  try {
    const data = {
      name: courseData.name,
      description: courseData.description,
      startDate: courseData.startDate,
      endDate: courseData.endDate,
      days: courseData.days,
      time: courseData.time,
      mode: courseData.mode,
      capacity: courseData.capacity || 30,
      enrolled: courseData.enrolled || 0,
      price: courseData.price,
      instructor: courseData.instructor,
      topics: courseData.topics || [],
      createdAt: serverTimestamp(),
    };

    const docRef = await addDoc(collection(db, "courses"), data);
    return docRef.id;
  } catch (error) {
    throw new Error(`Failed to create course: ${error.message}`);
  }
}

/**
 * Get all courses
 * @returns {Promise<array>} Array of courses
 */
export async function getCourses() {
  try {
    const querySnapshot = await getDocs(collection(db, "courses"));
    return querySnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    throw new Error(`Failed to get courses: ${error.message}`);
  }
}

/**
 * Get single course
 * @param {string} courseId - Course ID
 * @returns {Promise<object>} Course data
 */
export async function getCourse(courseId) {
  try {
    const docSnap = await getDoc(doc(db, "courses", courseId));
    if (docSnap.exists()) {
      return { id: docSnap.id, ...docSnap.data() };
    }
    return null;
  } catch (error) {
    throw new Error(`Failed to get course: ${error.message}`);
  }
}

/**
 * Enroll user in course
 * @param {string} uid - User UID
 * @param {string} courseId - Course ID
 * @returns {Promise<void>}
 */
export async function enrollCourse(uid, courseId) {
  try {
    const enrollmentData = {
      uid,
      courseId,
      status: "active",
      enrolledAt: serverTimestamp(),
      progress: 0,
    };

    const docRef = await addDoc(collection(db, "enrollments"), enrollmentData);
    return docRef.id;
  } catch (error) {
    throw new Error(`Failed to enroll course: ${error.message}`);
  }
}

/**
 * Get user's courses
 * @param {string} uid - User UID
 * @returns {Promise<array>} Array of user's courses
 */
export async function getUserCourses(uid) {
  try {
    const q = query(collection(db, "enrollments"), where("uid", "==", uid));
    const querySnapshot = await getDocs(q);
    return querySnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  } catch (error) {
    throw new Error(`Failed to get user courses: ${error.message}`);
  }
}
