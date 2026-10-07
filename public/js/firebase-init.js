/* ===== Firebase Initialization ===== */

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";
import { getStorage } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-storage.js";

// Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyB9HRc_R4KOh9n5Ih-bxKcUtHEqpdHMOYQ",
  authDomain: "flutter-in-10-days.firebaseapp.com",
  projectId: "flutter-in-10-days",
  storageBucket: "flutter-in-10-days.firebasestorage.app",
  messagingSenderId: "456315843656",
  appId: "1:456315843656:web:d000428857fb49c4ccd47d"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Services
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

export default app;
