import { describe, expect, it } from 'vitest';
import { formatReviewAnswer } from './answer-review';
import type { Question } from './api';

const question: Question = { id:'q1',kind:'multiple_choice',prompt:'Greeting?',payload:{},options:[
  { id:'55555555-5555-4555-8555-555555555501',text:'How is it going?' },
] };

describe('formatReviewAnswer',()=>{
  it('shows option text instead of its internal UUID',()=>{
    expect(formatReviewAnswer('55555555-5555-4555-8555-555555555501',question)).toBe('How is it going?');
  });
  it('keeps server-provided display text',()=>{
    expect(formatReviewAnswer('Good morning',question)).toBe('Good morning');
  });
  it('formats matching answers with learner-facing labels',()=>{
    const matching:Question={id:'q2',kind:'matching',prompt:'Match',payload:{left:[{id:'station',text:'Station'}],right:[{id:'train',text:'Catch a train'}]},options:[]};
    expect(formatReviewAnswer({station:'train'},matching)).toBe('Station → Catch a train');
  });
});

