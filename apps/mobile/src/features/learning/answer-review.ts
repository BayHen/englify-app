import type { Question, QuestionReview } from './api';

export function formatReviewAnswer(value: unknown, question?: Question): string {
  const resolved = typeof value === 'string' && question
    ? question.options.find((option) => option.id === value)?.text ?? value : value;
  if (resolved === null || resolved === undefined || resolved === '') return 'Not available';
  if (typeof resolved === 'string') return resolved;
  if (typeof resolved === 'object' && !Array.isArray(resolved)) {
    return Object.entries(resolved as Record<string, unknown>).map(([key, item]) => {
      const left = question && Array.isArray(question.payload.left) ? (question.payload.left as { id:string; text:string }[]).find((choice) => choice.id === key)?.text ?? key : key;
      const right = question && Array.isArray(question.payload.right) ? (question.payload.right as { id:string; text:string }[]).find((choice) => choice.id === item)?.text ?? String(item) : String(item);
      return `${left} → ${right}`;
    }).join(', ');
  }
  return String(resolved);
}

export function reviewQuestion(review: QuestionReview, questions: Question[]): Question | undefined {
  return questions.find((question) => question.id === review.question_id);
}

