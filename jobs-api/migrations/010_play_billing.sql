-- Google Play "user choice billing": each payment records how it was paid, and Razorpay payments
-- made through the app's choice screen are reported to Google Play (token + the student's state for tax).
ALTER TABLE payments ADD COLUMN channel VARCHAR(20) NOT NULL DEFAULT 'razorpay';
ALTER TABLE payments ADD COLUMN ext_token TEXT NULL;
ALTER TABLE payments ADD COLUMN tax_state VARCHAR(60) NULL;
ALTER TABLE payments ADD COLUMN reported_at TIMESTAMP NULL;
ALTER TABLE payments ADD COLUMN purchase_token VARCHAR(600) NULL;
