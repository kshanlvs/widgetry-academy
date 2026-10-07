/* ===== Firebase Initialization ===== */

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";
import { getStorage } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-storage.js";

// Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBLvbZZVMVcM3dEzcNjNEBx8cNXVlGBMhc",
  authDomain: "widgetry-academy.firebaseapp.com",
  projectId: "widgetry-academy",
  storageBucket: "widgetry-academy.appspot.com",
  messagingSenderId: "787697842476",
  appId: "1:787697842476:web:3e10d7e0b25ad39a6a7d1b",
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Services
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

export default app;
