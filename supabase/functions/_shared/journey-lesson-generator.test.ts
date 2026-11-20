/// <reference lib="deno.ns" />
import { assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { generateJourneyLesson, JourneyGenerationError } from './journey-lesson-generator.ts';
const input={cefr_level:'A1',topic:'Greetings',learning_objective:'Use greetings',grammar_focus:'be',vocabulary_focus:'hello',desired_blocks:['introduction']};const response=(status:number,text:string)=>new Response(text,{status});
Deno.test('accepts a structured reviewable Journey lesson',async()=>{const x=await generateJourneyLesson(input,'gemini-test','key',async()=>response(200,JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({title:'Greetings',objective:'Use greetings',blocks:[{type:'introduction',content:{text_en:'Hello',text_vi:'Xin chào'}}]})}]}}]})));assertEquals(x.blocks.length,1);});
Deno.test('rejects HTML or malformed AI blocks',async()=>{await assertRejects(()=>generateJourneyLesson(input,'gemini-test','key',async()=>response(200,JSON.stringify({candidates:[{content:{parts:[{text:JSON.stringify({title:'x',objective:'x',blocks:[{type:'theory',content:{html:'<script>'}}]})}]}}]}))),JourneyGenerationError,'invalid lesson blocks');});
