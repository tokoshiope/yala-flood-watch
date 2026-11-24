-- Yala Flood Watch — Phase 2 Initial Supabase Schema, RLS & PDPA Retention
-- Target: Yala Province ONLY (province_code = '95', 8 amphoes)
-- Privacy-by-Design: Zero PII on server (no phone, name, or continuous GPS tracking)

-- 1. Storage bucket for precomputed 5-source CDN snapshots
INSERT INTO storage.buckets (id, name, public)
VALUES ('snapshots', 'snapshots', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public anonymous READ ONLY on snapshots bucket (writes restricted to service_role)
DROP POLICY IF EXISTS "Public read snapshots" ON storage.objects;
CREATE POLICY "Public read snapshots"
  ON storage.objects FOR SELECT
  TO anon, authenticated
  USING (bucket_id = 'snapshots');

-- 2. Verified Community Flood Reports (Tier C Signal, PDPA 90-day retention)
CREATE TABLE IF NOT EXISTS public.community_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '90 days'),
  amphoe_th TEXT NOT NULL CHECK (
    amphoe_th IN (
      'เมืองยะลา', 'รามัน', 'ยะหา', 'กรงปินัง',
      'เบตง', 'บันนังสตา', 'ธารโต', 'กาบัง'
    )
  ),
  report_type TEXT NOT NULL CHECK (
    report_type IN ('water_rising', 'road_flooded', 'flash_flood', 'landslide', 'shelter_full')
  ),
  -- Rounded to ~110m (3 decimals) to prevent exact home tracking (PDPA)
  lat DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN 5.5 AND 7.2),
  lon DOUBLE PRECISION NOT NULL CHECK (lon BETWEEN 100.5 AND 101.9),
  water_depth_cm INTEGER CHECK (water_depth_cm IS NULL OR (water_depth_cm >= 0 AND water_depth_cm <= 1000)),
  note_th TEXT CHECK (note_th IS NULL OR char_length(note_th) <= 280),
  device_hash TEXT NOT NULL CHECK (char_length(device_hash) = 64),
  trust_score SMALLINT NOT NULL DEFAULT 1 CHECK (trust_score BETWEEN 1 AND 5),
  verified BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_community_reports_recent
  ON public.community_reports (amphoe_th, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_reports_rate_limit
  ON public.community_reports (device_hash, created_at DESC);

ALTER TABLE public.community_reports ENABLE ROW LEVEL SECURITY;

-- Restrict raw table SELECT (contains device_hash) to service_role only;
-- expose anonymized public_community_reports view without device_hash for anon/authenticated.
DROP POLICY IF EXISTS "Public read recent community reports" ON public.community_reports;
CREATE POLICY "Service role read community reports"
  ON public.community_reports FOR SELECT
  TO service_role
  USING (true);

CREATE OR REPLACE VIEW public.public_community_reports AS
SELECT
  id,
  created_at,
  expires_at,
  amphoe_th,
  report_type,
  lat,
  lon,
  water_depth_cm,
  note_th,
  trust_score
FROM public.community_reports
WHERE expires_at > now();

GRANT SELECT ON public.public_community_reports TO anon, authenticated;

-- Direct INSERT blocked for anon — must go through rate-limited RPC below
DROP POLICY IF EXISTS "Deny direct anon insert" ON public.community_reports;
CREATE POLICY "Deny direct anon insert"
  ON public.community_reports FOR INSERT
  TO anon
  WITH CHECK (false);

-- 3. Rate-limited RPC: max 1 report per device_hash per 60 minutes (AC-402)
CREATE OR REPLACE FUNCTION public.submit_community_report(
  p_amphoe_th TEXT,
  p_report_type TEXT,
  p_lat DOUBLE PRECISION,
  p_lon DOUBLE PRECISION,
  p_device_hash TEXT,
  p_water_depth_cm INTEGER DEFAULT NULL,
  p_note_th TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recent_count INTEGER;
  v_new_id UUID;
BEGIN
  IF p_lat < 5.5 OR p_lat > 7.2 OR p_lon < 100.5 OR p_lon > 101.9 THEN
    RAISE EXCEPTION 'Coordinates outside Yala Province bounding box';
  END IF;

  SELECT COUNT(*) INTO v_recent_count
  FROM public.community_reports
  WHERE device_hash = p_device_hash
    AND created_at > now() - INTERVAL '60 minutes';

  IF v_recent_count >= 1 THEN
    RAISE EXCEPTION 'Rate limit exceeded: max 1 report per device per hour';
  END IF;

  INSERT INTO public.community_reports (
    amphoe_th,
    report_type,
    lat,
    lon,
    water_depth_cm,
    note_th,
    device_hash,
    trust_score
  )
  VALUES (
    p_amphoe_th,
    p_report_type,
    round(p_lat::numeric, 3)::double precision,
    round(p_lon::numeric, 3)::double precision,
    p_water_depth_cm,
    p_note_th,
    p_device_hash,
    1
  )
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_community_report(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, INTEGER, TEXT) TO anon, authenticated;

-- 4. Automated PDPA Retention Purge (called daily by GitHub Actions service_role)
CREATE OR REPLACE FUNCTION public.purge_expired_reports()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted INTEGER;
BEGIN
  DELETE FROM public.community_reports WHERE expires_at <= now();
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_expired_reports() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_expired_reports() TO service_role;
