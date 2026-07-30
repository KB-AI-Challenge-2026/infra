CREATE ROLE kb_backend_user LOGIN PASSWORD 'kb_backend_password';
CREATE ROLE kb_ai_user LOGIN PASSWORD 'kb_ai_password';

CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS core AUTHORIZATION kb_backend_user;
CREATE SCHEMA IF NOT EXISTS ai AUTHORIZATION kb_ai_user;
CREATE SCHEMA IF NOT EXISTS rag AUTHORIZATION kb_ai_user;

GRANT CONNECT ON DATABASE kbai TO kb_backend_user, kb_ai_user;
GRANT USAGE, CREATE ON SCHEMA core TO kb_backend_user;
GRANT USAGE, CREATE ON SCHEMA ai, rag TO kb_ai_user;
