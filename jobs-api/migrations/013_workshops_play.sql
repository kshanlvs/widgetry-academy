-- Short courses bought in the Android app: Google Play purchases, and Razorpay payments chosen on
-- Google's choice screen (reported to Google within 24 hours).
ALTER TABLE workshop_enrollments
  ADD COLUMN channel        VARCHAR(20)  NOT NULL DEFAULT 'razorpay',
  ADD COLUMN ext_token      TEXT         NULL,
  ADD COLUMN tax_state      VARCHAR(60)  NULL,
  ADD COLUMN reported_at    TIMESTAMP    NULL,
  ADD COLUMN purchase_token VARCHAR(500) NULL;
