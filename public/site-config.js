// ===== Widgetry Academy: site settings =====
// Edit only the values in quotes, then redeploy (firebase deploy --only hosting).

window.WIDGETRY = {
  // Razorpay Payment Button IDs (start with "pl_"). Leave "" to show "Online payment opening soon".
  // Use TEST IDs only on a preview channel; on the live site use LIVE IDs or leave empty.
  razorpay: {
    earlyBird: "pl_Tl4maYsbl2Eaxn",   // ₹3,499 – first 10 seats
    regular:   "pl_Tl4tO3qkfF95TV",   // ₹4,999
    booking:   "pl_Tl4y52Nbm6N2QY"    // ₹2,500 – pay in 2 parts
  },

  // ---- Next batch (shown in the hero, fees section and WhatsApp messages) ----
  batch: {
    name:      "Batch 1",
    startDate: "Saturday, 17 October 2026", // fallback: live details are edited in Admin → Next batch
    days:      "Saturdays & Sundays",
    time:      "11:00 AM – 2:00 PM IST", // e.g. "10:00 AM – 12:00 PM IST"
    mode:      "",                       // e.g. "Live online (Google Meet)" or "In-person, Salt Lake"
    demo:      "",                       // e.g. "Free demo: Sunday, 26 October, 11 AM"
    seatsLeft: null                      // early-bird seats left, e.g. 7 (null = hide). Keep it honest.
  },

  // ---- Contact (Contact page, policy pages, WhatsApp button) ----
  whatsapp:     "918617692683",       // WhatsApp number with country code, digits only, e.g. "919876543210". Empty = no WhatsApp button.
  contactEmail: "kishantechdev@gmail.com", // shown on the Contact page and policy pages
  contactPhone: "",                   // e.g. "+91 98765 43210" (optional)
  instagram:    "widgetry.academy",   // Instagram handle without @
  address:      "",                   // e.g. "Kolkata, West Bengal, India" (Razorpay may ask for this)
  ownerName:    "Kishan Kumar Sharma",// Legal name used for Razorpay KYC

  // ---- Tracking ----
  metaPixelId:  ""                    // Meta (Facebook/Instagram) Pixel ID, digits only. Empty = off.
};
