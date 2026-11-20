-- Reviewed Journey Unit exercises. Preserve attempted question and option IDs.
DO $journey$
DECLARE
  item record;
  original public.quiz_questions%ROWTYPE;
BEGIN
  FOR item IN SELECT * FROM jsonb_to_recordset('[{"prompt":"We have a meeting on the 5th of July. Today is the 4th, so the meeting is ______.","choices":["tomorrow","yesterday","today"],"correct_index":0,"explanation_vi":"Ngày 4 là hôm nay, vì vậy ngày 5 là ngày mai.","old_id":"3da366ed-173c-55fc-8ee3-ef17f60511b2","new_id":"c36954fb-15ae-5e4d-8723-dd69d04cc135"},{"prompt":"Today is Tuesday. My birthday is tomorrow. Is it on a ______?","choices":["Saturday","Wednesday","Sunday"],"correct_index":1,"explanation_vi":"Ngày ngay sau thứ Ba là thứ Tư.","old_id":"f1245e5c-4ea3-5d13-81fe-749d27d80ed5","new_id":"b27cdd7e-cb2d-5c4b-8240-223aea343e30"},{"prompt":"There are seven ______ in a week: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, and Sunday.","choices":["days","dates","months"],"correct_index":0,"explanation_vi":"Từ thứ Hai đến Chủ Nhật là các ngày trong tuần.","old_id":"8d54fb87-8e68-5a16-8635-aca58b0ab59f","new_id":"4191fd78-a6f9-5428-b1c0-4e2a36376cea"},{"prompt":"I have one brother, but she has three ______.","choices":["brother","brothers","brotheres"],"correct_index":1,"explanation_vi":"Khi số lượng lớn hơn một, danh từ phải ở dạng số nhiều (thêm s).","old_id":"6c567668-593e-5bec-aea4-e08e04b9a6c5","new_id":"eb8ccffc-5d5b-5e1d-923d-5649ef1c7028"},{"prompt":"The library has one book on the table and two ______ on the shelf.","choices":["bookes","books","book"],"correct_index":1,"explanation_vi":"Vì có hai cuốn sách nên danh từ phải ở dạng số nhiều là books.","old_id":"2795325a-950f-540f-ab9a-cfdf7259c3b3","new_id":"f66e37c6-7887-545a-817d-a13c302f14ec"},{"prompt":"Today is the ______ of October.","choices":["once","one","first"],"correct_index":2,"explanation_vi":"Khi nói về ngày trong tháng, chúng ta sử dụng số thứ tự (first).","old_id":"ace68924-6686-5ba7-b866-58087bcca36d","new_id":"8123ea18-ec85-5e2b-b573-ba388daac1af"},{"prompt":"A: What is today''s date?\nB: It is ______.","choices":["Monday","the three","the 12th of May"],"correct_index":2,"explanation_vi":"Câu hỏi về ngày tháng cần một câu trả lời chỉ ngày cụ thể trong tháng.","old_id":"e777a1c5-b2f7-5670-8dac-2220d5e4dd8a","new_id":"3ae2768f-dc7a-596f-bb77-d6ab20e833d7"},{"prompt":"A: When is your class?\nB: It is ______.","choices":["in the number","at twenty","on Tuesday"],"correct_index":2,"explanation_vi":"Để nói về thời gian diễn ra sự kiện trong tuần, chúng ta dùng giới từ ''on'' kèm theo thứ.","old_id":"39cd2b6b-fec9-586a-a2ee-df8390c8a0e4","new_id":"1608010f-a07a-597f-a41b-305651096a1c"},{"prompt":"A: How many pens do you have?\nB: I have ______.","choices":["the 5th","four pens","a Friday"],"correct_index":1,"explanation_vi":"Câu hỏi ''How many'' yêu cầu câu trả lời là số lượng đồ vật.","old_id":"558ce8a5-0b44-5ca8-9077-78eeebebf25b","new_id":"1a988ec9-227a-54be-b27e-9f8de26591e8"},{"prompt":"The trip takes three ______. Complete the sentence with the plural of ''day''.","choices":["days","dayes","day"],"correct_index":0,"explanation_vi":"Dạng số nhiều của ''day'' là ''days''.","old_id":"3a0f1fbb-f507-5752-be7e-d9b76df54a38","new_id":"b71acbdd-d747-53bb-8384-9857939515d3"},{"prompt":"Your work schedule runs from Monday to Friday. The first workday is ______.","choices":["Sunday","Monday","Friday"],"correct_index":1,"explanation_vi":"Theo quy ước thông thường trong lịch làm việc, thứ Hai là ngày đầu tiên của tuần.","old_id":"f1351fa1-8440-5de4-b4d6-7f1d900103bb","new_id":"58d14b35-ea7a-54a3-ac22-d89cb98c9d73"},{"prompt":"If today is Friday, tomorrow is ______.","choices":["Sunday","Thursday","Saturday"],"correct_index":2,"explanation_vi":"Ngày tiếp sau thứ Sáu là thứ Bảy.","old_id":"16da20ee-3b76-5373-9751-89a884396f66","new_id":"8acf1b92-4118-531c-b9aa-3f4d3096cb52"},{"prompt":"What comes after the number 19?","choices":["eighteen","thirty","twenty"],"correct_index":2,"explanation_vi":"Số tiếp theo sau 19 là 20.","old_id":"f173164b-4da3-56c1-9d5d-6feecd4949e4","new_id":"ac13c21e-dfaa-5a45-b434-46be37a41ab0"},{"prompt":"Which option is a date?","choices":["the 20th of August","the ten days","the two books"],"correct_index":0,"explanation_vi":"Ngày tháng bao gồm ngày cụ thể và tên tháng.","old_id":"a257c62c-1d73-50f1-badb-a5f0e373a2ec","new_id":"8fe54673-141a-515f-8232-cca1ec471d1d"},{"prompt":"Choose the correct singular noun.","choices":["month","months","dates"],"correct_index":0,"explanation_vi":"''Month'' là danh từ số ít, còn ''months'' và ''dates'' là số nhiều.","old_id":"136f0dd6-9c05-5675-a4b3-3e5c1c0bd1df","new_id":"d4375e08-ef93-5c30-8477-9ef19c376a83"}]'::jsonb)
    AS draft(old_id uuid, new_id uuid, prompt text, choices jsonb, correct_index integer, explanation_vi text)
  LOOP
    IF EXISTS (SELECT 1 FROM public.quiz_questions WHERE id=item.new_id AND is_published AND archived_at IS NULL) THEN
      CONTINUE;
    END IF;
    UPDATE public.quiz_questions
    SET archived_at=transaction_timestamp(), is_published=false
    WHERE id=item.old_id AND archived_at IS NULL AND is_published AND kind='multiple_choice'
    RETURNING * INTO original;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Expected published generated question %', item.old_id;
    END IF;

    INSERT INTO public.quiz_questions(id, lesson_id, position, kind, prompt, explanation, explanation_vi, is_published)
    VALUES(item.new_id, original.lesson_id, original.position+20, 'multiple_choice',
      item.prompt, item.explanation_vi, item.explanation_vi, false);

    INSERT INTO public.quiz_options(question_id, position, answer_text, is_correct)
    SELECT item.new_id, choice.position::int, choice.answer, choice.position=item.correct_index+1
    FROM jsonb_array_elements_text(item.choices) WITH ORDINALITY AS choice(answer, position);

    UPDATE public.quiz_questions SET is_published=true WHERE id=item.new_id;
  END LOOP;
END
$journey$;
