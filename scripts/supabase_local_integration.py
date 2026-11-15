"""Exercise local Supabase Auth/PostgREST/RLS with disposable accounts.

Only runs against the CLI's loopback API. Never prints keys, passwords or JWTs.
"""

from __future__ import annotations

import json
import secrets
import subprocess
from datetime import UTC, datetime, timedelta
from urllib.parse import urlsplit
from uuid import uuid4

import httpx


def require_status(response: httpx.Response, allowed: set[int], label: str) -> None:
    if response.status_code not in allowed:
        detail = response.json().get("message", "") if response.headers.get("content-type", "").startswith("application/json") else ""
        raise RuntimeError(f"{label}: HTTP {response.status_code}: {detail[:180]}")


def main() -> int:
    result = subprocess.run(
        ["npx.cmd", "supabase", "status", "--output", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    config = json.loads(result.stdout)
    base = config["API_URL"].rstrip("/")
    parsed = urlsplit(base)
    if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost"} or parsed.port != 54321:
        raise RuntimeError("Refusing to test a non-local Supabase project")
    public_key = config["ANON_KEY"]
    admin_key = config["SERVICE_ROLE_KEY"]
    admin_headers = {"apikey": admin_key, "Authorization": f"Bearer {admin_key}"}
    public_headers = {"apikey": public_key, "Authorization": f"Bearer {public_key}"}
    accounts: list[str] = []
    admin_content_ids: list[str] = []
    admin_question_ids: list[str] = []
    admin_lesson_ids: list[str] = []
    with httpx.Client(base_url=base, timeout=15) as client:
        try:
            sessions = []
            for _ in range(2):
                email = f"englify-local-{uuid4().hex}@example.test"
                password = secrets.token_urlsafe(24)
                created = client.post(
                    "/auth/v1/admin/users",
                    headers=admin_headers,
                    json={"email": email, "password": password, "email_confirm": True},
                )
                require_status(created, {200, 201}, "create local account")
                accounts.append(created.json()["id"])
                signed_in = client.post(
                    "/auth/v1/token?grant_type=password",
                    headers=public_headers,
                    json={"email": email, "password": password},
                )
                require_status(signed_in, {200}, "local sign in")
                sessions.append({
                    "apikey": public_key,
                    "Authorization": f"Bearer {signed_in.json()['access_token']}",
                })
            alice, bob = accounts
            alice_headers, bob_headers = sessions

            own = client.get("/rest/v1/profiles", params={"select": "id"}, headers=alice_headers)
            require_status(own, {200}, "own profile")
            if [row["id"] for row in own.json()] != [alice]:
                raise RuntimeError("own profile is missing or another profile is visible")
            other = client.get(
                "/rest/v1/profiles", params={"select": "id", "id": f"eq.{bob}"}, headers=alice_headers
            )
            require_status(other, {200}, "cross-user profile query")
            if other.json():
                raise RuntimeError("cross-user profile was exposed")
            anonymous = client.get("/rest/v1/profiles", params={"select": "id"}, headers=public_headers)
            if anonymous.is_success and anonymous.json():
                raise RuntimeError("anonymous profile access was exposed")

            onboarding = {
                "p_learning_goal": "conversation",
                "p_initial_proficiency": "beginner",
                "p_daily_goal_minutes": 15,
            }
            first = client.post("/rest/v1/rpc/englify_save_onboarding", headers=alice_headers, json=onboarding)
            require_status(first, {200, 204}, "onboarding RPC")
            preferences = client.get(
                "/rest/v1/user_preferences",
                params={"select": "onboarding_completed_at,daily_goal_minutes", "user_id": f"eq.{alice}"},
                headers=alice_headers,
            )
            require_status(preferences, {200}, "onboarding preferences")
            first_completed = preferences.json()[0]["onboarding_completed_at"]
            repeated_onboarding = client.post(
                "/rest/v1/rpc/englify_save_onboarding",
                headers=alice_headers,
                json={**onboarding, "p_daily_goal_minutes": 20},
            )
            require_status(repeated_onboarding, {200, 204}, "repeat onboarding RPC")
            preferences = client.get(
                "/rest/v1/user_preferences",
                params={"select": "onboarding_completed_at,daily_goal_minutes", "user_id": f"eq.{alice}"},
                headers=alice_headers,
            )
            if preferences.json()[0] != {"onboarding_completed_at": first_completed, "daily_goal_minutes": 20}:
                raise RuntimeError("onboarding timestamp or preference update changed incorrectly")
            anonymous_onboarding = client.post(
                "/rest/v1/rpc/englify_save_onboarding", headers=public_headers, json=onboarding
            )
            if anonymous_onboarding.is_success:
                raise RuntimeError("anonymous onboarding was accepted")
            own_update = client.patch(
                "/rest/v1/profiles",
                params={"id": f"eq.{alice}"},
                headers={**alice_headers, "Prefer": "return=representation"},
                json={"display_name": "Alice Updated"},
            )
            require_status(own_update, {200}, "own profile update")
            if own_update.json()[0]["display_name"] != "Alice Updated":
                raise RuntimeError("own profile did not update")
            bad_avatar = client.patch(
                "/rest/v1/profiles",
                params={"id": f"eq.{alice}"},
                headers=alice_headers,
                json={"avatar_url": f"{bob}/{uuid4()}.jpg"},
            )
            if bad_avatar.is_success:
                raise RuntimeError("profile accepted another user's avatar path")

            dictionary = client.get(
                "/rest/v1/dictionary_entries",
                params={"select": "id", "language": "eq.en", "is_published": "eq.true", "limit": 1},
                headers=alice_headers,
            )
            require_status(dictionary, {200}, "dictionary query")
            if not dictionary.json():
                raise RuntimeError("development dictionary seed is missing")
            word_id = dictionary.json()[0]["id"]
            own_save = client.post(
                "/rest/v1/saved_vocabulary",
                headers={**alice_headers, "Prefer": "return=representation"},
                json={"user_id": alice, "entry_id": word_id, "note": ""},
            )
            require_status(own_save, {201}, "save own word")
            repeated = client.post(
                "/rest/v1/saved_vocabulary",
                params={"on_conflict": "user_id,entry_id"},
                headers={**alice_headers, "Prefer": "resolution=ignore-duplicates,return=minimal"},
                json={"user_id": alice, "entry_id": word_id, "note": ""},
            )
            require_status(repeated, {200, 201, 204}, "idempotent save")
            own_saved = client.get(
                "/rest/v1/saved_vocabulary",
                params={"select": "id", "user_id": f"eq.{alice}"},
                headers=alice_headers,
            )
            require_status(own_saved, {200}, "own saved words")
            if len(own_saved.json()) != 1:
                raise RuntimeError("duplicate vocabulary save created extra records")
            forged = client.post(
                "/rest/v1/saved_vocabulary",
                headers=alice_headers,
                json={"user_id": bob, "entry_id": word_id, "note": ""},
            )
            if forged.is_success:
                raise RuntimeError("cross-user vocabulary insert was accepted")
            other_saved = client.get(
                "/rest/v1/saved_vocabulary",
                params={"select": "id", "user_id": f"eq.{alice}"},
                headers=bob_headers,
            )
            require_status(other_saved, {200}, "cross-user vocabulary query")
            if other_saved.json():
                raise RuntimeError("cross-user vocabulary was exposed")
            forged_xp = client.post(
                "/rest/v1/xp_events",
                headers=alice_headers,
                json={"user_id": alice, "source_type": "lesson", "source_id": str(uuid4()), "amount": 1000},
            )
            if forged_xp.is_success:
                raise RuntimeError("client XP write was accepted")
            expressions = client.get(
                "/rest/v1/real_english_expressions",
                params={"select": "id", "is_published": "eq.true", "limit": 1},
                headers=alice_headers,
            )
            require_status(expressions, {200}, "published expressions")
            if not expressions.json():
                raise RuntimeError("development expression seed is missing")
            expression_id = expressions.json()[0]["id"]
            quiz = client.post(
                "/rest/v1/rpc/englify_context_quiz",
                headers=alice_headers,
                json={"p_expression_id": expression_id},
            )
            require_status(quiz, {200}, "context quiz")
            quiz_data = quiz.json()
            if "answer_id" in quiz_data or "correct_option" in quiz_data or not quiz_data["options"]:
                raise RuntimeError("quiz leaked its answer or has no options")
            option_id = quiz_data["options"][0]["id"]
            request_id = str(uuid4())
            submission = {"p_expression_id": expression_id, "p_request_id": request_id,
                          "p_selected_option": option_id}
            attempt = client.post(
                "/rest/v1/rpc/englify_submit_context_quiz", headers=alice_headers, json=submission
            )
            require_status(attempt, {200}, "context quiz submission")
            repeated_quiz = client.post(
                "/rest/v1/rpc/englify_submit_context_quiz", headers=alice_headers, json=submission
            )
            require_status(repeated_quiz, {200}, "idempotent context quiz submission")
            if attempt.json()["attempt_id"] != repeated_quiz.json()["attempt_id"]:
                raise RuntimeError("duplicate quiz submission created another attempt")
            bad_option = client.post(
                "/rest/v1/rpc/englify_submit_context_quiz", headers=alice_headers,
                json={**submission, "p_request_id": str(uuid4()), "p_selected_option": "not-an-option"},
            )
            if bad_option.is_success:
                raise RuntimeError("invalid context quiz answer was accepted")
            anonymous_quiz = client.post(
                "/rest/v1/rpc/englify_context_quiz", headers=public_headers,
                json={"p_expression_id": expression_id},
            )
            if anonymous_quiz.is_success:
                raise RuntimeError("anonymous context quiz was accepted")
            own_expression_save = client.post(
                "/rest/v1/saved_expressions", headers=alice_headers,
                json={"user_id": alice, "expression_id": expression_id},
            )
            require_status(own_expression_save, {201}, "save expression")
            bob_saves = client.get(
                "/rest/v1/saved_expressions", headers=bob_headers,
                params={"select": "id", "user_id": f"eq.{alice}"},
            )
            require_status(bob_saves, {200}, "cross-user expression query")
            if bob_saves.json():
                raise RuntimeError("cross-user expression save was exposed")
            forged_expression_save = client.post(
                "/rest/v1/saved_expressions", headers=alice_headers,
                json={"user_id": bob, "expression_id": expression_id},
            )
            if forged_expression_save.is_success:
                raise RuntimeError("cross-user expression save was accepted")
            for _ in range(10):
                reserved = client.post(
                    "/rest/v1/rpc/englify_reserve_translation", headers=alice_headers,
                    json={"p_characters": 10},
                )
                require_status(reserved, {200, 204}, "translation quota reservation")
            excess = client.post(
                "/rest/v1/rpc/englify_reserve_translation", headers=alice_headers,
                json={"p_characters": 10},
            )
            if excess.is_success:
                raise RuntimeError("translation minute quota was bypassed")
            other_reservation = client.post(
                "/rest/v1/rpc/englify_reserve_translation", headers=bob_headers,
                json={"p_characters": 10},
            )
            require_status(other_reservation, {200, 204}, "other user's translation quota")
            anonymous_reservation = client.post(
                "/rest/v1/rpc/englify_reserve_translation", headers=public_headers,
                json={"p_characters": 10},
            )
            if anonymous_reservation.is_success:
                raise RuntimeError("anonymous translation quota reservation was accepted")
            oversized_reservation = client.post(
                "/rest/v1/rpc/englify_reserve_translation", headers=bob_headers,
                json={"p_characters": 2001},
            )
            if oversized_reservation.is_success:
                raise RuntimeError("oversized translation request was accepted")
            today = datetime.now(UTC).date()
            tasks = [{"day": (today + timedelta(days=offset)).isoformat(), "kind": "vocabulary",
                      "title": "Learn new words", "minutes": 5, "target_count": 2}
                     for offset in range(7)]
            plan = client.post(
                "/rest/v1/rpc/englify_plan_replace", headers=alice_headers,
                json={"p_tasks": tasks, "p_force": False},
            )
            require_status(plan, {200}, "generate learning plan")
            plan_id = plan.json()
            repeated_plan = client.post(
                "/rest/v1/rpc/englify_plan_replace", headers=alice_headers,
                json={"p_tasks": tasks, "p_force": False},
            )
            require_status(repeated_plan, {200}, "idempotent plan generation")
            if repeated_plan.json() != plan_id:
                raise RuntimeError("duplicate active plan was created")
            plan_rows = client.get(
                "/rest/v1/learning_plans", headers=alice_headers,
                params={"select": "id", "status": "eq.active"},
            )
            require_status(plan_rows, {200}, "own active plan")
            if len(plan_rows.json()) != 1:
                raise RuntimeError("active plan count is incorrect")
            hidden_plan = client.get(
                "/rest/v1/learning_plans", headers=bob_headers,
                params={"select": "id", "id": f"eq.{plan_id}"},
            )
            require_status(hidden_plan, {200}, "cross-user plan read")
            if hidden_plan.json():
                raise RuntimeError("cross-user plan was exposed")
            plan_tasks = client.get(
                "/rest/v1/learning_plan_tasks", headers=alice_headers,
                params={"select": "id,status", "plan_id": f"eq.{plan_id}"},
            )
            require_status(plan_tasks, {200}, "own plan tasks")
            if len(plan_tasks.json()) != 7:
                raise RuntimeError("weekly plan tasks were not persisted")
            task_id = plan_tasks.json()[0]["id"]
            completed_task = client.post(
                "/rest/v1/rpc/englify_plan_complete_task", headers=alice_headers,
                json={"p_task_id": task_id},
            )
            require_status(completed_task, {200}, "complete own non-lesson task")
            forged_task = client.post(
                "/rest/v1/rpc/englify_plan_complete_task", headers=bob_headers,
                json={"p_task_id": task_id},
            )
            if forged_task.is_success:
                raise RuntimeError("cross-user plan task completion was accepted")
            regenerated = client.post(
                "/rest/v1/rpc/englify_plan_replace", headers=alice_headers,
                json={"p_tasks": tasks, "p_force": True},
            )
            require_status(regenerated, {200}, "regenerate learning plan")
            if regenerated.json() == plan_id:
                raise RuntimeError("regeneration did not create a new active plan")
            history = client.get(
                "/rest/v1/learning_plans", headers=alice_headers,
                params={"select": "id,status", "order": "created_at.asc"},
            )
            require_status(history, {200}, "plan history")
            if len(history.json()) != 2 or {row["status"] for row in history.json()} != {"paused", "active"}:
                raise RuntimeError("plan regeneration lost historical plan")
            edge_get = client.post(
                "/functions/v1/study-plan", headers=alice_headers, json={"action": "get"}
            )
            require_status(edge_get, {200}, "Edge study-plan read")
            if edge_get.json()["id"] != regenerated.json() or len(edge_get.json()["tasks"]) != 7:
                raise RuntimeError("Edge plan read did not preserve active tasks")
            edge_regenerate = client.post(
                "/functions/v1/study-plan", headers=alice_headers, json={"action": "regenerate"}
            )
            require_status(edge_regenerate, {200}, "Edge plan regeneration")
            if edge_regenerate.json()["id"] == regenerated.json() or not edge_regenerate.json()["tasks"]:
                raise RuntimeError("Edge rules did not generate a new plan")
            edge_task = next((item for item in edge_regenerate.json()["tasks"] if item["kind"] != "lesson"), None)
            if edge_task is None:
                raise RuntimeError("Edge plan has no practice task")
            edge_complete = client.post(
                "/functions/v1/study-plan", headers=alice_headers,
                json={"action": "complete", "taskId": edge_task["id"]},
            )
            require_status(edge_complete, {200}, "Edge plan task completion")
            if not any(item["id"] == edge_task["id"] and item["status"] == "completed"
                       for item in edge_complete.json()["tasks"]):
                raise RuntimeError("Edge task completion did not persist")
            edge_preferences = client.post(
                "/functions/v1/study-plan", headers=alice_headers,
                json={"action": "preferences", "preferences": {
                    "learning_goal": "work", "initial_proficiency": "beginner",
                    "daily_goal_minutes": 20, "preferred_topics": ["travel"]}},
            )
            require_status(edge_preferences, {200}, "Edge plan preference update")
            if edge_preferences.json()["preferences"]["daily_goal_minutes"] != 20:
                raise RuntimeError("Edge plan preferences did not persist")
            lesson_task = next((item for item in edge_preferences.json()["tasks"] if item["kind"] == "lesson"), None)
            if lesson_task:
                forged_completion = client.post(
                    "/functions/v1/study-plan", headers=alice_headers,
                    json={"action": "complete", "taskId": lesson_task["id"]},
                )
                if forged_completion.is_success:
                    raise RuntimeError("lesson task was completed without a quiz")
            pending_task = next(item for item in edge_preferences.json()["tasks"] if item["status"] == "pending")
            missed = client.patch(
                "/rest/v1/learning_plan_tasks", headers=admin_headers,
                params={"id": f"eq.{pending_task['id']}"},
                json={"scheduled_on": (today - timedelta(days=1)).isoformat()},
            )
            require_status(missed, {200, 204}, "simulate a missed day in local database")
            rescheduled = client.post(
                "/functions/v1/study-plan", headers=alice_headers, json={"action": "reschedule"}
            )
            require_status(rescheduled, {200}, "Edge missed-day rescheduling")
            moved = next(item for item in rescheduled.json()["tasks"] if item["id"] == pending_task["id"])
            if moved["scheduled_on"] < today.isoformat() or moved["original_date"] != pending_task["original_date"]:
                raise RuntimeError("missed-day rescheduling changed history or did not move task")
            edge_no_onboarding = client.post(
                "/functions/v1/study-plan", headers=bob_headers, json={"action": "get"}
            )
            if edge_no_onboarding.status_code != 409:
                raise RuntimeError(f"onboarding guard returned HTTP {edge_no_onboarding.status_code}")
            initial_game = client.post(
                "/rest/v1/rpc/englify_gamification_overview", headers=alice_headers, json={}
            )
            require_status(initial_game, {200}, "gamification overview")
            if initial_game.json()["total_xp"] != 0 or initial_game.json()["level"] != 1:
                raise RuntimeError("new learner XP snapshot is incorrect")
            reward_id = initial_game.json()["rewards"][0]["id"]
            premature_claim = client.post(
                "/rest/v1/rpc/englify_claim_reward", headers=alice_headers,
                json={"p_reward_id": reward_id},
            )
            if premature_claim.is_success:
                raise RuntimeError("reward claim bypassed XP eligibility")
            local_rule = client.get(
                "/rest/v1/gamification_config", headers=admin_headers,
                params={"select": "level_xp_step", "id": "eq.1"},
            )
            require_status(local_rule, {200}, "local XP rule")
            step = local_rule.json()[0]["level_xp_step"]
            funded = client.post(
                "/rest/v1/xp_events", headers=admin_headers,
                json={"user_id": alice, "source_type": "adjustment", "source_id": str(uuid4()), "amount": 200},
            )
            require_status(funded, {201}, "fund disposable local account")
            level_row = client.post(
                "/rest/v1/user_levels", headers=admin_headers,
                json={"user_id": alice, "total_xp": 200, "level": 200 // step + 1},
            )
            require_status(level_row, {201}, "local level snapshot")
            claim = client.post(
                "/rest/v1/rpc/englify_claim_reward", headers=alice_headers,
                json={"p_reward_id": reward_id},
            )
            require_status(claim, {200}, "eligible reward claim")
            repeated_claim = client.post(
                "/rest/v1/rpc/englify_claim_reward", headers=alice_headers,
                json={"p_reward_id": reward_id},
            )
            require_status(repeated_claim, {200}, "idempotent reward claim")
            if not claim.json()["newly_claimed"] or repeated_claim.json()["newly_claimed"] or claim.json()["claim_id"] != repeated_claim.json()["claim_id"]:
                raise RuntimeError("duplicate claim created another reward")
            game_after_claim = client.post(
                "/rest/v1/rpc/englify_gamification_overview", headers=alice_headers, json={}
            )
            require_status(game_after_claim, {200}, "updated gamification overview")
            if game_after_claim.json()["available_xp"] != claim.json()["available_xp"]:
                raise RuntimeError("available XP was not reduced by the claim")
            notices = client.get(
                "/rest/v1/reward_notifications", headers=alice_headers,
                params={"select": "id,read_at", "user_id": f"eq.{alice}"},
            )
            require_status(notices, {200}, "reward notification")
            if len(notices.json()) != 1:
                raise RuntimeError("reward notification was not unique")
            notice_id = notices.json()[0]["id"]
            bob_read = client.post(
                "/rest/v1/rpc/englify_mark_reward_read", headers=bob_headers,
                json={"p_notification_id": notice_id},
            )
            require_status(bob_read, {200}, "cross-user notification read attempt")
            if bob_read.json()["read"]:
                raise RuntimeError("cross-user notification was marked read")
            alice_read = client.post(
                "/rest/v1/rpc/englify_mark_reward_read", headers=alice_headers,
                json={"p_notification_id": notice_id},
            )
            require_status(alice_read, {200}, "own notification read")
            if not alice_read.json()["read"]:
                raise RuntimeError("own notification was not marked read")
            journey = client.post("/rest/v1/rpc/englify_journey", headers=alice_headers, json={})
            require_status(journey, {200}, "journey RPC")
            lessons = [lesson for course in journey.json() for unit in course["units"] for lesson in unit["lessons"]]
            if len(lessons) < 2 or lessons[0]["state"] != "available" or lessons[1]["state"] != "locked":
                raise RuntimeError("initial lesson unlock order is incorrect")
            locked = client.post("/rest/v1/rpc/englify_lesson_detail", headers=alice_headers,
                                 json={"p_lesson_id": lessons[1]["id"]})
            if locked.is_success:
                raise RuntimeError("locked lesson detail was exposed")
            detail = client.post("/rest/v1/rpc/englify_lesson_detail", headers=alice_headers,
                                 json={"p_lesson_id": lessons[0]["id"]})
            require_status(detail, {200}, "available lesson detail")
            if "is_correct" in json.dumps(detail.json()) or "answer_key" in json.dumps(detail.json()):
                raise RuntimeError("quiz answer key leaked from lesson detail")
            version = client.post("/rest/v1/rpc/englify_lesson_content_version", headers=alice_headers,
                                  json={"p_lesson_id": lessons[0]["id"]})
            require_status(version, {200}, "lesson content version")
            if len(version.json()) != 64:
                raise RuntimeError("content fingerprint has the wrong format")
            summary = client.post("/rest/v1/rpc/englify_journey_summary", headers=alice_headers, json={})
            require_status(summary, {200}, "journey summary")
            if summary.json()["total_lessons"] != len(lessons):
                raise RuntimeError("journey summary lesson count is inconsistent")
            anonymous_journey = client.post("/rest/v1/rpc/englify_journey", headers=public_headers, json={})
            if anonymous_journey.is_success:
                raise RuntimeError("anonymous journey was exposed")
            denied_start = client.post("/rest/v1/rpc/englify_start_lesson", headers=bob_headers,
                                       json={"p_lesson_id": lessons[1]["id"]})
            if denied_start.is_success:
                raise RuntimeError("locked lesson could be started")
            started = client.post("/rest/v1/rpc/englify_start_lesson", headers=bob_headers,
                                  json={"p_lesson_id": lessons[0]["id"]})
            require_status(started, {200}, "start available lesson")
            if started.json()["state"] != "in_progress":
                raise RuntimeError("lesson did not enter in-progress state")
            question_id = detail.json()["questions"][0]["id"]
            wrong_option = "55555555-5555-4555-8555-555555555502"
            right_option = "55555555-5555-4555-8555-555555555501"
            bad_request_id = str(uuid4())
            wrong = client.post("/rest/v1/rpc/englify_submit_lesson", headers=bob_headers,
                                json={"p_lesson_id": lessons[0]["id"], "p_request_id": bad_request_id,
                                      "p_answers": {question_id: wrong_option}})
            require_status(wrong, {200}, "server-graded incorrect answer")
            if wrong.json()["passed"] or wrong.json()["earned_xp"] != 0:
                raise RuntimeError("incorrect answer earned XP")
            request_id = str(uuid4())
            submission = {"p_lesson_id": lessons[0]["id"], "p_request_id": request_id,
                          "p_answers": {question_id: right_option}, "p_content_version": version.json()}
            correct = client.post("/rest/v1/rpc/englify_submit_lesson", headers=bob_headers, json=submission)
            require_status(correct, {200}, "server-graded correct answer")
            if not correct.json()["passed"] or correct.json()["earned_xp"] <= 0:
                raise RuntimeError("first lesson completion was not rewarded")
            repeated = client.post("/rest/v1/rpc/englify_submit_lesson", headers=bob_headers, json=submission)
            require_status(repeated, {200}, "duplicate quiz submission")
            if repeated.json() != correct.json():
                raise RuntimeError("duplicate quiz request changed the result")
            unlocked = client.post("/rest/v1/rpc/englify_journey", headers=bob_headers, json={})
            require_status(unlocked, {200}, "journey after quiz completion")
            next_lesson = [lesson for course in unlocked.json() for unit in course["units"]
                           for lesson in unit["lessons"]][1]
            if next_lesson["state"] != "available":
                raise RuntimeError("next lesson remained locked after passing quiz")
            stale = client.post("/rest/v1/rpc/englify_submit_lesson", headers=bob_headers,
                                json={"p_lesson_id": next_lesson["id"], "p_request_id": str(uuid4()),
                                      "p_answers": {"44444444-4444-4444-8444-444444444402": "are",
                                                    "44444444-4444-4444-8444-444444444403": "She is happy."},
                                      "p_content_version": "0" * 64})
            if stale.status_code != 409:
                raise RuntimeError(f"stale offline content returned HTTP {stale.status_code}, expected 409")
            reused = client.post("/rest/v1/rpc/englify_submit_lesson", headers=bob_headers,
                                 json={"p_lesson_id": next_lesson["id"], "p_request_id": request_id,
                                       "p_answers": {"44444444-4444-4444-8444-444444444402": "are"}})
            if reused.status_code != 409:
                raise RuntimeError("quiz request ID could be reused for another lesson")
            unit_answers = [
                {"44444444-4444-4444-8444-444444444402": " ARE ",
                 "44444444-4444-4444-8444-444444444403": "she is happy!"},
                {"44444444-4444-4444-8444-444444444404": {"station": "trains", "library": "books"}},
                {"44444444-4444-4444-8444-444444444405": "good morning",
                 "44444444-4444-4444-8444-444444444406": "55555555-5555-4555-8555-555555555504"},
            ]
            for lesson, answers in zip(lessons[1:], unit_answers, strict=True):
                latest_version = client.post("/rest/v1/rpc/englify_lesson_content_version", headers=bob_headers,
                                             json={"p_lesson_id": lesson["id"]})
                require_status(latest_version, {200}, "offline lesson version")
                result = client.post("/rest/v1/rpc/englify_submit_lesson", headers=bob_headers,
                                     json={"p_lesson_id": lesson["id"], "p_request_id": str(uuid4()),
                                           "p_answers": answers, "p_content_version": latest_version.json()})
                require_status(result, {200}, "complete seeded lesson")
                if not result.json()["passed"] or result.json()["correct_count"] != result.json()["question_count"]:
                    raise RuntimeError("seeded lesson did not pass with expected answers")
            final_journey = client.post("/rest/v1/rpc/englify_journey", headers=bob_headers, json={})
            require_status(final_journey, {200}, "completed unit journey")
            unit_lessons = [lesson for course in final_journey.json() for unit in course["units"]
                            for lesson in unit["lessons"]]
            if any(lesson["state"] not in {"completed", "mastered"} for lesson in unit_lessons):
                raise RuntimeError("seeded learning unit is not fully completed")
            bob_xp = client.get("/rest/v1/xp_events", headers=bob_headers,
                                params={"select": "amount", "source_type": "eq.lesson"})
            require_status(bob_xp, {200}, "own lesson XP events")
            if len(bob_xp.json()) != len(unit_lessons):
                raise RuntimeError("duplicate lesson XP event was created")
            completed_total = sum(item["amount"] for item in bob_xp.json())
            replay = client.post("/rest/v1/rpc/englify_submit_lesson", headers=bob_headers,
                                 json={"p_lesson_id": lessons[0]["id"], "p_request_id": str(uuid4()),
                                       "p_answers": {question_id: right_option}})
            require_status(replay, {200}, "replay completed lesson")
            if replay.json()["earned_xp"] != 0 or replay.json()["state"] != "mastered":
                raise RuntimeError("perfect replay did not become mastered without duplicate XP")
            all_xp = client.get("/rest/v1/xp_events", headers=bob_headers,
                                params={"select": "source_type,amount"})
            require_status(all_xp, {200}, "server XP after full unit")
            if sum(item["amount"] for item in all_xp.json() if item["source_type"] == "lesson") != completed_total:
                raise RuntimeError("replay changed the lesson XP total")
            claims = client.get("/rest/v1/quest_claims", headers=bob_headers, params={"select": "id"})
            require_status(claims, {200}, "server quest claims")
            badges = client.get("/rest/v1/user_badges", headers=bob_headers, params={"select": "id"})
            require_status(badges, {200}, "server badge unlocks")
            if not claims.json() or not badges.json():
                raise RuntimeError("quest or badge was not awarded after completing the unit")
            alice_attempts = client.get("/rest/v1/lesson_attempts", headers=alice_headers,
                                        params={"select": "id", "user_id": f"eq.{bob}"})
            require_status(alice_attempts, {200}, "cross-user quiz attempt isolation")
            if alice_attempts.json():
                raise RuntimeError("another learner's quiz attempts leaked")
            exercises = client.get("/rest/v1/writing_exercises", headers=alice_headers,
                                   params={"select": "id,kind", "is_published": "eq.true"})
            require_status(exercises, {200}, "published writing exercises")
            if len(exercises.json()) != 4:
                raise RuntimeError("writing development exercises are missing")
            writing_input = {"p_request_id": str(uuid4()),
                             "p_exercise_id": "44444444-4444-4444-8444-444444444401",
                             "p_body": " i practice english every day! ", "p_grammar_check": True}
            writing = client.post("/rest/v1/rpc/englify_submit_writing", headers=alice_headers, json=writing_input)
            require_status(writing, {200}, "structured writing rule")
            if writing.json()["feedback"]["rule_result"] != "matched" or writing.json()["feedback"]["grammar_status"] != "unavailable":
                raise RuntimeError("writing rule or provider fallback is incorrect")
            writing_repeat = client.post("/rest/v1/rpc/englify_submit_writing", headers=alice_headers, json=writing_input)
            require_status(writing_repeat, {200}, "idempotent writing submission")
            if writing_repeat.json() != writing.json():
                raise RuntimeError("writing retry created different feedback")
            forged_grammar = client.post("/rest/v1/rpc/englify_attach_grammar_feedback", headers=alice_headers,
                                         json={"p_submission_id": writing.json()["id"], "p_matches": []})
            if forged_grammar.is_success:
                raise RuntimeError("learner could forge provider grammar feedback")
            edge_grammar = client.post("/functions/v1/writing-grammar", headers=alice_headers,
                                       json={"submissionId": writing.json()["id"]})
            require_status(edge_grammar, {200}, "optional grammar Edge fallback")
            if edge_grammar.json().get("status") != "unavailable":
                raise RuntimeError("grammar Edge claimed availability without LanguageTool")
            history = client.post("/rest/v1/rpc/englify_writing_history", headers=alice_headers, json={})
            require_status(history, {200}, "own writing history")
            if len(history.json()) != 1 or history.json()[0]["body"] != writing.json()["body"]:
                raise RuntimeError("writing history did not persist original text")
            other_history = client.post("/rest/v1/rpc/englify_writing_history", headers=bob_headers, json={})
            require_status(other_history, {200}, "cross-user writing history")
            if other_history.json():
                raise RuntimeError("another learner's writing history was exposed")
            paragraph = client.post("/rest/v1/rpc/englify_submit_writing", headers=bob_headers,
                                    json={"p_request_id": str(uuid4()),
                                          "p_exercise_id": "44444444-4444-4444-8444-444444444404",
                                          "p_body": "a short paragraph", "p_grammar_check": False})
            require_status(paragraph, {200}, "paragraph self-review")
            if paragraph.json()["feedback"]["rule_result"] != "self_review" or not paragraph.json()["feedback"]["suggestions"]:
                raise RuntimeError("paragraph received fabricated score or no suggestions")
            denied_admin = client.post("/rest/v1/rpc/englify_is_admin", headers=bob_headers, json={})
            require_status(denied_admin, {200}, "non-admin role check")
            if denied_admin.json() is not False:
                raise RuntimeError("ordinary learner passed administrator role check")
            denied_write = client.post("/rest/v1/dictionary_entries", headers=bob_headers,
                                       json={"language": "en", "term": "blocked", "normalized_term": "blocked",
                                             "definition": "blocked", "translation": "blocked",
                                             "source_name": "local-test", "license_id": "project-owned"})
            if denied_write.is_success:
                raise RuntimeError("ordinary learner could create editorial content")
            membership = client.post("/rest/v1/admin_members", headers=admin_headers,
                                     json={"user_id": alice})
            require_status(membership, {201}, "grant disposable local admin membership")
            allowed_admin = client.post("/rest/v1/rpc/englify_is_admin", headers=alice_headers, json={})
            require_status(allowed_admin, {200}, "administrator role check")
            if allowed_admin.json() is not True:
                raise RuntimeError("admin membership was not recognized")
            admin_metrics = client.post("/rest/v1/rpc/englify_admin_metrics", headers=alice_headers,
                                        json={"p_view": "analytics"})
            require_status(admin_metrics, {200}, "admin analytics")
            if admin_metrics.json()["lesson_attempts"] < len(lessons):
                raise RuntimeError("admin analytics omitted local quiz attempts")
            learner_metrics = client.post("/rest/v1/rpc/englify_admin_metrics", headers=bob_headers,
                                          json={"p_view": "analytics"})
            if learner_metrics.is_success:
                raise RuntimeError("learner accessed administrator analytics")
            attempted_edit = client.patch("/rest/v1/quiz_questions", headers=alice_headers,
                                          params={"id": f"eq.{question_id}"},
                                          json={"prompt": "Changed after attempts"})
            if attempted_edit.status_code != 409:
                raise RuntimeError(f"quiz content with attempts accepted edit: HTTP {attempted_edit.status_code}")
            attempted_insert = client.post("/rest/v1/quiz_questions", headers=alice_headers,
                                           json={"lesson_id": lessons[0]["id"], "position": 10,
                                                 "kind": "multiple_choice", "prompt": "Late question"})
            if attempted_insert.status_code != 409:
                raise RuntimeError("admin added quiz content after a learner attempted the lesson")
            draft_id = str(uuid4())
            draft = client.post("/rest/v1/dictionary_entries",
                                headers={**alice_headers, "Prefer": "return=representation"},
                                json={"id": draft_id, "language": "en", "term": "Local QA Draft",
                                      "normalized_term": "local qa draft", "definition": "A test entry.",
                                      "translation": "Bản thử", "source_name": "Englify Quest editorial",
                                      "license_id": "project-owned"})
            require_status(draft, {201}, "admin creates dictionary draft")
            admin_content_ids.append(draft_id)
            invisible = client.get("/rest/v1/dictionary_entries", headers=bob_headers,
                                   params={"select": "id", "id": f"eq.{draft_id}"})
            require_status(invisible, {200}, "draft visibility to learner")
            if invisible.json():
                raise RuntimeError("unpublished admin draft leaked to learner")
            published = client.patch("/rest/v1/dictionary_entries", headers=alice_headers,
                                     params={"id": f"eq.{draft_id}"}, json={"is_published": True})
            require_status(published, {200, 204}, "admin publishes dictionary entry")
            visible = client.get("/rest/v1/dictionary_entries", headers=bob_headers,
                                 params={"select": "id", "id": f"eq.{draft_id}"})
            require_status(visible, {200}, "published entry visible to learner")
            if len(visible.json()) != 1:
                raise RuntimeError("published admin entry is not visible to mobile learner")
            draft_lesson_id = str(uuid4())
            draft_lesson = client.post("/rest/v1/lessons", headers=alice_headers,
                                       json={"id": draft_lesson_id, "course_id": journey.json()[0]["id"],
                                             "unit_id": journey.json()[0]["units"][0]["id"],
                                             "slug": f"admin-qa-{draft_lesson_id[:8]}", "position": 5,
                                             "title": "Admin QA lesson", "objective": "Test editorial workflow"})
            require_status(draft_lesson, {201}, "admin creates draft lesson")
            admin_lesson_ids.append(draft_lesson_id)
            question_seed = {"id": str(uuid4()), "lesson_id": draft_lesson_id,
                             "position": 10, "kind": "multiple_choice", "prompt": "Choose a test answer"}
            premature = client.post("/rest/v1/quiz_questions", headers=alice_headers,
                                    json={**question_seed, "is_published": True})
            if premature.is_success:
                raise RuntimeError("admin published an incomplete quiz question")
            draft_question = client.post("/rest/v1/quiz_questions", headers=alice_headers,
                                         json=question_seed)
            require_status(draft_question, {201}, "admin creates quiz draft")
            admin_question_ids.append(question_seed["id"])
            for position, correct in ((1, True), (2, False)):
                option = client.post("/rest/v1/quiz_options", headers=alice_headers,
                                     json={"question_id": question_seed["id"], "position": position,
                                           "answer_text": f"Choice {position}", "is_correct": correct})
                require_status(option, {201}, "admin creates private quiz option")
            publish_question = client.patch("/rest/v1/quiz_questions", headers=alice_headers,
                                            params={"id": f"eq.{question_seed['id']}"},
                                            json={"is_published": True})
            require_status(publish_question, {200, 204}, "admin publishes ready quiz")
            own_options = client.get("/rest/v1/quiz_options", headers=alice_headers,
                                     params={"select": "id", "question_id": f"eq.{question_seed['id']}"})
            require_status(own_options, {200}, "admin sees private quiz options")
            live_option_edit = client.patch("/rest/v1/quiz_options", headers=alice_headers,
                                            params={"id": f"eq.{own_options.json()[0]['id']}"},
                                            json={"answer_text": "Edited live answer"})
            if live_option_edit.status_code != 409:
                raise RuntimeError("admin edited answers while the question was published")
            hidden_options = client.get("/rest/v1/quiz_options", headers=bob_headers,
                                        params={"select": "id", "question_id": f"eq.{question_seed['id']}"})
            if hidden_options.is_success and hidden_options.json():
                raise RuntimeError("quiz option correctness leaked to learner")
            hidden_keys = client.get("/rest/v1/quiz_answer_keys", headers=bob_headers,
                                     params={"select": "question_id"})
            if hidden_keys.is_success and hidden_keys.json():
                raise RuntimeError("private quiz answer keys leaked to learner")
            audit = client.get("/rest/v1/admin_audit_logs", headers=alice_headers,
                               params={"select": "action", "record_id": f"eq.{draft_id}"})
            require_status(audit, {200}, "admin audit history")
            if {item["action"] for item in audit.json()} != {"create", "publish"}:
                raise RuntimeError("admin content write was not audited")
            private_audit = client.get("/rest/v1/admin_audit_logs", headers=bob_headers,
                                       params={"select": "id"})
            if private_audit.is_success and private_audit.json():
                raise RuntimeError("admin audit history leaked to learner")
            print("PASS: local Auth/RLS, profile, dictionary, Real English, quotas, plan, gamification, full Journey unit, writing, admin RLS/draft/publish/audit")
        finally:
            if accounts:
                removed_logs = client.delete("/rest/v1/admin_audit_logs", headers=admin_headers,
                                             params={"actor_id": f"eq.{accounts[0]}"})
                require_status(removed_logs, {200, 204}, "remove disposable admin audit logs")
            for record_id in admin_content_ids:
                client.delete("/rest/v1/dictionary_entries", headers=admin_headers,
                              params={"id": f"eq.{record_id}"})
            for record_id in admin_question_ids:
                client.delete("/rest/v1/quiz_questions", headers=admin_headers,
                              params={"id": f"eq.{record_id}"})
            for record_id in admin_lesson_ids:
                client.delete("/rest/v1/lessons", headers=admin_headers,
                              params={"id": f"eq.{record_id}"})
            for user_id in accounts:
                removed_user = client.delete(f"/auth/v1/admin/users/{user_id}", headers=admin_headers)
                require_status(removed_user, {200, 204}, "remove disposable local account")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
