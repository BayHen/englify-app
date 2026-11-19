"""Build an isolated schema clone to verify fresh Arena install and additive upgrade."""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from uuid import uuid4

import psycopg
from psycopg import sql
from psycopg.conninfo import make_conninfo

TIME_ATTACK = "--time-attack" in sys.argv
RANKED = "--ranked" in sys.argv
ARENA_V2 = TIME_ATTACK or RANKED

NPX = "npx.cmd" if os.name == "nt" else "npx"

status = json.loads(
    subprocess.run(
        [NPX, "--no-install", "supabase", "status", "--output", "json"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
)
url = status["DB_URL"]
if "@127.0.0.1:54322/" not in url:
    raise RuntimeError("Refusing to clone a non-local database")
name = "arena_upgrade_check_" + uuid4().hex[:12]
dump = subprocess.run(
    [
        "docker",
        "exec",
        "supabase_db_englify-app",
        "pg_dump",
        "-U",
        "postgres",
        "-d",
        "postgres",
        "--schema-only",
        "--no-owner",
        "--schema=public",
        "--schema=auth",
        "--schema=storage",
        "--schema=extensions",
    ],
    capture_output=True,
    text=True,
    encoding="utf-8",
    check=True,
).stdout
with psycopg.connect(url, autocommit=True) as admin:
    admin.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
    try:
        with psycopg.connect(make_conninfo(url, dbname=name), autocommit=True) as c:
            c.execute(
                'DROP SCHEMA public CASCADE; CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions; CREATE EXTENSION pg_trgm WITH SCHEMA extensions; CREATE EXTENSION unaccent WITH SCHEMA extensions; CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions'
            )
            dump = re.sub(r"ALTER DEFAULT PRIVILEGES.*?;", "", dump, flags=re.DOTALL)
            c.execute(
                "\n".join(
                    line.replace(
                        "CREATE SCHEMA extensions;",
                        "CREATE SCHEMA IF NOT EXISTS extensions;",
                    )
                    for line in dump.splitlines()
                    if not line.startswith("\\")
                )
            )
            if RANKED:
                for (signature,) in c.execute(
                    "SELECT oid::regprocedure::text FROM pg_proc WHERE pronamespace='public'::regnamespace AND (proname LIKE 'englify_ranked_%' OR proname LIKE 'englify_admin_%arena%' OR proname LIKE 'englify_admin_%ranked%' OR proname='englify_admin_set_season_reward' OR proname='englify_arena_tier')"
                ).fetchall():
                    c.execute("DROP FUNCTION " + signature + " CASCADE")
                for table in [
                    "arena_season_reward_rules",
                    "arena_ranked_security_events",
                    "arena_season_rewards",
                    "arena_season_standings",
                    "arena_rating_events",
                    "arena_ranked_answers",
                    "arena_ranked_matches",
                    "arena_player_ratings",
                    "arena_seasons",
                    "arena_ranked_rulesets",
                ]:
                    c.execute(
                        sql.SQL("DROP TABLE IF EXISTS public.{} CASCADE").format(
                            sql.Identifier(table)
                        )
                    )
                c.execute(
                    "ALTER TABLE public.arena_sessions DROP CONSTRAINT arena_sessions_mode_check; "
                    "ALTER TABLE public.arena_sessions ADD CONSTRAINT arena_sessions_mode_check CHECK(mode IN ('practice','time_attack'))"
                )
                migration = Path(
                    "supabase/migrations/20261118040000_quiz_arena_ranked.sql"
                ).read_text(encoding="utf-8") + "\n" + Path(
                    "supabase/migrations/20261118040100_quiz_arena_ranked_admin_config.sql"
                ).read_text(encoding="utf-8") + "\n" + Path(
                    "supabase/migrations/20261118040200_quiz_arena_ranked_security_limits.sql"
                ).read_text(encoding="utf-8")
            elif TIME_ATTACK:
                c.execute("DROP TRIGGER IF EXISTS quiz_ingest_practice ON public.arena_sessions")
                for (signature,) in c.execute(
                    "SELECT oid::regprocedure::text FROM pg_proc WHERE pronamespace='public'::regnamespace AND (proname LIKE 'englify_time_attack_%' OR proname='englify_arena_grade')"
                ).fetchall():
                    c.execute("DROP FUNCTION " + signature + " CASCADE")
                for table in [
                    "arena_time_attack_answers",
                    "arena_time_attack_sessions",
                    "arena_time_attack_rules",
                ]:
                    c.execute(
                        sql.SQL("DROP TABLE IF EXISTS public.{} CASCADE").format(
                            sql.Identifier(table)
                        )
                    )
                c.execute(
                    # The clone is dumped from the latest schema, so later Ranked FKs may
                    # reference this pre-Time-Attack key. CASCADE removes only those
                    # future dependencies inside the disposable database.
                    "ALTER TABLE public.arena_sessions DROP COLUMN mode CASCADE; ALTER TABLE public.arena_sessions DROP CONSTRAINT arena_sessions_id_user_key CASCADE"
                )
                prior = Path(
                    "supabase/migrations/20261118020000_quiz_arena_practice.sql"
                ).read_text(encoding="utf-8")
                for part in prior.split("CREATE FUNCTION ")[1:]:
                    c.execute(
                        "CREATE OR REPLACE FUNCTION " + part.split("$$;", 1)[0] + "$$;"
                    )
                migration = Path(
                    "supabase/migrations/20261118030000_quiz_arena_time_attack.sql"
                ).read_text(encoding="utf-8")
            else:
                for (signature,) in c.execute(
                    "SELECT oid::regprocedure::text FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname LIKE 'englify_arena_%'"
                ).fetchall():
                    c.execute("DROP FUNCTION " + signature + " CASCADE")
                for table in [
                    "arena_session_questions",
                    "arena_reward_claims",
                    "arena_sessions",
                    "arena_answer_keys",
                    "arena_questions",
                ]:
                    c.execute(
                        sql.SQL("DROP TABLE IF EXISTS public.{} CASCADE").format(
                            sql.Identifier(table)
                        )
                    )
                c.execute(
                    "ALTER TABLE public.xp_events DROP CONSTRAINT xp_events_source_type_check; ALTER TABLE public.xp_events ADD CONSTRAINT xp_events_source_type_check CHECK(source_type IN ('lesson','quiz','review','speaking','writing','adjustment','quest'))"
                )
                migration = Path(
                    "supabase/migrations/20261118020000_quiz_arena_practice.sql"
                ).read_text(encoding="utf-8")
            with c.transaction():
                c.execute(migration)
                assert (
                    c.execute("SELECT count(*) FROM public.arena_sessions").fetchone()[
                        0
                    ]
                    == 0
                )
                raise psycopg.Rollback()
            print("PASS: Arena migration on empty pre-Arena application schema")
            for seed in ["development.sql", "gamification_development.sql"]:
                c.execute(Path("supabase/seeds", seed).read_text(encoding="utf-8"))
            user = "a2999999-9999-4999-8999-999999999999"
            c.execute("INSERT INTO auth.users(id) VALUES(%s)", (user,))
            c.execute("SELECT set_config('request.jwt.claim.sub',%s,false)", (user,))
            lesson = c.execute(
                "SELECT l.id FROM public.lessons l JOIN public.learning_units u ON u.id=l.unit_id JOIN public.courses course ON course.id=u.course_id WHERE l.is_published AND u.is_published AND course.is_published ORDER BY course.created_at,u.position,l.position LIMIT 1"
            ).fetchone()[0]
            questions = c.execute(
                "SELECT q.id,q.kind,k.answer FROM public.quiz_questions q LEFT JOIN public.quiz_answer_keys k ON k.question_id=q.id WHERE q.lesson_id=%s AND q.is_published",
                (lesson,),
            ).fetchall()
            answers = {}
            for question, kind, key in questions:
                if kind == "multiple_choice":
                    answers[str(question)] = str(
                        c.execute(
                            "SELECT id FROM public.quiz_options WHERE question_id=%s AND is_correct",
                            (question,),
                        ).fetchone()[0]
                    )
                else:
                    answers[str(question)] = key if kind == "matching" else key[0]
            c.execute(
                "SELECT public.englify_submit_lesson(%s,%s,%s::jsonb)",
                (lesson, uuid4(), json.dumps(answers)),
            )
            c.execute(
                "INSERT INTO public.quiz_attempts(user_id,question_id,selected_option_id,is_correct) "
                "SELECT %s,q.id,o.id,true FROM public.quiz_questions q JOIN public.quiz_options o ON o.question_id=q.id "
                "WHERE q.lesson_id=%s AND o.is_correct LIMIT 1",
                (user, lesson),
            )
            if ARENA_V2:
                # Latest-schema clones include the additive V2.5 topic FK even
                # while this harness rewinds only the Arena mode under test.
                # Seed the canonical metadata dependency without touching user data.
                if c.execute("SELECT to_regclass('public.arena_topics')").fetchone()[0]:
                    c.execute(
                        "INSERT INTO public.arena_topics(slug,title) SELECT value,initcap(replace(value,'_',' ')) FROM unnest(ARRAY['grammar','vocabulary','reading','everyday','business','travel','sentence_structure','phrasal_verbs','idioms']) value ON CONFLICT DO NOTHING"
                    )
                c.execute(
                    Path("supabase/seeds/quiz_arena_development.sql").read_text(
                        encoding="utf-8"
                    )
                )
                practice = c.execute(
                    "SELECT public.englify_arena_start(%s,'A1',NULL,NULL,5,NULL)",
                    (uuid4(),),
                ).fetchone()[0]
                practice_answers = c.execute(
                    "SELECT jsonb_object_agg(question_id::text,CASE WHEN question->>'kind' IN ('fill_blank','grammar_correction') THEN answer->0 ELSE answer END) FROM public.arena_session_questions WHERE session_id=%s",
                    (practice["id"],),
                ).fetchone()[0]
                c.execute(
                    "SELECT public.englify_arena_submit(%s,%s::jsonb)",
                    (practice["id"], json.dumps(practice_answers)),
                )
            tables = [
                "courses",
                "learning_units",
                "lessons",
                "quiz_attempts",
                "quiz_questions",
                "quiz_options",
                "quiz_answer_keys",
                "lesson_attempts",
                "lesson_answer_attempts",
                "learning_progress",
                "xp_events",
                "user_levels",
            ]

            if ARENA_V2:
                tables += [
                    "arena_questions",
                    "arena_answer_keys",
                    "arena_sessions",
                    "arena_session_questions",
                    "arena_reward_claims",
                ]
            if RANKED:
                tables += [
                    "arena_time_attack_rules",
                    "arena_time_attack_sessions",
                    "arena_time_attack_answers",
                ]

            def snapshot():
                return {
                    t: c.execute(
                        sql.SQL(
                            "SELECT md5(coalesce(jsonb_agg(to_jsonb(t)-'mode' ORDER BY (to_jsonb(t)-'mode')::text)::text,'[]')) FROM public.{} t"
                        ).format(sql.Identifier(t))
                    ).fetchone()[0]
                    for t in tables
                }

            before = snapshot()
            c.execute("SELECT set_config('request.jwt.claim.sub','',false)")
            c.execute(migration)
            c.execute("SELECT set_config('request.jwt.claim.sub',%s,false)", (user,))
            c.execute(
                Path("supabase/seeds/quiz_arena_development.sql").read_text(
                    encoding="utf-8"
                )
            )
            assert snapshot() == before
            assert (
                c.execute(
                    "SELECT count(*) FROM public.lesson_attempts WHERE user_id=%s",
                    (user,),
                ).fetchone()[0]
                == 1
            )
            print(
                "PASS: seeded Journey questions, answer keys, completion, attempt history and XP unchanged by upgrade"
            )
            c.execute("SET row_security=on")
            c.execute(
                Path("supabase/tests/quiz_arena_practice_smoke.sql").read_text(
                    encoding="utf-8"
                )
            )
            print("PASS: Arena SQL regression on isolated upgraded database")
            if TIME_ATTACK:
                c.execute(
                    Path("supabase/tests/quiz_arena_time_attack_smoke.sql").read_text(
                        encoding="utf-8"
                    )
                )
                print(
                    "PASS: Time Attack migration preserved Practice bank, snapshot, history, reward and Journey/XP; timed SQL regression passed"
                )
            if RANKED:
                c.execute(
                    Path("supabase/tests/quiz_arena_ranked_smoke.sql").read_text(
                        encoding="utf-8"
                    )
                )
                print(
                    "PASS: Ranked migration preserved Practice, Time Attack, Journey/XP and passed ranked lifecycle/security regression"
                )
    finally:
        assert name.startswith("arena_upgrade_check_")
        admin.execute(
            sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(name))
        )
