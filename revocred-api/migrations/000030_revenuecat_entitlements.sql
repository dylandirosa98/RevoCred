-- +goose Up
-- RevenueCat subscription state. The runtime role still cannot write
-- ai_entitlements directly: it may only call apply_revenuecat_entitlement,
-- which writes 'revenuecat' rows for existing accounts, never touches
-- 'manual' rows, never grants open-ended access, and ignores replays and
-- events older than the state already stored.
ALTER TABLE revocred.ai_entitlements
 ADD COLUMN product_id TEXT CHECK (char_length(product_id) <= 200),
 ADD COLUMN revenuecat_event_at TIMESTAMPTZ;

-- Processed webhook event ids, for idempotent retries. Kept 90 days.
CREATE TABLE revocred.revenuecat_events (
 id TEXT PRIMARY KEY CHECK (char_length(id) BETWEEN 1 AND 200),
 user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 event_at TIMESTAMPTZ NOT NULL,
 received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX revenuecat_events_received ON revocred.revenuecat_events(received_at);

-- Returns 'applied', 'duplicate', 'stale', 'manual' or 'unknown_user'.
-- p_event_id is NULL for a server-side refresh from the RevenueCat API.
-- +goose StatementBegin
CREATE FUNCTION revocred.apply_revenuecat_entitlement(
    p_event_id TEXT, p_user_id UUID, p_event_at TIMESTAMPTZ,
    p_expires_at TIMESTAMPTZ, p_product_id TEXT
) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    current_source TEXT;
    current_event_at TIMESTAMPTZ;
BEGIN
    IF p_user_id IS NULL OR p_event_at IS NULL OR p_expires_at IS NULL THEN
        RAISE EXCEPTION 'user, event time and expiry are required';
    END IF;
    -- Subscriptions are monthly; nothing legitimate lasts beyond 13 months.
    IF p_expires_at > now() + interval '13 months' THEN
        RAISE EXCEPTION 'expiry is too far in the future';
    END IF;
    IF p_event_at > now() + interval '1 hour' THEN
        RAISE EXCEPTION 'event time is in the future';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RETURN 'unknown_user';
    END IF;
    -- Serialize with AI-use reservations and concurrent events for this user.
    PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text, 1));
    IF p_event_id IS NOT NULL THEN
        INSERT INTO revocred.revenuecat_events(id, user_id, event_at)
        VALUES (p_event_id, p_user_id, p_event_at) ON CONFLICT (id) DO NOTHING;
        IF NOT FOUND THEN
            RETURN 'duplicate';
        END IF;
        DELETE FROM revocred.revenuecat_events WHERE received_at < now() - interval '90 days';
    END IF;
    SELECT source, revenuecat_event_at INTO current_source, current_event_at
    FROM revocred.ai_entitlements WHERE user_id = p_user_id FOR UPDATE;
    IF current_source = 'manual' THEN
        RETURN 'manual';
    END IF;
    IF current_event_at IS NOT NULL AND current_event_at >= p_event_at THEN
        RETURN 'stale';
    END IF;
    INSERT INTO revocred.ai_entitlements(user_id, source, expires_at, product_id, revenuecat_event_at, updated_at)
    VALUES (p_user_id, 'revenuecat', p_expires_at, left(p_product_id, 200), p_event_at, now())
    ON CONFLICT (user_id) DO UPDATE SET
        expires_at = excluded.expires_at,
        product_id = coalesce(excluded.product_id, revocred.ai_entitlements.product_id),
        revenuecat_event_at = excluded.revenuecat_event_at,
        updated_at = now()
    WHERE revocred.ai_entitlements.source = 'revenuecat';
    RETURN 'applied';
END;
$$;
-- +goose StatementEnd
REVOKE ALL ON FUNCTION revocred.apply_revenuecat_entitlement(TEXT, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM PUBLIC;
-- +goose StatementBegin
DO $$ DECLARE r TEXT; BEGIN
    FOREACH r IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=r) THEN
            EXECUTE format('REVOKE ALL ON FUNCTION revocred.apply_revenuecat_entitlement(TEXT, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) FROM %I', r);
            EXECUTE format('REVOKE ALL ON revocred.revenuecat_events FROM %I', r);
        END IF;
    END LOOP;
END $$;
-- +goose StatementEnd
GRANT EXECUTE ON FUNCTION revocred.apply_revenuecat_entitlement(TEXT, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO revocred_runtime;

-- +goose Down
DROP FUNCTION revocred.apply_revenuecat_entitlement(TEXT, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT);
DROP TABLE revocred.revenuecat_events;
ALTER TABLE revocred.ai_entitlements DROP COLUMN revenuecat_event_at, DROP COLUMN product_id;
