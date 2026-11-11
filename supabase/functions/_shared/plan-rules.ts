// Port of backend/app/planning/rules.py. UTC dates and algorithm version stay stable.
export const ALGORITHM_VERSION = 1;
export type PlannedTask = {
  day: string; kind: 'lesson' | 'vocabulary' | 'review' | 'speaking' | 'writing';
  title: string; minutes: number; target_count: number | null; lesson_id: string | null; topic: string | null;
};
export type PlanInput = {
  start: string; proficiency: string; goal: string; daily_minutes: number; topics: string[];
  quiz_accuracy: number | null; lessons: { id: string; title: string; completed: boolean }[]; due_reviews: number;
};
function addDays(day: string, days: number): string {
  const value = new Date(`${day}T00:00:00.000Z`);
  if (Number.isNaN(value.getTime())) throw new Error('Invalid UTC calendar date');
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}
function task(day: string, kind: PlannedTask['kind'], title: string, minutes: number,
  target_count: number | null = null, lesson_id: string | null = null, topic: string | null = null): PlannedTask {
  return { day, kind, title, minutes, target_count, lesson_id, topic };
}
export function generateWeek(input: PlanInput): PlannedTask[] {
  if (!Number.isInteger(input.daily_minutes) || input.daily_minutes < 1 || input.daily_minutes > 180) {
    throw new Error('daily_minutes must be between 1 and 180');
  }
  if (input.quiz_accuracy !== null && (input.quiz_accuracy < 0 || input.quiz_accuracy > 1)) {
    throw new Error('quiz_accuracy must be between 0 and 1');
  }
  const lessons = input.lessons.filter((lesson) => !lesson.completed);
  const struggling = input.quiz_accuracy !== null && input.quiz_accuracy < 0.6;
  const practice: readonly ['writing', 'speaking'] | readonly ['speaking', 'writing'] =
    input.goal === 'work' || input.goal === 'exams' ? ['writing', 'speaking'] : ['speaking', 'writing'];
  const sequence: PlannedTask['kind'][] = struggling
    ? ['review', practice[0], 'lesson', practice[1], 'review', 'vocabulary', 'lesson']
    : ['lesson', practice[0], 'lesson', practice[1], 'lesson', 'vocabulary', 'review'];
  const output: PlannedTask[] = [];
  let lessonIndex = 0;
  for (let offset = 0; offset < 7; offset++) {
    const day = addDays(input.start, offset);
    const topic = input.topics.length ? input.topics[offset % input.topics.length] : null;
    let budget = input.daily_minutes;
    let primary = sequence[offset];
    if (primary === 'lesson' && lessonIndex < lessons.length && budget >= 5) {
      const lesson = lessons[lessonIndex++];
      const minutes = Math.min(input.proficiency === 'beginner' ? 15 : 20, budget);
      output.push(task(day, 'lesson', lesson.title, minutes, null, lesson.id, topic));
      budget -= minutes;
    } else if (primary === 'lesson') primary = 'vocabulary';
    if (primary === 'review' && budget >= 5) {
      const minutes = Math.min(10, budget);
      output.push(task(day, 'review', 'Review vocabulary and quiz mistakes', minutes,
        Math.min(Math.max(input.due_reviews, 3), 10), null, topic));
      budget -= minutes;
    }
    if ((primary === 'writing' || primary === 'speaking') && budget >= 5) {
      const minutes = Math.min(10, budget);
      output.push(task(day, primary, primary === 'writing' ? 'Writing practice' : 'Speaking practice',
        minutes, null, null, topic));
      budget -= minutes;
    }
    if (budget >= 5) {
      const minutes = Math.min(5, budget);
      const count = Math.max(1, Math.min(10, Math.floor(minutes / 2) + (input.proficiency === 'advanced' ? 1 : 0)));
      output.push(task(day, 'vocabulary', 'Learn new words', minutes, count, null, topic));
      budget -= minutes;
    }
    if ((input.due_reviews > 0 || struggling) && budget >= 5 && primary !== 'review') {
      const minutes = Math.min(5, budget);
      output.push(task(day, 'review', 'Review vocabulary and quiz mistakes', minutes,
        Math.min(Math.max(input.due_reviews, 3), 10), null, topic));
    }
    if (!output.some((item) => item.day === day)) {
      const kind = primary === 'lesson' ? 'vocabulary' : primary;
      const title = { review: 'Review one word', vocabulary: 'Learn one word', speaking: 'Say one sentence',
        writing: 'Write one sentence' }[kind];
      output.push(task(day, kind, title, budget, kind === 'vocabulary' || kind === 'review' ? 1 : null, null, topic));
    }
  }
  return output;
}

export function rescheduleMissed(tasks: PlannedTask[], today: string, dailyMinutes: number): PlannedTask[] {
  const used = new Map<string, number>();
  for (let offset = 0; offset < 28; offset++) used.set(addDays(today, offset), 0);
  for (const item of tasks) if (item.day >= today && used.has(item.day)) used.set(item.day, (used.get(item.day) ?? 0) + item.minutes);
  return tasks.map((item) => {
    if (item.day >= today) return item;
    let day = today;
    while ((used.get(day) ?? 0) + item.minutes > dailyMinutes) day = addDays(day, 1);
    used.set(day, (used.get(day) ?? 0) + item.minutes);
    return { ...item, day };
  });
}