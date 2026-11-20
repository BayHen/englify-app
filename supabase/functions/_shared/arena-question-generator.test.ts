/// <reference lib="deno.ns" />
import { assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { ArenaGenerationError, generateArenaQuestions } from './arena-question-generator.ts';
const input={cefr_level:'B1',topic:'grammar',kind:'multiple_choice',difficulty:2,count:1,learning_objective:'Test present perfect'};
const response=(status:number,text:string)=>new Response(text,{status,headers:{'Content-Type':'application/json'}});
Deno.test('accepts exact structured Gemini question count',async()=>{const generated={prompt:'Choose',passage:null,options:[{id:'a',text:'A'},{id:'b',text:'B'}],left_items:[],right_items:[],answer_json:'"a"',explanation_vi:'Giải thích'};const result=await generateArenaQuestions(input,'gemini-2.5-flash-lite','test',async()=>response(200,JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({questions:[generated]})}]}}]})));assertEquals(result[0].answer,'a');});
Deno.test('rejects malformed structured output',async()=>{await assertRejects(()=>generateArenaQuestions(input,'gemini-2.5-flash-lite','test',async()=>response(200,JSON.stringify({candidates:[{content:{parts:[{text:'not-json'}]}}]}))),ArenaGenerationError,'malformed JSON');});
Deno.test('maps provider quota without returning partial drafts',async()=>{await assertRejects(()=>generateArenaQuestions(input,'gemini-2.5-flash-lite','test',async()=>response(429,'{}')),ArenaGenerationError,'quota reached');});
