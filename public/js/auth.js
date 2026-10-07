/* ===== Authentication Utilities ===== */

import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
  sendPasswordResetEmail,
  updateProfile,
  onAuthStateChanged,
  setPersistence,
  browserLocalPersistence,
} from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { auth } from "./firebase-init.js";

// Enable persistence
await setPersistence(auth, browserLocalPersistence);

/**
 * Register new user
 * @param {string} email - User email
 * @param {string} password - User password
 * @param {object} userData - Additional user data (name, phone, etc.)
 * @returns {Promise<object>} User object with UID
 */
export async function registerUser(email, password, userData) {
  try {
    const userCred = await createUserWithEmailAndPassword(auth, email, password);
    const user = userCred.user;

    // Update profile with display name
    if (userData.name) {
      await updateProfile(user, { displayName: userData.name });
    }

    return {
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      ...userData,
    };
  } catch (error) {
    throw new Error(`Registration failed: ${error.message}`);
  }
}

/**
 * Sign in user
 * @param {string} email - User email
 * @param {string} password - User password
 * @returns {Promise<object>} User object
 */
export async function loginUser(email, password) {
  try {
    const userCred = await signInWithEmailAndPassword(auth, email, password);
    return {
      uid: userCred.user.uid,
      email: userCred.user.email,
      displayName: userCred.user.displayName,
    };
  } catch (error) {
    throw new Error(`Login failed: ${error.message}`);
  }
}

/**
 * Sign out current user
 * @returns {Promise<void>}
 */
export async function logoutUser() {
  try {
    await signOut(auth);
  } catch (error) {
    throw new Error(`Logout failed: ${error.message}`);
  }
}

/**
 * Send password reset email
 * @param {string} email - User email
 * @returns {Promise<void>}
 */
export async function resetPassword(email) {
  try {
    await sendPasswordResetEmail(auth, email);
  } catch (error) {
    throw new Error(`Password reset failed: ${error.message}`);
  }
}

/**
 * Get current user
 * @returns {object|null} Current user or null
 */
export function getCurrentUser() {
  return auth.currentUser;
}

/**
 * Wait for auth to load
 * @returns {Promise<object|null>} Current user or null
 */
export function onAuthReady() {
  return new Promise((resolve) => {
    onAuthStateChanged(auth, (user) => {
      resolve(user);
    });
  });
}

/**
 * Listen to auth state changes
 * @param {function} callback - Function to call when auth state changes
 * @returns {function} Unsubscribe function
 */
export function watchAuthState(callback) {
  return onAuthStateChanged(auth, callback);
}

/**
 * Check if user is authenticated
 * @returns {boolean}
 */
export function isAuthenticated() {
  return auth.currentUser !== null;
}

/**
 * Get auth token
 * @returns {Promise<string>} ID token
 */
export async function getAuthToken() {
  if (!auth.currentUser) return null;
  return await auth.currentUser.getIdToken();
}
