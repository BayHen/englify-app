SET local check_function_bodies = off;

CREATE SEQUENCE "public"."gamification_config_id_seq" AS integer INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START WITH 1 CACHE 1 NO CYCLE;

CREATE TABLE "public"."admin_audit_logs" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "actor_id"    uuid                     NOT NULL,
  "action"      text                     NOT NULL,
  "resource"    text                     NOT NULL,
  "record_id"   uuid                     NOT NULL,
  "before_data" jsonb,
  "after_data"  jsonb,
  "created_at"  timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "admin_audit_logs_action_check" CHECK ((action = ANY (ARRAY['create'::text, 'update'::text, 'delete'::text, 'publish'::text, 'unpublish'::text]))),
  CONSTRAINT "admin_audit_logs_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."admin_audit_logs"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."admin_members" (
  "user_id"    uuid                     NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "admin_members_pkey" PRIMARY KEY (user_id)
);

ALTER TABLE "public"."admin_members"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."alembic_version" (
  "version_num" character varying(32) NOT NULL,
  CONSTRAINT "alembic_version_pkc" PRIMARY KEY (version_num)
);

CREATE TABLE "public"."badge_rules" (
  "badge_id" uuid    NOT NULL,
  "metric"   text    NOT NULL,
  "target"   integer NOT NULL,
  CONSTRAINT "badge_rules_metric_check" CHECK ((metric = ANY (ARRAY['completed_lessons'::text, 'total_xp'::text]))),
  CONSTRAINT "badge_rules_pkey" PRIMARY KEY (badge_id),
  CONSTRAINT "badge_rules_target_check" CHECK ((target > 0))
);

ALTER TABLE "public"."badge_rules"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."badge_rules" FROM "anon", "authenticated";

CREATE TABLE "public"."badges" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "code"         text                     NOT NULL,
  "title"        text                     NOT NULL,
  "description"  text                     NOT NULL DEFAULT ''::text,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "is_published" boolean                  NOT NULL DEFAULT false,
  "archived_at"  timestamp with time zone,
  CONSTRAINT "badges_code_key" UNIQUE (code),
  CONSTRAINT "badges_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."badges"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."badges" FROM "anon";

CREATE TABLE "public"."courses" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "slug"         text                     NOT NULL,
  "title"        text                     NOT NULL,
  "description"  text                     NOT NULL DEFAULT ''::text,
  "level"        integer                  NOT NULL DEFAULT 1,
  "is_published" boolean                  NOT NULL DEFAULT false,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "archived_at"  timestamp with time zone,
  CONSTRAINT "courses_level_check" CHECK ((level > 0)),
  CONSTRAINT "courses_pkey" PRIMARY KEY (id),
  CONSTRAINT "courses_slug_key" UNIQUE (slug)
);

ALTER TABLE "public"."courses"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."courses" FROM "anon";

CREATE TABLE "public"."dictionary_entries" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "language"        text                     NOT NULL,
  "term"            text                     NOT NULL,
  "normalized_term" text                     NOT NULL,
  "definition"      text                     NOT NULL,
  "translation"     text,
  "part_of_speech"  text,
  "example"         text,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "ipa"             text,
  "audio_url"       text,
  "source_name"     text                     NOT NULL DEFAULT 'Englify Quest editorial'::text,
  "license_id"      text                     NOT NULL DEFAULT 'project-owned'::text,
  "is_published"    boolean                  NOT NULL DEFAULT false,
  "archived_at"     timestamp with time zone,
  CONSTRAINT "ck_dictionary_audio_https" CHECK (((audio_url IS NULL) OR (audio_url ~~ 'https://%'::text))),
  CONSTRAINT "dictionary_entries_language_check" CHECK ((language = ANY (ARRAY['en'::text, 'vi'::text]))),
  CONSTRAINT "dictionary_entries_language_normalized_term_key" UNIQUE (LANGUAGE, normalized_term),
  CONSTRAINT "dictionary_entries_normalized_term_check" CHECK ((length(TRIM(BOTH FROM normalized_term)) > 0)),
  CONSTRAINT "dictionary_entries_pkey" PRIMARY KEY (id),
  CONSTRAINT "dictionary_entries_term_check" CHECK ((length(TRIM(BOTH FROM term)) > 0))
);

ALTER TABLE "public"."dictionary_entries"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."dictionary_entries" FROM "anon";

CREATE TABLE "public"."gamification_config" (
  "id"                        integer                  NOT NULL DEFAULT nextval('public.gamification_config_id_seq'::regclass),
  "level_xp_step"             integer                  NOT NULL,
  "lesson_multiplier_percent" integer                  NOT NULL,
  "updated_at"                timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "gamification_config_id_check" CHECK ((id = 1)),
  CONSTRAINT "gamification_config_lesson_multiplier_percent_check" CHECK (((lesson_multiplier_percent >= 0) AND (lesson_multiplier_percent <= 200))),
  CONSTRAINT "gamification_config_level_xp_step_check" CHECK (((level_xp_step >= 10) AND (level_xp_step <= 10000))),
  CONSTRAINT "gamification_config_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."gamification_config"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."gamification_config" FROM "anon", "authenticated";

CREATE TABLE "public"."learning_plan_tasks" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "plan_id"          uuid                     NOT NULL,
  "user_id"          uuid                     NOT NULL,
  "lesson_id"        uuid,
  "kind"             text                     NOT NULL,
  "title"            text                     NOT NULL,
  "scheduled_on"     date                     NOT NULL,
  "original_date"    date                     NOT NULL,
  "duration_minutes" integer                  NOT NULL,
  "target_count"     integer,
  "topic"            text,
  "status"           text                     NOT NULL DEFAULT 'pending'::text,
  "completed_at"     timestamp with time zone,
  "position"         integer                  NOT NULL,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "learning_plan_tasks_duration_minutes_check" CHECK (((duration_minutes >= 1) AND (duration_minutes <= 180))),
  CONSTRAINT "learning_plan_tasks_kind_check" CHECK ((kind = ANY (ARRAY['lesson'::text, 'vocabulary'::text, 'review'::text, 'speaking'::text, 'writing'::text]))),
  CONSTRAINT "learning_plan_tasks_pkey" PRIMARY KEY (id),
  CONSTRAINT "learning_plan_tasks_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'completed'::text]))),
  CONSTRAINT "learning_plan_tasks_target_count_check" CHECK ((target_count > 0)),
  CONSTRAINT "plan_task_completed_consistency" CHECK ((((status = 'completed'::text) AND (completed_at IS NOT NULL)) OR ((status = 'pending'::text) AND (completed_at IS NULL))))
);

ALTER TABLE "public"."learning_plan_tasks"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."learning_plans" (
  "id"                uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"           uuid                     NOT NULL,
  "title"             text                     NOT NULL,
  "goal"              text                     NOT NULL,
  "status"            text                     NOT NULL DEFAULT 'active'::text,
  "target_date"       date,
  "created_at"        timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"        timestamp with time zone NOT NULL DEFAULT now(),
  "algorithm_version" integer                  NOT NULL DEFAULT 1,
  "starts_on"         date,
  CONSTRAINT "learning_plans_id_user_unique" UNIQUE (id, user_id),
  CONSTRAINT "learning_plans_pkey" PRIMARY KEY (id),
  CONSTRAINT "learning_plans_status_check" CHECK ((status = ANY (ARRAY['active'::text, 'paused'::text, 'completed'::text])))
);

ALTER TABLE "public"."learning_plans"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."learning_plans" FROM "anon";

CREATE TABLE "public"."learning_progress" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"      uuid                     NOT NULL,
  "lesson_id"    uuid                     NOT NULL,
  "status"       text                     NOT NULL DEFAULT 'not_started'::text,
  "completed_at" timestamp with time zone,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "learning_progress_check" CHECK (((status = ANY (ARRAY['completed'::text, 'mastered'::text])) = (completed_at IS NOT NULL))),
  CONSTRAINT "learning_progress_pkey" PRIMARY KEY (id),
  CONSTRAINT "learning_progress_status_check" CHECK ((status = ANY (ARRAY['not_started'::text, 'in_progress'::text, 'completed'::text, 'mastered'::text]))),
  CONSTRAINT "learning_progress_user_id_lesson_id_key" UNIQUE (user_id, lesson_id)
);

ALTER TABLE "public"."learning_progress"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."learning_progress" FROM "anon";

CREATE TABLE "public"."learning_units" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "course_id"    uuid                     NOT NULL,
  "slug"         text                     NOT NULL,
  "title"        text                     NOT NULL,
  "position"     integer                  NOT NULL,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "is_published" boolean                  NOT NULL DEFAULT false,
  "archived_at"  timestamp with time zone,
  CONSTRAINT "learning_units_course_id_position_key" UNIQUE (course_id, "position"),
  CONSTRAINT "learning_units_course_id_slug_key" UNIQUE (course_id, slug),
  CONSTRAINT "learning_units_pkey" PRIMARY KEY (id),
  CONSTRAINT "learning_units_position_check" CHECK (("position" > 0))
);

ALTER TABLE "public"."learning_units"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."learning_units" FROM "anon";

CREATE TABLE "public"."lesson_answer_attempts" (
  "id"          uuid    NOT NULL DEFAULT gen_random_uuid(),
  "attempt_id"  uuid    NOT NULL,
  "question_id" uuid    NOT NULL,
  "answer"      jsonb   NOT NULL,
  "is_correct"  boolean NOT NULL,
  CONSTRAINT "lesson_answer_attempts_attempt_id_question_id_key" UNIQUE (attempt_id, question_id),
  CONSTRAINT "lesson_answer_attempts_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."lesson_answer_attempts"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."lesson_answer_attempts" FROM "anon";

CREATE TABLE "public"."lesson_attempts" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"        uuid                     NOT NULL,
  "lesson_id"      uuid                     NOT NULL,
  "request_id"     uuid                     NOT NULL,
  "correct_count"  integer                  NOT NULL,
  "question_count" integer                  NOT NULL,
  "passed"         boolean                  NOT NULL,
  "result_state"   text                     NOT NULL,
  "earned_xp"      integer                  NOT NULL DEFAULT 0,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "reward_payload" jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  CONSTRAINT "lesson_attempts_check" CHECK (((question_count > 0) AND ((correct_count >= 0) AND (correct_count <= question_count)))),
  CONSTRAINT "lesson_attempts_earned_xp_check" CHECK ((earned_xp >= 0)),
  CONSTRAINT "lesson_attempts_pkey" PRIMARY KEY (id),
  CONSTRAINT "lesson_attempts_result_state_check" CHECK ((result_state = ANY (ARRAY['in_progress'::text, 'completed'::text, 'mastered'::text]))),
  CONSTRAINT "lesson_attempts_user_id_request_id_key" UNIQUE (user_id, request_id)
);

ALTER TABLE "public"."lesson_attempts"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."lesson_attempts" FROM "anon";

CREATE TABLE "public"."lesson_items" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "lesson_id"    uuid                     NOT NULL,
  "position"     integer                  NOT NULL,
  "kind"         text                     NOT NULL,
  "body"         jsonb                    NOT NULL,
  "is_published" boolean                  NOT NULL DEFAULT false,
  "archived_at"  timestamp with time zone,
  CONSTRAINT "lesson_items_kind_check" CHECK ((kind = ANY (ARRAY['reading'::text, 'tip'::text]))),
  CONSTRAINT "lesson_items_lesson_id_position_key" UNIQUE (lesson_id, "position"),
  CONSTRAINT "lesson_items_pkey" PRIMARY KEY (id),
  CONSTRAINT "lesson_items_position_check" CHECK (("position" > 0))
);

ALTER TABLE "public"."lesson_items"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."lesson_items" FROM "anon";

CREATE TABLE "public"."lessons" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "course_id"    uuid                     NOT NULL,
  "slug"         text                     NOT NULL,
  "position"     integer                  NOT NULL,
  "title"        text                     NOT NULL,
  "objective"    text                     NOT NULL,
  "content"      jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "xp_reward"    integer                  NOT NULL DEFAULT 0,
  "is_published" boolean                  NOT NULL DEFAULT false,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "unit_id"      uuid,
  "archived_at"  timestamp with time zone,
  CONSTRAINT "lessons_content_check" CHECK ((jsonb_typeof(content) = 'object'::text)),
  CONSTRAINT "lessons_course_id_position_key" UNIQUE (course_id, "position"),
  CONSTRAINT "lessons_course_id_slug_key" UNIQUE (course_id, slug),
  CONSTRAINT "lessons_pkey" PRIMARY KEY (id),
  CONSTRAINT "lessons_position_check" CHECK (("position" > 0)),
  CONSTRAINT "lessons_xp_reward_check" CHECK (((xp_reward >= 0) AND (xp_reward <= 1000)))
);

ALTER TABLE "public"."lessons"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."lessons" FROM "anon";

CREATE TABLE "public"."profiles" (
  "id"           uuid                     NOT NULL,
  "display_name" text                     NOT NULL,
  "avatar_url"   text,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "username"     text,
  "bio"          text,
  CONSTRAINT "profiles_bio_length" CHECK (((bio IS NULL) OR (char_length(bio) <= 160))),
  CONSTRAINT "profiles_display_name_check" CHECK (((length(TRIM(BOTH FROM display_name)) >= 1) AND (length(TRIM(BOTH FROM display_name)) <= 80))),
  CONSTRAINT "profiles_pkey" PRIMARY KEY (id),
  CONSTRAINT "profiles_username_format" CHECK (((username IS NULL) OR (username ~ '^[a-z0-9_]{3,30}$'::text)))
);

ALTER TABLE "public"."profiles"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."profiles" FROM "anon";

CREATE TABLE "public"."quest_claims" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"      uuid                     NOT NULL,
  "quest_id"     uuid                     NOT NULL,
  "period_start" date                     NOT NULL,
  "awarded_xp"   integer                  NOT NULL,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "quest_claims_awarded_xp_check" CHECK ((awarded_xp >= 0)),
  CONSTRAINT "quest_claims_pkey" PRIMARY KEY (id),
  CONSTRAINT "quest_claims_user_id_quest_id_period_start_key" UNIQUE (user_id, quest_id, period_start)
);

ALTER TABLE "public"."quest_claims"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."quest_claims" FROM "anon";

CREATE TABLE "public"."quests" (
  "id"             uuid                     NOT NULL,
  "code"           text                     NOT NULL,
  "title"          text                     NOT NULL,
  "description"    text                     NOT NULL,
  "period"         text                     NOT NULL,
  "target_lessons" integer                  NOT NULL,
  "reward_xp"      integer                  NOT NULL,
  "is_active"      boolean                  NOT NULL DEFAULT true,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "quests_code_key" UNIQUE (code),
  CONSTRAINT "quests_period_check" CHECK ((period = ANY (ARRAY['daily'::text, 'weekly'::text]))),
  CONSTRAINT "quests_pkey" PRIMARY KEY (id),
  CONSTRAINT "quests_reward_xp_check" CHECK (((reward_xp >= 0) AND (reward_xp <= 1000))),
  CONSTRAINT "quests_target_lessons_check" CHECK (((target_lessons >= 1) AND (target_lessons <= 100)))
);

ALTER TABLE "public"."quests"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."quests" FROM "anon";

CREATE TABLE "public"."quiz_answer_keys" (
  "question_id" uuid  NOT NULL,
  "answer"      jsonb NOT NULL,
  CONSTRAINT "quiz_answer_keys_pkey" PRIMARY KEY (question_id)
);

ALTER TABLE "public"."quiz_answer_keys"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."quiz_answer_keys" FROM "anon", "authenticated";

CREATE TABLE "public"."quiz_attempts" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"            uuid                     NOT NULL,
  "question_id"        uuid                     NOT NULL,
  "selected_option_id" uuid                     NOT NULL,
  "is_correct"         boolean                  NOT NULL,
  "created_at"         timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "quiz_attempts_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."quiz_attempts"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."quiz_attempts" FROM "anon";

CREATE TABLE "public"."quiz_options" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "question_id" uuid                     NOT NULL,
  "position"    integer                  NOT NULL,
  "answer_text" text                     NOT NULL,
  "is_correct"  boolean                  NOT NULL DEFAULT false,
  "created_at"  timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"  timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "quiz_options_id_question_id_key" UNIQUE (id, question_id),
  CONSTRAINT "quiz_options_pkey" PRIMARY KEY (id),
  CONSTRAINT "quiz_options_position_check" CHECK (("position" > 0)),
  CONSTRAINT "quiz_options_question_id_position_key" UNIQUE (question_id, "position")
);

ALTER TABLE "public"."quiz_options"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."quiz_options" FROM "anon", "authenticated";

CREATE TABLE "public"."quiz_questions" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "lesson_id"    uuid                     NOT NULL,
  "position"     integer                  NOT NULL,
  "prompt"       text                     NOT NULL,
  "explanation"  text                     NOT NULL DEFAULT ''::text,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "kind"         text                     NOT NULL DEFAULT 'multiple_choice'::text,
  "payload"      jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "is_published" boolean                  NOT NULL DEFAULT false,
  "archived_at"  timestamp with time zone,
  CONSTRAINT "ck_quiz_question_kind" CHECK ((kind = ANY (ARRAY['multiple_choice'::text, 'fill_blank'::text, 'matching'::text, 'listening'::text, 'grammar'::text]))),
  CONSTRAINT "quiz_questions_lesson_id_position_key" UNIQUE (lesson_id, "position"),
  CONSTRAINT "quiz_questions_pkey" PRIMARY KEY (id),
  CONSTRAINT "quiz_questions_position_check" CHECK (("position" > 0))
);

ALTER TABLE "public"."quiz_questions"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."quiz_questions" FROM "anon";

CREATE TABLE "public"."real_english_expressions" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "slug"                text                     NOT NULL,
  "kind"                text                     NOT NULL,
  "expression"          text                     NOT NULL,
  "meaning_vi"          text                     NOT NULL,
  "context_explanation" text                     NOT NULL,
  "example_en"          text                     NOT NULL,
  "example_vi"          text                     NOT NULL,
  "dialogue"            jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "formality"           text                     NOT NULL,
  "region_note"         text                     NOT NULL,
  "source_name"         text                     NOT NULL,
  "license_id"          text                     NOT NULL,
  "provenance_note"     text                     NOT NULL,
  "is_published"        boolean                  NOT NULL DEFAULT false,
  "created_at"          timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"          timestamp with time zone NOT NULL DEFAULT now(),
  "archived_at"         timestamp with time zone,
  CONSTRAINT "real_english_expressions_dialogue_check" CHECK ((jsonb_typeof(dialogue) = 'array'::text)),
  CONSTRAINT "real_english_expressions_formality_check" CHECK ((formality = ANY (ARRAY['informal'::text, 'neutral'::text, 'formal'::text]))),
  CONSTRAINT "real_english_expressions_kind_check"
    CHECK ((kind = ANY (ARRAY['slang'::text, 'idiom'::text, 'phrasal_verb'::text, 'casual_expression'::text, 'everyday_conversation'::text, 'movie_style_dialogue'::text]))),
  CONSTRAINT "real_english_expressions_pkey" PRIMARY KEY (id),
  CONSTRAINT "real_english_expressions_slug_key" UNIQUE (slug)
);

ALTER TABLE "public"."real_english_expressions"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."real_english_quiz_attempts" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"         uuid                     NOT NULL,
  "question_id"     uuid                     NOT NULL,
  "request_id"      uuid                     NOT NULL,
  "selected_option" text                     NOT NULL,
  "is_correct"      boolean                  NOT NULL,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "real_english_quiz_attempts_pkey" PRIMARY KEY (id),
  CONSTRAINT "real_english_quiz_attempts_user_id_request_id_key" UNIQUE (user_id, request_id)
);

ALTER TABLE "public"."real_english_quiz_attempts"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."real_english_quiz_questions" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "expression_id" uuid                     NOT NULL,
  "prompt"        text                     NOT NULL,
  "options"       jsonb                    NOT NULL,
  "answer_id"     text                     NOT NULL,
  "explanation"   text                     NOT NULL,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "real_english_quiz_questions_expression_id_key" UNIQUE (expression_id),
  CONSTRAINT "real_english_quiz_questions_options_check" CHECK ((jsonb_typeof(options) = 'array'::text)),
  CONSTRAINT "real_english_quiz_questions_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."real_english_quiz_questions"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."review_history" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"             uuid                     NOT NULL,
  "saved_vocabulary_id" uuid                     NOT NULL,
  "rating"              integer                  NOT NULL,
  "reviewed_at"         timestamp with time zone NOT NULL DEFAULT now(),
  "created_at"          timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "review_history_pkey" PRIMARY KEY (id),
  CONSTRAINT "review_history_rating_check" CHECK (((rating >= 0) AND (rating <= 5)))
);

ALTER TABLE "public"."review_history"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."review_history" FROM "anon";

CREATE TABLE "public"."reward_claims" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"    uuid                     NOT NULL,
  "reward_id"  uuid                     NOT NULL,
  "xp_cost"    integer                  NOT NULL,
  "claimed_at" timestamp with time zone NOT NULL DEFAULT now(),
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "reward_claims_pkey" PRIMARY KEY (id),
  CONSTRAINT "reward_claims_user_id_reward_id_key" UNIQUE (user_id, reward_id),
  CONSTRAINT "reward_claims_xp_cost_check" CHECK ((xp_cost >= 0))
);

ALTER TABLE "public"."reward_claims"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."reward_claims" FROM "anon";

CREATE TABLE "public"."reward_items" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "code"           text                     NOT NULL,
  "title"          text                     NOT NULL,
  "description"    text                     NOT NULL DEFAULT ''::text,
  "xp_cost"        integer                  NOT NULL,
  "is_active"      boolean                  NOT NULL DEFAULT false,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "required_level" integer                  NOT NULL DEFAULT 1,
  CONSTRAINT "ck_reward_required_level" CHECK ((required_level >= 1)),
  CONSTRAINT "reward_items_code_key" UNIQUE (code),
  CONSTRAINT "reward_items_pkey" PRIMARY KEY (id),
  CONSTRAINT "reward_items_xp_cost_check" CHECK ((xp_cost >= 0))
);

ALTER TABLE "public"."reward_items"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."reward_items" FROM "anon";

CREATE TABLE "public"."reward_notifications" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"    uuid                     NOT NULL,
  "kind"       text                     NOT NULL,
  "source_id"  uuid                     NOT NULL,
  "title"      text                     NOT NULL,
  "message"    text                     NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "read_at"    timestamp with time zone,
  CONSTRAINT "reward_notifications_kind_check" CHECK ((kind = ANY (ARRAY['xp'::text, 'level'::text, 'badge'::text, 'quest'::text, 'reward'::text]))),
  CONSTRAINT "reward_notifications_pkey" PRIMARY KEY (id),
  CONSTRAINT "reward_notifications_user_id_kind_source_id_key" UNIQUE (user_id, kind, source_id)
);

ALTER TABLE "public"."reward_notifications"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."reward_notifications" FROM "anon";

CREATE TABLE "public"."saved_expressions" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"       uuid                     NOT NULL,
  "expression_id" uuid                     NOT NULL,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "saved_expressions_pkey" PRIMARY KEY (id),
  CONSTRAINT "saved_expressions_user_id_expression_id_key" UNIQUE (user_id, expression_id)
);

ALTER TABLE "public"."saved_expressions"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."saved_vocabulary" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"        uuid                     NOT NULL,
  "entry_id"       uuid                     NOT NULL,
  "note"           text                     NOT NULL DEFAULT ''::text,
  "next_review_at" timestamp with time zone,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"     timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "saved_vocabulary_id_user_id_key" UNIQUE (id, user_id),
  CONSTRAINT "saved_vocabulary_pkey" PRIMARY KEY (id),
  CONSTRAINT "saved_vocabulary_user_id_entry_id_key" UNIQUE (user_id, entry_id)
);

ALTER TABLE "public"."saved_vocabulary"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."saved_vocabulary" FROM "anon";

CREATE TABLE "public"."speaking_attempts" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"    uuid                     NOT NULL,
  "lesson_id"  uuid,
  "prompt"     text                     NOT NULL,
  "transcript" text,
  "feedback"   jsonb,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "speaking_attempts_feedback_check" CHECK (((feedback IS NULL) OR (jsonb_typeof(feedback) = 'object'::text))),
  CONSTRAINT "speaking_attempts_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."speaking_attempts"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."speaking_attempts" FROM "anon";

CREATE TABLE "public"."user_badges" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"    uuid                     NOT NULL,
  "badge_id"   uuid                     NOT NULL,
  "awarded_at" timestamp with time zone NOT NULL DEFAULT now(),
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "user_badges_pkey" PRIMARY KEY (id),
  CONSTRAINT "user_badges_user_id_badge_id_key" UNIQUE (user_id, badge_id)
);

ALTER TABLE "public"."user_badges"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."user_badges" FROM "anon";

CREATE TABLE "public"."user_levels" (
  "user_id"    uuid                     NOT NULL,
  "total_xp"   integer                  NOT NULL DEFAULT 0,
  "level"      integer                  NOT NULL DEFAULT 1,
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "user_levels_check" CHECK (((total_xp >= 0) AND (level >= 1))),
  CONSTRAINT "user_levels_pkey" PRIMARY KEY (user_id)
);

ALTER TABLE "public"."user_levels"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."user_levels" FROM "anon";

CREATE TABLE "public"."user_preferences" (
  "id"                      uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"                 uuid                     NOT NULL,
  "learning_language"       text                     NOT NULL DEFAULT 'en'::text,
  "native_language"         text                     NOT NULL DEFAULT 'vi'::text,
  "daily_goal_minutes"      integer                  NOT NULL DEFAULT 10,
  "reminder_enabled"        boolean                  NOT NULL DEFAULT false,
  "theme"                   text                     NOT NULL DEFAULT 'system'::text,
  "created_at"              timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"              timestamp with time zone NOT NULL DEFAULT now(),
  "learning_goal"           text,
  "initial_proficiency"     text,
  "onboarding_completed_at" timestamp with time zone,
  "preferred_topics"        text[]                   NOT NULL DEFAULT '{}'::text[],
  "current_cefr"            text,
  "preferred_accent"        text                     NOT NULL DEFAULT 'en-US'::text,
  "interface_language"      text                     NOT NULL DEFAULT 'en'::text,
  CONSTRAINT "ck_preferences_initial_proficiency"
    CHECK (((initial_proficiency IS NULL) OR (initial_proficiency = ANY (ARRAY['beginner'::text, 'intermediate'::text, 'advanced'::text])))),
  CONSTRAINT "ck_preferences_learning_goal"
    CHECK (((learning_goal IS NULL) OR (learning_goal = ANY (ARRAY['conversation'::text, 'travel'::text, 'work'::text, 'exams'::text, 'real_english'::text])))),
  CONSTRAINT "ck_preferences_onboarding_complete" CHECK (((onboarding_completed_at IS NULL) OR ((learning_goal IS NOT NULL) AND (initial_proficiency IS NOT NULL)))),
  CONSTRAINT "preferences_accent_check" CHECK ((preferred_accent = ANY (ARRAY['en-US'::text, 'en-GB'::text, 'en-AU'::text]))),
  CONSTRAINT "preferences_cefr_check" CHECK (((current_cefr IS NULL) OR (current_cefr = ANY (ARRAY['A1'::text, 'A2'::text, 'B1'::text, 'B2'::text, 'C1'::text, 'C2'::text])))),
  CONSTRAINT "preferences_interface_check" CHECK ((interface_language = ANY (ARRAY['en'::text, 'vi'::text]))),
  CONSTRAINT "user_preferences_daily_goal_minutes_check" CHECK (((daily_goal_minutes >= 1) AND (daily_goal_minutes <= 180))),
  CONSTRAINT "user_preferences_learning_language_check" CHECK ((learning_language = 'en'::text)),
  CONSTRAINT "user_preferences_native_language_check" CHECK ((native_language = ANY (ARRAY['vi'::text, 'en'::text]))),
  CONSTRAINT "user_preferences_pkey" PRIMARY KEY (id),
  CONSTRAINT "user_preferences_theme_check" CHECK ((theme = ANY (ARRAY['system'::text, 'light'::text, 'dark'::text]))),
  CONSTRAINT "user_preferences_user_id_key" UNIQUE (user_id)
);

ALTER TABLE "public"."user_preferences"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."user_preferences" FROM "anon";

CREATE TABLE "public"."writing_answer_keys" (
  "exercise_id"      uuid  NOT NULL,
  "accepted_answers" jsonb NOT NULL,
  CONSTRAINT "writing_answer_keys_accepted_answers_check" CHECK ((jsonb_typeof(accepted_answers) = 'array'::text)),
  CONSTRAINT "writing_answer_keys_pkey" PRIMARY KEY (exercise_id)
);

ALTER TABLE "public"."writing_answer_keys"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."writing_exercises" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "slug"         text                     NOT NULL,
  "kind"         text                     NOT NULL,
  "prompt"       text                     NOT NULL,
  "hint"         text                     NOT NULL DEFAULT ''::text,
  "tokens"       jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "is_published" boolean                  NOT NULL DEFAULT false,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "writing_exercises_kind_check" CHECK ((kind = ANY (ARRAY['sentence'::text, 'fill_blank'::text, 'sentence_order'::text, 'paragraph'::text]))),
  CONSTRAINT "writing_exercises_pkey" PRIMARY KEY (id),
  CONSTRAINT "writing_exercises_slug_key" UNIQUE (slug),
  CONSTRAINT "writing_exercises_tokens_check" CHECK ((jsonb_typeof(tokens) = 'array'::text))
);

ALTER TABLE "public"."writing_exercises"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."writing_feedback" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "submission_id"   uuid                     NOT NULL,
  "rule_result"     text                     NOT NULL,
  "suggestions"     jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "grammar_status"  text                     NOT NULL,
  "grammar_matches" jsonb                    NOT NULL DEFAULT '[]'::jsonb,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "writing_feedback_grammar_matches_check" CHECK ((jsonb_typeof(grammar_matches) = 'array'::text)),
  CONSTRAINT "writing_feedback_grammar_status_check" CHECK ((grammar_status = ANY (ARRAY['not_requested'::text, 'available'::text, 'unavailable'::text]))),
  CONSTRAINT "writing_feedback_pkey" PRIMARY KEY (id),
  CONSTRAINT "writing_feedback_rule_result_check" CHECK ((rule_result = ANY (ARRAY['matched'::text, 'needs_revision'::text, 'self_review'::text]))),
  CONSTRAINT "writing_feedback_submission_id_key" UNIQUE (submission_id),
  CONSTRAINT "writing_feedback_suggestions_check" CHECK ((jsonb_typeof(suggestions) = 'array'::text))
);

ALTER TABLE "public"."writing_feedback"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."writing_submissions" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"     uuid                     NOT NULL,
  "lesson_id"   uuid,
  "prompt"      text                     NOT NULL,
  "body"        text                     NOT NULL,
  "feedback"    jsonb,
  "created_at"  timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"  timestamp with time zone NOT NULL DEFAULT now(),
  "exercise_id" uuid,
  "request_id"  uuid,
  CONSTRAINT "writing_submissions_body_check" CHECK ((length(body) <= 20000)),
  CONSTRAINT "writing_submissions_feedback_check" CHECK (((feedback IS NULL) OR (jsonb_typeof(feedback) = 'object'::text))),
  CONSTRAINT "writing_submissions_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."writing_submissions"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."writing_submissions" FROM "anon";

CREATE TABLE "public"."xp_events" (
  "id"          uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"     uuid                     NOT NULL,
  "source_type" text                     NOT NULL,
  "source_id"   uuid                     NOT NULL,
  "amount"      integer                  NOT NULL,
  "created_at"  timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "xp_events_amount_check" CHECK ((((amount >= '-10000'::integer) AND (amount <= 10000)) AND (amount <> 0))),
  CONSTRAINT "xp_events_pkey" PRIMARY KEY (id),
  CONSTRAINT "xp_events_source_type_check"
    CHECK ((source_type = ANY (ARRAY['lesson'::text, 'quiz'::text, 'review'::text, 'speaking'::text, 'writing'::text, 'adjustment'::text, 'quest'::text]))),
  CONSTRAINT "xp_events_user_id_source_type_source_id_key" UNIQUE (user_id, source_type, source_id)
);

ALTER TABLE "public"."xp_events"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."xp_events" FROM "anon";

ALTER SEQUENCE "public"."gamification_config_id_seq" OWNED BY "public"."gamification_config"."id";

CREATE OR REPLACE FUNCTION public.lesson_unlocked (
  target_lesson_id uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
      SELECT EXISTS (SELECT 1 FROM public.lessons current_lesson
      JOIN public.learning_units current_unit ON current_unit.id=current_lesson.unit_id
      JOIN public.courses course ON course.id=current_unit.course_id
      WHERE current_lesson.id=target_lesson_id AND current_lesson.is_published AND current_lesson.archived_at IS NULL
        AND current_unit.is_published AND current_unit.archived_at IS NULL
        AND course.is_published AND course.archived_at IS NULL AND (select auth.uid()) IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM public.lessons prior
          JOIN public.learning_units prior_unit ON prior_unit.id=prior.unit_id
          LEFT JOIN public.learning_progress progress ON progress.lesson_id=prior.id AND progress.user_id=(select auth.uid())
          WHERE prior_unit.course_id=course.id AND prior.is_published AND prior.archived_at IS NULL
            AND prior_unit.is_published AND prior_unit.archived_at IS NULL
            AND (prior_unit.position<current_unit.position OR (prior_unit.position=current_unit.position AND prior.position<current_lesson.position))
            AND (progress.status IS NULL OR progress.status NOT IN ('completed','mastered')))) $function$;

REVOKE ALL ON FUNCTION "public"."lesson_unlocked"(uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.provision_profile()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
BEGIN
  INSERT INTO public.profiles(id, display_name)
  VALUES (NEW.id, left(coalesce(nullif(trim(NEW.raw_user_meta_data->>'display_name'), ''), 'Learner'), 80))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END $function$;

REVOKE ALL ON FUNCTION "public"."provision_profile"() FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.touch_offline_content_version()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
        DECLARE parent_id uuid;
        BEGIN
          IF TG_TABLE_NAME = 'lesson_items' THEN
            parent_id := coalesce(NEW.lesson_id, OLD.lesson_id);
            UPDATE public.lessons SET updated_at=now() WHERE id=parent_id;
          ELSE
            parent_id := coalesce(NEW.question_id, OLD.question_id);
            UPDATE public.quiz_questions SET updated_at=now() WHERE id=parent_id;
          END IF;
          RETURN coalesce(NEW, OLD);
        END $function$;

REVOKE ALL ON FUNCTION "public"."touch_offline_content_version"() FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.touch_updated_at()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $function$;

REVOKE ALL ON FUNCTION "public"."touch_updated_at"() FROM PUBLIC, "anon", "authenticated";

ALTER TABLE "public"."admin_audit_logs"
  ADD CONSTRAINT "admin_audit_logs_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE "public"."admin_members"
  ADD CONSTRAINT "admin_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."badge_rules"
  ADD CONSTRAINT "badge_rules_badge_id_fkey" FOREIGN KEY (badge_id) REFERENCES public.badges(id) ON DELETE CASCADE;

ALTER TABLE "public"."learning_plan_tasks"
  ADD CONSTRAINT "plan_task_owner_fk" FOREIGN KEY (plan_id, user_id) REFERENCES public.learning_plans(id, user_id) ON DELETE CASCADE;

ALTER TABLE "public"."learning_units"
  ADD CONSTRAINT "learning_units_course_id_fkey" FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;

ALTER TABLE "public"."lesson_answer_attempts"
  ADD CONSTRAINT "lesson_answer_attempts_attempt_id_fkey" FOREIGN KEY (attempt_id) REFERENCES public.lesson_attempts(id) ON DELETE CASCADE;

ALTER TABLE "public"."lessons"
  ADD CONSTRAINT "lessons_course_id_fkey" FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;

ALTER TABLE "public"."learning_plan_tasks"
  ADD CONSTRAINT "learning_plan_tasks_lesson_id_fkey" FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE SET NULL;

ALTER TABLE "public"."learning_progress"
  ADD CONSTRAINT "learning_progress_lesson_id_fkey" FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE CASCADE;

ALTER TABLE "public"."lesson_attempts"
  ADD CONSTRAINT "lesson_attempts_lesson_id_fkey" FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE CASCADE;

ALTER TABLE "public"."lesson_items"
  ADD CONSTRAINT "lesson_items_lesson_id_fkey" FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE CASCADE;

ALTER TABLE "public"."lessons"
  ADD CONSTRAINT "lessons_unit_id_fkey" FOREIGN KEY (unit_id) REFERENCES public.learning_units(id) ON DELETE SET NULL;

ALTER TABLE "public"."profiles"
  ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."learning_plans"
  ADD CONSTRAINT "learning_plans_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."learning_progress"
  ADD CONSTRAINT "learning_progress_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."lesson_attempts"
  ADD CONSTRAINT "lesson_attempts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."quest_claims"
  ADD CONSTRAINT "quest_claims_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."quest_claims"
  ADD CONSTRAINT "quest_claims_quest_id_fkey" FOREIGN KEY (quest_id) REFERENCES public.quests(id) ON DELETE CASCADE;

ALTER TABLE "public"."quiz_attempts"
  ADD CONSTRAINT "quiz_attempts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."quiz_attempts"
  ADD CONSTRAINT "quiz_attempts_selected_option_id_question_id_fkey" FOREIGN KEY (selected_option_id, question_id) REFERENCES public.quiz_options(id, question_id) ON DELETE CASCADE;

ALTER TABLE "public"."quiz_questions"
  ADD CONSTRAINT "quiz_questions_lesson_id_fkey" FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE CASCADE;

ALTER TABLE "public"."lesson_answer_attempts"
  ADD CONSTRAINT "lesson_answer_attempts_question_id_fkey" FOREIGN KEY (question_id) REFERENCES public.quiz_questions(id) ON DELETE CASCADE;

ALTER TABLE "public"."quiz_answer_keys"
  ADD CONSTRAINT "quiz_answer_keys_question_id_fkey" FOREIGN KEY (question_id) REFERENCES public.quiz_questions(id) ON DELETE CASCADE;

ALTER TABLE "public"."quiz_attempts"
  ADD CONSTRAINT "quiz_attempts_question_id_fkey" FOREIGN KEY (question_id) REFERENCES public.quiz_questions(id) ON DELETE CASCADE;

ALTER TABLE "public"."quiz_options"
  ADD CONSTRAINT "quiz_options_question_id_fkey" FOREIGN KEY (question_id) REFERENCES public.quiz_questions(id) ON DELETE CASCADE;

ALTER TABLE "public"."real_english_quiz_attempts"
  ADD CONSTRAINT "real_english_quiz_attempts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."real_english_quiz_questions"
  ADD CONSTRAINT "real_english_quiz_questions_expression_id_fkey" FOREIGN KEY (expression_id) REFERENCES public.real_english_expressions(id) ON DELETE CASCADE;

ALTER TABLE "public"."real_english_quiz_attempts"
  ADD CONSTRAINT "real_english_quiz_attempts_question_id_fkey" FOREIGN KEY (question_id) REFERENCES public.real_english_quiz_questions(id) ON DELETE CASCADE;

ALTER TABLE "public"."review_history"
  ADD CONSTRAINT "review_history_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."reward_claims"
  ADD CONSTRAINT "reward_claims_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."reward_claims"
  ADD CONSTRAINT "reward_claims_reward_id_fkey" FOREIGN KEY (reward_id) REFERENCES public.reward_items(id) ON DELETE RESTRICT;

ALTER TABLE "public"."reward_notifications"
  ADD CONSTRAINT "reward_notifications_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."saved_expressions"
  ADD CONSTRAINT "saved_expressions_expression_id_fkey" FOREIGN KEY (expression_id) REFERENCES public.real_english_expressions(id) ON DELETE CASCADE;

ALTER TABLE "public"."saved_expressions"
  ADD CONSTRAINT "saved_expressions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."saved_vocabulary"
  ADD CONSTRAINT "saved_vocabulary_entry_id_fkey" FOREIGN KEY (entry_id) REFERENCES public.dictionary_entries(id) ON DELETE CASCADE;

ALTER TABLE "public"."review_history"
  ADD CONSTRAINT "review_history_saved_vocabulary_id_user_id_fkey" FOREIGN KEY (saved_vocabulary_id, user_id) REFERENCES public.saved_vocabulary(id, user_id) ON DELETE CASCADE;

ALTER TABLE "public"."saved_vocabulary"
  ADD CONSTRAINT "saved_vocabulary_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."speaking_attempts"
  ADD CONSTRAINT "speaking_attempts_lesson_id_fkey" FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE SET NULL;

ALTER TABLE "public"."speaking_attempts"
  ADD CONSTRAINT "speaking_attempts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."user_badges"
  ADD CONSTRAINT "user_badges_badge_id_fkey" FOREIGN KEY (badge_id) REFERENCES public.badges(id) ON DELETE CASCADE;

ALTER TABLE "public"."user_badges"
  ADD CONSTRAINT "user_badges_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."user_levels"
  ADD CONSTRAINT "user_levels_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."user_preferences"
  ADD CONSTRAINT "user_preferences_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."writing_answer_keys"
  ADD CONSTRAINT "writing_answer_keys_exercise_id_fkey" FOREIGN KEY (exercise_id) REFERENCES public.writing_exercises(id) ON DELETE CASCADE;

ALTER TABLE "public"."writing_submissions"
  ADD CONSTRAINT "writing_submissions_exercise_id_fkey" FOREIGN KEY (exercise_id) REFERENCES public.writing_exercises(id) ON DELETE SET NULL;

ALTER TABLE "public"."writing_submissions"
  ADD CONSTRAINT "writing_submissions_lesson_id_fkey" FOREIGN KEY (lesson_id) REFERENCES public.lessons(id) ON DELETE SET NULL;

ALTER TABLE "public"."writing_feedback"
  ADD CONSTRAINT "writing_feedback_submission_id_fkey" FOREIGN KEY (submission_id) REFERENCES public.writing_submissions(id) ON DELETE CASCADE;

ALTER TABLE "public"."writing_submissions"
  ADD CONSTRAINT "writing_submissions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."xp_events"
  ADD CONSTRAINT "xp_events_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

CREATE INDEX admin_audit_logs_recent_idx ON public.admin_audit_logs USING btree (created_at DESC);

CREATE INDEX admin_audit_logs_record_idx ON public.admin_audit_logs USING btree (resource, record_id, created_at DESC);

CREATE INDEX badges_published_idx ON public.badges USING btree (is_published);

CREATE INDEX dictionary_entries_published_idx ON public.dictionary_entries USING btree (is_published);

CREATE INDEX ix_courses_published_level ON public.courses USING btree (is_published, level);

CREATE INDEX ix_dictionary_english_prefix ON public.dictionary_entries USING btree (normalized_term text_pattern_ops)
  WHERE (LANGUAGE = 'en'::text);

CREATE INDEX ix_dictionary_entries_lookup ON public.dictionary_entries USING btree (LANGUAGE, normalized_term);

CREATE INDEX ix_learning_plans_user_status ON public.learning_plans USING btree (user_id, status);

CREATE INDEX ix_learning_progress_lesson ON public.learning_progress USING btree (lesson_id);

CREATE INDEX ix_learning_progress_user_status ON public.learning_progress USING btree (user_id, status);

CREATE INDEX ix_lesson_attempts_user_lesson ON public.lesson_attempts USING btree (user_id, lesson_id, created_at);

CREATE INDEX ix_lessons_course_position ON public.lessons USING btree (course_id, "position");

CREATE INDEX ix_lessons_unit_position ON public.lessons USING btree (unit_id, "position");

CREATE INDEX ix_quest_claims_user_recent ON public.quest_claims USING btree (user_id, period_start);

CREATE INDEX ix_quests_active_period ON public.quests USING btree (is_active, period);

CREATE INDEX ix_quiz_attempts_question ON public.quiz_attempts USING btree (question_id);

CREATE INDEX ix_quiz_attempts_user_recent ON public.quiz_attempts USING btree (user_id, created_at DESC);

CREATE INDEX ix_review_history_saved ON public.review_history USING btree (saved_vocabulary_id);

CREATE INDEX ix_review_history_user_recent ON public.review_history USING btree (user_id, reviewed_at DESC);

CREATE INDEX ix_reward_claims_user_recent ON public.reward_claims USING btree (user_id, claimed_at DESC);

CREATE INDEX ix_reward_notifications_user_unread ON public.reward_notifications USING btree (user_id, read_at, created_at);

CREATE INDEX ix_saved_vocabulary_due ON public.saved_vocabulary USING btree (user_id, next_review_at);

CREATE INDEX ix_saved_vocabulary_entry ON public.saved_vocabulary USING btree (entry_id);

CREATE INDEX ix_speaking_attempts_lesson ON public.speaking_attempts USING btree (lesson_id);

CREATE INDEX ix_speaking_attempts_user_recent ON public.speaking_attempts USING btree (user_id, created_at DESC);

CREATE INDEX ix_user_badges_user_recent ON public.user_badges USING btree (user_id, awarded_at DESC);

CREATE INDEX ix_writing_submissions_lesson ON public.writing_submissions USING btree (lesson_id);

CREATE INDEX ix_writing_submissions_user_recent ON public.writing_submissions USING btree (user_id, created_at DESC);

CREATE INDEX ix_xp_events_user_recent ON public.xp_events USING btree (user_id, created_at DESC);

CREATE INDEX learning_units_published_idx ON public.learning_units USING btree (is_published);

CREATE INDEX lesson_items_published_idx ON public.lesson_items USING btree (is_published);

CREATE INDEX plan_tasks_plan_idx ON public.learning_plan_tasks USING btree (plan_id);

CREATE INDEX plan_tasks_user_date_idx ON public.learning_plan_tasks USING btree (user_id, scheduled_on, "position");

CREATE UNIQUE INDEX profiles_username_ci_unique ON public.profiles USING btree (lower(username))
  WHERE (username IS NOT NULL);

CREATE INDEX quiz_questions_published_idx ON public.quiz_questions USING btree (is_published);

CREATE INDEX real_english_attempts_user_recent_idx ON public.real_english_quiz_attempts USING btree (user_id, created_at DESC);

CREATE INDEX real_english_kind_idx ON public.real_english_expressions USING btree (kind, expression)
  WHERE is_published;

CREATE INDEX real_english_search_idx ON public.real_english_expressions USING gin (to_tsvector('simple'::regconfig, ((expression || ' '::text) || meaning_vi)))
  WHERE is_published;

CREATE INDEX saved_expressions_user_recent_idx ON public.saved_expressions USING btree (user_id, created_at DESC);

CREATE UNIQUE INDEX ux_learning_plans_one_active ON public.learning_plans USING btree (user_id)
  WHERE (status = 'active'::text);

CREATE UNIQUE INDEX ux_quiz_one_correct_option ON public.quiz_options USING btree (question_id)
  WHERE is_correct;

CREATE INDEX writing_exercises_published_kind_idx ON public.writing_exercises USING btree (kind)
  WHERE is_published;

CREATE UNIQUE INDEX writing_submissions_user_request_idx ON public.writing_submissions USING btree (user_id, request_id)
  WHERE (request_id IS NOT NULL);

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.provision_profile();

CREATE TRIGGER trg_badges_updated_at
  BEFORE UPDATE ON public.badges
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_courses_updated_at
  BEFORE UPDATE ON public.courses
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_dictionary_entries_updated_at
  BEFORE UPDATE ON public.dictionary_entries
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_learning_plans_updated_at
  BEFORE UPDATE ON public.learning_plans
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_learning_progress_updated_at
  BEFORE UPDATE ON public.learning_progress
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER offline_version_items
  AFTER INSERT OR DELETE OR UPDATE ON public.lesson_items
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_offline_content_version();

CREATE TRIGGER trg_lessons_updated_at
  BEFORE UPDATE ON public.lessons
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER offline_version_keys
  AFTER INSERT OR DELETE OR UPDATE ON public.quiz_answer_keys
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_offline_content_version();

CREATE TRIGGER offline_version_options
  AFTER INSERT OR DELETE OR UPDATE ON public.quiz_options
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_offline_content_version();

CREATE TRIGGER trg_quiz_options_updated_at
  BEFORE UPDATE ON public.quiz_options
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_quiz_questions_updated_at
  BEFORE UPDATE ON public.quiz_questions
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_reward_items_updated_at
  BEFORE UPDATE ON public.reward_items
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_saved_vocabulary_updated_at
  BEFORE UPDATE ON public.saved_vocabulary
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_speaking_attempts_updated_at
  BEFORE UPDATE ON public.speaking_attempts
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_user_preferences_updated_at
  BEFORE UPDATE ON public.user_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_writing_submissions_updated_at
  BEFORE UPDATE ON public.writing_submissions
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_updated_at();

CREATE POLICY "badges_read" ON "public"."badges"
  FOR SELECT
  TO "authenticated"
  USING ((is_published AND (archived_at IS NULL)));

CREATE POLICY "courses_read" ON "public"."courses"
  FOR SELECT
  TO "authenticated"
  USING ((is_published AND (archived_at IS NULL)));

CREATE POLICY "dictionary_read" ON "public"."dictionary_entries"
  FOR SELECT
  TO "authenticated"
  USING ((is_published AND (archived_at IS NULL)));

CREATE POLICY "plan_tasks_own_read" ON "public"."learning_plan_tasks"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "learning_plans_own_select" ON "public"."learning_plans"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "learning_progress_own_select" ON "public"."learning_progress"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "units_read" ON "public"."learning_units"
  FOR SELECT
  TO "authenticated"
  USING ((is_published AND (archived_at IS NULL) AND (EXISTS ( SELECT 1
   FROM public.courses c
  WHERE ((c.id = learning_units.course_id) AND c.is_published AND (c.archived_at IS NULL))))));

CREATE POLICY "answers_own_read" ON "public"."lesson_answer_attempts"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.lesson_attempts a
  WHERE ((a.id = lesson_answer_attempts.attempt_id) AND (a.user_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "attempts_own_read" ON "public"."lesson_attempts"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "items_read" ON "public"."lesson_items"
  FOR SELECT
  TO "authenticated"
  USING ((is_published AND (archived_at IS NULL) AND ( SELECT public.lesson_unlocked(lesson_items.lesson_id) AS lesson_unlocked)));

CREATE POLICY "lessons_read" ON "public"."lessons"
  FOR SELECT
  TO "authenticated"
  USING ((is_published AND (archived_at IS NULL) AND (EXISTS ( SELECT 1
   FROM public.courses c
  WHERE ((c.id = lessons.course_id) AND c.is_published AND (c.archived_at IS NULL))))));

CREATE POLICY "profiles_own_select" ON "public"."profiles"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = id));

CREATE POLICY "profiles_own_update" ON "public"."profiles"
  FOR UPDATE
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = id))
  WITH CHECK ((( SELECT auth.uid() AS uid) = id));

CREATE POLICY "quest_claims_own_read" ON "public"."quest_claims"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "quests_read" ON "public"."quests"
  FOR SELECT
  TO "authenticated"
  USING (is_active);

CREATE POLICY "quiz_attempts_own_select" ON "public"."quiz_attempts"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "questions_read" ON "public"."quiz_questions"
  FOR SELECT
  TO "authenticated"
  USING ((is_published AND (archived_at IS NULL) AND ( SELECT public.lesson_unlocked(quiz_questions.lesson_id) AS lesson_unlocked)));

CREATE POLICY "real_english_published_read" ON "public"."real_english_expressions"
  FOR SELECT
  TO "authenticated"
  USING ((is_published AND (archived_at IS NULL)));

CREATE POLICY "real_english_attempts_own_read" ON "public"."real_english_quiz_attempts"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "review_history_own_select" ON "public"."review_history"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "reward_claims_own_select" ON "public"."reward_claims"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "rewards_read" ON "public"."reward_items"
  FOR SELECT
  TO "authenticated"
  USING (is_active);

CREATE POLICY "reward_notifications_own_read" ON "public"."reward_notifications"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "saved_expressions_own_read" ON "public"."saved_expressions"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "saved_delete" ON "public"."saved_vocabulary"
  FOR DELETE
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "saved_insert" ON "public"."saved_vocabulary"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "saved_update" ON "public"."saved_vocabulary"
  FOR UPDATE
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id))
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "saved_vocabulary_own_select" ON "public"."saved_vocabulary"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "speaking_attempts_own_select" ON "public"."speaking_attempts"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "user_badges_own_select" ON "public"."user_badges"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "user_levels_own_read" ON "public"."user_levels"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "preferences_delete" ON "public"."user_preferences"
  FOR DELETE
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "preferences_insert" ON "public"."user_preferences"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "preferences_update" ON "public"."user_preferences"
  FOR UPDATE
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id))
  WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "user_preferences_own_select" ON "public"."user_preferences"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "writing_exercises_read" ON "public"."writing_exercises"
  FOR SELECT
  TO "authenticated"
  USING (is_published);

CREATE POLICY "writing_feedback_own_read" ON "public"."writing_feedback"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.writing_submissions s
  WHERE ((s.id = writing_feedback.submission_id) AND (s.user_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "writing_submissions_own_select" ON "public"."writing_submissions"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "xp_events_own_select" ON "public"."xp_events"
  FOR SELECT
  TO "authenticated"
  USING ((( SELECT auth.uid() AS uid) = user_id));

CREATE POLICY "englify_avatar_delete_own" ON "storage"."objects"
  FOR DELETE
  TO "authenticated"
  USING (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

CREATE POLICY "englify_avatar_insert_own" ON "storage"."objects"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text) AND (storage.extension(name) = 'jpg'::text)));

CREATE POLICY "englify_avatar_read_own" ON "storage"."objects"
  FOR SELECT
  TO "authenticated"
  USING (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (( SELECT auth.uid() AS uid))::text)));

GRANT EXECUTE ON FUNCTION "public"."lesson_unlocked"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."lesson_unlocked"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."lesson_unlocked"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."lesson_unlocked"(uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."provision_profile"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."provision_profile"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."provision_profile"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."touch_offline_content_version"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."touch_offline_content_version"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."touch_offline_content_version"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."touch_updated_at"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."touch_updated_at"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."touch_updated_at"() TO "service_role";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."gamification_config_id_seq" TO "anon", "authenticated";

REVOKE ALL ON SEQUENCE "public"."gamification_config_id_seq" FROM "postgres";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."gamification_config_id_seq" TO "postgres";

GRANT SELECT, UPDATE, USAGE ON SEQUENCE "public"."gamification_config_id_seq" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."admin_audit_logs" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."admin_audit_logs" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."admin_audit_logs" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."admin_audit_logs" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."admin_members" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."admin_members" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."admin_members" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."admin_members" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."alembic_version" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."alembic_version" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."alembic_version" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."alembic_version" TO "service_role";

REVOKE ALL ON TABLE "public"."badge_rules" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."badge_rules" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."badge_rules" TO "service_role";

REVOKE ALL ON TABLE "public"."badges" FROM "authenticated";

GRANT SELECT ON TABLE "public"."badges" TO "authenticated";

REVOKE ALL ON TABLE "public"."badges" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."badges" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."badges" TO "service_role";

REVOKE ALL ON TABLE "public"."courses" FROM "authenticated";

GRANT SELECT ON TABLE "public"."courses" TO "authenticated";

REVOKE ALL ON TABLE "public"."courses" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."courses" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."courses" TO "service_role";

REVOKE ALL ON TABLE "public"."dictionary_entries" FROM "authenticated";

GRANT SELECT ON TABLE "public"."dictionary_entries" TO "authenticated";

REVOKE ALL ON TABLE "public"."dictionary_entries" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."dictionary_entries" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."dictionary_entries" TO "service_role";

REVOKE ALL ON TABLE "public"."gamification_config" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."gamification_config" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."gamification_config" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."learning_plan_tasks" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."learning_plan_tasks" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."learning_plan_tasks" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."learning_plan_tasks" TO "service_role";

REVOKE ALL ON TABLE "public"."learning_plans" FROM "authenticated";

GRANT SELECT ON TABLE "public"."learning_plans" TO "authenticated";

REVOKE ALL ON TABLE "public"."learning_plans" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."learning_plans" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."learning_plans" TO "service_role";

REVOKE ALL ON TABLE "public"."learning_progress" FROM "authenticated";

GRANT SELECT ON TABLE "public"."learning_progress" TO "authenticated";

REVOKE ALL ON TABLE "public"."learning_progress" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."learning_progress" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."learning_progress" TO "service_role";

REVOKE ALL ON TABLE "public"."learning_units" FROM "authenticated";

GRANT SELECT ON TABLE "public"."learning_units" TO "authenticated";

REVOKE ALL ON TABLE "public"."learning_units" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."learning_units" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."learning_units" TO "service_role";

REVOKE ALL ON TABLE "public"."lesson_answer_attempts" FROM "authenticated";

GRANT SELECT ON TABLE "public"."lesson_answer_attempts" TO "authenticated";

REVOKE ALL ON TABLE "public"."lesson_answer_attempts" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lesson_answer_attempts" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lesson_answer_attempts" TO "service_role";

REVOKE ALL ON TABLE "public"."lesson_attempts" FROM "authenticated";

GRANT SELECT ON TABLE "public"."lesson_attempts" TO "authenticated";

REVOKE ALL ON TABLE "public"."lesson_attempts" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lesson_attempts" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lesson_attempts" TO "service_role";

REVOKE ALL ON TABLE "public"."lesson_items" FROM "authenticated";

GRANT SELECT ON TABLE "public"."lesson_items" TO "authenticated";

REVOKE ALL ON TABLE "public"."lesson_items" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lesson_items" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lesson_items" TO "service_role";

REVOKE ALL ON TABLE "public"."lessons" FROM "authenticated";

GRANT SELECT ON TABLE "public"."lessons" TO "authenticated";

REVOKE ALL ON TABLE "public"."lessons" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lessons" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."lessons" TO "service_role";

REVOKE ALL ON TABLE "public"."profiles" FROM "authenticated";

REVOKE ALL ("avatar_url") ON TABLE "public"."profiles" FROM "authenticated";

GRANT UPDATE ("avatar_url") ON TABLE "public"."profiles" TO "authenticated";

REVOKE ALL ("bio") ON TABLE "public"."profiles" FROM "authenticated";

GRANT UPDATE ("bio") ON TABLE "public"."profiles" TO "authenticated";

REVOKE ALL ("display_name") ON TABLE "public"."profiles" FROM "authenticated";

GRANT UPDATE ("display_name") ON TABLE "public"."profiles" TO "authenticated";

REVOKE ALL ("username") ON TABLE "public"."profiles" FROM "authenticated";

GRANT UPDATE ("username") ON TABLE "public"."profiles" TO "authenticated";

GRANT SELECT ON TABLE "public"."profiles" TO "authenticated";

REVOKE ALL ON TABLE "public"."profiles" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "service_role";

REVOKE ALL ON TABLE "public"."quest_claims" FROM "authenticated";

GRANT SELECT ON TABLE "public"."quest_claims" TO "authenticated";

REVOKE ALL ON TABLE "public"."quest_claims" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quest_claims" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quest_claims" TO "service_role";

REVOKE ALL ON TABLE "public"."quests" FROM "authenticated";

GRANT SELECT ON TABLE "public"."quests" TO "authenticated";

REVOKE ALL ON TABLE "public"."quests" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quests" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quests" TO "service_role";

REVOKE ALL ON TABLE "public"."quiz_answer_keys" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz_answer_keys" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz_answer_keys" TO "service_role";

REVOKE ALL ON TABLE "public"."quiz_attempts" FROM "authenticated";

GRANT SELECT ON TABLE "public"."quiz_attempts" TO "authenticated";

REVOKE ALL ON TABLE "public"."quiz_attempts" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz_attempts" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz_attempts" TO "service_role";

REVOKE ALL ON TABLE "public"."quiz_options" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz_options" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz_options" TO "service_role";

REVOKE ALL ON TABLE "public"."quiz_questions" FROM "authenticated";

GRANT SELECT ON TABLE "public"."quiz_questions" TO "authenticated";

REVOKE ALL ON TABLE "public"."quiz_questions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz_questions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."quiz_questions" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."real_english_expressions" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."real_english_expressions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."real_english_expressions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."real_english_expressions" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."real_english_quiz_attempts" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."real_english_quiz_attempts" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."real_english_quiz_attempts" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."real_english_quiz_attempts" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."real_english_quiz_questions" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."real_english_quiz_questions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."real_english_quiz_questions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."real_english_quiz_questions" TO "service_role";

REVOKE ALL ON TABLE "public"."review_history" FROM "authenticated";

GRANT SELECT ON TABLE "public"."review_history" TO "authenticated";

REVOKE ALL ON TABLE "public"."review_history" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."review_history" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."review_history" TO "service_role";

REVOKE ALL ON TABLE "public"."reward_claims" FROM "authenticated";

GRANT SELECT ON TABLE "public"."reward_claims" TO "authenticated";

REVOKE ALL ON TABLE "public"."reward_claims" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reward_claims" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reward_claims" TO "service_role";

REVOKE ALL ON TABLE "public"."reward_items" FROM "authenticated";

GRANT SELECT ON TABLE "public"."reward_items" TO "authenticated";

REVOKE ALL ON TABLE "public"."reward_items" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reward_items" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reward_items" TO "service_role";

REVOKE ALL ON TABLE "public"."reward_notifications" FROM "authenticated";

GRANT SELECT ON TABLE "public"."reward_notifications" TO "authenticated";

REVOKE ALL ON TABLE "public"."reward_notifications" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reward_notifications" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reward_notifications" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."saved_expressions" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."saved_expressions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."saved_expressions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."saved_expressions" TO "service_role";

REVOKE ALL ON TABLE "public"."saved_vocabulary" FROM "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."saved_vocabulary" TO "authenticated";

REVOKE ALL ON TABLE "public"."saved_vocabulary" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."saved_vocabulary" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."saved_vocabulary" TO "service_role";

REVOKE ALL ON TABLE "public"."speaking_attempts" FROM "authenticated";

GRANT SELECT ON TABLE "public"."speaking_attempts" TO "authenticated";

REVOKE ALL ON TABLE "public"."speaking_attempts" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."speaking_attempts" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."speaking_attempts" TO "service_role";

REVOKE ALL ON TABLE "public"."user_badges" FROM "authenticated";

GRANT SELECT ON TABLE "public"."user_badges" TO "authenticated";

REVOKE ALL ON TABLE "public"."user_badges" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_badges" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_badges" TO "service_role";

REVOKE ALL ON TABLE "public"."user_levels" FROM "authenticated";

GRANT SELECT ON TABLE "public"."user_levels" TO "authenticated";

REVOKE ALL ON TABLE "public"."user_levels" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_levels" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_levels" TO "service_role";

REVOKE ALL ON TABLE "public"."user_preferences" FROM "authenticated";

REVOKE ALL ("current_cefr") ON TABLE "public"."user_preferences" FROM "authenticated";

GRANT UPDATE ("current_cefr") ON TABLE "public"."user_preferences" TO "authenticated";

REVOKE ALL ("interface_language") ON TABLE "public"."user_preferences" FROM "authenticated";

GRANT UPDATE ("interface_language") ON TABLE "public"."user_preferences" TO "authenticated";

REVOKE ALL ("preferred_accent") ON TABLE "public"."user_preferences" FROM "authenticated";

GRANT UPDATE ("preferred_accent") ON TABLE "public"."user_preferences" TO "authenticated";

GRANT DELETE, INSERT, SELECT, UPDATE ON TABLE "public"."user_preferences" TO "authenticated";

REVOKE ALL ON TABLE "public"."user_preferences" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_preferences" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."user_preferences" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_answer_keys" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."writing_answer_keys" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_answer_keys" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_answer_keys" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_exercises" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."writing_exercises" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_exercises" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_exercises" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_feedback" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."writing_feedback" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_feedback" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_feedback" TO "service_role";

REVOKE ALL ON TABLE "public"."writing_submissions" FROM "authenticated";

GRANT SELECT ON TABLE "public"."writing_submissions" TO "authenticated";

REVOKE ALL ON TABLE "public"."writing_submissions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_submissions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."writing_submissions" TO "service_role";

REVOKE ALL ON TABLE "public"."xp_events" FROM "authenticated";

GRANT SELECT ON TABLE "public"."xp_events" TO "authenticated";

REVOKE ALL ON TABLE "public"."xp_events" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."xp_events" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."xp_events" TO "service_role";
