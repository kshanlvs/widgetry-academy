-- LLM chat (Claude): one row per conversation, one row per message.
-- The server owns the history: the app sends only the new message, the API loads past ones from here.
CREATE TABLE chat_conversations (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  uid         VARCHAR(128)    NOT NULL,
  title       VARCHAR(200)    NULL,
  created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_chat_conv_uid (uid, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE chat_messages (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  conversation_id  BIGINT UNSIGNED NOT NULL,
  role             ENUM('user','assistant') NOT NULL,
  content          TEXT            NOT NULL,
  input_tokens     INT UNSIGNED    NULL,     -- tokens sent to Claude for this reply (cost tracking)
  output_tokens    INT UNSIGNED    NULL,     -- tokens Claude generated
  created_at       TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),  -- ms precision keeps question/reply order
  PRIMARY KEY (id),
  KEY idx_chat_msg_conv (conversation_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
