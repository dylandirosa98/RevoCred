-- +goose Up
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS revocred;

CREATE TABLE revocred.profiles (
    user_id UUID PRIMARY KEY,
    display_name TEXT NOT NULL DEFAULT '' CHECK (char_length(display_name) <= 100),
    credit_card_strategy TEXT NOT NULL DEFAULT '' CHECK (char_length(credit_card_strategy) <= 500),
    goal TEXT NOT NULL DEFAULT '' CHECK (char_length(goal) <= 500),
    top_spend_categories TEXT[] NOT NULL DEFAULT '{}',
    next_application_target TEXT NOT NULL DEFAULT '' CHECK (char_length(next_application_target) <= 200),
    rewards_goal TEXT NOT NULL DEFAULT '' CHECK (rewards_goal IN ('', 'cash_back', 'travel', 'hybrid')),
    travel_scope TEXT NOT NULL DEFAULT '' CHECK (travel_scope IN ('', 'none', 'domestic', 'international', 'both')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE revocred.catalog_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    url TEXT,
    disclaimer TEXT NOT NULL,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE revocred.catalog_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
    issuer TEXT NOT NULL,
    network TEXT NOT NULL,
    name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX catalog_cards_active_name_idx ON revocred.catalog_cards (is_active, issuer, name);

CREATE TABLE revocred.card_catalog_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    catalog_card_id UUID NOT NULL REFERENCES revocred.catalog_cards(id) ON DELETE CASCADE,
    source_id UUID NOT NULL REFERENCES revocred.catalog_sources(id) ON DELETE RESTRICT,
    dataset_version TEXT NOT NULL,
    summary TEXT NOT NULL DEFAULT '',
    best_use TEXT NOT NULL DEFAULT '',
    annual_fee_cents INTEGER NOT NULL CHECK (annual_fee_cents >= 0),
    reward_rates JSONB NOT NULL CHECK (jsonb_typeof(reward_rates) = 'object'),
    benefits JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(benefits) = 'array'),
    transferable_points BOOLEAN NOT NULL DEFAULT false,
    travel_scope TEXT NOT NULL CHECK (travel_scope IN ('none', 'domestic', 'international', 'both')),
    minimum_credit_tier TEXT NOT NULL CHECK (minimum_credit_tier IN ('building', 'fair', 'good', 'excellent')),
    rewards_type TEXT NOT NULL CHECK (rewards_type IN ('cash_back', 'travel', 'hybrid')),
    first_year_bonus_estimate_cents INTEGER NOT NULL DEFAULT 0 CHECK (first_year_bonus_estimate_cents >= 0),
    annual_benefit_estimate_cents INTEGER NOT NULL DEFAULT 0 CHECK (annual_benefit_estimate_cents >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (catalog_card_id, dataset_version)
);

CREATE INDEX card_catalog_versions_latest_idx ON revocred.card_catalog_versions (catalog_card_id, created_at DESC);
CREATE INDEX card_catalog_versions_dataset_idx ON revocred.card_catalog_versions (dataset_version);

CREATE TABLE revocred.questionnaire_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    monthly_category_spend JSONB NOT NULL CHECK (jsonb_typeof(monthly_category_spend) = 'object'),
    fee_tolerance_cents INTEGER NOT NULL CHECK (fee_tolerance_cents >= 0),
    travel_scope TEXT NOT NULL CHECK (travel_scope IN ('none', 'domestic', 'international', 'both')),
    rewards_goal TEXT NOT NULL CHECK (rewards_goal IN ('cash_back', 'travel', 'hybrid')),
    credit_tier TEXT NOT NULL CHECK (credit_tier IN ('building', 'fair', 'good', 'excellent')),
    existing_card_ids TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX questionnaire_responses_user_created_idx ON revocred.questionnaire_responses (user_id, created_at DESC);

CREATE TABLE revocred.wallet_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    catalog_card_id UUID NOT NULL REFERENCES revocred.catalog_cards(id) ON DELETE RESTRICT,
    nickname TEXT NOT NULL DEFAULT '' CHECK (char_length(nickname) <= 100),
    status TEXT NOT NULL CHECK (status IN ('active', 'inactive')),
    opened_on DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, catalog_card_id)
);

CREATE INDEX wallet_cards_user_created_idx ON revocred.wallet_cards (user_id, created_at DESC);

CREATE TABLE revocred.recommendation_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    questionnaire_response_id UUID NOT NULL REFERENCES revocred.questionnaire_responses(id) ON DELETE RESTRICT,
    engine_version TEXT NOT NULL,
    dataset_version TEXT NOT NULL,
    exclusions JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(exclusions) = 'array'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX recommendation_runs_user_created_idx ON revocred.recommendation_runs (user_id, created_at DESC);

CREATE TABLE revocred.recommendation_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recommendation_run_id UUID NOT NULL REFERENCES revocred.recommendation_runs(id) ON DELETE CASCADE,
    catalog_card_id UUID NOT NULL REFERENCES revocred.catalog_cards(id) ON DELETE RESTRICT,
    rank INTEGER NOT NULL CHECK (rank > 0),
    score NUMERIC(12, 2) NOT NULL,
    first_year_estimate_cents BIGINT NOT NULL,
    ongoing_annual_estimate_cents BIGINT NOT NULL,
    reasons JSONB NOT NULL CHECK (jsonb_typeof(reasons) = 'array'),
    UNIQUE (recommendation_run_id, rank),
    UNIQUE (recommendation_run_id, catalog_card_id)
);

CREATE INDEX recommendation_items_run_rank_idx ON revocred.recommendation_items (recommendation_run_id, rank);

CREATE TABLE revocred.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 8000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX chat_messages_user_created_idx ON revocred.chat_messages (user_id, created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS revocred.chat_messages;
DROP TABLE IF EXISTS revocred.recommendation_items;
DROP TABLE IF EXISTS revocred.recommendation_runs;
DROP TABLE IF EXISTS revocred.wallet_cards;
DROP TABLE IF EXISTS revocred.questionnaire_responses;
DROP TABLE IF EXISTS revocred.card_catalog_versions;
DROP TABLE IF EXISTS revocred.catalog_cards;
DROP TABLE IF EXISTS revocred.catalog_sources;
DROP TABLE IF EXISTS revocred.profiles;
DROP SCHEMA IF EXISTS revocred;
