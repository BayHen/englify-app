-- Restore the unified Real English search RPC when production migration history
-- is incomplete. This migration is data-preserving and only replaces the RPC.

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.englify_normalize_search(p_value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = ''
AS $$ SELECT lower(extensions.unaccent(coalesce(p_value, ''))) $$;
REVOKE ALL ON FUNCTION public.englify_normalize_search(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_normalize_search(text) TO authenticated, service_role;

ALTER TABLE public.real_english_expressions
  ADD COLUMN IF NOT EXISTS cefr_level text,
  ADD COLUMN IF NOT EXISTS topic_slug text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.real_english_expressions'::regclass
      AND conname = 'real_english_expressions_cefr_check'
  ) THEN
    ALTER TABLE public.real_english_expressions
      ADD CONSTRAINT real_english_expressions_cefr_check
      CHECK (cefr_level IS NULL OR cefr_level IN ('A1', 'A2', 'B1', 'B2', 'C1', 'C2'))
      NOT VALID;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS real_english_expressions_filter_idx
  ON public.real_english_expressions (cefr_level, topic_slug, kind, expression)
  WHERE is_published AND archived_at IS NULL;

CREATE OR REPLACE FUNCTION public.englify_search_real_english(
  p_query text DEFAULT '',
  p_cefr text DEFAULT NULL,
  p_topic text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_saved_only boolean DEFAULT false,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 5
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_query text := public.englify_normalize_search(left(btrim(coalesce(p_query, '')), 80));
  v_page integer := greatest(1, coalesce(p_page, 1));
  v_size integer := least(20, greatest(1, coalesce(p_page_size, 5)));
  v_total bigint;
  v_items jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF length(btrim(coalesce(p_query, ''))) > 80 THEN
    RAISE EXCEPTION 'Search term is too long' USING ERRCODE = '22023';
  END IF;
  IF p_cefr IS NOT NULL AND p_cefr NOT IN ('A1', 'A2', 'B1', 'B2', 'C1', 'C2') THEN
    RAISE EXCEPTION 'Invalid CEFR level' USING ERRCODE = '22023';
  END IF;

  WITH library AS (
    SELECT
      'expression'::text AS item_type,
      e.id,
      e.expression AS title,
      e.meaning_vi AS subtitle,
      e.cefr_level,
      e.topic_slug,
      e.kind AS category,
      e.formality,
      e.created_at AS sort_at,
      EXISTS (
        SELECT 1
        FROM public.saved_expressions s
        WHERE s.user_id = v_uid AND s.expression_id = e.id
      ) AS saved,
      NULL::text AS progress_status
    FROM public.real_english_expressions e
    WHERE e.is_published AND e.archived_at IS NULL
      AND (
        v_query = '' OR public.englify_normalize_search(
          e.expression || ' ' || e.meaning_vi || ' ' || e.context_explanation || ' '
          || e.example_en || ' ' || e.example_vi || ' ' || e.dialogue::text
        ) LIKE '%' || v_query || '%'
      )
    UNION ALL
    SELECT
      'lesson',
      l.id,
      l.title,
      l.description,
      l.difficulty,
      t.slug,
      l.content_type,
      NULL,
      l.published_at,
      coalesce(p.is_bookmarked, false),
      p.status
    FROM public.real_english_lessons l
    JOIN public.real_english_topics t ON t.id = l.topic_id
    LEFT JOIN public.real_english_user_progress p
      ON p.lesson_id = l.id AND p.user_id = v_uid
    WHERE l.status = 'published'
      AND (
        v_query = ''
        OR public.englify_normalize_search(l.title || ' ' || l.description || ' ' || t.title)
          LIKE '%' || v_query || '%'
        OR EXISTS (
          SELECT 1
          FROM public.real_english_phrases ph
          WHERE ph.lesson_id = l.id
            AND public.englify_normalize_search(
              ph.english_text || ' ' || ph.vietnamese_translation || ' ' || ph.usage_context
            ) LIKE '%' || v_query || '%'
        )
        OR EXISTS (
          SELECT 1
          FROM public.real_english_dialogues d
          JOIN public.real_english_dialogue_lines dl ON dl.dialogue_id = d.id
          WHERE d.lesson_id = l.id
            AND public.englify_normalize_search(dl.english_text || ' ' || dl.vietnamese_translation)
              LIKE '%' || v_query || '%'
        )
      )
  ), filtered AS (
    SELECT *
    FROM library
    WHERE (p_cefr IS NULL OR cefr_level = p_cefr)
      AND (p_topic IS NULL OR topic_slug = p_topic)
      AND (
        p_category IS NULL
        OR (p_category = 'expression' AND (item_type = 'expression' OR category = 'expression'))
        OR (p_category = 'dialogue' AND category IN ('dialogue', 'everyday_conversation', 'movie_style_dialogue'))
        OR (p_category NOT IN ('expression', 'dialogue') AND category = p_category)
      )
      AND (NOT p_saved_only OR saved)
  )
  SELECT
    (SELECT count(*) FROM filtered),
    (
      SELECT coalesce(
        jsonb_agg(to_jsonb(page_rows) - 'sort_at' ORDER BY sort_at DESC, id),
        '[]'::jsonb
      )
      FROM (
        SELECT *
        FROM filtered
        ORDER BY sort_at DESC, id
        OFFSET (v_page - 1) * v_size
        LIMIT v_size
      ) page_rows
    )
  INTO v_total, v_items;

  RETURN jsonb_build_object(
    'items', v_items,
    'total', v_total,
    'page', v_page,
    'page_size', v_size,
    'page_count', greatest(1, ceil(v_total::numeric / v_size)::integer)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.englify_search_real_english(
  text, text, text, text, boolean, integer, integer
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_search_real_english(
  text, text, text, text, boolean, integer, integer
) TO authenticated, service_role;

COMMENT ON FUNCTION public.englify_search_real_english(
  text, text, text, text, boolean, integer, integer
) IS 'Searches the unified published Real English library with server-side pagination.';

ALTER TABLE public.real_english_expressions
  VALIDATE CONSTRAINT real_english_expressions_cefr_check;

NOTIFY pgrst, 'reload schema';
