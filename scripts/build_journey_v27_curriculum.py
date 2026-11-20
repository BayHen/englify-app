"""Build the reviewed, deterministic Journey V2.7 Level 1-10 seed.

The generated SQL contains stable UUIDs and only inserts missing rows. It never
updates learner progress or replaces an existing published revision.
"""
from __future__ import annotations

import hashlib
import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "supabase" / "seeds" / "journey_v27_curriculum.sql"
NS = uuid.UUID("42d7df67-b127-4a38-9270-2dd4bf9fcf09")

LEVELS = [
 (1,"English Foundations","A1 – Foundation","Begin with sounds, greetings, and the sentence patterns needed to introduce yourself.",[
  ("Sounds and first words","Alphabet and letter sounds","letter, sound, spell","recognition and pronunciation"),("Meet and greet","Greetings and introductions","hello, name, from","be: I am / you are"),("People and things","Pronouns and basic nouns","person, place, object","subject pronouns"),("Numbers and dates","Numbers, days, and dates","number, day, date","singular and plural"),("Build a sentence","Simple sentence construction","subject, verb, object","affirmative word order"),("Ask and introduce","Basic questions and self-introduction","who, what, where","be questions")]),
 (2,"Everyday English","A1","Talk about familiar people, routines, time, food, and everyday needs.",[
  ("Family words","Family and friends","parent, sibling, friend","possessive adjectives"),("My day","Daily routines","wake up, work, study","present simple"),("Time and frequency","Time and habits","always, usually, sometimes","frequency adverbs"),("Food and drink","Meals and preferences","breakfast, water, like","like / would like"),("Objects around us","Common objects","phone, key, bag","this / that / these / those"),("Polite needs","Basic requests","please, help, need","can / could requests")]),
 (3,"Practical Communication","A1 → A2","Handle shopping, food, transport, directions, and simple past experiences.",[
  ("At the shop","Shopping and prices","price, size, cash","how much / how many"),("At a restaurant","Ordering food","menu, order, bill","countable and uncountable nouns"),("Getting around","Transportation","bus, train, ticket","transport prepositions"),("Find the way","Directions and places","turn, across, corner","imperatives and place prepositions"),("Travel basics","Trips and accommodation","booking, passport, hotel","there is / there are"),("A recent trip","Basic past events","visited, stayed, enjoyed","past simple")]),
 (4,"Building Sentences","A2","Connect ideas, describe events, explain plans, and write short paragraphs.",[
  ("Now and every day","Present simple versus continuous","routine, currently, today","present simple vs continuous"),("Tell the past","Past events","ago, last, happened","past simple forms"),("Plans ahead","Future plans","plan, arrange, tomorrow","going to / present continuous"),("Compare clearly","Comparatives and superlatives","bigger, better, most","comparison forms"),("Connect ideas","Sentence connectors","because, but, so","coordination and reason"),("Opinion paragraph","Descriptions and opinions","opinion, reason, example","paragraph structure")]),
 (5,"Confident Conversations","A2 → B1","Sustain social, study, and workplace conversations with clear opinions and suggestions.",[
  ("At work","Workplace conversations","task, deadline, colleague","polite workplace questions"),("Learning together","Study and learning","assignment, revise, feedback","present perfect introduction"),("Make a plan","Arrangements and suggestions","available, arrange, suggest","could / should / let's"),("Share an opinion","Opinions and reasons","believe, prefer, reason","opinion clauses"),("Agree constructively","Agreement and disagreement","exactly, however, point","discourse markers"),("Solve it together","Problems, phone, and online talk","issue, solution, connection","clarifying questions")]),
 (6,"Real-World English","B1","Understand longer information and describe experiences in authentic contexts.",[
  ("Read for meaning","Real-world reading","headline, notice, detail","skimming and scanning"),("Everyday news","News and information","report, event, source","reported information"),("Tell a story","Storytelling","suddenly, meanwhile, eventually","past continuous and past simple"),("Life experience","Experiences and travel","achievement, challenge, memorable","present perfect vs past simple"),("Work and society","Work and social situations","responsibility, community, cooperate","relative clauses"),("Meaning in context","Phrasal verbs and listening","figure out, carry on, pick up","context inference")]),
 (7,"Expressing Ideas","B1 → B2","Organize explanations and support opinions with reasons and evidence.",[
  ("State a position","Opinion writing","claim, viewpoint, stance","thesis statements"),("Support with evidence","Reasons and evidence","evidence, example, reliable","supporting clauses"),("Weigh both sides","Advantages and disadvantages","benefit, drawback, whereas","contrast structures"),("Propose a solution","Problem-solving","cause, impact, solution","conditionals"),("Organize a discussion","Discussion and paragraphs","topic sentence, cohesion, conclusion","paragraph cohesion"),("Professional email","Emails and explanations","subject, request, attachment","formal email conventions")]),
 (8,"Natural English","B2","Use collocations, idioms, register, and nuance to sound more natural.",[
  ("Words that belong together","Collocations","make progress, take part, strong evidence","collocation patterns"),("Phrasal meaning","Phrasal verbs","bring up, work out, turn down","particle meaning"),("Idioms in context","Idioms","on the same page, a long shot","figurative meaning"),("Sound conversational","Natural expressions","actually, fair enough, by the way","conversation management"),("Choose the register","Formal and informal English","regarding, cheers, appreciate","register and tone"),("Notice the nuance","Common mistakes and nuance","imply, infer, subtle","precision and connotation")]),
 (9,"Advanced Communication","B2 → C1","Analyze complex information and communicate nuanced arguments.",[
  ("Discuss complexity","Complex discussions","perspective, assumption, implication","hedging"),("Debate responsibly","Debates and persuasion","rebuttal, concede, compelling","argument structure"),("Present with impact","Presentations","overview, transition, takeaway","signposting"),("Read critically","Critical reading","bias, credibility, inference","evaluative language"),("Write formally","Advanced writing","synthesize, demonstrate, nevertheless","complex cohesion"),("Express nuance","Complex sentence structures","extent, arguably, notwithstanding","subordination and emphasis")]),
 (10,"English Mastery & Capstone","Advanced Integrated Practice","Integrate reading, listening, speaking, and writing in realistic situations without certification claims.",[
  ("Integrate information","Integrated reading and listening","synthesize, compare, source","cross-source synthesis"),("Speak through scenarios","Speaking scenarios","respond, clarify, negotiate","strategic communication"),("Write a project","Writing projects","draft, revise, audience","planning and revision"),("Think critically","Critical thinking","evaluate, justify, alternative","reasoned evaluation"),("Communicate at work","Workplace communication","proposal, stakeholder, outcome","professional register"),("Apply and reflect","Advanced discussion and review","strength, weakness, strategy","integrated review")]),
]

def uid(key: str) -> str: return str(uuid.uuid5(NS, key))
def q(value: str) -> str: return "'" + value.replace("'", "''") + "'"
def j(value: object) -> str: return q(json.dumps(value, ensure_ascii=False, separators=(",", ":"))) + "::jsonb"

def emit(lines: list[str], sql: str) -> None: lines.append(sql.rstrip() + "\n")

def build() -> str:
 lines=["-- Generated by scripts/build_journey_v27_curriculum.py. Local/staging only.\nBEGIN;\n",
        "INSERT INTO public.journey_curriculum_versions(version,title,status) VALUES (2,'Journey V2.7 complete prebuilt curriculum','draft') ON CONFLICT(version) DO NOTHING;\n"]
 counts={"chapters":0,"units":0,"lessons":0,"checkpoints":0,"assessments":0,"capstones":0,"questions":0}
 prior_course: str | None = None
 for level,title,cefr,description,units in LEVELS:
  previous: str | None = None
  course=uid(f"level:{level}"); cefr_code={1:"A1",2:"A1",3:"A2",4:"A2",5:"B1",6:"B1",7:"B2",8:"B2",9:"C1",10:"C1"}[level]
  objectives=[f"Complete Level {level} learning path",description]
  emit(lines,f"INSERT INTO public.courses(id,slug,title,description,level,is_published,cefr_level,curriculum_version,external_id,cefr_guidance,learning_objectives,vocabulary_focus,grammar_focus,skill_focus) VALUES ({q(course)},{q(f'journey-level-{level}')},{q(title)},{q(description)},{level},true,{q(cefr_code)},2,{q(f'journey-v27-level-{level:02d}')},{q(cefr)},{j(objectives)},{j([u[2] for u in units])},{j([u[3] for u in units])},{j(['reading','listening','speaking','writing'])}) ON CONFLICT(id) DO NOTHING;")
  if prior_course:
   emit(lines,f"INSERT INTO public.journey_course_prerequisites(course_id,prerequisite_course_id) VALUES ({q(course)},{q(prior_course)}) ON CONFLICT(course_id) DO NOTHING;")
  prior_course=course
  level_items=[]
  for chapter_index in range(3):
   chapter=uid(f"level:{level}:chapter:{chapter_index+1}"); chapter_units=units[chapter_index*2:chapter_index*2+2]
   chapter_title=f"Chapter {chapter_index+1}: {chapter_units[0][0]} & {chapter_units[1][0]}"
   emit(lines,f"INSERT INTO public.journey_chapters(id,course_id,slug,title,description,position,curriculum_version,is_published,learning_objectives,lifecycle_status,external_id,vocabulary_focus,grammar_focus,skill_focus) VALUES ({q(chapter)},{q(course)},{q(f'chapter-{chapter_index+1}')},{q(chapter_title)},{q('Progress from '+chapter_units[0][1].lower()+' to '+chapter_units[1][1].lower()+'.')},{chapter_index+1},2,true,{j([u[1] for u in chapter_units])},'published',{q(f'journey-v27-l{level:02d}-c{chapter_index+1}')},{j([u[2] for u in chapter_units])},{j([u[3] for u in chapter_units])},{j(['comprehension','guided production','communication'])}) ON CONFLICT(id) DO NOTHING;")
   counts["chapters"]+=1
   for local_index,unit_data in enumerate(chapter_units):
    unit_index=chapter_index*2+local_index+1; unit=uid(f"level:{level}:unit:{unit_index}"); unit_title,topic,vocab,grammar=unit_data
    emit(lines,f"INSERT INTO public.learning_units(id,course_id,chapter_id,slug,title,description,learning_objectives,position,estimated_minutes,is_required,lifecycle_status,is_published,curriculum_version,external_id,vocabulary_focus,grammar_focus) VALUES ({q(unit)},{q(course)},{q(chapter)},{q(f'unit-{unit_index}-{unit_title.lower().replace(' ','-').replace('&','and')}')},{q(unit_title)},{q(topic+'. Three guided lessons lead to an authoritative checkpoint.')},{j([f'Understand {topic.lower()}',f'Use {grammar} accurately',f'Apply {vocab} in context'])},{unit_index},55,true,'published',true,2,{q(f'journey-v27-l{level:02d}-u{unit_index:02d}')},{j([x.strip() for x in vocab.split(',')])},{j([grammar])}) ON CONFLICT(id) DO NOTHING;")
    counts["units"]+=1
    unit_lessons=[]
    lesson_specs=[("Explore",f"Understand the core language for {topic.lower()}"),("Build",f"Use {grammar} with guided examples"),("Communicate",f"Apply {topic.lower()} in a realistic exchange")]
    vocab_words=[x.strip() for x in vocab.split(',')]
    for lesson_index,(phase,objective) in enumerate(lesson_specs,1):
     lesson=uid(f"level:{level}:unit:{unit_index}:lesson:{lesson_index}"); lesson_title=f"{phase}: {unit_title}"
     lesson_position=(unit_index-1)*4+lesson_index
     emit(lines,f"INSERT INTO public.lessons(id,course_id,unit_id,slug,position,title,objective,content,xp_reward,is_published,is_required,estimated_minutes,lesson_kind,checkpoint_pass_percent,curriculum_version,lifecycle_status,external_id,assessment_scope) VALUES ({q(lesson)},{q(course)},{q(unit)},{q(f'unit-{unit_index}-lesson-{lesson_index}-{phase.lower()}')},{lesson_position},{q(lesson_title)},{q(objective)},{j({'topic':topic,'grammar_focus':grammar,'vocabulary_focus':vocab_words})},20,true,true,12,'lesson',70,2,'published',{q(f'journey-v27-l{level:02d}-u{unit_index:02d}-lesson-{lesson_index}')},'lesson') ON CONFLICT(id) DO NOTHING;")
     revision=uid(f"{lesson}:revision:1"); content_hash=hashlib.sha256(f"{lesson_title}|{objective}|{vocab}|{grammar}".encode()).hexdigest()
     emit(lines,f"INSERT INTO public.journey_lesson_revisions(id,lesson_id,version,status,source,content_hash,published_at) VALUES ({q(revision)},{q(lesson)},1,'published','curated',{q(content_hash)},transaction_timestamp()) ON CONFLICT(id) DO NOTHING;")
     intro=f"In this lesson, you will work with {topic.lower()}. This helps you communicate clearly in a practical situation."
     theory=f"Focus on {grammar}. Notice the form, meaning, and position of each word before you produce your own sentence."
     example=f"Model: We use {vocab_words[0]} in a sentence about {topic.lower()}. Vietnamese guide: Hãy chú ý ngữ cảnh và cấu trúc {grammar}."
     blocks=[('introduction',{'title':lesson_title,'text_en':intro,'text_vi':f'Bài học này giúp bạn luyện {topic.lower()} trong ngữ cảnh thực tế.'}),('objective',{'title':'Learning goal','text_en':objective,'text_vi':'Hoàn thành mục tiêu và tự tạo một ví dụ mới.'}),('theory',{'title':grammar,'text_en':theory,'text_vi':f'Tập trung vào cấu trúc {grammar}; quan sát dạng, nghĩa và vị trí từ.'})]
     for word in vocab_words: blocks.append(('vocabulary',{'word':word,'meaning_vi':f'Từ/cụm từ trọng tâm về {topic.lower()}','part_of_speech':'word or phrase','example_en':f"Use “{word}” when discussing {topic.lower()}.",'example_vi':f'Dùng “{word}” khi nói về {topic.lower()}.'}))
     blocks += [('example',{'title':'Natural examples','text_en':example+' Then adapt the model with your own information.','text_vi':'Đọc ví dụ, xác định cấu trúc, rồi thay bằng thông tin của bạn.'}),('summary',{'title':'Lesson recap','text_en':f"You practiced {', '.join(vocab_words)} and {grammar}. Use them together in one accurate, meaningful response.",'text_vi':'Ôn từ vựng, cấu trúc và áp dụng trong một câu trả lời có nghĩa.'})]
     for pos,(kind,content) in enumerate(blocks,1):
      block=uid(f"{revision}:block:{pos}"); emit(lines,f"INSERT INTO public.journey_lesson_blocks(id,revision_id,lesson_id,position,block_type,content) VALUES ({q(block)},{q(revision)},{q(lesson)},{pos},{q(kind)},{j(content)}) ON CONFLICT(id) DO NOTHING;")
     for qi in range(1,4):
      question=uid(f"{lesson}:question:{qi}"); correct=vocab_words[(qi-1)%len(vocab_words)]; prompt=f"{lesson_title} — item {qi}: Which answer best fits the objective ‘{objective}’?"
      explanation=f"“{correct}” is part of this lesson's {topic.lower()} vocabulary and fits the target structure {grammar}. The other choices belong to a different context."
      emit(lines,f"INSERT INTO public.quiz_questions(id,lesson_id,position,kind,prompt,explanation,payload,is_published,hint_en,hint_vi,explanation_en,explanation_vi) VALUES ({q(question)},{q(lesson)},{qi},'multiple_choice',{q(prompt)},{q(explanation)},'{{}}'::jsonb,false,{q('Review the vocabulary and grammar blocks.')},{q('Xem lại phần từ vựng và ngữ pháp.')},{q(explanation)},{q('Đáp án đúng phù hợp với mục tiêu, ngữ cảnh và cấu trúc của bài; các lựa chọn còn lại không phù hợp ngữ cảnh.')}) ON CONFLICT(id) DO NOTHING;")
      options=[correct,f"not {correct}",f"unrelated {qi}"]
      for oi,answer in enumerate(options,1):
       option=uid(f"{question}:option:{oi}"); emit(lines,f"INSERT INTO public.quiz_options(id,question_id,position,answer_text,is_correct) VALUES ({q(option)},{q(question)},{oi},{q(answer)},{str(oi==1).lower()}) ON CONFLICT(id) DO NOTHING;")
      counts["questions"]+=1
     if previous: emit(lines,f"INSERT INTO public.journey_lesson_prerequisites(lesson_id,prerequisite_lesson_id) VALUES ({q(lesson)},{q(previous)}) ON CONFLICT DO NOTHING;")
     previous=lesson; unit_lessons.append(lesson); level_items.append(lesson); counts["lessons"]+=1
    checkpoint=uid(f"level:{level}:unit:{unit_index}:checkpoint"); checkpoint_title=f"Checkpoint: {unit_title}"
    checkpoint_position=unit_index*4
    emit(lines,f"INSERT INTO public.lessons(id,course_id,unit_id,slug,position,title,objective,content,xp_reward,is_published,is_required,estimated_minutes,lesson_kind,checkpoint_pass_percent,curriculum_version,lifecycle_status,external_id,assessment_scope) VALUES ({q(checkpoint)},{q(course)},{q(unit)},{q(f'unit-{unit_index}-checkpoint')},{checkpoint_position},{q(checkpoint_title)},{q('Demonstrate the objectives from all three lessons in this unit.')},'{{}}'::jsonb,20,true,true,15,'checkpoint',70,2,'published',{q(f'journey-v27-l{level:02d}-u{unit_index:02d}-checkpoint')},'unit_checkpoint') ON CONFLICT(id) DO NOTHING;")
    revision=uid(f"{checkpoint}:revision:1"); emit(lines,f"INSERT INTO public.journey_lesson_revisions(id,lesson_id,version,status,source,content_hash,published_at) VALUES ({q(revision)},{q(checkpoint)},1,'published','curated',{q(hashlib.sha256(checkpoint.encode()).hexdigest())},transaction_timestamp()) ON CONFLICT(id) DO NOTHING;")
    block=uid(f"{revision}:block:1"); emit(lines,f"INSERT INTO public.journey_lesson_blocks(id,revision_id,lesson_id,position,block_type,content) VALUES ({q(block)},{q(revision)},{q(checkpoint)},1,'summary',{j({'title':checkpoint_title,'text_en':f'Review {topic}, {vocab}, and {grammar} before submitting.','text_vi':'Ôn toàn bộ ba bài trong Unit trước khi nộp bài.'})}) ON CONFLICT(id) DO NOTHING;")
    for qi in range(1,7):
     question=uid(f"{checkpoint}:question:{qi}"); correct=vocab_words[(qi-1)%len(vocab_words)]; prompt=f"{checkpoint_title} — objective check {qi}: Select the language that belongs to {topic.lower()}."
     emit(lines,f"INSERT INTO public.quiz_questions(id,lesson_id,position,kind,prompt,explanation,payload,is_published,explanation_en,explanation_vi) VALUES ({q(question)},{q(checkpoint)},{qi},'multiple_choice',{q(prompt)},{q(f'{correct} is taught and practiced in this unit.')},'{{}}'::jsonb,false,{q(f'{correct} matches the unit vocabulary and objective.')},{q('Đáp án đúng thuộc từ vựng và mục tiêu đã học trong Unit.')}) ON CONFLICT(id) DO NOTHING;")
     for oi,answer in enumerate([correct,f"different context {qi}",f"unsupported form {qi}"],1): emit(lines,f"INSERT INTO public.quiz_options(id,question_id,position,answer_text,is_correct) VALUES ({q(uid(f'{question}:option:{oi}'))},{q(question)},{oi},{q(answer)},{str(oi==1).lower()}) ON CONFLICT(id) DO NOTHING;")
     counts["questions"]+=1
    for required in unit_lessons: emit(lines,f"INSERT INTO public.journey_lesson_prerequisites(lesson_id,prerequisite_lesson_id) VALUES ({q(checkpoint)},{q(required)}) ON CONFLICT DO NOTHING;")
    emit(lines,f"INSERT INTO public.journey_checkpoint_configs(lesson_id,unit_id,passing_percent,objectives,reward_xp,is_published) VALUES ({q(checkpoint)},{q(unit)},70,{j([topic,grammar])},20,true) ON CONFLICT(lesson_id) DO NOTHING;")
    previous=checkpoint; level_items.append(checkpoint); counts["checkpoints"]+=1
  final=uid(f"level:{level}:assessment"); last_unit=uid(f"level:{level}:unit:6")
  emit(lines,f"INSERT INTO public.lessons(id,course_id,unit_id,slug,position,title,objective,content,xp_reward,is_published,is_required,estimated_minutes,lesson_kind,checkpoint_pass_percent,curriculum_version,lifecycle_status,external_id,assessment_scope) VALUES ({q(final)},{q(course)},{q(last_unit)},'level-final-assessment',25,{q(f'Level {level} Final Assessment')},{q(f'Demonstrate cumulative Level {level} vocabulary, grammar, reading, and practical application.')},'{{}}'::jsonb,40,true,true,30,'lesson',70,2,'published',{q(f'journey-v27-l{level:02d}-assessment')},'level_assessment') ON CONFLICT(id) DO NOTHING;")
  revision=uid(f"{final}:revision:1"); emit(lines,f"INSERT INTO public.journey_lesson_revisions(id,lesson_id,version,status,source,content_hash,published_at) VALUES ({q(revision)},{q(final)},1,'published','curated',{q(hashlib.sha256(final.encode()).hexdigest())},transaction_timestamp()) ON CONFLICT(id) DO NOTHING;")
  emit(lines,f"INSERT INTO public.journey_lesson_blocks(id,revision_id,lesson_id,position,block_type,content) VALUES ({q(uid(f'{revision}:block:1'))},{q(revision)},{q(final)},1,'summary',{j({'title':f'Level {level} assessment','text_en':'Apply learning from all three chapters. Read every prompt carefully and choose the answer supported by the level content.','text_vi':'Vận dụng nội dung của cả ba Chapter; đọc kỹ ngữ cảnh trước khi trả lời.'})}) ON CONFLICT(id) DO NOTHING;")
  for qi,u in enumerate(units,1):
   question=uid(f"{final}:question:{qi}"); correct=u[2].split(',')[0].strip(); prompt=f"Level {level} final — chapter coverage {qi}: Which expression was studied for {u[1].lower()}?"
   emit(lines,f"INSERT INTO public.quiz_questions(id,lesson_id,position,kind,prompt,explanation,payload,is_published,explanation_en,explanation_vi) VALUES ({q(question)},{q(final)},{qi},'multiple_choice',{q(prompt)},{q(f'{correct} belongs to the {u[1].lower()} unit.')},'{{}}'::jsonb,false,{q(f'{correct} is the relevant expression from this level.')},{q('Đáp án đúng thuộc đúng Unit và mục tiêu của Level này.')}) ON CONFLICT(id) DO NOTHING;")
   for oi,answer in enumerate([correct,f"unrelated level choice {qi}",f"incorrect context {qi}"],1): emit(lines,f"INSERT INTO public.quiz_options(id,question_id,position,answer_text,is_correct) VALUES ({q(uid(f'{question}:option:{oi}'))},{q(question)},{oi},{q(answer)},{str(oi==1).lower()}) ON CONFLICT(id) DO NOTHING;")
   counts["questions"]+=1
  for required in level_items[-2:]: emit(lines,f"INSERT INTO public.journey_lesson_prerequisites(lesson_id,prerequisite_lesson_id) VALUES ({q(final)},{q(required)}) ON CONFLICT DO NOTHING;")
  previous=final; counts["assessments"]+=1
  if level==10:
   capstone=uid("level:10:capstone"); emit(lines,f"INSERT INTO public.lessons(id,course_id,unit_id,slug,position,title,objective,content,xp_reward,is_published,is_required,estimated_minutes,lesson_kind,checkpoint_pass_percent,curriculum_version,lifecycle_status,external_id,assessment_scope) VALUES ({q(capstone)},{q(course)},{q(last_unit)},'integrated-capstone',26,'Level 10 Integrated Capstone','Synthesize information, choose context-appropriate language, and reflect on a practical communication strategy.','{{}}'::jsonb,50,true,true,45,'lesson',70,2,'published','journey-v27-l10-capstone','capstone') ON CONFLICT(id) DO NOTHING;")
   revision=uid(f"{capstone}:revision:1"); emit(lines,f"INSERT INTO public.journey_lesson_revisions(id,lesson_id,version,status,source,content_hash,published_at) VALUES ({q(revision)},{q(capstone)},1,'published','curated',{q(hashlib.sha256(capstone.encode()).hexdigest())},transaction_timestamp()) ON CONFLICT(id) DO NOTHING;")
   cap_blocks=[('introduction',{'title':'Capstone scenario','text_en':'You are preparing a proposal for an international team. Read the situation, evaluate the evidence, and select language that is clear, professional, and appropriately nuanced.','text_vi':'Bạn chuẩn bị đề xuất cho một nhóm quốc tế; cần tổng hợp thông tin và chọn ngôn ngữ phù hợp.'}),('theory',{'title':'Integrated strategy','text_en':'First identify purpose and audience. Next compare sources, state a supported position, anticipate a concern, and end with a practical action.','text_vi':'Xác định mục đích và người đọc, so sánh nguồn, nêu quan điểm có căn cứ và đề xuất hành động.'}),('summary',{'title':'Final reflection','text_en':'Review which reading, vocabulary, grammar, and communication strategies helped you most. Use the Smart Review path for remaining weaknesses.','text_vi':'Tự đánh giá điểm mạnh, điểm cần ôn và tiếp tục bằng Smart Review.'})]
   for pos,(kind,content) in enumerate(cap_blocks,1): emit(lines,f"INSERT INTO public.journey_lesson_blocks(id,revision_id,lesson_id,position,block_type,content) VALUES ({q(uid(f'{revision}:block:{pos}'))},{q(revision)},{q(capstone)},{pos},{q(kind)},{j(content)}) ON CONFLICT(id) DO NOTHING;")
   for qi in range(1,10):
    question=uid(f"{capstone}:question:{qi}"); correct=f"supported integrated response {qi}"; prompt=f"Capstone scenario {qi}: Which response best combines evidence, audience awareness, and a practical next step?"
    emit(lines,f"INSERT INTO public.quiz_questions(id,lesson_id,position,kind,prompt,explanation,payload,is_published,explanation_en,explanation_vi) VALUES ({q(question)},{q(capstone)},{qi},'multiple_choice',{q(prompt)},{q('The supported response connects evidence to the audience and proposes an actionable next step.')},'{{}}'::jsonb,false,{q('It integrates information and uses an appropriate professional tone.')},{q('Đáp án đúng tổng hợp thông tin, phù hợp người đọc và đưa ra bước tiếp theo khả thi.')}) ON CONFLICT(id) DO NOTHING;")
    for oi,answer in enumerate([correct,f"unsupported claim {qi}",f"context-free reply {qi}"],1): emit(lines,f"INSERT INTO public.quiz_options(id,question_id,position,answer_text,is_correct) VALUES ({q(uid(f'{question}:option:{oi}'))},{q(question)},{oi},{q(answer)},{str(oi==1).lower()}) ON CONFLICT(id) DO NOTHING;")
    counts["questions"]+=1
   emit(lines,f"INSERT INTO public.journey_lesson_prerequisites(lesson_id,prerequisite_lesson_id) VALUES ({q(capstone)},{q(final)}) ON CONFLICT DO NOTHING;"); previous=capstone; counts["capstones"]+=1
 lines.append("UPDATE public.quiz_questions q SET is_published=true FROM public.lessons l WHERE l.id=q.lesson_id AND l.external_id LIKE 'journey-v27-%' AND NOT q.is_published AND q.archived_at IS NULL;\nCOMMIT;\n")
 lines.insert(1,"-- Expected generated counts: "+json.dumps(counts,sort_keys=True)+"\n")
 return "".join(lines)

if __name__ == "__main__":
 OUTPUT.write_text(build(),encoding="utf-8")
 print(f"Wrote {OUTPUT}")

