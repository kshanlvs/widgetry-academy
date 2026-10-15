-- Push notifications: one row per signed-in phone (FCM registration token)
CREATE TABLE device_tokens (
  token       VARCHAR(512) NOT NULL,
  uid         VARCHAR(128) NOT NULL,
  platform    ENUM('android','ios','web') NOT NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (token),
  KEY idx_device_tokens_uid (uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
