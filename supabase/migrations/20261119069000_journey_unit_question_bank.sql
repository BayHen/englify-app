-- Reviewed Journey Unit exercises. Preserve attempted question and option IDs.
DO $journey$
DECLARE
  item record;
  original public.quiz_questions%ROWTYPE;
BEGIN
  FOR item IN SELECT * FROM jsonb_to_recordset('[
  {
    "prompt": "Look at the letter ''B''. What is the most common sound it makes in a word like ''bat''?",
    "choices": [
      "/p/",
      "/b/",
      "/d/"
    ],
    "correct_index": 1,
    "explanation_vi": "Âm /b/ là âm cơ bản đại diện cho chữ cái ''B'' trong từ ''bat''.",
    "old_id": "ca4be556-b2dc-55a0-bfdf-11dbad66e7ea",
    "new_id": "364ddaba-9723-5fde-889b-66ba04612e2e"
  },
  {
    "prompt": "If you want to know how to write a word correctly, what do you ask a friend?",
    "choices": [
      "What is this sound?",
      "Is this a letter?",
      "How do you spell it?"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''How do you spell it?'' được dùng khi muốn hỏi cách viết chính tả của một từ.",
    "old_id": "30e8982b-9aaa-567b-b233-18c566bc7b64",
    "new_id": "06cc4200-5ccc-51be-becd-c1e578a97e47"
  },
  {
    "prompt": "Which of these is a letter of the English alphabet?",
    "choices": [
      "Z",
      "Apple",
      "Sound"
    ],
    "correct_index": 0,
    "explanation_vi": "Z là một chữ cái trong bảng chữ cái tiếng Anh, trong khi các từ còn lại là từ vựng hoặc khái niệm.",
    "old_id": "fc1c9381-320b-5558-9a9e-824d9524884e",
    "new_id": "51e8c952-8493-5ad5-b32d-b6dcae79a96f"
  },
  {
    "prompt": "Your teacher says /b/ aloud. Which sentence describes what you do with your ears?",
    "choices": [
      "I write the sound.",
      "I hear the sound.",
      "I make a spell."
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''hear the sound'' diễn tả việc lắng nghe và nhận diện âm thanh của chữ cái.",
    "old_id": "2481bdb9-5531-56fe-acc6-704410f42b81",
    "new_id": "4fdf0a87-4563-5e60-89b8-4cadbe4a360e"
  },
  {
    "prompt": "Complete the sentence: ''The letter A __________ the sound /æ/ in apple.''",
    "choices": [
      "make",
      "makes",
      "spells"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''makes'' chia ở ngôi thứ ba số ít cho chủ ngữ ''The letter A''.",
    "old_id": "eed61eaf-893b-53c6-8e57-c46f23900583",
    "new_id": "e664b1a7-05a1-53ec-99b5-a8aff6c8829b"
  },
  {
    "prompt": "Which phrase is grammatically correct to describe a letter?",
    "choices": [
      "This are a letter.",
      "These is a sound.",
      "That is a sound."
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng ''That is a...'' là đúng ngữ pháp khi chỉ một chữ cái duy nhất.",
    "old_id": "8f95fea2-c419-5e23-a030-e83eb98bce3f",
    "new_id": "3cdfeb54-57a8-54d2-b48d-a8627d4cfc27"
  },
  {
    "prompt": "Person A: ''What letter is this?'' Person B: ''__________''",
    "choices": [
      "It makes M.",
      "I spell M.",
      "It is letter M."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời ''It is letter M'' cung cấp thông tin chính xác cho câu hỏi định danh chữ cái.",
    "old_id": "c1ff238f-cec2-54e1-be95-cd89d9c31a3c",
    "new_id": "a837e193-d457-576d-91e4-e07e086d5371"
  },
  {
    "prompt": "Person A: ''How do you spell cat?'' Person B: ''__________''",
    "choices": [
      "It is a sound.",
      "I know the letter.",
      "C-A-T."
    ],
    "correct_index": 2,
    "explanation_vi": "Việc đánh vần các chữ cái tạo nên từ ''cat'' là câu trả lời trực tiếp cho câu hỏi ''How do you spell''.",
    "old_id": "b1ecb3c5-422b-5f3b-a630-8d01f3240262",
    "new_id": "44117663-af08-59fa-bcd5-9e3d4123c892"
  },
  {
    "prompt": "Pointing to the T in ''top'', A asks, ''Does this letter make a /t/ sound?'' B replies, ''__________''",
    "choices": [
      "Yes, it does.",
      "Yes, it letter.",
      "No, it spell."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời ''Yes, it does'' phù hợp với câu hỏi bắt đầu bằng trợ động từ ''Does''.",
    "old_id": "05a0fec1-f82d-57f0-bab7-730d601c4ab1",
    "new_id": "c67f6e1f-5187-579e-8530-13c443950360"
  },
  {
    "prompt": "Which letter comes right before ''B'' in the alphabet?",
    "choices": [
      "A",
      "C",
      "D"
    ],
    "correct_index": 0,
    "explanation_vi": "Chữ cái A nằm ngay trước B trong thứ tự bảng chữ cái.",
    "old_id": "bdc118c8-108c-57b5-b644-fec109ac78f4",
    "new_id": "4b769c4e-f09f-573c-b280-ba1ad18561c1"
  },
  {
    "prompt": "If you hear the /s/ sound at the start of ''sun'', which letter is it?",
    "choices": [
      "S",
      "C",
      "T"
    ],
    "correct_index": 0,
    "explanation_vi": "Âm /s/ trong từ ''sun'' được thể hiện bằng chữ cái S.",
    "old_id": "218b6ef8-e064-5fea-983e-04d91170ef5f",
    "new_id": "29a27dc9-8243-5480-9854-f60a1517b514"
  },
  {
    "prompt": "What is the primary purpose of learning letter sounds?",
    "choices": [
      "To count letters.",
      "To read new words.",
      "To change the alphabet."
    ],
    "correct_index": 1,
    "explanation_vi": "Việc học âm của chữ cái giúp người học kết hợp chúng lại để đọc các từ mới.",
    "old_id": "01cc68d6-b6d5-5617-bee6-1ce788550ff7",
    "new_id": "654154c1-67ba-5ab9-9d21-7bd52b45d748"
  },
  {
    "prompt": "How many letters are in the English word ''dog''?",
    "choices": [
      "Two",
      "One",
      "Three"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''dog'' được cấu tạo bởi ba chữ cái riêng biệt là D, O, và G.",
    "old_id": "a2b31239-481a-5b2d-ad44-2cb07b8a8077",
    "new_id": "738ba1e0-58f5-5ec8-a756-4f866fcb88eb"
  },
  {
    "prompt": "Which letter represents the /m/ sound?",
    "choices": [
      "N",
      "M",
      "W"
    ],
    "correct_index": 1,
    "explanation_vi": "Chữ cái M là biểu tượng chính cho âm mũi /m/.",
    "old_id": "4e53cbff-4eb1-5723-bc24-1a29d6f9ae97",
    "new_id": "3e6239f7-1a3f-5536-9bfa-0ba958bbce29"
  },
  {
    "prompt": "Which word describes the action of saying each letter of a word in order?",
    "choices": [
      "Spelling",
      "Sounding",
      "Listening"
    ],
    "correct_index": 0,
    "explanation_vi": "Hành động nêu tên các chữ cái theo thứ tự của một từ được gọi là đánh vần (spelling).",
    "old_id": "411117dd-7102-526e-9db4-0d64baa70108",
    "new_id": "b24e456e-70c4-54d1-a158-ae855af4921e"
  },
  {
    "prompt": "Which sentence correctly introduces a person?",
    "choices": [
      "I am Tom.",
      "I are Tom.",
      "Tom am I."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu ''I am Tom'' tuân thủ đúng quy tắc ngữ pháp chủ ngữ và động từ to be.",
    "old_id": "ee085156-a1e8-571f-9efe-f72cdb40997b",
    "new_id": "7a9840a1-eaee-581a-a585-399e711b929d"
  },
  {
    "prompt": "Pick the correct way to talk to someone else.",
    "choices": [
      "You am Sam.",
      "You are Sam.",
      "Sam are you."
    ],
    "correct_index": 1,
    "explanation_vi": "Đại từ ''You'' đi kèm với động từ ''are''.",
    "old_id": "ee70f250-9c53-593e-85df-68c14202615f",
    "new_id": "fdee9672-a090-599d-abf5-5bae27ddf6ca"
  },
  {
    "prompt": "Choose the best response to ''Hello, I am Lucy.''",
    "choices": [
      "I am Sam.",
      "Hello from.",
      "You are Sam."
    ],
    "correct_index": 0,
    "explanation_vi": "Khi ai đó giới thiệu tên họ, cách đáp lại tự nhiên nhất là giới thiệu tên của bạn.",
    "old_id": "c1a1f69a-d8d7-5a25-9c52-9714a3c9e02e",
    "new_id": "bb01114e-e3c9-5187-b167-5e1fad5910dd"
  },
  {
    "prompt": "Which option is correct for a greeting?",
    "choices": [
      "Name hello!",
      "I am from hello.",
      "Hello, I am Li."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu ''Hello, I am Li'' là cách chào hỏi và giới thiệu chuẩn mực.",
    "old_id": "9650e4d3-6206-5443-bde2-a8c18be62549",
    "new_id": "66f8508d-8127-5449-9d68-ed50d419a000"
  },
  {
    "prompt": "Select the correct sentence.",
    "choices": [
      "Italy am I from.",
      "I from am Italy.",
      "I am from Italy."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu này sắp xếp đúng trật tự chủ ngữ, động từ và tân ngữ chỉ nơi chốn.",
    "old_id": "29e11804-5eee-55b7-b762-5aedb6689998",
    "new_id": "6a5ca792-5c5e-5527-834a-764787696711"
  },
  {
    "prompt": "What is the best way to ask someone''s identity?",
    "choices": [
      "Hello, I am you?",
      "Hello, you are?",
      "Hello, name?"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ ''You are?'' dùng để xác nhận danh tính hoặc tên của người đối diện.",
    "old_id": "ecfecf0f-793f-5b1e-8459-f304df395ab1",
    "new_id": "8c23c8c0-553f-5ae3-865c-4c7218b775d6"
  },
  {
    "prompt": "The cat is sleeping on the chair. ________ is very tired.",
    "choices": [
      "He",
      "She",
      "It"
    ],
    "correct_index": 2,
    "explanation_vi": "Con vật (con mèo) được thay thế bằng đại từ ''It'' trong ngữ cảnh này.",
    "old_id": "924d7dad-cd4c-5328-9f1d-e529fb854e2f",
    "new_id": "dd147f61-03b1-5fc9-976a-75f6e4696b2c"
  },
  {
    "prompt": "My mother works at the hospital. ________ is a doctor.",
    "choices": [
      "It",
      "She",
      "He"
    ],
    "correct_index": 1,
    "explanation_vi": "Mẹ là nữ giới nên ta dùng đại từ ''She''.",
    "old_id": "4ceafcde-aac0-53e6-b69d-b13c1d5e5bad",
    "new_id": "10a547e2-de58-566d-a984-0902356d1c6b"
  },
  {
    "prompt": "Look at those books. ________ are very interesting.",
    "choices": [
      "They",
      "We",
      "It"
    ],
    "correct_index": 0,
    "explanation_vi": "Những cuốn sách là số nhiều, vì vậy dùng ''They'' để thay thế.",
    "old_id": "c60a7f11-3d7f-5323-b8ed-6882d123ab34",
    "new_id": "213c68ad-f958-553a-a1f5-fe302fd070ac"
  },
  {
    "prompt": "The library is a quiet ________ where we study.",
    "choices": [
      "object",
      "place",
      "person"
    ],
    "correct_index": 1,
    "explanation_vi": "Thư viện là một địa điểm nên dùng ''place''.",
    "old_id": "08b34f5e-23f0-538f-8470-04dfe7269dde",
    "new_id": "91842e3e-ed68-512c-a227-711a4787ca5f"
  },
  {
    "prompt": "This cup is blue. ________ is on the desk.",
    "choices": [
      "He",
      "It",
      "We"
    ],
    "correct_index": 1,
    "explanation_vi": "Cái cốc là đồ vật nên dùng ''It''.",
    "old_id": "3d420b68-42cd-5219-a786-72703f40358c",
    "new_id": "bea21b4f-b30f-5862-a38b-208b7345fc09"
  },
  {
    "prompt": "Mr. Lee is a nice ________. He works in the bank.",
    "choices": [
      "object",
      "person",
      "place"
    ],
    "correct_index": 1,
    "explanation_vi": "Ông Lee là một con người nên dùng ''person''.",
    "old_id": "4845dc7d-a37a-5995-8b85-7d840a2a1358",
    "new_id": "5757972f-3616-5e3f-b45f-72d603c648f6"
  },
  {
    "prompt": "We have a meeting on the 5th of July. Today is the 4th, so the meeting is ______.",
    "choices": [
      "tomorrow",
      "yesterday",
      "today"
    ],
    "correct_index": 0,
    "explanation_vi": "Ngày 4 là hôm nay, vì vậy ngày 5 là ngày mai.",
    "old_id": "3da366ed-173c-55fc-8ee3-ef17f60511b2",
    "new_id": "c36954fb-15ae-5e4d-8723-dd69d04cc135"
  },
  {
    "prompt": "Today is Tuesday. My birthday is tomorrow. Is it on a ______?",
    "choices": [
      "Saturday",
      "Wednesday",
      "Sunday"
    ],
    "correct_index": 1,
    "explanation_vi": "Ngày ngay sau thứ Ba là thứ Tư.",
    "old_id": "f1245e5c-4ea3-5d13-81fe-749d27d80ed5",
    "new_id": "b27cdd7e-cb2d-5c4b-8240-223aea343e30"
  },
  {
    "prompt": "There are seven ______ in a week: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, and Sunday.",
    "choices": [
      "days",
      "dates",
      "months"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ thứ Hai đến Chủ Nhật là các ngày trong tuần.",
    "old_id": "8d54fb87-8e68-5a16-8635-aca58b0ab59f",
    "new_id": "4191fd78-a6f9-5428-b1c0-4e2a36376cea"
  },
  {
    "prompt": "I have one brother, but she has three ______.",
    "choices": [
      "brother",
      "brothers",
      "brotheres"
    ],
    "correct_index": 1,
    "explanation_vi": "Khi số lượng lớn hơn một, danh từ phải ở dạng số nhiều (thêm s).",
    "old_id": "6c567668-593e-5bec-aea4-e08e04b9a6c5",
    "new_id": "eb8ccffc-5d5b-5e1d-923d-5649ef1c7028"
  },
  {
    "prompt": "The library has one book on the table and two ______ on the shelf.",
    "choices": [
      "bookes",
      "books",
      "book"
    ],
    "correct_index": 1,
    "explanation_vi": "Vì có hai cuốn sách nên danh từ phải ở dạng số nhiều là books.",
    "old_id": "2795325a-950f-540f-ab9a-cfdf7259c3b3",
    "new_id": "f66e37c6-7887-545a-817d-a13c302f14ec"
  },
  {
    "prompt": "Today is the ______ of October.",
    "choices": [
      "once",
      "one",
      "first"
    ],
    "correct_index": 2,
    "explanation_vi": "Khi nói về ngày trong tháng, chúng ta sử dụng số thứ tự (first).",
    "old_id": "ace68924-6686-5ba7-b866-58087bcca36d",
    "new_id": "8123ea18-ec85-5e2b-b573-ba388daac1af"
  },
  {
    "prompt": "A: What is today''s date?\nB: It is ______.",
    "choices": [
      "Monday",
      "the three",
      "the 12th of May"
    ],
    "correct_index": 2,
    "explanation_vi": "Câu hỏi về ngày tháng cần một câu trả lời chỉ ngày cụ thể trong tháng.",
    "old_id": "e777a1c5-b2f7-5670-8dac-2220d5e4dd8a",
    "new_id": "3ae2768f-dc7a-596f-bb77-d6ab20e833d7"
  },
  {
    "prompt": "A: When is your class?\nB: It is ______.",
    "choices": [
      "in the number",
      "at twenty",
      "on Tuesday"
    ],
    "correct_index": 2,
    "explanation_vi": "Để nói về thời gian diễn ra sự kiện trong tuần, chúng ta dùng giới từ ''on'' kèm theo thứ.",
    "old_id": "39cd2b6b-fec9-586a-a2ee-df8390c8a0e4",
    "new_id": "1608010f-a07a-597f-a41b-305651096a1c"
  },
  {
    "prompt": "A: How many pens do you have?\nB: I have ______.",
    "choices": [
      "the 5th",
      "four pens",
      "a Friday"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu hỏi ''How many'' yêu cầu câu trả lời là số lượng đồ vật.",
    "old_id": "558ce8a5-0b44-5ca8-9077-78eeebebf25b",
    "new_id": "1a988ec9-227a-54be-b27e-9f8de26591e8"
  },
  {
    "prompt": "The trip takes three ______. Complete the sentence with the plural of ''day''.",
    "choices": [
      "days",
      "dayes",
      "day"
    ],
    "correct_index": 0,
    "explanation_vi": "Dạng số nhiều của ''day'' là ''days''.",
    "old_id": "3a0f1fbb-f507-5752-be7e-d9b76df54a38",
    "new_id": "b71acbdd-d747-53bb-8384-9857939515d3"
  },
  {
    "prompt": "Your work schedule runs from Monday to Friday. The first workday is ______.",
    "choices": [
      "Sunday",
      "Monday",
      "Friday"
    ],
    "correct_index": 1,
    "explanation_vi": "Theo quy ước thông thường trong lịch làm việc, thứ Hai là ngày đầu tiên của tuần.",
    "old_id": "f1351fa1-8440-5de4-b4d6-7f1d900103bb",
    "new_id": "58d14b35-ea7a-54a3-ac22-d89cb98c9d73"
  },
  {
    "prompt": "If today is Friday, tomorrow is ______.",
    "choices": [
      "Sunday",
      "Thursday",
      "Saturday"
    ],
    "correct_index": 2,
    "explanation_vi": "Ngày tiếp sau thứ Sáu là thứ Bảy.",
    "old_id": "16da20ee-3b76-5373-9751-89a884396f66",
    "new_id": "8acf1b92-4118-531c-b9aa-3f4d3096cb52"
  },
  {
    "prompt": "What comes after the number 19?",
    "choices": [
      "eighteen",
      "thirty",
      "twenty"
    ],
    "correct_index": 2,
    "explanation_vi": "Số tiếp theo sau 19 là 20.",
    "old_id": "f173164b-4da3-56c1-9d5d-6feecd4949e4",
    "new_id": "ac13c21e-dfaa-5a45-b434-46be37a41ab0"
  },
  {
    "prompt": "Which option is a date?",
    "choices": [
      "the 20th of August",
      "the ten days",
      "the two books"
    ],
    "correct_index": 0,
    "explanation_vi": "Ngày tháng bao gồm ngày cụ thể và tên tháng.",
    "old_id": "a257c62c-1d73-50f1-badb-a5f0e373a2ec",
    "new_id": "8fe54673-141a-515f-8232-cca1ec471d1d"
  },
  {
    "prompt": "Choose the correct singular noun.",
    "choices": [
      "month",
      "months",
      "dates"
    ],
    "correct_index": 0,
    "explanation_vi": "''Month'' là danh từ số ít, còn ''months'' và ''dates'' là số nhiều.",
    "old_id": "136f0dd6-9c05-5675-a4b3-3e5c1c0bd1df",
    "new_id": "d4375e08-ef93-5c30-8477-9ef19c376a83"
  },
  {
    "prompt": "In the sentence ''The cat eats the fish'', which word is the verb?",
    "choices": [
      "fish",
      "eats",
      "The"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ là từ chỉ hành động, trong câu này ''eats'' (ăn) là hành động.",
    "old_id": "f3de120e-03d8-5a6a-ab27-eb3ce2a5af1d",
    "new_id": "dcfb84a1-7d96-5f01-820e-b5f9d1d22781"
  },
  {
    "prompt": "Identify the subject in the sentence: ''Sarah reads a book.''",
    "choices": [
      "Sarah",
      "reads",
      "book"
    ],
    "correct_index": 0,
    "explanation_vi": "Chủ ngữ là người hoặc vật thực hiện hành động, ở đây là ''Sarah''.",
    "old_id": "8afd23a4-90fa-5a43-9214-d525bdd85579",
    "new_id": "2775230c-9bdf-5bcf-8489-455e367c3bdf"
  },
  {
    "prompt": "Which part of the sentence ''He drinks water'' is the object?",
    "choices": [
      "drinks",
      "He",
      "water"
    ],
    "correct_index": 2,
    "explanation_vi": "Tân ngữ là đối tượng nhận hành động, ''water'' là thứ bị uống.",
    "old_id": "684e0a04-a603-5852-b8fc-f02885efa566",
    "new_id": "0964c007-70ea-587a-b64d-bf44f1dd89d9"
  },
  {
    "prompt": "Choose the correct word order for an affirmative sentence.",
    "choices": [
      "Subject + Verb + Object",
      "Verb + Subject + Object",
      "Object + Verb + Subject"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc câu khẳng định cơ bản trong tiếng Anh là Chủ ngữ + Động từ + Tân ngữ.",
    "old_id": "020bd9eb-d6a5-5bf0-81cc-f581ab7a9302",
    "new_id": "df4f3489-5481-5e20-bd3a-8e736660bdf8"
  },
  {
    "prompt": "Select the correct sentence structure.",
    "choices": [
      "Football play they.",
      "Play they football.",
      "They play football."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu ''They play football'' tuân thủ đúng trật tự Chủ ngữ (They) + Động từ (play) + Tân ngữ (football).",
    "old_id": "4ac49d7f-b608-5035-9e53-7a7398f61491",
    "new_id": "146ea560-c8a3-5340-a92e-ef1056617485"
  },
  {
    "prompt": "Complete the sentence: ''The baby ____ milk.''",
    "choices": [
      "the baby",
      "milk",
      "drinks"
    ],
    "correct_index": 2,
    "explanation_vi": "Câu cần một động từ để nối chủ ngữ và tân ngữ, ''drinks'' phù hợp về ngữ pháp và nghĩa.",
    "old_id": "cf98d0fb-056b-5aa6-b21b-22671bab7afb",
    "new_id": "843dc0ca-20b8-52b5-a672-c6b1a05603a0"
  },
  {
    "prompt": "A: ''What does your brother do?'' B: ''He ____ a letter.''",
    "choices": [
      "a letter",
      "writes",
      "is"
    ],
    "correct_index": 1,
    "explanation_vi": "Cần một động từ để mô tả hành động của chủ ngữ ''He'' đối với ''a letter''.",
    "old_id": "fa2027cc-eb96-576d-9e7c-de971fd6cff0",
    "new_id": "61304cb7-c1ea-5ea1-b3bb-24af703cfaec"
  },
  {
    "prompt": "A: ''Who is eating the apple?'' B: ''____ is eating the apple.''",
    "choices": [
      "The apple",
      "The boy",
      "Eat"
    ],
    "correct_index": 1,
    "explanation_vi": "Cần một chủ ngữ chỉ người để thực hiện hành động ăn táo.",
    "old_id": "8e3b61ed-1050-58cd-a723-0c6ec6b0401d",
    "new_id": "765c0a18-5a72-5fa3-aa3b-e44284b7a2d5"
  },
  {
    "prompt": "A: ''What are you holding?'' B: ''I ____ a pen.''",
    "choices": [
      "pen",
      "you",
      "hold"
    ],
    "correct_index": 2,
    "explanation_vi": "Chủ ngữ ''I'' cần đi với động từ ''hold'' để tạo thành câu hoàn chỉnh.",
    "old_id": "2b595907-d1b6-502f-afdd-903e9fa2fd30",
    "new_id": "c169732c-75e8-5326-94ab-98aa4d14e731"
  },
  {
    "prompt": "Which sentence is written correctly?",
    "choices": [
      "Students teacher teaches.",
      "Teacher teaches students.",
      "Teaches teacher students."
    ],
    "correct_index": 1,
    "explanation_vi": "Chỉ có ''Teacher teaches students'' sắp xếp theo đúng trật tự Chủ ngữ - Động từ - Tân ngữ.",
    "old_id": "3eef342e-988e-5f80-949f-ed4e22cd9ef7",
    "new_id": "2cc6306c-4ee2-5ce9-8dad-fc4c96d3af2f"
  },
  {
    "prompt": "Choose the best fit: ''The chef ____ the meal.''",
    "choices": [
      "cooks",
      "the chef",
      "meal"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu này đang thiếu động từ để liên kết chủ ngữ ''The chef'' và tân ngữ ''the meal''.",
    "old_id": "a07ebdea-ce69-581a-8fbb-f96bca79cc74",
    "new_id": "257d8957-c2fd-55b8-a1cd-8c3fdaad2ac0"
  },
  {
    "prompt": "Select the sentence with the correct order.",
    "choices": [
      "Dog chases cat.",
      "Cat dog chases.",
      "Chases dog cat."
    ],
    "correct_index": 0,
    "explanation_vi": "Trật tự câu đúng là chủ ngữ ''Dog'', động từ ''chases'' và tân ngữ ''cat''.",
    "old_id": "71c7f364-7a49-573c-ae89-703b279acf08",
    "new_id": "c19a9098-a2f3-5a6c-a9bb-3d4432188796"
  },
  {
    "prompt": "Identify the correct structure for: ''She likes coffee.''",
    "choices": [
      "Subject + Verb + Object",
      "Object + Verb + Subject",
      "Verb + Subject + Object"
    ],
    "correct_index": 0,
    "explanation_vi": "''She'' là chủ ngữ, ''likes'' là động từ, ''coffee'' là tân ngữ, đúng theo công thức S-V-O.",
    "old_id": "7d71f98d-4578-5870-b280-a8ead6d62811",
    "new_id": "462c2245-70ec-5baa-8c9b-fc5a2aee88a3"
  },
  {
    "prompt": "Complete correctly: ''The birds ____ in the sky.''",
    "choices": [
      "birds",
      "the sky",
      "fly"
    ],
    "correct_index": 2,
    "explanation_vi": "Sau chủ ngữ ''The birds'', câu cần một động từ là ''fly'' để diễn tả hành động.",
    "old_id": "5566784d-e910-537a-b751-a334777d0412",
    "new_id": "a050bc27-95f4-5159-9c87-74b4c96fcb82"
  },
  {
    "prompt": "Which option makes a complete sentence?",
    "choices": [
      "The earth the sun warms.",
      "The sun warms the earth.",
      "Warms the sun earth."
    ],
    "correct_index": 1,
    "explanation_vi": "Đây là câu duy nhất tuân thủ đúng quy tắc trật tự từ chủ ngữ - động từ - tân ngữ.",
    "old_id": "d764c2ed-b8b2-504a-a41c-8b219cd3e8c7",
    "new_id": "f0e6877f-f7d6-545e-9687-9ae64b6e2b61"
  },
  {
    "prompt": "You meet a new student at the door. You want to ask for their name. You say: \"_____ is your name?\"",
    "choices": [
      "Where",
      "Who",
      "What"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''What'' để hỏi về thông tin hoặc tên của một người.",
    "old_id": "f658dd21-6f23-5d10-b855-f41384b7d8e1",
    "new_id": "c987a7eb-4a59-5706-a9e7-7f84c773045f"
  },
  {
    "prompt": "Someone is standing at your gate. You don''t know them. You ask: \"_____ are you?\"",
    "choices": [
      "Who",
      "What",
      "Where"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''Who'' khi muốn hỏi về danh tính của một người.",
    "old_id": "1e863d7a-597f-5667-bdf9-d13401749e3f",
    "new_id": "22e1eb09-1829-50e1-9f44-37b3c9e91aa2"
  },
  {
    "prompt": "You are lost in a city and need to know the name of the place. You ask: \"_____ is this?\"",
    "choices": [
      "Who",
      "What",
      "Where"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''Where'' để hỏi về địa điểm hoặc vị trí.",
    "old_id": "751ab123-8bd5-5f12-9386-a34701249d6d",
    "new_id": "e617465e-b4c2-595f-858e-9e0ae24b9b4d"
  },
  {
    "prompt": "Choose the correct sentence to ask about someone''s origin.",
    "choices": [
      "Where are you from?",
      "Where am you from?",
      "Where is you from?"
    ],
    "correct_index": 0,
    "explanation_vi": "Động từ ''be'' chia là ''are'' khi đi với chủ ngữ ''you''.",
    "old_id": "0beafd34-e856-5f76-a6bc-18dc0a41ea26",
    "new_id": "5d4097d6-c560-5799-94d3-ca3810264693"
  },
  {
    "prompt": "Complete the question: \"_____ she a new teacher?\"",
    "choices": [
      "Is",
      "Am",
      "Are"
    ],
    "correct_index": 0,
    "explanation_vi": "Chủ ngữ ngôi thứ ba số ít ''she'' phải đi với động từ ''is''.",
    "old_id": "354b1693-46c7-5a28-b11e-4f5213995cf7",
    "new_id": "97ab3e19-bf2f-5813-93b5-371b3ddff2a7"
  },
  {
    "prompt": "Complete the question: \"_____ they students in this class?\"",
    "choices": [
      "Am",
      "Are",
      "Is"
    ],
    "correct_index": 1,
    "explanation_vi": "Chủ ngữ số nhiều ''they'' đi với động từ ''are'' trong câu hỏi.",
    "old_id": "f54a8ddf-6c6b-5939-abb6-67e353abeb1b",
    "new_id": "09ed2c90-968d-50bc-8d4c-4f94873a5406"
  },
  {
    "prompt": "Person A: \"Hi, I am Tom.\" Person B: \"_____?\"",
    "choices": [
      "Where are you?",
      "Who are you?",
      "What is your name?"
    ],
    "correct_index": 1,
    "explanation_vi": "Khi được giới thiệu, hỏi ''Who are you?'' để biết danh tính người đối diện là tự nhiên nhất.",
    "old_id": "e9cd38c9-2bcf-58d5-913e-4eb44d28b30e",
    "new_id": "d7c029d4-7ed1-51e9-b9a6-f96779d4b65c"
  },
  {
    "prompt": "Person A: \"_____?\" Person B: \"I am from Vietnam.\"",
    "choices": [
      "Where are you from?",
      "What is your name?",
      "Who are you?"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời đề cập đến nguồn gốc (Vietnam) nên câu hỏi phù hợp là ''Where''.",
    "old_id": "17eaeb82-1e58-5714-8a83-f7b56abbcd78",
    "new_id": "9c1da6a6-8ea7-59b6-937b-70f39c2e7b8d"
  },
  {
    "prompt": "Person A: \"Is this your office?\" Person B: \"_____\"",
    "choices": [
      "Yes, you are.",
      "Yes, I am.",
      "Yes, it is."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu hỏi bắt đầu với ''Is this'' yêu cầu câu trả lời xác nhận về đồ vật bằng ''it is''.",
    "old_id": "870fe45b-9df6-5a9f-8b79-bc474d6b9e59",
    "new_id": "17d1cad7-1c10-51e2-8b54-b75bb6165122"
  },
  {
    "prompt": "Which sentence is grammatically correct to ask about identity?",
    "choices": [
      "Who am that person?",
      "Who is that person?",
      "Who are that person?"
    ],
    "correct_index": 1,
    "explanation_vi": " ''That person'' là chủ ngữ số ít, nên dùng ''is''.",
    "old_id": "298c039e-bdf2-52fb-9454-201558f91c03",
    "new_id": "d04b553e-93e1-5138-a70d-5c6859c00ee3"
  },
  {
    "prompt": "Choose the correct way to ask for a location.",
    "choices": [
      "Where the library is?",
      "Where are the library?",
      "Where is the library?"
    ],
    "correct_index": 2,
    "explanation_vi": "Trong câu hỏi trực tiếp, động từ ''is'' phải đứng trước chủ ngữ ''the library''.",
    "old_id": "f79a423f-3989-5ba5-bbc9-1cb2461af2d2",
    "new_id": "d84d30be-7dd1-5f35-9a78-ce1e51e8d49c"
  },
  {
    "prompt": "Complete the question: \"What _____ these?\"",
    "choices": [
      "are",
      "am",
      "is"
    ],
    "correct_index": 0,
    "explanation_vi": "Chủ ngữ số nhiều ''these'' đi với động từ ''are''.",
    "old_id": "379b6721-ae34-5f2f-a400-b1d0b272eb4a",
    "new_id": "5ba974dc-0a85-51ea-a45c-69a716d7ff9e"
  },
  {
    "prompt": "Select the correct option to complete: \"_____ you okay?\"",
    "choices": [
      "Is",
      "Am",
      "Are"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''to be'' đi với ''you'' luôn là ''are''.",
    "old_id": "05fb04f3-b4ae-5e0e-a18f-99f83443ee57",
    "new_id": "6c5b5919-4894-5e66-b6e0-aae51942b362"
  },
  {
    "prompt": "Which sentence correctly asks about an object?",
    "choices": [
      "Who is that in your hand?",
      "What is that in your hand?",
      "Where is that in your hand?"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng ''what'' để hỏi về vật thể.",
    "old_id": "b6b65e6d-733e-59fe-86e1-6bfc770fe5c8",
    "new_id": "0ab0cb68-c076-5665-9466-e77e6459931c"
  },
  {
    "prompt": "Fill in the blank: \"Where _____ they now?\"",
    "choices": [
      "am",
      "are",
      "is"
    ],
    "correct_index": 1,
    "explanation_vi": "Chủ ngữ ''they'' (họ) yêu cầu động từ ''are'' ở thì hiện tại.",
    "old_id": "bc0b86bf-eaf5-5ab2-82c3-d2307b8f71a4",
    "new_id": "a88b36fc-8f13-58b6-ab57-7f6d80863b3b"
  },
  {
    "prompt": "My mother and father are my _______.",
    "choices": [
      "siblings",
      "parents",
      "friends"
    ],
    "correct_index": 1,
    "explanation_vi": "Cha và mẹ được gọi chung là bố mẹ (parents).",
    "old_id": "19c34739-ffde-5d18-a892-af949e203d87",
    "new_id": "1671060f-ff8a-5bc5-a6b1-84ce771086e1"
  },
  {
    "prompt": "Anna and I study together at school. She is my best _______.",
    "choices": [
      "parent",
      "friend",
      "sibling"
    ],
    "correct_index": 1,
    "explanation_vi": "Người cùng học và thân thiết ở trường được gọi là bạn (friend).",
    "old_id": "11b84f67-b31e-5511-948a-4001c4961ea0",
    "new_id": "b0aa3cb8-38af-5d2e-b525-b33cdfe6affe"
  },
  {
    "prompt": "I have one brother. He is my only _______.",
    "choices": [
      "sibling",
      "friend",
      "parent"
    ],
    "correct_index": 0,
    "explanation_vi": "Anh hoặc em trai là anh chị em ruột, gọi chung là sibling.",
    "old_id": "337a2b56-99fb-5946-a52a-0d6577685e91",
    "new_id": "1a28ed48-ff5a-5334-b65a-2dffa2fe8ffb"
  },
  {
    "prompt": "This is Mark. _______ sister is a doctor.",
    "choices": [
      "My",
      "Her",
      "His"
    ],
    "correct_index": 2,
    "explanation_vi": "Vì Mark là nam giới, ta dùng tính từ sở hữu ''His''.",
    "old_id": "e188f1b9-ebcf-58b9-9cb4-d989a3a52bc9",
    "new_id": "7ce83f18-d6d5-55ed-a3e9-a80f3a42ce52"
  },
  {
    "prompt": "Sarah loves _______ dog. It is very cute.",
    "choices": [
      "her",
      "his",
      "their"
    ],
    "correct_index": 0,
    "explanation_vi": "Sarah là nữ giới nên ta dùng tính từ sở hữu ''her''.",
    "old_id": "4646e3bf-f3fe-52a8-902c-77bd3ec5ed62",
    "new_id": "8073ff60-cf9f-5c32-a80d-448b63bc99c0"
  },
  {
    "prompt": "We live in a big house. _______ family is very happy.",
    "choices": [
      "My",
      "Their",
      "Our"
    ],
    "correct_index": 2,
    "explanation_vi": "Chủ ngữ là ''We'' (chúng tôi) nên tính từ sở hữu tương ứng là ''Our''.",
    "old_id": "c0e045d0-cd6a-5ab6-a2a3-c656203f5fab",
    "new_id": "b28f8919-8288-5975-80ab-b0ef90728a79"
  },
  {
    "prompt": "A: Who is that man? B: That is _______ father.",
    "choices": [
      "I",
      "me",
      "my"
    ],
    "correct_index": 2,
    "explanation_vi": "Cần tính từ sở hữu ''my'' để chỉ mối quan hệ gia đình của người nói.",
    "old_id": "5cb94c26-a9de-5d87-b408-c515956bb744",
    "new_id": "04ebb99b-0ea2-5f6d-b9bf-19a177ecd6fb"
  },
  {
    "prompt": "A: Is this your sibling? B: Yes, _______ name is Tom.",
    "choices": [
      "Her",
      "His",
      "Its"
    ],
    "correct_index": 1,
    "explanation_vi": "Tom là nam giới nên ta sử dụng ''His'' để chỉ tên của anh ấy.",
    "old_id": "faf0492f-6ed9-51ee-846f-958813ddb34e",
    "new_id": "8174cf06-b6a6-5628-87cf-9331b81c8d02"
  },
  {
    "prompt": "A: Are those your friends? B: Yes, they are _______ friends.",
    "choices": [
      "our",
      "my",
      "your"
    ],
    "correct_index": 1,
    "explanation_vi": "Người nói đang khẳng định về những người bạn của chính mình nên dùng ''my''.",
    "old_id": "1dc6476f-ac8a-5b2f-ae09-7785f63c0631",
    "new_id": "6833747a-5f4e-5436-9e80-61c6a3f555b0"
  },
  {
    "prompt": "My _______ is my mother''s sister.",
    "choices": [
      "aunt",
      "friend",
      "sibling"
    ],
    "correct_index": 0,
    "explanation_vi": "Chị hoặc em gái của mẹ trong tiếng Anh được gọi là aunt (dì/cô).",
    "old_id": "7eedf11f-bfea-5e26-b781-66824e8c8d7a",
    "new_id": "8b257904-5d0b-5058-a21c-308f993bd43c"
  },
  {
    "prompt": "They are brother and sister. They have the same _______.",
    "choices": [
      "aunts",
      "parents",
      "friends"
    ],
    "correct_index": 1,
    "explanation_vi": "Anh chị em ruột thường có chung cha mẹ (parents).",
    "old_id": "46b9b29c-950e-5eaf-83d2-a7d44a312365",
    "new_id": "bdb7e618-be34-592e-8ea8-52f236dfaa8f"
  },
  {
    "prompt": "Look at that boy. Is he your _______?",
    "choices": [
      "parent",
      "aunt",
      "friend"
    ],
    "correct_index": 2,
    "explanation_vi": "Đại từ ''he'' chỉ nam giới, phù hợp với ''friend'' trong ngữ cảnh này.",
    "old_id": "05267191-15aa-58d2-b5a2-a041f6fb4b39",
    "new_id": "ef3470b3-4f6f-5184-9cc7-e3dedd1997d9"
  },
  {
    "prompt": "We are brothers. This is _______ room.",
    "choices": [
      "our",
      "his",
      "my"
    ],
    "correct_index": 0,
    "explanation_vi": "Vì chủ ngữ là ''We'' (chúng tôi) nên phải dùng ''our'' để chỉ sự sở hữu chung.",
    "old_id": "9f6f0f09-4b9a-5934-9900-6527398247b5",
    "new_id": "e2095cce-5b17-54c9-956d-f8fcdb3853de"
  },
  {
    "prompt": "Maria is nice. _______ parents are very kind too.",
    "choices": [
      "Their",
      "His",
      "Her"
    ],
    "correct_index": 2,
    "explanation_vi": "Maria là tên nữ giới, ta dùng ''Her'' để chỉ sở hữu cách.",
    "old_id": "091e7397-167a-560f-8d8a-9f40c9378a94",
    "new_id": "bd4688ab-e24d-5d71-a94d-3c8213526935"
  },
  {
    "prompt": "I have many friends, but this is _______ best friend.",
    "choices": [
      "my",
      "your",
      "our"
    ],
    "correct_index": 0,
    "explanation_vi": "Người nói đang nói về bản thân mình nên dùng ''my'' cho bạn thân nhất.",
    "old_id": "ca821b6c-3770-58c1-9b15-89c1dd852365",
    "new_id": "cc845f22-c65b-504f-bfb0-5e4aee5cab06"
  },
  {
    "prompt": "After the alarm clock rings at 7:00 AM, I usually ______ and get out of bed.",
    "choices": [
      "wake up",
      "work",
      "study"
    ],
    "correct_index": 0,
    "explanation_vi": "Wake up có nghĩa là thức dậy, phù hợp với ngữ cảnh sau khi chuông báo thức reo.",
    "old_id": "9a399d6f-cd04-54e6-99a1-a8bb9262aa84",
    "new_id": "3523c311-2902-552f-a3ba-20fe9ba65b07"
  },
  {
    "prompt": "I go to the office from Monday to Friday because I have a lot of ______ to do there.",
    "choices": [
      "work",
      "study",
      "wake up"
    ],
    "correct_index": 0,
    "explanation_vi": "Work (làm việc) là hoạt động diễn ra tại văn phòng.",
    "old_id": "0facae4e-8fbd-56a2-84d1-75c76e55ff51",
    "new_id": "d7c5e198-08bb-5b36-96c7-61b35fd36ad5"
  },
  {
    "prompt": "Every evening, she sits at her desk to ______ for her upcoming English exam.",
    "choices": [
      "work",
      "study",
      "wake up"
    ],
    "correct_index": 1,
    "explanation_vi": "Study (học) là hành động hợp lý khi ngồi tại bàn để chuẩn bị cho kỳ thi.",
    "old_id": "12379a1c-6363-525a-9046-3216333636fe",
    "new_id": "dc51f904-356a-5467-9efa-4641c371523f"
  },
  {
    "prompt": "My brother ______ in a bank in the city center.",
    "choices": [
      "work",
      "to work",
      "works"
    ],
    "correct_index": 2,
    "explanation_vi": "Chủ ngữ là ''My brother'' (số ít) nên động từ ''work'' phải thêm ''s''.",
    "old_id": "ce71fd97-f76f-590e-b88f-a49e91c6f09b",
    "new_id": "70383ef2-5ce7-5835-b327-28157bef4038"
  },
  {
    "prompt": "They ______ hard every day to pass the university entrance exam.",
    "choices": [
      "studies",
      "study",
      "studying"
    ],
    "correct_index": 1,
    "explanation_vi": "Chủ ngữ là ''They'' (số nhiều) nên động từ ''study'' giữ nguyên dạng.",
    "old_id": "cf052e08-4536-5bd0-939e-d44db85fc895",
    "new_id": "ee6354aa-80f5-5bf8-837a-924417ec628a"
  },
  {
    "prompt": "She ______ at 6:00 AM every morning during the week.",
    "choices": [
      "waking up",
      "wakes up",
      "wake up"
    ],
    "correct_index": 1,
    "explanation_vi": "Chủ ngữ ''She'' là ngôi thứ ba số ít nên động từ cần thêm ''s''.",
    "old_id": "af7765ce-e0bd-5c5d-81c2-fe6d68014cc8",
    "new_id": "0332bedb-ce97-58db-8e76-e4456d69a30b"
  },
  {
    "prompt": "A: What do you do in the morning? B: I ______ for my math class.",
    "choices": [
      "work",
      "study",
      "wake up"
    ],
    "correct_index": 1,
    "explanation_vi": "Đáp án ''study'' hợp lý nhất khi đề cập đến lớp học toán.",
    "old_id": "515c0268-cd4a-5cf3-a7d3-175a3e66ff39",
    "new_id": "1feaba15-575f-5acc-94c5-84177e53662d"
  },
  {
    "prompt": "A: Does your father like his job? B: Yes, he likes to ______ at the hospital.",
    "choices": [
      "study",
      "wake up",
      "work"
    ],
    "correct_index": 2,
    "explanation_vi": "Công việc thường gắn liền với địa điểm là bệnh viện, nên chọn ''work''.",
    "old_id": "97644f07-7333-50f7-b73a-c6fedb60c6e3",
    "new_id": "a0b8602c-1747-50d7-bc50-5e90b519c531"
  },
  {
    "prompt": "A: Why are you so tired? B: Because I ______ too early every day.",
    "choices": [
      "work",
      "study",
      "wake up"
    ],
    "correct_index": 2,
    "explanation_vi": "Thức dậy quá sớm (wake up) là lý do phổ biến khiến ai đó cảm thấy mệt mỏi.",
    "old_id": "b6f5890c-a7ce-5d2d-be19-9ad7215f835f",
    "new_id": "0cbe560c-9869-5171-bb71-e782abaab959"
  },
  {
    "prompt": "He ______ his lessons carefully before he goes to class.",
    "choices": [
      "studies",
      "study",
      "work"
    ],
    "correct_index": 0,
    "explanation_vi": "Chủ ngữ ''He'' yêu cầu động từ thêm ''es'' vì kết thúc bằng ''y'' sau phụ âm.",
    "old_id": "3ab34cff-dbe9-5749-b2b6-fda188a7cc45",
    "new_id": "d5d9f118-c198-589b-8d3c-d26b18cc7b43"
  },
  {
    "prompt": "My parents ______ at a local school as teachers.",
    "choices": [
      "study",
      "works",
      "work"
    ],
    "correct_index": 2,
    "explanation_vi": "Chủ ngữ ''My parents'' (số nhiều) nên động từ ''work'' không chia.",
    "old_id": "42f959d2-a7db-5049-8380-7b0f3dbd7f2c",
    "new_id": "adbb247d-f8b7-578e-8275-311c24427e82"
  },
  {
    "prompt": "I ______ at 7:30, have breakfast, and then leave for school.",
    "choices": [
      "wake up",
      "study",
      "work"
    ],
    "correct_index": 0,
    "explanation_vi": "Hành động đầu tiên trong ngày thường là thức dậy (wake up).",
    "old_id": "64c603cf-312e-5c4a-a00e-c719a6a7152c",
    "new_id": "b45abca9-dff9-58a3-bebb-92327f572e3a"
  },
  {
    "prompt": "She ______ in the library every afternoon.",
    "choices": [
      "study",
      "work",
      "studies"
    ],
    "correct_index": 2,
    "explanation_vi": "Chủ ngữ ''She'' đi với động từ ''studies'' để chỉ việc học tập.",
    "old_id": "6bfbecae-66a0-59d2-af0e-ef37a6ebf897",
    "new_id": "9fbffd98-9b61-5aaf-adcd-f00109f0b247"
  },
  {
    "prompt": "They ______ at the coffee shop to prepare for their presentation.",
    "choices": [
      "studies",
      "work",
      "wake up"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng ''work'' để chỉ hoạt động chuẩn bị bài thuyết trình tại quán cà phê.",
    "old_id": "3736ca34-54df-5491-9455-e823c098a56f",
    "new_id": "5e60f18d-6d07-5114-aaf5-9c96c87416ed"
  },
  {
    "prompt": "My sister ______ up at 5:00 AM to go jogging.",
    "choices": [
      "wakes",
      "wake",
      "work"
    ],
    "correct_index": 0,
    "explanation_vi": "Chủ ngữ ''My sister'' là số ít nên dùng ''wakes'' để tạo cụm ''wakes up''.",
    "old_id": "1463b84b-cd34-5c89-a7e9-daf0445e9b71",
    "new_id": "7c016a3f-5a02-5df2-9196-68afe4708fdb"
  },
  {
    "prompt": "I eat breakfast at 7:00 AM every single day. My routine is constant. I ____ eat breakfast.",
    "choices": [
      "always",
      "usually",
      "sometimes"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''every single day'' chỉ thói quen không thay đổi nên dùng ''always''.",
    "old_id": "6e25f31a-572b-5633-9107-2a6eba535c8b",
    "new_id": "08eadd3b-0054-58d2-a512-dc90932f8108"
  },
  {
    "prompt": "Minh goes to the gym on Mondays and Wednesdays, but not on other days. He ____ goes to the gym.",
    "choices": [
      "always",
      "sometimes",
      "usually"
    ],
    "correct_index": 1,
    "explanation_vi": "Việc chỉ tập một vài ngày trong tuần được diễn tả bằng ''sometimes''.",
    "old_id": "a017571e-fd92-5601-ad47-d9067a630733",
    "new_id": "5d6bf223-0665-58b3-920e-4fe9a2921737"
  },
  {
    "prompt": "Sarah speaks English at home most of the time, but she speaks French on weekends. She ____ speaks English.",
    "choices": [
      "usually",
      "always",
      "sometimes"
    ],
    "correct_index": 0,
    "explanation_vi": "Việc xảy ra phần lớn thời gian được diễn tả bằng ''usually''.",
    "old_id": "0876c4ef-a320-5b3a-998f-7360cd0c43ad",
    "new_id": "cc097b70-dda6-563e-a394-f78382377f20"
  },
  {
    "prompt": "Choose the correct sentence structure for frequency adverbs.",
    "choices": [
      "He is always late.",
      "He always is late.",
      "Always he is late."
    ],
    "correct_index": 0,
    "explanation_vi": "Trạng từ chỉ tần suất đứng sau động từ ''to be''.",
    "old_id": "f76fdbb4-d41d-5c59-96bd-ae163fc07486",
    "new_id": "1e627c77-ce35-5812-9169-ed9cbeb5773c"
  },
  {
    "prompt": "Select the sentence with the correct word order.",
    "choices": [
      "Usually they play soccer.",
      "They usually play soccer.",
      "They play usually soccer."
    ],
    "correct_index": 1,
    "explanation_vi": "Trạng từ chỉ tần suất đứng trước động từ thường.",
    "old_id": "f63e501a-0e01-50a3-bcc4-088b65e9e520",
    "new_id": "da6ebfaf-39db-554f-8918-4d79a3f9b940"
  },
  {
    "prompt": "Which option is grammatically correct?",
    "choices": [
      "Sometimes she walks to work.",
      "She walks sometimes to work.",
      "She sometimes walks to work."
    ],
    "correct_index": 2,
    "explanation_vi": "Trạng từ chỉ tần suất thường đứng trước động từ chính trong câu.",
    "old_id": "ef52c2f9-d0a8-5932-956b-878e8efb3b8a",
    "new_id": "82024552-b2b1-5424-9214-fea4640e0420"
  },
  {
    "prompt": "Person A: ''Do you watch TV before bed?'' Person B: ''Yes, ____. It helps me relax.''",
    "choices": [
      "I always am",
      "I usually go",
      "I always do"
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời sử dụng trợ động từ ''do'' để lặp lại hành động trước đó.",
    "old_id": "480a13cf-c80e-56ee-9002-356f5abac8fd",
    "new_id": "e7d981c8-48ba-52c9-93b1-a29bb64ddf34"
  },
  {
    "prompt": "Person A: ''How often do you visit your grandparents?'' Person B: ''____, about once a month.''",
    "choices": [
      "Always",
      "Usually",
      "Sometimes"
    ],
    "correct_index": 2,
    "explanation_vi": "Vì tần suất là ''một lần một tháng'' nên ''sometimes'' là phù hợp nhất.",
    "old_id": "9ed06a4b-99a7-568f-ad07-86a4db2c874e",
    "new_id": "b58aa82f-a426-534c-a012-f885d47b489a"
  },
  {
    "prompt": "Person A: ''Is the library busy in the morning?'' Person B: ''Yes, it ____ crowded at 9:00 AM.''",
    "choices": [
      "always is",
      "always has",
      "is always"
    ],
    "correct_index": 2,
    "explanation_vi": "Trạng từ ''always'' phải đứng sau động từ ''is''.",
    "old_id": "8cec218a-1bd3-55f6-9aa0-ce4f56a80041",
    "new_id": "f8aa3dfa-42d8-5b05-a886-5c2c5bc9e9b7"
  },
  {
    "prompt": "Mark plays tennis every Saturday and Sunday without fail. He ____ plays tennis on weekends.",
    "choices": [
      "always",
      "sometimes",
      "usually"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm từ ''without fail'' nhấn mạnh tính chất luôn luôn.",
    "old_id": "36eb3e3a-9b27-553a-b555-8c621b4d31f0",
    "new_id": "3c15e264-8a7a-5938-909e-7bb941126160"
  },
  {
    "prompt": "I don''t like coffee, so I ____ drink it.",
    "choices": [
      "sometimes",
      "usually",
      "never"
    ],
    "correct_index": 2,
    "explanation_vi": "Vì không thích cà phê nên tôi không bao giờ uống nó.",
    "old_id": "931d75d3-ca22-5376-948d-3516cd5523ed",
    "new_id": "311a00e8-0f67-5eda-8916-a962662f2b50"
  },
  {
    "prompt": "We ____ go to the beach in summer because it is very hot.",
    "choices": [
      "sometimes",
      "usually",
      "never"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu văn mô tả một thói quen thường xuyên vào mùa hè.",
    "old_id": "93cd9d11-3103-5616-b503-cbb53f08e7fe",
    "new_id": "98a8508f-f049-5e6e-8761-72966d964214"
  },
  {
    "prompt": "Look at the chart: Mon (Yes), Tue (Yes), Wed (No), Thu (Yes), Fri (Yes). She ____ studies at home.",
    "choices": [
      "sometimes",
      "usually",
      "always"
    ],
    "correct_index": 1,
    "explanation_vi": "Vì cô ấy học hầu hết các ngày (4/5) nên ''usually'' là phù hợp.",
    "old_id": "9dce96d8-7823-5bc3-97fd-83f019c81dc8",
    "new_id": "dc577dfd-4d76-5f2d-abea-5e6541ba893d"
  },
  {
    "prompt": "My brother is a chef. He ____ finishes work very late at night.",
    "choices": [
      "always",
      "never",
      "sometimes"
    ],
    "correct_index": 0,
    "explanation_vi": "Đặc thù công việc đầu bếp thường dẫn đến việc về muộn hàng ngày.",
    "old_id": "77c38660-59fc-583c-b200-a8adaf8565a1",
    "new_id": "5e71a70a-63bd-5383-9e73-e91d5ce125ca"
  },
  {
    "prompt": "I ____ forget my keys, but it happens once in a blue moon.",
    "choices": [
      "usually",
      "sometimes",
      "always"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ ''once in a blue moon'' có nghĩa là hiếm khi, tương ứng với ''sometimes''.",
    "old_id": "ad1a6f0f-9c28-596b-9fd7-fb35faa3ddf6",
    "new_id": "54130f3e-af6f-5afc-8b71-495bfe6538b2"
  },
  {
    "prompt": "In the morning, I always eat toast and drink orange juice for ________.",
    "choices": [
      "like",
      "water",
      "breakfast"
    ],
    "correct_index": 2,
    "explanation_vi": "Breakfast là bữa ăn đầu tiên trong ngày vào buổi sáng.",
    "old_id": "68b2d95a-6bd0-59de-b6f4-ddfc370cacd3",
    "new_id": "7636ea93-de35-5890-b8ef-038381baaa11"
  },
  {
    "prompt": "I am very thirsty after my run, so I need a big glass of ________.",
    "choices": [
      "like",
      "water",
      "breakfast"
    ],
    "correct_index": 1,
    "explanation_vi": "Water là thức uống phù hợp nhất khi cơ thể bị khát.",
    "old_id": "02599784-56a8-51c3-a881-56adf1ee93ff",
    "new_id": "d405b848-ffb8-52ec-8234-3ed1642c9339"
  },
  {
    "prompt": "My sister does not ________ spicy food, but she loves sweet chocolate.",
    "choices": [
      "water",
      "like",
      "breakfast"
    ],
    "correct_index": 1,
    "explanation_vi": "Like được dùng để diễn tả sở thích đối với một loại thực phẩm.",
    "old_id": "fdb3b0f9-ddc8-59b7-aa7a-0e99119ef34f",
    "new_id": "523eabfd-e701-5d24-b282-0e50e044ff2c"
  },
  {
    "prompt": "I ________ a cup of coffee, please. I am tired.",
    "choices": [
      "would like",
      "like",
      "likes"
    ],
    "correct_index": 0,
    "explanation_vi": "Would like là cấu trúc lịch sự dùng để gọi món hoặc đưa ra yêu cầu.",
    "old_id": "e0c0bc7f-b743-55c9-8df3-faf5e1d5368b",
    "new_id": "1c3bfb73-e0bf-5a65-9fd5-5f7d4f2f877b"
  },
  {
    "prompt": "He ________ apples, but he doesn''t eat bananas.",
    "choices": [
      "would like",
      "like",
      "likes"
    ],
    "correct_index": 2,
    "explanation_vi": "Chủ ngữ là ngôi thứ ba số ít ''He'' nên động từ ''like'' cần thêm ''s''.",
    "old_id": "7618c683-8eea-5617-a3da-5cfd5f007949",
    "new_id": "1635a949-ed3e-57d2-b172-8fbbda8df8e0"
  },
  {
    "prompt": "________ you like to eat lunch with us today?",
    "choices": [
      "Are",
      "Would",
      "Do"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc Would you like là cách hỏi lịch sự về ý muốn của người khác.",
    "old_id": "63c94f4b-cb53-569b-8f90-998a7514f438",
    "new_id": "af26c6bf-6d4e-5ae2-acae-b21271a3f6a1"
  },
  {
    "prompt": "- Do you want some cake?\n- Yes, ________.",
    "choices": [
      "please",
      "I would",
      "I like"
    ],
    "correct_index": 0,
    "explanation_vi": "Khi đồng ý nhận một món đồ được mời, người ta dùng ''please'' để tỏ thái độ lịch sự.",
    "old_id": "0633b4d3-138b-588c-9b63-93ee60011a8d",
    "new_id": "87277c84-22b5-5e10-a569-da5d3b28b1ec"
  },
  {
    "prompt": "- What do you drink for breakfast?\n- I usually drink ________.",
    "choices": [
      "some milk",
      "would milk",
      "like milk"
    ],
    "correct_index": 0,
    "explanation_vi": "Some dùng trước danh từ không đếm được như milk để chỉ một lượng không xác định.",
    "old_id": "8507f687-ba0b-5553-862f-11b65a992784",
    "new_id": "b5bbade7-5656-5cb2-8b7d-250d99ddf1e1"
  },
  {
    "prompt": "- Would you like some water?\n- No, thank you. I ________ coffee.",
    "choices": [
      "would like",
      "like",
      "breakfast"
    ],
    "correct_index": 0,
    "explanation_vi": "Người nói đang thể hiện mong muốn dùng cà phê thay vì nước lọc.",
    "old_id": "fdc185fc-4d0e-53f3-abd3-cc100a7d1b32",
    "new_id": "68addf59-d5a0-50e9-9f38-a572cfc1b285"
  },
  {
    "prompt": "My parents ________ tea in the morning.",
    "choices": [
      "likes",
      "would",
      "like"
    ],
    "correct_index": 2,
    "explanation_vi": "Chủ ngữ ''My parents'' ở dạng số nhiều nên dùng ''like'' nguyên thể.",
    "old_id": "12ae7caf-b52d-5d98-9bae-363d5476eae7",
    "new_id": "615b694a-e550-53bb-9e40-c80b7213924c"
  },
  {
    "prompt": "I am hungry! I ________ a sandwich.",
    "choices": [
      "breakfast",
      "like",
      "would like"
    ],
    "correct_index": 2,
    "explanation_vi": "Khi cảm thấy đói, người ta thường dùng ''would like'' để nói về món mình muốn ăn ngay.",
    "old_id": "3ca0ddea-53e0-55b0-b9bf-c64a6677909b",
    "new_id": "24761b21-33e2-57de-8fee-d8db0efc4955"
  },
  {
    "prompt": "________ your brother like ice cream?",
    "choices": [
      "Are",
      "Does",
      "Do"
    ],
    "correct_index": 1,
    "explanation_vi": "Chủ ngữ ''your brother'' là ngôi thứ ba số ít nên trợ động từ phải là ''Does''.",
    "old_id": "74aa8169-7ae7-596b-9e17-394f7c9fd909",
    "new_id": "eba1448f-4308-56b7-ae7c-a02d373f64d2"
  },
  {
    "prompt": "We have eggs and bread for ________ every day.",
    "choices": [
      "like",
      "breakfast",
      "water"
    ],
    "correct_index": 1,
    "explanation_vi": "Eggs và bread là các món ăn phổ biến cho bữa sáng.",
    "old_id": "edfa70f1-36e8-5092-9c93-7ec4f7302693",
    "new_id": "cefe55b1-6a36-562b-9b6c-3da0c4bcbe29"
  },
  {
    "prompt": "She ________ cold water on a hot day.",
    "choices": [
      "would like",
      "do like",
      "like"
    ],
    "correct_index": 0,
    "explanation_vi": "Would like là cách diễn đạt phù hợp khi muốn một món đồ uống cụ thể.",
    "old_id": "8c7fc566-4379-5bd8-916c-b17d44e4d035",
    "new_id": "dd864c87-3746-5508-83d0-8bda5e716ecd"
  },
  {
    "prompt": "Do you ________ vegetables?",
    "choices": [
      "likes",
      "would like",
      "like"
    ],
    "correct_index": 2,
    "explanation_vi": "Sau trợ động từ ''Do'', ta sử dụng động từ ''like'' ở dạng nguyên thể.",
    "old_id": "ec1eb14e-4348-56ea-9045-dd0aa3f4a136",
    "new_id": "2d4b707b-37a5-5af9-870b-89bcf433cba7"
  },
  {
    "prompt": "You are going to school and need to carry your books. What do you put them in?",
    "choices": [
      "a bag",
      "a phone",
      "a key"
    ],
    "correct_index": 0,
    "explanation_vi": "Cặp sách (bag) là vật dụng phù hợp nhất để đựng sách khi đi học.",
    "old_id": "43ffd143-b9ac-5491-8ced-e04e2faef55f",
    "new_id": "cca644bc-e1bd-5d1c-bd99-ef981b2f4b42"
  },
  {
    "prompt": "You want to unlock your front door when you get home. What do you need?",
    "choices": [
      "a key",
      "a phone",
      "a bag"
    ],
    "correct_index": 0,
    "explanation_vi": "Chìa khóa (key) là vật dụng dùng để mở cửa.",
    "old_id": "a34492a6-53d6-53d5-b3a4-73584e162e65",
    "new_id": "c518cdf7-73c2-5c2c-8ad6-50178f302a05"
  },
  {
    "prompt": "You want to talk to your friend who lives in another city. What do you use?",
    "choices": [
      "a phone",
      "a key",
      "a bag"
    ],
    "correct_index": 0,
    "explanation_vi": "Điện thoại (phone) được sử dụng để liên lạc với người khác từ xa.",
    "old_id": "62750ea7-3d09-5155-ac82-d34166fa3187",
    "new_id": "5ff9a859-bddb-5f10-ac58-928d9941cc90"
  },
  {
    "prompt": "Look at the object right here in my hand. _____ is my new phone.",
    "choices": [
      "These",
      "That",
      "This"
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng ''this'' cho một vật ở gần người nói.",
    "old_id": "12da0ff2-ee4a-5f49-80f4-d7aae3ac51e7",
    "new_id": "e5e1c240-0d8b-5995-bdfd-97e0331004e6"
  },
  {
    "prompt": "Look over there at the wall. Are _____ your keys on the table?",
    "choices": [
      "this",
      "those",
      "these"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng ''those'' cho các vật ở xa người nói.",
    "old_id": "1ad0ca5d-f88f-5d0b-8996-2d761b9164f6",
    "new_id": "fc6743ab-9b19-5156-8fe7-8f4829808ce5"
  },
  {
    "prompt": "I have two bags here by my feet. _____ are for my travel.",
    "choices": [
      "This",
      "That",
      "These"
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng ''these'' cho nhiều vật ở gần người nói.",
    "old_id": "60df9cb4-31a1-5873-855f-5d8781e4f910",
    "new_id": "36d42017-aec1-50ab-b3d9-40093be808dd"
  },
  {
    "prompt": "A: Is this your bag? B: Yes, _____.",
    "choices": [
      "they are",
      "this is",
      "it is"
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời ngắn cho ''Is this...'' phải là ''it is''.",
    "old_id": "74972646-3759-5963-a9c6-0d35afac7417",
    "new_id": "88c967ea-949f-51c6-9cd3-6f21833c8ff1"
  },
  {
    "prompt": "A: What are those in your hand? B: _____ my phones.",
    "choices": [
      "It is",
      "They are",
      "This is"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng ''They are'' để chỉ nhiều vật (số nhiều).",
    "old_id": "0f318477-04a9-5ee9-948e-bdf67a84ebaf",
    "new_id": "a1ebb70a-955b-5c5a-92e3-e29840ce9eb1"
  },
  {
    "prompt": "A: Excuse me, is that your key? B: No, _____ not.",
    "choices": [
      "they",
      "these",
      "it"
    ],
    "correct_index": 2,
    "explanation_vi": "Đại từ ''it'' thay thế cho danh từ số ít ''key''.",
    "old_id": "a29913c5-5ed8-588a-ab9a-655d570d9a61",
    "new_id": "96d4b291-c711-56ad-af1a-9e747e7d2d1e"
  },
  {
    "prompt": "Pick up the phone that is right here. _____ is a black phone.",
    "choices": [
      "This",
      "That",
      "Those"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''this'' để chỉ một vật ở gần ngay lúc nói.",
    "old_id": "e1bec2d6-3025-51fe-98ff-66ef1c03d30d",
    "new_id": "7f679cb2-94a8-5ae0-8d0b-051e008a1b5d"
  },
  {
    "prompt": "Look at the bags on that chair across the room. Are _____ your bags?",
    "choices": [
      "this",
      "that",
      "those"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''those'' cho nhiều vật ở vị trí xa người nói.",
    "old_id": "b353a904-d2af-5fb6-8149-3eb7dd967b18",
    "new_id": "446ff1b9-b3ac-5957-8a40-8fee3239e291"
  },
  {
    "prompt": "I cannot find my key. Is _____ the key in your pocket?",
    "choices": [
      "those",
      "that",
      "these"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng ''that'' để chỉ một vật ở xa người nói.",
    "old_id": "579ea0e7-f691-59aa-8066-c285d4b146cc",
    "new_id": "ffd5080a-fb26-5d90-8885-83f3702011ae"
  },
  {
    "prompt": "Look at these keys here. Are _____ yours?",
    "choices": [
      "these",
      "this",
      "that"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''these'' để chỉ nhiều vật ở gần người nói.",
    "old_id": "a10c2070-921f-53a3-8834-dd125a3867fc",
    "new_id": "23e5b9ea-2245-5a13-b573-8b3a69c9de54"
  },
  {
    "prompt": "A: Are those your phones? B: No, _____ are not.",
    "choices": [
      "that",
      "those",
      "this"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc trả lời với ''those'' dùng lại từ ''those''.",
    "old_id": "46e7b746-191c-584c-b9fc-07924219340d",
    "new_id": "088e7c80-b0cf-59df-9349-5d9519ed8d88"
  },
  {
    "prompt": "This is my bag, and _____ is my phone on the desk.",
    "choices": [
      "those",
      "that",
      "these"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng ''that'' cho một vật ở khoảng cách xa hơn so với vật đầu tiên.",
    "old_id": "2b25c859-f631-5c40-a53f-6dea12906d6f",
    "new_id": "940fa703-8d22-5ef8-b87a-1362ef17ffca"
  },
  {
    "prompt": "I have too many books to carry. Could you _______ me, please?",
    "choices": [
      "need",
      "help",
      "thank"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''help'' phù hợp với ngữ cảnh nhờ ai đó hỗ trợ khi có quá nhiều đồ đạc.",
    "old_id": "540df335-5f5d-5dfc-9ce2-34edd62d42d5",
    "new_id": "21ba9c7e-c0b4-50db-8b8b-b6b24facb74b"
  },
  {
    "prompt": "The teacher is speaking fast. I _______ to ask him to repeat it.",
    "choices": [
      "please",
      "need",
      "can"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''need to'' diễn tả sự cần thiết thực hiện một hành động trong tình huống này.",
    "old_id": "15cf53a5-9b32-50c6-a465-4bcb113901c1",
    "new_id": "7c1b82c0-4322-5bdb-a406-f10f93c162ca"
  },
  {
    "prompt": "I don''t know the way to the library. Could you _______ me, please?",
    "choices": [
      "need",
      "help",
      "please"
    ],
    "correct_index": 1,
    "explanation_vi": "Khi không biết đường, chúng ta thường nhờ người khác giúp đỡ.",
    "old_id": "6fc45cb4-e3cf-5825-b82c-00e767d48abb",
    "new_id": "4bbcc8d0-608f-5360-b55e-0fee9d50c985"
  },
  {
    "prompt": "_______ you open the window, please? It is very hot in here.",
    "choices": [
      "Help",
      "Could",
      "Need"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''Could you'' là cách đưa ra yêu cầu lịch sự.",
    "old_id": "83dcf65e-e906-5f79-8c9b-3cd20d9d6ebf",
    "new_id": "61def422-093e-57bf-95c9-3a822215f46e"
  },
  {
    "prompt": "I am tired. _______ I sit here for a moment, please?",
    "choices": [
      "Help",
      "Need",
      "Can"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''Can I'' để xin phép một cách lịch sự.",
    "old_id": "cb3e4a6a-237b-533c-ac58-212263353527",
    "new_id": "a8c08773-c0f1-5904-bd8b-475f09cdc933"
  },
  {
    "prompt": "_______ you show me how to use this machine, please?",
    "choices": [
      "Can",
      "Help",
      "Need"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''Can you'' thường được dùng để nhờ ai đó hướng dẫn làm việc gì.",
    "old_id": "f90343b6-e9bd-53d7-9760-a6d519d26dce",
    "new_id": "f9c1c7f4-a094-5c85-8c74-2759ca441d39"
  },
  {
    "prompt": "A: It is raining outside. Could you lend me your umbrella, please? B: _______",
    "choices": [
      "Yes, of course.",
      "Yes, please.",
      "No, I need."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời ''Yes, of course'' thể hiện sự đồng ý lịch sự với một yêu cầu.",
    "old_id": "b2c1365b-83f8-5be0-ae03-231647887bd6",
    "new_id": "2fd4ba1f-1c5c-5ddc-ac2c-43268e0ffbcf"
  },
  {
    "prompt": "A: I am lost. Can you help me find the station, please? B: _______",
    "choices": [
      "Sure, follow me.",
      "No, please help.",
      "Yes, I need."
    ],
    "correct_index": 0,
    "explanation_vi": "Phản hồi này xác nhận việc đồng ý giúp đỡ người hỏi đường.",
    "old_id": "0a85d6a6-0aa0-56bd-8fab-462e63ef7b41",
    "new_id": "07c82ed5-4f3b-5841-b0d2-be516dd63290"
  },
  {
    "prompt": "A: Could you pass the salt, please? B: _______",
    "choices": [
      "Here you are.",
      "No, I need.",
      "Yes, I help."
    ],
    "correct_index": 0,
    "explanation_vi": "Khi đưa đồ vật cho người khác, cụm từ ''Here you are'' là cách đáp lại tự nhiên nhất.",
    "old_id": "1cf1bb3f-34de-5902-be65-d90a3a617ec9",
    "new_id": "6a142e40-ad75-560f-b77e-929269e0d14a"
  },
  {
    "prompt": "_______ you speak a little louder, please? I cannot hear you.",
    "choices": [
      "Help",
      "Need",
      "Could"
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng ''Could'' trong câu hỏi để đưa ra yêu cầu lịch sự về việc thay đổi hành động của người khác.",
    "old_id": "9152f2f9-0f6f-5c90-ac76-2b5722290373",
    "new_id": "a2314403-f314-5760-8d19-d9674994dcb6"
  },
  {
    "prompt": "I _______ a pen to write my notes. Do you have one?",
    "choices": [
      "can",
      "help",
      "need"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''need'' diễn tả nhu cầu về một đồ vật nào đó.",
    "old_id": "b74b1201-ff6a-53d9-8242-2b479e3d6bfe",
    "new_id": "e8afb1a3-e7e9-5e58-bcd3-1fc8e0a24084"
  },
  {
    "prompt": "Could you _______ me with my heavy bag, please?",
    "choices": [
      "need",
      "can",
      "help"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc ''help me'' phù hợp với ngữ cảnh yêu cầu hỗ trợ mang vác vật nặng.",
    "old_id": "0b5dabca-f3fb-5c21-a890-fe139d640767",
    "new_id": "a43ff1c2-6099-5db1-a14b-0b4d77356b95"
  },
  {
    "prompt": "A: I cannot reach the top shelf. Could you help me, please? B: _______",
    "choices": [
      "Yes, I need.",
      "Sure, no problem.",
      "Please, I can."
    ],
    "correct_index": 1,
    "explanation_vi": "Đây là cách đáp lại lời yêu cầu giúp đỡ một cách thân thiện và lịch sự.",
    "old_id": "158da727-bca7-5f9b-8170-933f8429521c",
    "new_id": "a8bf9b2d-5c33-5163-b6bc-b8fa5bbbf4b9"
  },
  {
    "prompt": "_______ I have a glass of water, please?",
    "choices": [
      "Can",
      "Need",
      "Help"
    ],
    "correct_index": 0,
    "explanation_vi": "Sử dụng ''Can I'' để yêu cầu thứ gì đó một cách lịch sự.",
    "old_id": "908a6adf-4004-5552-8028-8906b9cbf2a2",
    "new_id": "4edac214-b9dd-58ca-a053-0e5a601d4a36"
  },
  {
    "prompt": "I feel sick. I _______ to go home early, please.",
    "choices": [
      "could",
      "help",
      "need"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''need to'' để thể hiện nhu cầu cá nhân về việc ra về sớm.",
    "old_id": "13bccf75-8623-5fe0-b3fe-cbbf10e77584",
    "new_id": "a9e081e8-6a7f-52cf-940f-9d069e06711f"
  },
  {
    "prompt": "I want to buy these shoes, but I need to know the ______ before I pay at the counter.",
    "choices": [
      "price",
      "cash",
      "size"
    ],
    "correct_index": 0,
    "explanation_vi": "Price là số tiền cần trả để mua món hàng.",
    "old_id": "eaac0017-ff45-5831-a006-44e5869d1b3a",
    "new_id": "6ae1d83d-2110-5088-a289-4f5de91aa04b"
  },
  {
    "prompt": "These jeans are too small for me. Do you have a larger ______?",
    "choices": [
      "price",
      "size",
      "cash"
    ],
    "correct_index": 1,
    "explanation_vi": "Size dùng để chỉ độ lớn hay kích cỡ của quần áo.",
    "old_id": "379d5f33-bd76-5c8b-bc18-7e35429bf760",
    "new_id": "ada414a4-019b-56a3-91c5-5a150f94b384"
  },
  {
    "prompt": "The machine is broken, so the shop assistant can only take ______ for your groceries.",
    "choices": [
      "price",
      "size",
      "cash"
    ],
    "correct_index": 2,
    "explanation_vi": "Cash là tiền mặt, dùng thay thế khi không thanh toán bằng thẻ.",
    "old_id": "4f262600-1424-5554-844a-dd14b5120178",
    "new_id": "97bb7b7b-dad3-573f-90cb-4b51d2772c45"
  },
  {
    "prompt": "______ does this red jacket cost?",
    "choices": [
      "How many",
      "How price",
      "How much"
    ],
    "correct_index": 2,
    "explanation_vi": "How much dùng để hỏi về giá tiền của một vật không đếm được.",
    "old_id": "3023c2c0-4ce0-5409-a980-c01450173caa",
    "new_id": "c337d44d-432c-5fb9-a665-3e0712bf0f4b"
  },
  {
    "prompt": "______ oranges do you want to buy for your juice?",
    "choices": [
      "How many",
      "How price",
      "How much"
    ],
    "correct_index": 0,
    "explanation_vi": "How many dùng cho danh từ đếm được số nhiều như oranges.",
    "old_id": "3cefbde9-fb10-5b61-8168-b3b4e970df19",
    "new_id": "617778c3-4426-5896-92d4-20e042ed8280"
  },
  {
    "prompt": "Look at these hats! ______ is the blue one?",
    "choices": [
      "How many",
      "How size",
      "How much"
    ],
    "correct_index": 2,
    "explanation_vi": "How much dùng để hỏi giá tiền của một vật cụ thể.",
    "old_id": "aee4ae2d-5f28-5295-8165-397ee2a2d244",
    "new_id": "18c63075-cc52-5f61-af0d-ab6bf2462630"
  },
  {
    "prompt": "Customer: ''Excuse me, how much is this notebook?'' Shop Assistant: ''______''",
    "choices": [
      "I have many books.",
      "It is five dollars.",
      "It is a medium size."
    ],
    "correct_index": 1,
    "explanation_vi": "Câu trả lời cần cung cấp thông tin về giá tiền cho câu hỏi How much.",
    "old_id": "a0da17ce-a401-5b5c-842a-66a02215ff60",
    "new_id": "37694df4-3dd6-53af-8a37-42221f41b91b"
  },
  {
    "prompt": "Customer: ''Do you have this shirt in a larger size?'' Shop Assistant: ''______''",
    "choices": [
      "It costs ten dollars.",
      "I do not have cash.",
      "Yes, here is a large one."
    ],
    "correct_index": 2,
    "explanation_vi": "Người bán hàng cần xác nhận có kích cỡ mà khách hàng yêu cầu.",
    "old_id": "3aa360af-314c-5d55-bb8a-682bfc3dce9d",
    "new_id": "318b88b5-4932-589f-bbad-e67f42ab9cbe"
  },
  {
    "prompt": "Customer: ''I only have fifty dollars in cash. Is that enough?'' Shop Assistant: ''______''",
    "choices": [
      "No, it is too small.",
      "Yes, that is perfect.",
      "Yes, it is my size."
    ],
    "correct_index": 1,
    "explanation_vi": "Đây là câu trả lời hợp lý nhất khi xác nhận số tiền thanh toán.",
    "old_id": "e0e5cf80-f30b-5cd0-a56b-0b92aa319cea",
    "new_id": "10bcd801-0f90-5218-937d-2e245a8379a1"
  },
  {
    "prompt": "I don''t have my credit card, so I will pay with ______.",
    "choices": [
      "price",
      "size",
      "cash"
    ],
    "correct_index": 2,
    "explanation_vi": "Cash là phương thức thanh toán thay thế cho thẻ tín dụng.",
    "old_id": "9d8b6e1f-d40b-5e3a-b595-ef7471d8c4fc",
    "new_id": "07cb49a9-026e-5440-8589-17e67527ef60"
  },
  {
    "prompt": "______ apples are in that bag on the table?",
    "choices": [
      "How much",
      "How many",
      "How size"
    ],
    "correct_index": 1,
    "explanation_vi": "How many được dùng để hỏi số lượng các đồ vật đếm được.",
    "old_id": "09e00e6c-b4da-5241-a01f-1ade25486632",
    "new_id": "485ac7c2-d098-52e1-87d4-bc95f78fe14e"
  },
  {
    "prompt": "Can you check the ______ of this laptop? I need to know if I can afford it.",
    "choices": [
      "price",
      "size",
      "cash"
    ],
    "correct_index": 0,
    "explanation_vi": "Price là thứ khách hàng cần biết để xác định khả năng chi trả.",
    "old_id": "574d01b4-db5b-5aca-bf3b-7009f2187955",
    "new_id": "79e7eaa7-be3b-5499-b93e-e9434e843ef5"
  },
  {
    "prompt": "These boots are size 38, but I need size 40. Do you have them in a bigger ______?",
    "choices": [
      "size",
      "price",
      "cash"
    ],
    "correct_index": 0,
    "explanation_vi": "Size được dùng để so sánh các loại kích cỡ khác nhau.",
    "old_id": "557c742c-7155-5666-8273-528762a87b50",
    "new_id": "9f2dc881-26a0-57b6-badb-b765c6ff1923"
  },
  {
    "prompt": "______ does the water bottle cost at the supermarket?",
    "choices": [
      "How much",
      "How many",
      "How price"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc How much dùng để hỏi giá tiền cho một sự vật.",
    "old_id": "00b3589b-c31f-5ccd-ab3d-36e77922c300",
    "new_id": "a46cb07a-94b8-55bb-85c1-e8a4087315c8"
  },
  {
    "prompt": "Customer: ''I would like to buy these three pens.'' Shop Assistant: ''That will be six dollars, please.'' Customer: ''______''",
    "choices": [
      "That is my size.",
      "Here is the cash.",
      "It is a good price."
    ],
    "correct_index": 1,
    "explanation_vi": "Khách hàng đưa tiền mặt sau khi biết tổng số tiền cần thanh toán.",
    "old_id": "44c8a8af-d96b-5872-8181-cf6fbc703af5",
    "new_id": "54845a97-4aed-5fc7-8d70-14eb9d4e21c4"
  },
  {
    "prompt": "The waiter gave us the ____ so we could choose what to eat for lunch.",
    "choices": [
      "order",
      "menu",
      "bill"
    ],
    "correct_index": 1,
    "explanation_vi": "Menu là danh sách các món ăn để khách hàng chọn lựa trước khi gọi món.",
    "old_id": "b91a2b8e-5f13-5715-afac-0b023a0131f0",
    "new_id": "b70b5914-19d2-520a-8c46-2b6bd41f1b47"
  },
  {
    "prompt": "I am finished with my meal. Could you please bring me the ____?",
    "choices": [
      "menu",
      "order",
      "bill"
    ],
    "correct_index": 2,
    "explanation_vi": "Bill là tờ hóa đơn khách hàng yêu cầu khi muốn thanh toán tiền ăn.",
    "old_id": "b6ca1b46-581b-5c72-998f-d21056325f05",
    "new_id": "3c3966f7-0b4a-58bd-9ddc-022f8b00250f"
  },
  {
    "prompt": "The server wrote down our ____ for two burgers and a large soda.",
    "choices": [
      "bill",
      "order",
      "menu"
    ],
    "correct_index": 1,
    "explanation_vi": "Order là yêu cầu về món ăn hoặc đồ uống mà khách đặt với nhà hàng.",
    "old_id": "62190bc0-d52d-54e9-a283-2a0da7e75a91",
    "new_id": "cc745df5-7632-5fe4-b509-93caa97c1ee7"
  },
  {
    "prompt": "We need ____ for the salad, please.",
    "choices": [
      "a oil",
      "an oil",
      "some oil"
    ],
    "correct_index": 2,
    "explanation_vi": "Oil là danh từ không đếm được nên không dùng mạo từ ''a/an'' mà dùng ''some''.",
    "old_id": "eb8575cc-4c28-52c8-8d53-fd4ca990f339",
    "new_id": "7d6ef533-d12e-5bd4-ae97-2ab5151d0340"
  },
  {
    "prompt": "Would you like ____ apple with your breakfast?",
    "choices": [
      "an",
      "any",
      "some"
    ],
    "correct_index": 0,
    "explanation_vi": "Apple là danh từ đếm được số ít bắt đầu bằng nguyên âm nên dùng mạo từ ''an''.",
    "old_id": "ade5255d-c3cd-5024-8500-67e6c4036810",
    "new_id": "7a17da07-13fd-5d5d-a329-0f0cf348315e"
  },
  {
    "prompt": "There are ____ cookies left in the jar on the table.",
    "choices": [
      "a",
      "any",
      "some"
    ],
    "correct_index": 2,
    "explanation_vi": "Cookies là danh từ đếm được số nhiều, dùng ''some'' trong câu khẳng định.",
    "old_id": "7b2208d4-3186-5c20-97e6-c4dfda01a7b7",
    "new_id": "6c582be4-5180-5f17-ab1d-1a8b7edc2431"
  },
  {
    "prompt": "Customer: ''Could I have a coffee, please?'' Waiter: ''____''",
    "choices": [
      "No, I cannot see the menu.",
      "Yes, here is the bill.",
      "Certainly, anything else?"
    ],
    "correct_index": 2,
    "explanation_vi": "Khi khách gọi món, nhân viên phục vụ thường xác nhận và hỏi khách có cần thêm gì không.",
    "old_id": "688f8c92-4ad8-5ecb-98ac-5450f812d90d",
    "new_id": "9d266e5c-4da9-5652-a604-c81cf28af058"
  },
  {
    "prompt": "Waiter: ''Are you ready to choose?'' Customer: ''____''",
    "choices": [
      "Yes, I would like the pasta.",
      "No, the bill is too high.",
      "Yes, this is my favorite menu."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời của khách cần liên quan đến việc chọn món ăn sau khi xem thực đơn.",
    "old_id": "ea29a0a7-ff3c-5619-8822-a6790cec7b64",
    "new_id": "f9ce06c3-6b53-50ce-9982-068c2aaf7b89"
  },
  {
    "prompt": "Customer: ''How much is the soup?'' Waiter: ''____''",
    "choices": [
      "It is on the menu.",
      "It is a hot soup.",
      "It is five dollars."
    ],
    "correct_index": 2,
    "explanation_vi": "Khi khách hỏi về giá tiền, nhân viên cần đưa ra con số cụ thể.",
    "old_id": "0022fcbc-f37e-50d9-a349-fd709f3050eb",
    "new_id": "ea9b7c9c-f5c3-5f62-96a9-3ed794ddd119"
  },
  {
    "prompt": "Which of these is uncountable?",
    "choices": [
      "water",
      "plate",
      "sandwich"
    ],
    "correct_index": 0,
    "explanation_vi": "Nước (water) là danh từ không đếm được trong tiếng Anh.",
    "old_id": "0480c9d7-28e8-588a-93e4-9519de790ce1",
    "new_id": "d835a013-7177-5d12-9c00-aefd36d15b11"
  },
  {
    "prompt": "Complete the phrase: ''Can I ____ a table for two?''",
    "choices": [
      "make",
      "book",
      "take"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ ''book a table'' có nghĩa là đặt bàn trước tại nhà hàng.",
    "old_id": "a119a068-bba0-53e6-bebf-e40aaf5e44ee",
    "new_id": "de4c9cf4-f254-59aa-9bbf-cbf3831c2311"
  },
  {
    "prompt": "Which sentence is grammatically correct?",
    "choices": [
      "I want some sugar in my tea.",
      "I want three sugars.",
      "I want three sugars in tea."
    ],
    "correct_index": 0,
    "explanation_vi": "Sugar là danh từ không đếm được nên dùng ''some'' thay vì số đếm.",
    "old_id": "8a79af93-5ac8-5d7d-b779-013f3466a82e",
    "new_id": "61eae1d5-d9dd-509a-805a-5c51342cd82b"
  },
  {
    "prompt": "If you are very hungry, you might order ____.",
    "choices": [
      "a water",
      "a main course",
      "a starter"
    ],
    "correct_index": 1,
    "explanation_vi": "Main course (món chính) là phần ăn quan trọng và lớn nhất trong bữa ăn.",
    "old_id": "b7eb762c-a308-5a4a-9d88-13cf4950f5d5",
    "new_id": "2bba6153-502e-511e-9f25-07752b35140a"
  },
  {
    "prompt": "Choose the best quantifier: ''I need ____ salt for the soup.''",
    "choices": [
      "some",
      "any",
      "a"
    ],
    "correct_index": 0,
    "explanation_vi": "Salt là danh từ không đếm được, dùng ''some'' để diễn tả một lượng nhỏ.",
    "old_id": "71f223cf-8ee0-56d7-ad95-8d5645dbc9c8",
    "new_id": "1361c77d-3298-56a9-8a10-f8de9c85ac51"
  },
  {
    "prompt": "What do you call the person who brings your food?",
    "choices": [
      "a cook",
      "a waiter",
      "a customer"
    ],
    "correct_index": 1,
    "explanation_vi": "Waiter (hoặc waitress) là người phục vụ mang đồ ăn ra bàn cho khách.",
    "old_id": "9bab03c8-deb8-53f7-b452-6a904d0109e0",
    "new_id": "a9a1fcd1-b478-5ec3-a6f6-790c8cbe8106"
  },
  {
    "prompt": "I don''t have a car, so I take the ______ to go to work every morning.",
    "choices": [
      "ticket",
      "bus",
      "station"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''bus'' là phương tiện giao thông phù hợp nhất để đi làm hàng ngày.",
    "old_id": "5a55dd2d-222d-5e56-8a27-292da57d5433",
    "new_id": "14f89f72-d492-5193-a7c5-ff21aa6b3d16"
  },
  {
    "prompt": "You need to buy a ______ before you can get on the train.",
    "choices": [
      "platform",
      "track",
      "ticket"
    ],
    "correct_index": 2,
    "explanation_vi": "Hành khách cần có vé trước khi lên tàu.",
    "old_id": "70ece9fe-fff5-5f5f-b863-5926ab428811",
    "new_id": "6d547028-f4dd-5468-bc13-fa0d42d297a0"
  },
  {
    "prompt": "The ______ leaves the city at 8:00 AM and arrives in the next town at 9:00 AM.",
    "choices": [
      "train",
      "driver",
      "seat"
    ],
    "correct_index": 0,
    "explanation_vi": "Tàu hỏa là phương tiện di chuyển phổ biến giữa các thành phố.",
    "old_id": "17739aa0-728e-54b1-9960-cb8ecf485741",
    "new_id": "148d3e2e-38f0-5383-bddd-b5692ed29ad3"
  },
  {
    "prompt": "We usually travel ______ bus when we go to the city center.",
    "choices": [
      "by",
      "in",
      "on"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''by + phương tiện giao thông'' được dùng để chỉ cách thức di chuyển.",
    "old_id": "8df9122a-ff8f-5825-ba29-e6c59aa7b58d",
    "new_id": "afbb7ecf-8089-5ec4-a44f-d6912fd0f7f6"
  },
  {
    "prompt": "My sister is ______ the train right now, so she cannot answer the phone.",
    "choices": [
      "at",
      "on",
      "by"
    ],
    "correct_index": 1,
    "explanation_vi": "Khi đang ở trên phương tiện giao thông công cộng, chúng ta dùng giới từ ''on''.",
    "old_id": "7d4ba077-cf11-59b1-a92d-e8928dee78f2",
    "new_id": "4fe6390e-3493-5cb4-aa1a-4dd638d48e38"
  },
  {
    "prompt": "He goes to the office ______ train every single day.",
    "choices": [
      "in",
      "by",
      "at"
    ],
    "correct_index": 1,
    "explanation_vi": "Giới từ ''by'' được sử dụng trước tên các loại phương tiện giao thông.",
    "old_id": "f591c040-1cf8-5ecd-bf2c-e69a2e6b3eea",
    "new_id": "71413a63-eac5-5861-8eed-1f0e7d82c4d2"
  },
  {
    "prompt": "A: Excuse me, where do I buy a ticket for the bus?\nB: ______",
    "choices": [
      "The bus is blue.",
      "It takes thirty minutes.",
      "You can buy it at the station."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời cung cấp đúng địa điểm mua vé theo yêu cầu của người hỏi.",
    "old_id": "32a342f0-4b99-5cc6-b0a5-805f77174e29",
    "new_id": "1f66db89-3f55-5170-984e-d4958365c4c9"
  },
  {
    "prompt": "A: Is it expensive to travel by train?\nB: ______",
    "choices": [
      "The train is very long.",
      "Yes, I like the train.",
      "No, it is quite cheap."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời trực tiếp phản hồi về chi phí di chuyển bằng tàu.",
    "old_id": "1116eb64-1ef2-54d1-8884-51fbb6631ed7",
    "new_id": "d14b9143-1fb2-52ec-81fa-5590be90f4cd"
  },
  {
    "prompt": "A: How do you get to school?\nB: ______",
    "choices": [
      "I take the bus.",
      "It is near the park.",
      "I have a new bag."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời nêu rõ phương tiện di chuyển để đến trường.",
    "old_id": "c7d31f1c-335b-5ebf-a29b-c47a0341e24c",
    "new_id": "bfa2d4ab-d150-53d0-967a-e0b28dfe2880"
  },
  {
    "prompt": "Most people in this city prefer to go to work ______ bus to save money.",
    "choices": [
      "by",
      "on",
      "at"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''by'' để diễn tả phương tiện giao thông được sử dụng để di chuyển.",
    "old_id": "3a95daaf-7ea4-5c17-b724-0328970d93e5",
    "new_id": "96f1b77b-ece5-5fcd-a910-e31c4b002dbb"
  },
  {
    "prompt": "Don''t forget your ______! You cannot get on the train without it.",
    "choices": [
      "train",
      "ticket",
      "bus"
    ],
    "correct_index": 1,
    "explanation_vi": "Vé là vật bắt buộc phải có để lên tàu.",
    "old_id": "d11d30cb-74e3-5427-895b-9cc7d4ec6f01",
    "new_id": "df145934-08fb-5acb-9880-4613889641cf"
  },
  {
    "prompt": "There are many people waiting for the ______ at the bus stop.",
    "choices": [
      "ticket",
      "station",
      "bus"
    ],
    "correct_index": 2,
    "explanation_vi": "Người ta thường đợi xe buýt tại trạm dừng xe buýt.",
    "old_id": "acbe2931-4c76-5ee8-85df-8ea00f36ed36",
    "new_id": "2e242744-7605-5a6a-b2f7-d349046bfede"
  },
  {
    "prompt": "I am sitting ______ the bus, looking out of the window.",
    "choices": [
      "on",
      "at",
      "by"
    ],
    "correct_index": 0,
    "explanation_vi": "Sử dụng ''on'' khi muốn diễn tả việc đang ở bên trong phương tiện giao thông.",
    "old_id": "e7d5e677-b8d8-500d-920d-920f67860808",
    "new_id": "80b8a7e0-f3f6-568f-a4b4-7a8c56c88a7c"
  },
  {
    "prompt": "We traveled ______ train across the country last summer.",
    "choices": [
      "on",
      "in",
      "by"
    ],
    "correct_index": 2,
    "explanation_vi": "Giới từ ''by'' đi kèm với ''train'' để chỉ phương thức di chuyển.",
    "old_id": "1f310a71-74b6-58e3-951a-3197636b4eb0",
    "new_id": "ab17fb56-1e6f-53fc-8277-1051fb3e4b90"
  },
  {
    "prompt": "He bought a bus ______ at the machine in the station.",
    "choices": [
      "seat",
      "ticket",
      "driver"
    ],
    "correct_index": 1,
    "explanation_vi": "Máy bán hàng tự động ở nhà ga thường được dùng để mua vé xe buýt.",
    "old_id": "9c754d99-185e-5df9-bec7-c096e4178a95",
    "new_id": "a59ce312-1e4e-5b5c-a3e0-44953e68933c"
  },
  {
    "prompt": "The post office is on the _______ of Main Street and Second Avenue.",
    "choices": [
      "turn",
      "corner",
      "across"
    ],
    "correct_index": 1,
    "explanation_vi": "Danh từ ''corner'' dùng để chỉ vị trí giao nhau của hai con đường.",
    "old_id": "0024ec6a-a5a9-5483-88eb-fd00222579e7",
    "new_id": "c009e3d5-5b66-5e28-a5e3-4b3869a4c6d6"
  },
  {
    "prompt": "The library is directly _______ the park. You just walk over the small bridge to get there.",
    "choices": [
      "corner",
      "turn",
      "across"
    ],
    "correct_index": 2,
    "explanation_vi": "Giới từ ''across'' diễn tả vị trí ở phía bên kia của một địa điểm.",
    "old_id": "b1037c26-d492-5757-815e-a0551d8e9f0f",
    "new_id": "07f0051d-e386-5ce8-84af-9e373b2294d5"
  },
  {
    "prompt": "When you reach the cinema, you need to _______ left to find the station.",
    "choices": [
      "across",
      "turn",
      "corner"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''turn'' được dùng khi chỉ dẫn hướng rẽ.",
    "old_id": "2c348be0-f761-5536-92aa-34b7f5c25a13",
    "new_id": "cc956a69-544e-5927-aa01-a05ccee40239"
  },
  {
    "prompt": "_______ straight for two blocks until you see the big hotel.",
    "choices": [
      "Go",
      "Going",
      "To go"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu mệnh lệnh bắt đầu bằng động từ nguyên thể không chia.",
    "old_id": "2f9d7064-aef3-55b5-add9-6a093a55eebc",
    "new_id": "28c1608e-06c5-56ae-afa6-297087152e05"
  },
  {
    "prompt": "The hospital is located _______ the bus stop and the bank.",
    "choices": [
      "next",
      "between",
      "across"
    ],
    "correct_index": 1,
    "explanation_vi": "Giới từ ''between'' dùng để chỉ vị trí nằm ở giữa hai địa điểm.",
    "old_id": "0db03db8-d07c-5b44-af5a-b9c28b528bff",
    "new_id": "777d8785-d2bf-50e9-8b57-51970f746827"
  },
  {
    "prompt": "Please _______ the map carefully before we start walking.",
    "choices": [
      "reads",
      "read",
      "reading"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu mệnh lệnh khẳng định yêu cầu sử dụng động từ ở dạng nguyên thể.",
    "old_id": "d3d52587-ca46-527f-a0c1-bb3e4eb6a00f",
    "new_id": "9e9a2578-9de7-5182-8405-aafabbac7438"
  },
  {
    "prompt": "A: Excuse me, how do I get to the museum?\nB: _______ right at the next traffic light.",
    "choices": [
      "Turn",
      "Across",
      "Next"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời cần một hành động hướng dẫn giao thông, phù hợp với từ ''Turn''.",
    "old_id": "345a57ce-f333-5322-9e52-6391a826d33d",
    "new_id": "5b89197e-5a79-5fe3-b79a-8e866539a171"
  },
  {
    "prompt": "A: Is the supermarket near here?\nB: Yes, it is _______ from the cinema.",
    "choices": [
      "corner",
      "turn",
      "across"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''across from'' là cấu trúc chính xác để chỉ vị trí đối diện.",
    "old_id": "22385a42-8c0f-5116-a1b0-7dedb317d6e2",
    "new_id": "93712a83-21d7-5a09-bf5d-3be71209b9e3"
  },
  {
    "prompt": "A: Where is the pharmacy?\nB: It is on the _______ of Oak Road.",
    "choices": [
      "corner",
      "turn",
      "between"
    ],
    "correct_index": 0,
    "explanation_vi": "Giới từ ''on the'' thường đi với danh từ ''corner'' để chỉ vị trí cụ thể.",
    "old_id": "fd0195b2-6f1b-5a15-acf5-53a1a7f100f5",
    "new_id": "fca3749e-d3d7-5cd7-b406-974728c4b308"
  },
  {
    "prompt": "_______ the street at the zebra crossing to stay safe.",
    "choices": [
      "Cross",
      "Turn",
      "Between"
    ],
    "correct_index": 0,
    "explanation_vi": "Động từ ''Cross'' phù hợp với ngữ cảnh băng qua đường.",
    "old_id": "ec64005c-251a-573f-bb30-28ece8345baf",
    "new_id": "e806651b-a41d-509d-84fe-fb5f3502b980"
  },
  {
    "prompt": "The coffee shop is _______ the bookstore, right next to the entrance.",
    "choices": [
      "next",
      "across",
      "beside"
    ],
    "correct_index": 2,
    "explanation_vi": "Giới từ ''beside'' có nghĩa là bên cạnh, phù hợp với ngữ cảnh vị trí.",
    "old_id": "81bacf0c-e696-523c-ae9a-7e1f5968a339",
    "new_id": "283fa12f-ed55-5abe-a33f-092adab2e66d"
  },
  {
    "prompt": "Don''t _______ left yet; wait until you see the blue house.",
    "choices": [
      "across",
      "turn",
      "corner"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu mệnh lệnh phủ định vẫn sử dụng động từ nguyên thể sau ''Don''t''.",
    "old_id": "f3b3adda-eea2-56b1-b950-e28bb38ca21c",
    "new_id": "4f3e5a19-cf8b-5785-8592-c5fe7b4013c2"
  },
  {
    "prompt": "Walk _______ the park until you see the fountain.",
    "choices": [
      "across",
      "corner",
      "through"
    ],
    "correct_index": 2,
    "explanation_vi": "Giới từ ''through'' diễn tả hành động đi xuyên qua một khu vực.",
    "old_id": "cb0b2de1-b6da-5a32-8de7-9675f21d881c",
    "new_id": "a39394f7-5356-51e1-a61c-ab69451faff7"
  },
  {
    "prompt": "My house is the third one _______ the left side of the road.",
    "choices": [
      "on",
      "at",
      "in"
    ],
    "correct_index": 0,
    "explanation_vi": "Sử dụng giới từ ''on'' khi nói về vị trí trên một phía của con đường.",
    "old_id": "b74fc59a-31a0-533e-acba-fa2166940bae",
    "new_id": "54379b1f-61a6-5a34-9a08-2d5e82c2d254"
  },
  {
    "prompt": "_______ the first exit at the roundabout to get to the city center.",
    "choices": [
      "Turn",
      "Go",
      "Take"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''Take'' thường dùng để chỉ việc chọn một lối rẽ hoặc lối ra cụ thể.",
    "old_id": "2dd42b65-e6b1-596a-af70-5fd2c09dfc3e",
    "new_id": "7634cd3a-2d08-5f03-ae83-59da5ace5ce9"
  },
  {
    "prompt": "Before you travel to another country, you must check that your __________ is valid.",
    "choices": [
      "hotel",
      "booking",
      "passport"
    ],
    "correct_index": 2,
    "explanation_vi": "Hộ chiếu là giấy tờ bắt buộc để đi du lịch nước ngoài.",
    "old_id": "97dd32cc-9b03-53dd-91f1-3af838905169",
    "new_id": "d15ee4d7-f294-551f-9558-0de116555b0c"
  },
  {
    "prompt": "We made a __________ for three nights at the beach resort.",
    "choices": [
      "passport",
      "booking",
      "travel"
    ],
    "correct_index": 1,
    "explanation_vi": "Booking được sử dụng để chỉ việc đặt chỗ trước cho dịch vụ lưu trú.",
    "old_id": "0aa068ae-fa24-5bde-9a09-3d70f0a2c129",
    "new_id": "723f345f-68e8-5f2e-81c0-ff647d7fbdbc"
  },
  {
    "prompt": "The __________ has a beautiful swimming pool and a nice restaurant.",
    "choices": [
      "hotel",
      "passport",
      "booking"
    ],
    "correct_index": 0,
    "explanation_vi": "Khách sạn là nơi có các tiện nghi như bể bơi và nhà hàng.",
    "old_id": "0df37532-f7fe-58e9-b464-80f412bacaf0",
    "new_id": "520bd057-39b7-5f57-ab25-e5f58ca0b8b2"
  },
  {
    "prompt": "__________ a small cafe near the park where we can drink coffee.",
    "choices": [
      "There are",
      "They are",
      "There is"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''There is'' cho danh từ số ít ''a small cafe''.",
    "old_id": "4e7b863b-c5ba-55d0-85c0-d22a521094a3",
    "new_id": "c3407195-d3de-5f2d-ae15-2c0ff3a78721"
  },
  {
    "prompt": "__________ many tourists in the city center during the summer.",
    "choices": [
      "There are",
      "There is",
      "They are"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''There are'' cho danh từ số nhiều ''many tourists''.",
    "old_id": "27d2d2b8-4d81-593d-95fb-3317e9519e7e",
    "new_id": "339704ea-39af-56cc-b836-8f51562ec8da"
  },
  {
    "prompt": "Look! __________ two elevators in the lobby of this building.",
    "choices": [
      "They have",
      "There is",
      "There are"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''There are'' vì danh từ ''two elevators'' ở dạng số nhiều.",
    "old_id": "70ac59ba-3639-5ee7-bd19-49515c959b79",
    "new_id": "45201ffe-112d-5dad-953e-2d8c1a39a280"
  },
  {
    "prompt": "Receptionist: ''How can I help you?'' Guest: ''__________.''",
    "choices": [
      "I have a passport for two people.",
      "I am a hotel for tonight.",
      "I have a booking for two nights."
    ],
    "correct_index": 2,
    "explanation_vi": "Khách hàng thường thông báo về việc đặt phòng khi đến quầy lễ tân.",
    "old_id": "22194eb0-0630-5d51-8f1b-af0e1f53e053",
    "new_id": "e3344893-4528-5457-bba9-4bb487589aea"
  },
  {
    "prompt": "Friend 1: ''Is there a quiet room in this hotel?'' Friend 2: ''__________.''",
    "choices": [
      "Yes, there is one.",
      "Yes, there are one.",
      "Yes, they are one."
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc trả lời cho câu hỏi với ''Is there'' là ''Yes, there is''.",
    "old_id": "8b9ad276-672f-5526-9c73-ef2bda6299d4",
    "new_id": "d552736f-25c4-5acc-b8ae-601a2c812db3"
  },
  {
    "prompt": "Traveler: ''Excuse me, where is my passport?'' Partner: ''__________.''",
    "choices": [
      "They are in your bag.",
      "There is in your bag.",
      "It is in your bag."
    ],
    "correct_index": 2,
    "explanation_vi": "Passport là danh từ số ít nên dùng đại từ ''It'' để thay thế.",
    "old_id": "c53ceaf1-6ac1-5559-937b-42bd995fe0d5",
    "new_id": "30cc9f2c-9c0f-52f0-8f25-52ef2414e9a0"
  },
  {
    "prompt": "__________ a big bed in my room, but no desk.",
    "choices": [
      "There are",
      "There is",
      "It has"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng ''There is'' cho danh từ số ít ''a big bed''.",
    "old_id": "b12f32cb-2a03-5649-ae15-93499b05abf6",
    "new_id": "dd006ecf-f803-59c8-bc22-d213876da025"
  },
  {
    "prompt": "Do you have your __________ with you for the flight?",
    "choices": [
      "passport",
      "hotel",
      "booking"
    ],
    "correct_index": 0,
    "explanation_vi": "Hộ chiếu là giấy tờ quan trọng cần mang theo khi đi máy bay.",
    "old_id": "7fed8b75-02a4-50d3-a313-95e7b4582159",
    "new_id": "85840f86-5b2d-5c90-9647-f087e8ee3aa8"
  },
  {
    "prompt": "__________ any free rooms available for tonight?",
    "choices": [
      "Is there",
      "Are there",
      "Are they"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng ''Are there'' để hỏi về sự tồn tại của danh từ số nhiều ''rooms''.",
    "old_id": "969720b2-fb63-58f0-88b7-b360e9430817",
    "new_id": "a09e5b64-32fc-52b8-9551-e4e4bcb01433"
  },
  {
    "prompt": "I need to __________ my flight and hotel online today.",
    "choices": [
      "booking",
      "book",
      "passport"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''book'' dùng để chỉ hành động đặt chỗ cho chuyến đi.",
    "old_id": "dfa83ceb-4e6e-5ff5-ab11-ac8dd94beff5",
    "new_id": "97953392-4afb-54ef-b17d-76567cd3273b"
  },
  {
    "prompt": "__________ three museums near our hotel in the city.",
    "choices": [
      "There are",
      "There is",
      "They are"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''There are'' cho số lượng ''three'' (số nhiều).",
    "old_id": "d0f86278-8119-5e8d-b0ad-991a0d2efaee",
    "new_id": "5b9d82cc-0c3a-5b24-8af2-ec13f4c4014e"
  },
  {
    "prompt": "Can you show me your __________ so I can check your name?",
    "choices": [
      "booking",
      "passport",
      "hotel"
    ],
    "correct_index": 1,
    "explanation_vi": "Lễ tân cần kiểm tra hộ chiếu để xác nhận danh tính khách hàng.",
    "old_id": "71040673-dff4-5d6d-86df-a609e6dc9792",
    "new_id": "95f4ebd5-4bb0-599f-abba-72c697e0d702"
  },
  {
    "prompt": "Last month, Sarah went to the mountains. She loved the clean air and beautiful scenery. She really ______ the trip.",
    "choices": [
      "stayed",
      "visited",
      "enjoyed"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''enjoyed'' phù hợp với ngữ cảnh bày tỏ cảm xúc tích cực về chuyến đi.",
    "old_id": "5cf7124a-b6a8-5a89-8b53-f304883c9046",
    "new_id": "49e88034-afeb-5cf6-8e9b-81192c31f627"
  },
  {
    "prompt": "We traveled to the coast for our vacation. We ______ at a small, comfortable hotel near the beach.",
    "choices": [
      "visited",
      "enjoyed",
      "stayed"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''stayed'' diễn tả việc lưu trú tại một địa điểm trong kỳ nghỉ.",
    "old_id": "ae1df1ad-04bf-50dd-84f6-02f07868e53f",
    "new_id": "a97862eb-ae4d-590a-811e-0e336bf619cc"
  },
  {
    "prompt": "During my summer holidays, I ______ many interesting museums and ancient palaces in the capital city.",
    "choices": [
      "enjoyed",
      "visited",
      "stayed"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''visited'' được dùng để chỉ việc đi tham quan các địa điểm du lịch.",
    "old_id": "36c3d28c-2f06-5701-a2d3-1382638649a6",
    "new_id": "5997d4b8-d871-5952-b50c-6dc63ee5e15b"
  },
  {
    "prompt": "I ______ a very delicious dinner with my family at a local restaurant last night.",
    "choices": [
      "had",
      "haded",
      "have"
    ],
    "correct_index": 0,
    "explanation_vi": "Quá khứ đơn của động từ ''have'' là ''had'' để chỉ hành động xảy ra trong quá khứ.",
    "old_id": "7b5dc999-554b-5d95-876a-226d457aa7fb",
    "new_id": "1c07b14b-e838-531e-9ab6-1d95bd749ffb"
  },
  {
    "prompt": "They ______ to the beach last weekend because the weather was sunny and warm.",
    "choices": [
      "went",
      "go",
      "goes"
    ],
    "correct_index": 0,
    "explanation_vi": "Quá khứ đơn của ''go'' là ''went'' phù hợp với trạng từ chỉ thời gian ''last weekend''.",
    "old_id": "4038bad4-5e16-5c35-a9d9-d0f6bd73fd58",
    "new_id": "956b29f1-27fd-58fe-b8ba-f95e73d2b0c3"
  },
  {
    "prompt": "We ______ our friends at the park yesterday afternoon for a short picnic.",
    "choices": [
      "meet",
      "met",
      "meets"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''met'' là dạng quá khứ bất quy tắc của ''meet'' dùng cho thời điểm quá khứ.",
    "old_id": "28fb0eb7-7696-5ae9-8aac-7f7ff50336f9",
    "new_id": "bb7a9473-119d-52b4-beff-a0ce3f56b7b9"
  },
  {
    "prompt": "A: Did you like your trip to Paris?\nB: Yes, it was amazing! I ______ every minute of it.",
    "choices": [
      "enjoyed",
      "visit",
      "stay"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời cần một động từ ở dạng quá khứ để đồng nhất với thì của câu hỏi.",
    "old_id": "ad4cea8f-ef3b-5f84-b9e3-09657e280cfc",
    "new_id": "d71791be-4f6f-5513-8704-93056d66a5c0"
  },
  {
    "prompt": "A: Where did you stay during your vacation?\nB: I ______ with my cousins in their house.",
    "choices": [
      "stays",
      "stayed",
      "stay"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu hỏi ở thì quá khứ nên câu trả lời phải dùng động từ ''stayed'' ở dạng quá khứ.",
    "old_id": "d550743c-ef82-5277-bbbc-e86ed456a95c",
    "new_id": "9241c093-4842-5439-ae52-eb27792a1792"
  },
  {
    "prompt": "A: Who did you visit in London?\nB: I ______ my uncle who lives in the city center.",
    "choices": [
      "visiting",
      "visited",
      "visit"
    ],
    "correct_index": 1,
    "explanation_vi": "Cần dùng thì quá khứ đơn ''visited'' để trả lời cho câu hỏi về hành động đã xảy ra.",
    "old_id": "527c70f1-ebf4-5f27-8f53-20b2a315b357",
    "new_id": "e7006c0a-14a3-5f50-9d60-ab65ece01d68"
  },
  {
    "prompt": "Yesterday, we ______ a long walk in the forest and took many photos.",
    "choices": [
      "takes",
      "take",
      "took"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''took'' là quá khứ của ''take'' để diễn tả hành động trong ngày hôm qua.",
    "old_id": "033084a3-ac03-5931-b14b-2b8444fdc392",
    "new_id": "704400be-785b-5361-862f-04c58cd32bd4"
  },
  {
    "prompt": "My sister ______ her suitcase carefully before we left for the airport.",
    "choices": [
      "packed",
      "pack",
      "packs"
    ],
    "correct_index": 0,
    "explanation_vi": "Hành động đã xảy ra và kết thúc trong quá khứ nên cần dùng dạng thêm đuôi ''-ed''.",
    "old_id": "77811df2-5c6c-5ff7-917b-20adfb643ccb",
    "new_id": "7dee15e3-4544-5aa1-b76b-1719f6c849b3"
  },
  {
    "prompt": "The flight ______ two hours late, so we arrived at the hotel very tired.",
    "choices": [
      "were",
      "is",
      "was"
    ],
    "correct_index": 2,
    "explanation_vi": "Chủ ngữ số ít ''the flight'' đi với ''was'' ở thì quá khứ.",
    "old_id": "c25b2029-7d30-51f0-8dc2-69569dd458e4",
    "new_id": "c64d3659-7f49-58f5-b2fa-60ad561af6e8"
  },
  {
    "prompt": "I ______ a beautiful sunset over the ocean while I was on the beach.",
    "choices": [
      "see",
      "saw",
      "sees"
    ],
    "correct_index": 1,
    "explanation_vi": "Dạng quá khứ của ''see'' là ''saw'' phù hợp với ngữ cảnh câu chuyện quá khứ.",
    "old_id": "7878f246-cb53-5366-b326-471465ae37c2",
    "new_id": "cd7e601a-230a-5c9a-85ad-292529308151"
  },
  {
    "prompt": "They ______ the bus to the city center because the subway was closed.",
    "choices": [
      "take",
      "takes",
      "took"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ bất quy tắc ''took'' là dạng đúng của ''take'' trong thì quá khứ đơn.",
    "old_id": "2ec6bed3-2cfd-5bf7-830d-b02b2f869eec",
    "new_id": "af2d6cb5-f357-579e-a130-0cb74443a012"
  },
  {
    "prompt": "We ______ all the souvenirs in the small shop near the museum.",
    "choices": [
      "bought",
      "buied",
      "buy"
    ],
    "correct_index": 0,
    "explanation_vi": "''Bought'' là dạng quá khứ đúng của động từ ''buy''.",
    "old_id": "1d98f049-38ae-58b9-8138-7435f55b20f2",
    "new_id": "83db028a-eb5d-5bd0-92ed-4485a5f2170a"
  },
  {
    "prompt": "I always go to the gym after work, but today I _______ at home because I am very tired.",
    "choices": [
      "to rest",
      "am resting",
      "rest"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng thì hiện tại tiếp diễn cho một hành động đang diễn ra cụ thể vào ''today'' (hôm nay).",
    "old_id": "9c635979-9bc4-5289-8bd6-477c6c70042a",
    "new_id": "36f01103-2954-5cf3-ab00-e14f3be9fa5e"
  },
  {
    "prompt": "My daily routine is simple; I _______ coffee every morning before I start my classes.",
    "choices": [
      "am drinking",
      "drink",
      "to drink"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng thì hiện tại đơn để diễn tả thói quen hằng ngày (daily routine).",
    "old_id": "82c636a3-3247-5a7d-801f-71b95832e69b",
    "new_id": "0a8c656f-b3b6-5661-a8f8-e3c86b8141e9"
  },
  {
    "prompt": "She is _______ a new project currently, so she does not have much free time this week.",
    "choices": [
      "works",
      "work",
      "working"
    ],
    "correct_index": 2,
    "explanation_vi": "Trạng từ ''currently'' chỉ một hành động đang diễn ra nên dùng thì hiện tại tiếp diễn.",
    "old_id": "16cdedfa-f8ce-51e0-9418-6a06a903bd99",
    "new_id": "2f0ce181-894c-5565-95f3-ad849d8d4c35"
  },
  {
    "prompt": "Usually, Mark _______ the bus to work, but he is driving his car this week.",
    "choices": [
      "takes",
      "take",
      "is taking"
    ],
    "correct_index": 0,
    "explanation_vi": "Trạng từ ''usually'' yêu cầu sử dụng thì hiện tại đơn cho hành động lặp đi lặp lại.",
    "old_id": "58f87c46-a234-5b94-97a3-6479da2f2228",
    "new_id": "32487801-27ab-5c03-b273-aa03a185c1cd"
  },
  {
    "prompt": "Look! The students _______ for the teacher in the hallway right now.",
    "choices": [
      "are waiting",
      "wait",
      "waits"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''Look!'' và ''right now'' cho thấy hành động đang xảy ra tại thời điểm nói.",
    "old_id": "0b77132e-8051-594d-8f7a-b4b2532c3c4f",
    "new_id": "1e257560-0e1b-5d94-aa40-66d8a01df10f"
  },
  {
    "prompt": "Every day, Sarah _______ to the park to practice her photography skills.",
    "choices": [
      "go",
      "is going",
      "goes"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''Every day'' xác định đây là một thói quen cần dùng thì hiện tại đơn.",
    "old_id": "29300c0e-55ec-560a-ab5e-ca20b0304106",
    "new_id": "73abea2c-83b6-5531-8977-9046439f43c7"
  },
  {
    "prompt": "A: Do you usually study in the library? B: Yes, but I _______ in a cafe today.",
    "choices": [
      "studied",
      "study",
      "am studying"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng thì hiện tại tiếp diễn để mô tả sự thay đổi tạm thời so với thói quen hằng ngày.",
    "old_id": "8d7e26cf-352e-57f5-be51-5deca2cfb9ef",
    "new_id": "f71b9716-7e73-5c58-986e-527e0452e4c5"
  },
  {
    "prompt": "A: What is your brother doing? B: He _______ for his final exams all afternoon.",
    "choices": [
      "is preparing",
      "prepares",
      "prepare"
    ],
    "correct_index": 0,
    "explanation_vi": "Hành động đang tiếp diễn tại thời điểm nói nên cần thì hiện tại tiếp diễn.",
    "old_id": "cecb4f75-7391-5d1c-aa62-44b8cf38ffe8",
    "new_id": "b6538bb3-2658-5a42-9e91-501c74f538b9"
  },
  {
    "prompt": "A: How often do you call your parents? B: I _______ them every Sunday evening.",
    "choices": [
      "am calling",
      "call",
      "calls"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu hỏi ''How often'' gợi ý dùng thì hiện tại đơn để trả lời về tần suất.",
    "old_id": "37a8b9a0-65c7-536a-b513-049dfbdc3c5f",
    "new_id": "e0d715c5-dc52-5a5f-9835-51b1f540e1b7"
  },
  {
    "prompt": "Most people _______ to sleep around 11 PM, but tonight I am staying up late.",
    "choices": [
      "go",
      "are going",
      "goes"
    ],
    "correct_index": 0,
    "explanation_vi": "Đây là một sự thật mang tính thói quen chung nên dùng thì hiện tại đơn.",
    "old_id": "789bbde5-d66f-5122-8e33-8ab7f06d165a",
    "new_id": "774718f9-2627-5b9c-8aa5-f95ee8b07d03"
  },
  {
    "prompt": "My sister _______ the piano lessons every Saturday, but she is busy today.",
    "choices": [
      "attends",
      "attend",
      "is attending"
    ],
    "correct_index": 0,
    "explanation_vi": "Sử dụng thì hiện tại đơn cho lịch trình lặp lại vào thứ Bảy hằng tuần.",
    "old_id": "5a5ee285-4d84-5286-9cd6-8d4c7deb26d8",
    "new_id": "8d2fcb0e-886a-5e6a-b563-c2c3b46f8566"
  },
  {
    "prompt": "Currently, the company _______ a new system to help employees work faster.",
    "choices": [
      "tests",
      "is testing",
      "test"
    ],
    "correct_index": 1,
    "explanation_vi": "Trạng từ ''currently'' chỉ sự việc đang diễn ra ở hiện tại nên dùng thì tiếp diễn.",
    "old_id": "3d4a0132-ddd5-5e51-a3d6-75e2ac7809da",
    "new_id": "a7cf5b54-092f-58eb-9f8a-8928eac81498"
  },
  {
    "prompt": "He _______ his emails before he starts any other task in the morning.",
    "choices": [
      "is checking",
      "checks",
      "check"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc diễn tả trình tự thói quen hằng ngày cần chia động từ ở hiện tại đơn.",
    "old_id": "f07feb1c-d542-5ff5-bb06-22d8ea46771d",
    "new_id": "a60662c9-a7c1-545b-87f2-7b36d0745567"
  },
  {
    "prompt": "Listen! The neighbors _______ loud music in their apartment again.",
    "choices": [
      "plays",
      "play",
      "are playing"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''Listen!'' yêu cầu sử dụng thì hiện tại tiếp diễn cho hành động đang nghe thấy.",
    "old_id": "8d43043e-b784-52ae-8623-cd829b23f162",
    "new_id": "527dde07-be94-5a20-b8e0-66dcdc0eafa7"
  },
  {
    "prompt": "I _______ my project today because the deadline is tomorrow morning.",
    "choices": [
      "finishes",
      "finish",
      "am finishing"
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng thì hiện tại tiếp diễn cho một nhiệm vụ cụ thể đang được thực hiện vào hôm nay.",
    "old_id": "ebf6e3c8-5e96-50e0-8598-fe0454319021",
    "new_id": "2a9c2a0d-7588-5467-8f22-446310bd41bc"
  },
  {
    "prompt": "I moved to this city three years ____, and I still love living here.",
    "choices": [
      "ago",
      "last",
      "before"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''ago'' được dùng sau một khoảng thời gian để chỉ một thời điểm trong quá khứ.",
    "old_id": "fa299dc8-1283-501f-99cd-4618a63fae50",
    "new_id": "d0a8aefc-45e4-595d-b873-3859377d866a"
  },
  {
    "prompt": "What ____ to your phone? It looks like the screen is completely broken.",
    "choices": [
      "did",
      "made",
      "happened"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''happen'' diễn tả sự việc đã xảy ra với một vật hoặc người.",
    "old_id": "3604db07-c6ce-53e2-8fcd-a652e1346f7c",
    "new_id": "21306076-4728-595a-888f-53f2a8f80a3a"
  },
  {
    "prompt": "We went on a trip to the mountains ____ weekend, and the weather was perfect.",
    "choices": [
      "ago",
      "past",
      "last"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''last weekend'' được sử dụng để chỉ thời điểm cuối tuần vừa qua.",
    "old_id": "ad611966-56d1-5639-b6b5-4c1421112db7",
    "new_id": "afba666b-9420-5112-bb6e-029aae2c45f1"
  },
  {
    "prompt": "I ____ my keys on the kitchen table yesterday morning.",
    "choices": [
      "left",
      "leave",
      "leaved"
    ],
    "correct_index": 0,
    "explanation_vi": "Động từ ''leave'' ở dạng quá khứ đơn là ''left''.",
    "old_id": "c38466df-46d1-5612-995c-0f80c72b2b7f",
    "new_id": "083bdcfe-1fe8-5fba-bb53-007f4bb6b2ac"
  },
  {
    "prompt": "They ____ at the library to finish their group project together.",
    "choices": [
      "meet",
      "meets",
      "met"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''meet'' ở dạng quá khứ đơn là ''met''.",
    "old_id": "a6144968-6bbb-56ae-9493-d05a45efc125",
    "new_id": "db699b78-71e3-5271-a7fc-68397c6f0bd2"
  },
  {
    "prompt": "She ____ very tired after the long flight home.",
    "choices": [
      "were",
      "was",
      "is"
    ],
    "correct_index": 1,
    "explanation_vi": "Chủ ngữ số ít ''she'' đi với động từ ''to be'' ở dạng quá khứ đơn là ''was''.",
    "old_id": "7b1a062f-d483-5344-879e-d4aeb17cdd56",
    "new_id": "808b3fd8-5cbd-51a7-b816-8f229c5fbca7"
  },
  {
    "prompt": "A: Did you see the news today? B: No, what ____?",
    "choices": [
      "happened",
      "it is",
      "was it"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu hỏi ''What happened?'' được dùng để hỏi về một sự kiện đã diễn ra.",
    "old_id": "1cae526d-08ce-567a-a6f1-feaf9c2e52a0",
    "new_id": "760053e7-5722-5dba-ba7e-e6a7e7694dd8"
  },
  {
    "prompt": "A: When did you visit your grandparents? B: I ____ them two days ago.",
    "choices": [
      "visited",
      "visiting",
      "visit"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời phải dùng thì quá khứ đơn để tương ứng với câu hỏi.",
    "old_id": "3bb9f8ec-59f8-562c-8469-3e471c50c1ef",
    "new_id": "1e4b44f9-6f6e-517e-8d98-d284946f87f9"
  },
  {
    "prompt": "A: How was your weekend? B: It ____ great, thanks for asking!",
    "choices": [
      "is",
      "was",
      "did"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu trả lời dùng ''was'' để miêu tả trạng thái của kỳ nghỉ đã qua.",
    "old_id": "1367a260-8246-5c00-91dc-0c81bac68ce5",
    "new_id": "173b9d03-01b3-5faa-af73-30816195b808"
  },
  {
    "prompt": "We ____ a delicious pizza for dinner last night.",
    "choices": [
      "eated",
      "ate",
      "eat"
    ],
    "correct_index": 1,
    "explanation_vi": "Dạng quá khứ đơn bất quy tắc của động từ ''eat'' là ''ate''.",
    "old_id": "d95a6d51-7f3c-5458-b6f1-676d493a1a1d",
    "new_id": "c463098a-a876-5787-bdd6-333f78b5916b"
  },
  {
    "prompt": "I ____ a text message from my brother an hour ago.",
    "choices": [
      "get",
      "got",
      "gets"
    ],
    "correct_index": 1,
    "explanation_vi": "Dạng quá khứ đơn của động từ ''get'' là ''got''.",
    "old_id": "c688050e-4f1f-535c-80e9-f59ad258cc2d",
    "new_id": "57c2cc28-e547-50b2-88c9-99b6fb2d77f1"
  },
  {
    "prompt": "She ____ her homework early because she wanted to watch a movie.",
    "choices": [
      "finish",
      "finished",
      "finishing"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ có quy tắc cần thêm đuôi ''-ed'' ở thì quá khứ đơn.",
    "old_id": "df983f6f-a2b0-56e4-bf99-2a46f75566c0",
    "new_id": "3ab2c5ad-c170-52e6-b021-7d4f62a10738"
  },
  {
    "prompt": "They ____ to the park to play soccer on Saturday afternoon.",
    "choices": [
      "went",
      "go",
      "goed"
    ],
    "correct_index": 0,
    "explanation_vi": "Dạng quá khứ đơn bất quy tắc của động từ ''go'' là ''went''.",
    "old_id": "23deec6e-1bdb-5000-8106-8a23bab807a5",
    "new_id": "92c59bd2-d797-5891-84f5-d3cb43ca984f"
  },
  {
    "prompt": "I ____ you at the supermarket last Monday.",
    "choices": [
      "see",
      "seen",
      "saw"
    ],
    "correct_index": 2,
    "explanation_vi": "Dạng quá khứ đơn bất quy tắc của động từ ''see'' là ''saw''.",
    "old_id": "9e544870-19d7-5fd6-917a-9843b4dc9794",
    "new_id": "5675dc52-b16c-5fea-8531-787eb4714472"
  },
  {
    "prompt": "He ____ his car to the garage because the engine made a loud noise.",
    "choices": [
      "takes",
      "take",
      "took"
    ],
    "correct_index": 2,
    "explanation_vi": "Dạng quá khứ đơn bất quy tắc của động từ ''take'' là ''took''.",
    "old_id": "727aa7ff-c9d9-55d5-ada5-ed331b7798d6",
    "new_id": "3adf90bb-5769-5395-9de6-a86f5bc154a7"
  },
  {
    "prompt": "I have a flight at 8 AM. I ______ to leave the house at 6 AM to be safe.",
    "choices": [
      "plan",
      "arrange",
      "tomorrow"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''plan'' dùng để diễn đạt dự định hoặc kế hoạch cá nhân trước khi thực hiện.",
    "old_id": "d9e6980b-cd82-5f5b-a3e2-41dd31dbda0e",
    "new_id": "0189c8a7-26ea-535e-9bb0-ed165c5b332d"
  },
  {
    "prompt": "We need to ______ a meeting with the client for next Monday to discuss the contract.",
    "choices": [
      "going to",
      "tomorrow",
      "arrange"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''arrange'' phù hợp trong ngữ cảnh thiết lập một buổi gặp mặt với người khác.",
    "old_id": "079a230f-ed61-54f9-812a-cf03ef6bccf4",
    "new_id": "da30ff0b-9a19-5a20-8b1c-999a65402fb0"
  },
  {
    "prompt": "The weather forecast says it will be sunny ______, so we should go for a picnic.",
    "choices": [
      "arrange",
      "plan",
      "tomorrow"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''tomorrow'' là danh từ chỉ thời gian phù hợp để nói về dự định cho ngày tiếp theo.",
    "old_id": "341ac397-6883-5cea-beb3-851934a22256",
    "new_id": "9d7e2dd9-e4c1-5732-8e6a-102a529cebae"
  },
  {
    "prompt": "Look at those dark clouds! It ______ rain very soon.",
    "choices": [
      "is going",
      "is going to",
      "go to"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''is going to'' được dùng để dự đoán dựa trên bằng chứng cụ thể là những đám mây đen.",
    "old_id": "96d65513-17b0-5fd8-857f-a7493f7da9ed",
    "new_id": "4263f0db-7d78-5b5f-b2ae-beb38d8679f9"
  },
  {
    "prompt": "We ______ a birthday party for my sister this Saturday evening.",
    "choices": [
      "are having",
      "having",
      "going to have"
    ],
    "correct_index": 0,
    "explanation_vi": "Thì hiện tại tiếp diễn được sử dụng để nói về các kế hoạch đã được ấn định thời gian cụ thể trong tương lai.",
    "old_id": "93a5efa6-8ac1-5182-a54f-b63abc5e849e",
    "new_id": "c2701a4b-f2d7-5ac0-bbcc-bdcac969c8bb"
  },
  {
    "prompt": "My parents ______ visit their friends in the countryside next week.",
    "choices": [
      "are going to",
      "are",
      "going to"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''are going to'' diễn đạt một dự định đã được vạch ra sẵn.",
    "old_id": "2e72fb26-6041-50c2-8e77-73f955b2f0b6",
    "new_id": "b1ec272a-1e8c-5af3-a168-2d41425f215a"
  },
  {
    "prompt": "A: What are your plans for the weekend? B: ______",
    "choices": [
      "I visit my grandmother.",
      "I am visiting my grandmother.",
      "I am visit my grandmother."
    ],
    "correct_index": 1,
    "explanation_vi": "Câu trả lời đúng phải chia theo thì hiện tại tiếp diễn để diễn đạt kế hoạch cụ thể cho tương lai.",
    "old_id": "a90d2772-3f83-5da4-92f0-c26272332b4f",
    "new_id": "a4378734-0f15-5179-92a2-62cb39b3e6a3"
  },
  {
    "prompt": "A: Are you free on Friday? B: No, ______. I have a dentist appointment.",
    "choices": [
      "I to work",
      "I work",
      "I am working"
    ],
    "correct_index": 2,
    "explanation_vi": "Thì hiện tại tiếp diễn là cách tự nhiên nhất để nói về lịch trình đã chốt trong tương lai.",
    "old_id": "aa70ea3f-7fba-5d09-95e2-c34ffde6fbd1",
    "new_id": "157a0318-b911-51cb-ad74-f225ad01ac02"
  },
  {
    "prompt": "A: Have you booked the tickets yet? B: Not yet, but I ______ buy them this afternoon.",
    "choices": [
      "going to",
      "am going to",
      "am go to"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''am going to'' cần động từ ''to be'' chia theo chủ ngữ ''I''.",
    "old_id": "37b41928-e097-5c10-85a0-f74f6bf5d9d0",
    "new_id": "65dd5d47-c838-59e4-941b-307551558cce"
  },
  {
    "prompt": "My brother ______ his luggage right now for his trip to Japan.",
    "choices": [
      "packs",
      "going to pack",
      "is packing"
    ],
    "correct_index": 2,
    "explanation_vi": "Hành động đang diễn ra tại thời điểm nói yêu cầu thì hiện tại tiếp diễn.",
    "old_id": "e5f6d106-85b3-5d35-b24b-f8ff644355d1",
    "new_id": "d310392a-d18e-5c90-99e8-8ae5f86b7f81"
  },
  {
    "prompt": "We ______ a new car, we have already saved enough money.",
    "choices": [
      "are going to buy",
      "are buying",
      "buy"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''going to'' diễn đạt ý định đã quyết định trước đó khi đã có đủ tiền.",
    "old_id": "4af35618-870a-5044-ba8f-1bf4aed48d16",
    "new_id": "a742c9f6-2eac-5c9c-8ad4-3646e5f7320f"
  },
  {
    "prompt": "Please don''t call me at 9 PM because I ______ a movie with my friends.",
    "choices": [
      "watch",
      "am watching",
      "going to watch"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng hiện tại tiếp diễn để nói về một sự việc đã sắp xếp cố định vào một thời điểm trong tương lai.",
    "old_id": "17cf4e95-6fc6-5f25-931f-2744736fb8df",
    "new_id": "acd86db5-40a0-53a6-83ce-5472d83ba7f6"
  },
  {
    "prompt": "I ______ to the gym later today to exercise for an hour.",
    "choices": [
      "am going",
      "am going to go",
      "go"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''am going to'' cộng với động từ ''go'' là cách diễn đạt đúng về kế hoạch tương lai.",
    "old_id": "48707349-b731-5181-8ea8-28ae0c1163f0",
    "new_id": "9a7baaf8-3bac-5398-bbf6-2c8ee32d4008"
  },
  {
    "prompt": "The company ______ a new manager next month to replace the old one.",
    "choices": [
      "hiring",
      "hires",
      "is hiring"
    ],
    "correct_index": 2,
    "explanation_vi": "Việc tuyển dụng đã có kế hoạch cụ thể nên sử dụng thì hiện tại tiếp diễn.",
    "old_id": "6e1779a1-7633-520d-95ed-aff7b018a0fd",
    "new_id": "ea03bc3c-8a57-5fa3-9870-e1535b0aea91"
  },
  {
    "prompt": "We ______ our house next summer; we have already hired an architect.",
    "choices": [
      "are renovating",
      "renovate",
      "renovating"
    ],
    "correct_index": 0,
    "explanation_vi": "Một kế hoạch chắc chắn với sự chuẩn bị từ trước cần dùng thì hiện tại tiếp diễn.",
    "old_id": "3654fc0f-17db-580f-bd0e-54d4da620225",
    "new_id": "4afc8963-cc8f-5521-b5ed-c09cde0c89de"
  },
  {
    "prompt": "Our new office is much _____ than the old one; we have enough space for everyone now.",
    "choices": [
      "bigger",
      "biggest",
      "big"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc so sánh hơn với ''than'' yêu cầu tính từ ngắn thêm đuôi -er.",
    "old_id": "fba168c2-2afa-5068-a55d-02ddc4428ed4",
    "new_id": "08c9a344-e251-5ae9-9f08-a70380a07ed1"
  },
  {
    "prompt": "This restaurant is the _____ place in town to eat because they use fresh local ingredients.",
    "choices": [
      "best",
      "better",
      "good"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc so sánh nhất đi với ''the'' yêu cầu dạng so sánh nhất.",
    "old_id": "1734ed01-fce0-5539-8f8e-13f42f486938",
    "new_id": "5aad6ffd-7d59-5949-a496-e3dc27f6e2b1"
  },
  {
    "prompt": "Traveling by train is _____ than taking the bus because it is faster and more comfortable.",
    "choices": [
      "more good",
      "the best",
      "better"
    ],
    "correct_index": 2,
    "explanation_vi": "Dạng so sánh hơn của ''good'' là ''better'', không dùng ''more good''.",
    "old_id": "7c3845de-8e1f-54c8-ac36-d39beb6baf8b",
    "new_id": "3f51c59f-b349-55ef-ab60-f1dd0f38cd2a"
  },
  {
    "prompt": "My sister is the _____ runner in her school; she wins every race she enters.",
    "choices": [
      "faster",
      "fastest",
      "fast"
    ],
    "correct_index": 1,
    "explanation_vi": "Trong ngữ cảnh so sánh với cả nhóm (trường học), ta dùng so sánh nhất.",
    "old_id": "feb4bc15-1915-5489-b121-0ea00fc36425",
    "new_id": "6ca75720-7700-5bed-a2e1-3d7d89517dac"
  },
  {
    "prompt": "Today is _____ than yesterday, so please wear a warmer coat outside.",
    "choices": [
      "coldest",
      "colder",
      "more cold"
    ],
    "correct_index": 1,
    "explanation_vi": "Tính từ ngắn ''cold'' khi so sánh hơn cần thêm đuôi -er.",
    "old_id": "965cccb1-2c28-5101-9d7a-e83799af5488",
    "new_id": "a453b8f1-e6d9-5dda-af4e-0f11e3ae76f5"
  },
  {
    "prompt": "Of all the movies we watched this year, this one was definitely the _____ interesting.",
    "choices": [
      "most",
      "more",
      "very"
    ],
    "correct_index": 0,
    "explanation_vi": "Tính từ dài ''interesting'' dùng ''most'' để tạo thành dạng so sánh nhất.",
    "old_id": "cba01a4c-69f3-5ee1-8bf1-2ad5ff433a38",
    "new_id": "54cc27c6-7740-55cb-8513-779dbff0e005"
  },
  {
    "prompt": "A: Which jacket do you prefer? B: I like the blue one. It is _____ than the grey one.",
    "choices": [
      "cheap",
      "the cheapest",
      "cheaper"
    ],
    "correct_index": 2,
    "explanation_vi": "Đang so sánh giữa hai đối tượng nên dùng so sánh hơn.",
    "old_id": "edabdd41-94b9-5f34-9d08-5a5cfd8a2f92",
    "new_id": "763a1ed4-2e4d-5e5d-acc9-eea3393d5498"
  },
  {
    "prompt": "A: Is this math problem difficult? B: Yes, it is the _____ one in the entire textbook.",
    "choices": [
      "hardest",
      "harder",
      "more hard"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm từ ''in the entire textbook'' xác định đây là so sánh nhất.",
    "old_id": "37c9bfef-212a-5ace-8825-386482091997",
    "new_id": "8f4ab1f1-f788-5e31-84e0-77ebdc48d488"
  },
  {
    "prompt": "A: Why did you choose this hotel? B: It offered the _____ price of all the places I checked.",
    "choices": [
      "lower",
      "low",
      "lowest"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc so sánh nhất với ''of all the places'' yêu cầu tính từ dạng ''lowest''.",
    "old_id": "6b1e254e-1d33-526c-b2bc-8c5f4f493dd9",
    "new_id": "9c7eceb9-aaaa-56d2-a428-06f0a68da2fe"
  },
  {
    "prompt": "The subway is the _____ way to get across the city during rush hour.",
    "choices": [
      "fast",
      "faster",
      "fastest"
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng so sánh nhất để chỉ phương thức hiệu quả nhất trong mọi trường hợp.",
    "old_id": "7929ad0d-403a-5673-adf6-d570211d7b9c",
    "new_id": "44f6c789-b0fa-56f5-a6c2-203f4a0bbfb8"
  },
  {
    "prompt": "Learning to play the piano is _____ than I expected, but I enjoy it.",
    "choices": [
      "harder",
      "more hard",
      "hardest"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc so sánh giữa hiện tại và kỳ vọng dùng so sánh hơn ''harder''.",
    "old_id": "fa1eb77d-fd4b-5372-b09b-01728a565b86",
    "new_id": "f1eb5896-1c6b-5b95-ac16-be63270d59c1"
  },
  {
    "prompt": "These shoes are _____ than the ones I bought last month.",
    "choices": [
      "comfortable",
      "more comfortable",
      "most comfortable"
    ],
    "correct_index": 1,
    "explanation_vi": "Tính từ dài ''comfortable'' dùng ''more'' cho so sánh hơn.",
    "old_id": "9ed44d45-438e-57b6-8f7a-4eed43622a30",
    "new_id": "d2bdccb3-f2b2-511f-b63d-a6f1524335f8"
  },
  {
    "prompt": "The coffee at this shop is the _____ in the neighborhood.",
    "choices": [
      "better",
      "good",
      "best"
    ],
    "correct_index": 2,
    "explanation_vi": "Khi so sánh một đối tượng với toàn bộ nhóm (trong khu phố), ta dùng so sánh nhất.",
    "old_id": "df90fd9e-0ac9-58aa-ae8a-1af1614f93b9",
    "new_id": "147cf625-cc1e-5967-ad45-e9115fef8d8d"
  },
  {
    "prompt": "My new computer is _____ than my laptop, so it fits in my bag easily.",
    "choices": [
      "smallest",
      "smaller",
      "small"
    ],
    "correct_index": 1,
    "explanation_vi": "So sánh giữa hai vật dùng tính từ ngắn thêm đuôi -er.",
    "old_id": "a1ed6768-b497-58b8-ab71-db08597fa8c6",
    "new_id": "cbe7f6b7-cc69-5899-8a85-57d35cb3650d"
  },
  {
    "prompt": "The test we took today was the _____ one we have had this semester.",
    "choices": [
      "longer",
      "longest",
      "long"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng so sánh nhất vì đang so sánh bài kiểm tra này với tất cả bài khác trong học kỳ.",
    "old_id": "121d550b-d1a6-5ce8-af7e-ae581eac731f",
    "new_id": "ef346a33-3f0a-59b9-9d4b-161112838668"
  },
  {
    "prompt": "I didn''t go to the park _______ it was raining heavily all afternoon.",
    "choices": [
      "because",
      "but",
      "so"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''because'' được dùng để chỉ lý do cho hành động không đi công viên.",
    "old_id": "042d23f9-397e-57c5-9196-3b21bc9b0106",
    "new_id": "36f81b74-7d2f-50b0-a4cf-e9fd836dbf20"
  },
  {
    "prompt": "The soup was very salty, _______ I didn''t finish eating it.",
    "choices": [
      "because",
      "but",
      "so"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''so'' dùng để nối kết quả của việc súp bị mặn là không ăn hết.",
    "old_id": "6ecebbd6-3456-5c00-8204-e985c441eab0",
    "new_id": "8bfd8e8c-721c-56a6-8c32-8bf41f2bb7c1"
  },
  {
    "prompt": "She studied hard for the test, _______ she did not get a high grade.",
    "choices": [
      "because",
      "but",
      "so"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''but'' dùng để diễn tả sự đối lập giữa việc học chăm chỉ và kết quả không tốt.",
    "old_id": "e2f6bddf-9918-54ab-93f3-45c076a4fd63",
    "new_id": "f9272668-62ec-5141-822f-7f28f8f41a6f"
  },
  {
    "prompt": "We were hungry, _______ we stopped at a restaurant for lunch.",
    "choices": [
      "because",
      "so",
      "but"
    ],
    "correct_index": 1,
    "explanation_vi": "Kết quả của việc đói bụng là dừng lại ăn trưa, nên dùng ''so''.",
    "old_id": "a5a5c1d7-deeb-5610-a298-62e83507eec5",
    "new_id": "0bbe257f-9d14-554d-8b94-d4ba38d98a18"
  },
  {
    "prompt": "He wants to buy a new car, _______ he doesn''t have enough money yet.",
    "choices": [
      "so",
      "but",
      "because"
    ],
    "correct_index": 1,
    "explanation_vi": "Có sự tương phản giữa mong muốn mua xe và thực tế thiếu tiền, nên dùng ''but''.",
    "old_id": "35006e7a-3b78-5845-b3a6-69d1b4964562",
    "new_id": "9e3ff9df-f08d-59cd-8f3d-d16a9731e43d"
  },
  {
    "prompt": "I am staying at home tonight _______ I have a lot of work to do.",
    "choices": [
      "but",
      "because",
      "so"
    ],
    "correct_index": 1,
    "explanation_vi": "Việc nhiều việc là lý do cho việc ở nhà, nên dùng ''because''.",
    "old_id": "c572e04b-82a2-57a8-aecd-b99d110153d3",
    "new_id": "fd25a5f8-2f86-5b84-af9c-46a09b67f3a2"
  },
  {
    "prompt": "A: Why are you wearing a coat? B: _______ it is very cold outside.",
    "choices": [
      "But",
      "So",
      "Because"
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời giải thích lý do cho việc mặc áo khoác nên dùng ''because''.",
    "old_id": "800fe293-c679-5af8-af52-229b8ddac7be",
    "new_id": "aef732bf-c86b-59b3-8632-d149f4d797be"
  },
  {
    "prompt": "A: Can we play football? B: It is dark, _______ we should go home now.",
    "choices": [
      "so",
      "because",
      "but"
    ],
    "correct_index": 0,
    "explanation_vi": "Trời tối là nguyên nhân dẫn đến quyết định về nhà, nên dùng ''so''.",
    "old_id": "46362bb2-aa51-508f-96b5-d68f1807255f",
    "new_id": "273b8161-a857-5c68-b08a-4bacf90e0ea8"
  },
  {
    "prompt": "A: Do you like the movie? B: The story is interesting, _______ the music is boring.",
    "choices": [
      "so",
      "because",
      "but"
    ],
    "correct_index": 2,
    "explanation_vi": "Câu này nối hai ý đối lập về cốt truyện và âm nhạc nên dùng ''but''.",
    "old_id": "df00b459-eb14-513a-b745-a6568623617c",
    "new_id": "510a9d2e-946e-51e5-b773-35e7a4fc8a50"
  },
  {
    "prompt": "I forgot my umbrella, _______ I got wet in the rain.",
    "choices": [
      "but",
      "because",
      "so"
    ],
    "correct_index": 2,
    "explanation_vi": "Việc quên ô dẫn đến kết quả là bị ướt, nên dùng ''so''.",
    "old_id": "369d3148-f20c-5f20-96a1-82169bd719fd",
    "new_id": "49196170-e889-55c4-92c1-70c9911ea376"
  },
  {
    "prompt": "She was tired _______ she went to bed early.",
    "choices": [
      "because",
      "so",
      "but"
    ],
    "correct_index": 1,
    "explanation_vi": "Kết quả của việc mệt mỏi là đi ngủ sớm, nên dùng ''so''.",
    "old_id": "16c49d1b-3703-5041-abcc-b59a784304c5",
    "new_id": "24be952f-d52f-541c-86d7-4bf836c966bb"
  },
  {
    "prompt": "The store was closed _______ it was a public holiday.",
    "choices": [
      "because",
      "but",
      "so"
    ],
    "correct_index": 0,
    "explanation_vi": "Việc là ngày lễ là lý do khiến cửa hàng đóng cửa, nên dùng ''because''.",
    "old_id": "8a2dc25a-d30e-5427-bdba-883731031c6a",
    "new_id": "2dcc0b4f-23c4-5b55-9e33-9120ec6d07e7"
  },
  {
    "prompt": "He ran very fast, _______ he missed the bus anyway.",
    "choices": [
      "so",
      "because",
      "but"
    ],
    "correct_index": 2,
    "explanation_vi": "Sự đối lập giữa việc chạy nhanh và việc vẫn lỡ xe được nối bằng ''but''.",
    "old_id": "9b4537a3-e714-5261-adad-b29ff335e900",
    "new_id": "9b7016c2-53e2-5cc5-850a-642a145d810d"
  },
  {
    "prompt": "The coffee is too hot, _______ I cannot drink it yet.",
    "choices": [
      "so",
      "because",
      "but"
    ],
    "correct_index": 0,
    "explanation_vi": "Việc cà phê quá nóng khiến tôi chưa uống được, nên dùng ''so''.",
    "old_id": "777c7c13-b947-5710-8722-238431782b80",
    "new_id": "feecd79e-b482-5637-ab6f-b4bb9eb06ba2"
  },
  {
    "prompt": "I bought this book _______ it was on sale for half price.",
    "choices": [
      "because",
      "so",
      "but"
    ],
    "correct_index": 0,
    "explanation_vi": "Lý do tôi mua cuốn sách là vì nó được giảm giá, nên dùng ''because''.",
    "old_id": "8b12fa8b-d8f7-545e-a0ea-76ffabf87745",
    "new_id": "490dad89-12cc-5784-a837-9e410c94ffdc"
  },
  {
    "prompt": "Which of these is a personal ''opinion'' rather than a factual statement?",
    "choices": [
      "The book has three hundred pages.",
      "I think this book is very boring.",
      "The author wrote this book in 1995."
    ],
    "correct_index": 1,
    "explanation_vi": "Đây là một ý kiến chủ quan dựa trên cảm nhận cá nhân thay vì một sự thật khách quan.",
    "old_id": "7d1948a4-bc6d-5b27-92af-97c75fffec94",
    "new_id": "07f53f83-3c71-5007-a439-9ffc2305dd8e"
  },
  {
    "prompt": "When you write an ''example'' in a paragraph, what are you doing?",
    "choices": [
      "Stating your main idea again.",
      "Explaining the history of your topic.",
      "Providing a specific case to prove your point."
    ],
    "correct_index": 2,
    "explanation_vi": "Ví dụ giúp làm rõ và minh họa cho ý chính của đoạn văn bằng một trường hợp cụ thể.",
    "old_id": "1857e222-f0b6-56a3-b2ed-9420ecfc8f48",
    "new_id": "5c42f0cd-f6af-5970-b319-b4e4d6ddc06b"
  },
  {
    "prompt": "If you need a ''reason'' for your opinion, what should you provide?",
    "choices": [
      "An explanation of why you feel that way.",
      "A list of your favorite colors.",
      "The exact date you formed your opinion."
    ],
    "correct_index": 0,
    "explanation_vi": "Lý do là sự giải thích hợp lý để thuyết phục người đọc về ý kiến của bạn.",
    "old_id": "a714b1bd-d48d-577c-ad0a-8106dc586990",
    "new_id": "eebe953f-35ce-56f4-9bec-0b3eedbe2c17"
  },
  {
    "prompt": "Which sentence is the best ''topic sentence'' for an opinion paragraph?",
    "choices": [
      "There are many public parks in this city with green grass.",
      "Some people like to go to the park on the weekend.",
      "Public parks are the best places for families to spend time together."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu chủ đề tốt nhất cần nêu rõ ý kiến chính mà đoạn văn sẽ thảo luận.",
    "old_id": "3a802952-e80a-56f7-bf20-cf22309cab16",
    "new_id": "977262bb-0103-5c75-a3ab-674171edb2bc"
  },
  {
    "prompt": "What is the correct order for an opinion paragraph?",
    "choices": [
      "Reason, example, opinion.",
      "Example, opinion, reason.",
      "Opinion, reason, example."
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc chuẩn của một đoạn văn nêu ý kiến thường đi từ ý kiến chủ đạo đến lý do và ví dụ minh họa.",
    "old_id": "ea8d0f1f-3c51-5518-bb0f-9629475c0502",
    "new_id": "869dc711-f9f6-5232-8ac0-b9b209463b2a"
  },
  {
    "prompt": "Choose the best concluding sentence for a paragraph about why cats are great pets.",
    "choices": [
      "In conclusion, cats are wonderful and easy companions.",
      "Many people prefer to have a dog instead.",
      "Cats have soft fur and sharp claws."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu kết luận giúp tóm tắt lại ý chính đã được trình bày trong toàn bộ đoạn văn.",
    "old_id": "5dce7034-2df0-5886-bc0e-d9ac0dd0764e",
    "new_id": "b1c55f98-b200-59b5-8495-53a70da8f053"
  },
  {
    "prompt": "Person A: ''Why do you like living in this city?'' Person B: ''________''",
    "choices": [
      "I think the public transportation is very convenient.",
      "There are many tall buildings in the center.",
      "The city was built over two hundred years ago."
    ],
    "correct_index": 0,
    "explanation_vi": "Người B đưa ra ý kiến cá nhân để trả lời cho câu hỏi về lý do tại sao thích thành phố.",
    "old_id": "6e97b699-9d3d-56cf-a13a-53632effb6fe",
    "new_id": "1555d211-656b-5d6f-b8a6-a18989e7974b"
  },
  {
    "prompt": "Person A: ''What do you think of this movie?'' Person B: ''I didn''t like it. ________''",
    "choices": [
      "It is a very long movie with many actors.",
      "The tickets cost ten dollars at the cinema.",
      "The story was confusing and the acting was poor."
    ],
    "correct_index": 2,
    "explanation_vi": "Người B đưa ra lý do cụ thể để giải thích cho ý kiến không thích bộ phim của mình.",
    "old_id": "143794bf-2f67-5eac-aea0-0585f852b389",
    "new_id": "bec4e199-88aa-5a3d-b47e-5eb535ead5b1"
  },
  {
    "prompt": "Person A: ''I believe online shopping is better.'' Person B: ''Can you give me an example?'' Person A: ''________''",
    "choices": [
      "Yes, it is faster than going to the store.",
      "Sure, I can buy clothes without leaving my house.",
      "Because I do not have a car to drive."
    ],
    "correct_index": 1,
    "explanation_vi": "Người A đưa ra một hành động cụ thể để minh họa cho ý kiến mua sắm trực tuyến tốt hơn.",
    "old_id": "051ac8d7-e972-5c37-87f6-78e7b76c7787",
    "new_id": "e285aa09-5fae-5a35-b67e-3f54a1550098"
  },
  {
    "prompt": "Which sentence follows logically after: ''I think that morning exercise is beneficial.''?",
    "choices": [
      "It helps me feel energetic for the rest of the day.",
      "Exercise is a physical activity for health.",
      "Many people exercise at the gym in the evening."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu này đưa ra lý do hỗ trợ trực tiếp cho ý kiến tập thể dục buổi sáng.",
    "old_id": "f6bcc72a-3e96-5ced-bf15-799b5be61c36",
    "new_id": "3a1bfe94-f182-507b-8e17-ed6e47d5f6e9"
  },
  {
    "prompt": "Which of these is a strong supporting reason for the opinion: ''Learning English is important.''?",
    "choices": [
      "I started learning English when I was seven years old.",
      "English is spoken in many countries around the world.",
      "Some people find English grammar quite difficult."
    ],
    "correct_index": 1,
    "explanation_vi": "Việc tiếng Anh được sử dụng rộng rãi là một lý do hợp lý giải thích tại sao nó quan trọng.",
    "old_id": "d9e4e1c2-e558-5224-8a84-4bad4d9be369",
    "new_id": "90c6467c-a5e8-5bfc-83cb-6242dc55190e"
  },
  {
    "prompt": "Identify the ''opinion'' in this set.",
    "choices": [
      "This laptop costs five hundred dollars.",
      "This laptop is the best one for students.",
      "This laptop has a large screen and a fast processor."
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ ''the best'' thể hiện quan điểm cá nhân chứ không phải dữ kiện kỹ thuật.",
    "old_id": "e6dcda46-7eee-582a-930e-326a9d500be8",
    "new_id": "18bdec0c-7566-53f0-821e-d25a556f1a8e"
  },
  {
    "prompt": "Which sentence is a clear ''example'' supporting the opinion that home-cooked food is healthier?",
    "choices": [
      "My friend likes to eat at restaurants every day.",
      "For instance, I can control the amount of salt in my meals.",
      "Home-cooked food is usually better for your body."
    ],
    "correct_index": 1,
    "explanation_vi": "Ví dụ về việc kiểm soát lượng muối minh họa trực tiếp cho luận điểm thức ăn tự nấu tốt cho sức khỏe.",
    "old_id": "1360496c-5b40-5e47-957d-d328ca1ec7cd",
    "new_id": "842fa206-813b-5221-a8b9-7827f30d10a7"
  },
  {
    "prompt": "What is the purpose of an opinion paragraph?",
    "choices": [
      "To persuade the reader to agree with your viewpoint.",
      "To give instructions on how to build something.",
      "To report facts about a news event."
    ],
    "correct_index": 0,
    "explanation_vi": "Mục đích chính của đoạn văn nêu ý kiến là thuyết phục người đọc đồng ý với quan điểm cá nhân.",
    "old_id": "0b2f295b-0424-5fe3-911d-bcfb68ae01ce",
    "new_id": "7cc1699c-019d-5337-904f-3d8aa67cfa97"
  },
  {
    "prompt": "Which part of a paragraph should contain your reasons?",
    "choices": [
      "The topic sentence.",
      "The concluding sentence.",
      "The body of the paragraph."
    ],
    "correct_index": 2,
    "explanation_vi": "Phần thân bài là nơi trình bày các lý do và ví dụ để làm rõ cho ý chính.",
    "old_id": "4843ad5b-6f9f-54c3-aa46-b9e34c12c36f",
    "new_id": "6967ae41-e683-5494-bb22-d494cd012f53"
  },
  {
    "prompt": "Our team has a big ________ to finish before the client arrives on Friday.",
    "choices": [
      "task",
      "colleague",
      "deadline"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''task'' (nhiệm vụ) phù hợp nhất với ngữ cảnh công việc cần hoàn thành trước khi khách đến.",
    "old_id": "9d887120-0aa1-5310-8ece-2cb82fc70964",
    "new_id": "a68667ff-df2c-5382-9a17-9bfdfc5686e5"
  },
  {
    "prompt": "If you don''t submit the report by 5 PM today, you will miss the ________.",
    "choices": [
      "colleague",
      "deadline",
      "task"
    ],
    "correct_index": 1,
    "explanation_vi": "Deadline nghĩa là hạn chót, dùng cho các công việc có thời hạn cụ thể.",
    "old_id": "a2137234-d7bd-5813-92a2-189de7f3a354",
    "new_id": "bf0f745f-1e20-5a8b-ad29-f3c00feff442"
  },
  {
    "prompt": "Sarah is a very helpful ________; she always assists me when I am busy.",
    "choices": [
      "task",
      "colleague",
      "deadline"
    ],
    "correct_index": 1,
    "explanation_vi": "Colleague có nghĩa là đồng nghiệp, phù hợp với ngữ cảnh người hỗ trợ công việc.",
    "old_id": "58d4ddd9-cc11-50e8-8de0-703000a5043d",
    "new_id": "c89d5628-e972-5499-902f-0ec8d94508fe"
  },
  {
    "prompt": "________ you mind helping me with this spreadsheet for a moment?",
    "choices": [
      "Do",
      "Could",
      "Would"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc ''Would you mind + V-ing'' là cách yêu cầu lịch sự phổ biến trong môi trường làm việc.",
    "old_id": "a0752ece-6ae5-517b-8abf-01a02859cd9a",
    "new_id": "90ea6248-a2bd-5bbc-b060-4839383088a1"
  },
  {
    "prompt": "________ I borrow your stapler for a minute, please?",
    "choices": [
      "Do",
      "Are",
      "Could"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''Could'' để tạo câu hỏi xin phép một cách lịch sự.",
    "old_id": "67508e8f-7a54-5df0-baa9-f787603d362c",
    "new_id": "9494a25c-7a92-578c-8106-b75d247227c5"
  },
  {
    "prompt": "Is it ________ if I leave the meeting five minutes early today?",
    "choices": [
      "okay",
      "polite",
      "possible"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''Is it okay if...'' là cách hỏi xin phép thông dụng và lịch sự.",
    "old_id": "7b46a665-5ade-5efb-8658-5650177f4074",
    "new_id": "1ab7eaa7-ee07-5240-9c41-2270318db170"
  },
  {
    "prompt": "Person A: Could you please send me the file? Person B: ________",
    "choices": [
      "No, I am busy.",
      "I don''t know the file.",
      "Sure, I will send it now."
    ],
    "correct_index": 2,
    "explanation_vi": "Phản hồi này thể hiện sự hợp tác và lịch sự khi đồng nghiệp yêu cầu hỗ trợ.",
    "old_id": "a6ff37ba-2574-559d-945b-baa038e7168d",
    "new_id": "75a79a23-b325-532b-81d4-ff7cafb40e13"
  },
  {
    "prompt": "Person A: Would you mind checking this email for me? Person B: ________",
    "choices": [
      "Not at all, I''d be happy to.",
      "I already checked it.",
      "Yes, it is very bad."
    ],
    "correct_index": 0,
    "explanation_vi": "Cách trả lời ''Not at all'' (không sao cả/rất sẵn lòng) là cách đáp lại lời nhờ vả lịch sự.",
    "old_id": "9460381c-8350-5187-8344-67717a7ac9d6",
    "new_id": "74d0d618-20f8-51cf-869d-110427c62164"
  },
  {
    "prompt": "Person A: Is it okay if I use your desk? Person B: ________",
    "choices": [
      "Yes, it is my desk.",
      "Actually, I need it right now.",
      "I am using it for a meeting."
    ],
    "correct_index": 1,
    "explanation_vi": "Đây là cách từ chối khéo léo và lịch sự khi không thể giúp đỡ đồng nghiệp.",
    "old_id": "aa6b0380-6790-55ab-b8ce-ffcdd96d697d",
    "new_id": "6d7f06ab-61f5-50ec-8a1e-3b2c3353ef22"
  },
  {
    "prompt": "Which word describes a person you work with?",
    "choices": [
      "Client",
      "Manager",
      "Colleague"
    ],
    "correct_index": 2,
    "explanation_vi": "Colleague là thuật ngữ chính xác để chỉ người làm việc cùng một nhóm hoặc công ty.",
    "old_id": "abc50cbb-f040-5aa8-9d6c-d3c167024ea9",
    "new_id": "fb19540f-2330-53a0-9804-a51847cfa55b"
  },
  {
    "prompt": "Choose the most polite way to ask for assistance.",
    "choices": [
      "Help me now.",
      "Would you mind helping me?",
      "Can you help me?"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng ''Would you mind...'' tạo ra cấu trúc yêu cầu trang trọng và lịch sự nhất.",
    "old_id": "e057798c-b6cc-55d4-b117-fba71c57c102",
    "new_id": "1dc903a0-64b1-52e7-aaad-29b0a42242dc"
  },
  {
    "prompt": "If you are struggling to meet a deadline, what should you do?",
    "choices": [
      "Go home early.",
      "Ignore it completely.",
      "Talk to your colleague about it."
    ],
    "correct_index": 2,
    "explanation_vi": "Trao đổi với đồng nghiệp hoặc cấp trên là cách giải quyết chuyên nghiệp khi gặp khó khăn về thời hạn.",
    "old_id": "daa8eb59-15e4-50e1-b133-3cc17fe847bc",
    "new_id": "db53f56d-f810-50cf-b28b-ef406cd81b1b"
  },
  {
    "prompt": "Which phrase is correct for asking permission?",
    "choices": [
      "Do I open the window?",
      "Could I open the window?",
      "Can I to open the window?"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''Could I + động từ nguyên thể'' là dạng câu hỏi xin phép chuẩn xác.",
    "old_id": "425df6a6-d10d-5fa7-9451-1f8489575b39",
    "new_id": "5efb19e6-a9b3-5716-b9d3-6b05f3d0df67"
  },
  {
    "prompt": "What do you call the date by which a task must be finished?",
    "choices": [
      "Deadline",
      "Schedule",
      "Appointment"
    ],
    "correct_index": 0,
    "explanation_vi": "Deadline là hạn cuối bắt buộc cho các dự án hoặc đầu mục công việc.",
    "old_id": "4a41f1da-d8c2-5d6f-8d59-5f41b59e3335",
    "new_id": "364c5ccd-65a0-52d2-9fd9-0fd0de99a5a6"
  },
  {
    "prompt": "Which response is polite when someone thanks you for your help?",
    "choices": [
      "No problem, any time.",
      "You are welcome to work.",
      "I help you."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu ''No problem, any time'' là cách phản hồi lịch sự và thân thiện nơi công sở.",
    "old_id": "a7416ad6-d7d4-5583-b424-23cb9c7be4f0",
    "new_id": "198d2d70-314f-5229-b732-80497181d8b4"
  },
  {
    "prompt": "Before the exam, I always spend two hours to ______ my notes to make sure I remember everything.",
    "choices": [
      "revise",
      "feedback",
      "assignment"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''revise'' có nghĩa là ôn tập, phù hợp nhất để dùng trước kỳ thi.",
    "old_id": "90f22a88-0e26-53ba-8d5b-d04d34886af7",
    "new_id": "8933428c-1395-53d9-8eca-24a72da9f1e6"
  },
  {
    "prompt": "Our teacher gave us a very difficult ______ about global warming that we need to finish by Friday.",
    "choices": [
      "revise",
      "assignment",
      "feedback"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''assignment'' có nghĩa là bài tập được giao, phù hợp với ngữ cảnh cần hoàn thành trước thứ Sáu.",
    "old_id": "b1b345ee-43d7-5f2b-99ab-33327013d2d0",
    "new_id": "63afce30-fdc8-5ac1-bf1d-a0e8d843ed57"
  },
  {
    "prompt": "I was nervous about my essay, but the teacher''s ______ helped me understand how to improve my writing.",
    "choices": [
      "feedback",
      "assignment",
      "revise"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''feedback'' có nghĩa là phản hồi, giúp người viết cải thiện bài làm của mình.",
    "old_id": "ff4b1636-bb8c-505b-a9e0-8c6a2508c2cf",
    "new_id": "2c695be4-e6d0-57f5-ae1b-8515fecca4ba"
  },
  {
    "prompt": "I ______ already ______ all the chapters for the history test.",
    "choices": [
      "have / read",
      "have / reading",
      "has / read"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc hiện tại hoàn thành với chủ ngữ ''I'' đi với trợ động từ ''have'' và quá khứ phân từ.",
    "old_id": "8d4642d4-7d1c-5901-ab11-2858026a6f30",
    "new_id": "9383b989-8c6f-5fb1-9176-c9e5d1bcf326"
  },
  {
    "prompt": "______ you ever ______ a presentation in front of the whole class?",
    "choices": [
      "Has / give",
      "Have / given",
      "Have / gave"
    ],
    "correct_index": 1,
    "explanation_vi": "Dạng nghi vấn của hiện tại hoàn thành yêu cầu ''Have'' + chủ ngữ + quá khứ phân từ (given).",
    "old_id": "bcfde387-1430-5474-a8dd-203a10e441b7",
    "new_id": "9798dd4a-ab47-5c2c-9191-4fcab2ba0605"
  },
  {
    "prompt": "Sarah ______ never ______ to the library to study before.",
    "choices": [
      "has / been",
      "has / went",
      "have / been"
    ],
    "correct_index": 0,
    "explanation_vi": "Chủ ngữ ngôi thứ ba số ít ''Sarah'' đi với ''has'' và quá khứ phân từ của ''be'' là ''been''.",
    "old_id": "4c16afcb-e91f-5a22-9c0a-834fcb01bdd8",
    "new_id": "4e3cbffd-9888-5944-b725-42d14d304b77"
  },
  {
    "prompt": "A: Did you finish the math homework? B: Yes, ______.",
    "choices": [
      "I finish it already",
      "I have it done",
      "I''ve just finished it"
    ],
    "correct_index": 2,
    "explanation_vi": "Thì hiện tại hoàn thành với ''just'' diễn tả một hành động vừa mới hoàn thành xong.",
    "old_id": "7d3b81af-f131-544a-a631-5cb4d5289978",
    "new_id": "b203fcbc-4a0a-52d6-9dea-511c9bb2fb44"
  },
  {
    "prompt": "A: Why are you so happy? B: ______.",
    "choices": [
      "I pass my exam",
      "I have passed my exam",
      "I passed my exam"
    ],
    "correct_index": 1,
    "explanation_vi": "Hiện tại hoàn thành nhấn mạnh kết quả của hành động thi đậu ở hiện tại.",
    "old_id": "fde74cd5-509e-50d9-bf54-c70e155ef1b1",
    "new_id": "411d9b6e-a7d0-5b4c-9220-6bfac03152ca"
  },
  {
    "prompt": "A: Can we use the classroom now? B: No, the teacher ______ locked the door.",
    "choices": [
      "hasn''t yet",
      "have yet",
      "has already"
    ],
    "correct_index": 2,
    "explanation_vi": "Trạng từ ''already'' được dùng trong câu khẳng định của thì hiện tại hoàn thành để chỉ hành động đã xảy ra.",
    "old_id": "c1de2e75-1dfd-5ce6-9f54-afe6818316b7",
    "new_id": "26cb75a9-79ca-5e0b-aab3-fdbddc622e8d"
  },
  {
    "prompt": "If you don''t understand the lesson, you should ask the teacher for ______. ",
    "choices": [
      "revision",
      "homework",
      "guidance"
    ],
    "correct_index": 2,
    "explanation_vi": "Khi không hiểu bài, việc xin sự hướng dẫn (guidance) là logic nhất.",
    "old_id": "366348b9-cd1c-5877-b45f-4269398a260a",
    "new_id": "464d6c37-2ed6-5470-b987-05a3c49f5195"
  },
  {
    "prompt": "She has ______ her textbook three times, so she knows the material very well.",
    "choices": [
      "reviewed with",
      "reviewing",
      "reviewed"
    ],
    "correct_index": 2,
    "explanation_vi": "Sau ''has'' cần một quá khứ phân từ (V3/ed) để tạo thành thì hiện tại hoàn thành.",
    "old_id": "239b1d43-c932-5b89-9068-74c9647437b0",
    "new_id": "3eab4c6a-a541-5e45-bf18-f462f7743868"
  },
  {
    "prompt": "Learning together in a group is often better because you can ______ ideas with your friends.",
    "choices": [
      "share",
      "give",
      "make"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm từ ''share ideas'' (chia sẻ ý tưởng) là kết hợp từ tự nhiên trong ngữ cảnh học tập nhóm.",
    "old_id": "4f30a1ea-61c1-5d42-acff-43419934c584",
    "new_id": "40b20378-61b6-5333-808b-8a841564b2d1"
  },
  {
    "prompt": "My brother has ______ at this university for three years now.",
    "choices": [
      "been studying",
      "studied",
      "study"
    ],
    "correct_index": 1,
    "explanation_vi": "Thì hiện tại hoàn thành diễn tả một hành động kéo dài từ quá khứ đến hiện tại.",
    "old_id": "b3ce773f-c085-5ae7-ab8b-1c75195ce204",
    "new_id": "e91f16fd-017e-54a4-a27a-573863279089"
  },
  {
    "prompt": "Make sure you ______ the instructions carefully before you start writing the assignment.",
    "choices": [
      "reading",
      "have read",
      "read"
    ],
    "correct_index": 2,
    "explanation_vi": "Đây là câu mệnh lệnh, cần dùng động từ nguyên thể ở đầu câu.",
    "old_id": "d36d2927-4c60-55dd-91bf-7c21e91a699b",
    "new_id": "0d7fdb4a-4810-55bb-84a4-8d81c43d20e8"
  },
  {
    "prompt": "We ______ all of our project goals for this semester already.",
    "choices": [
      "has achieved",
      "have achieved",
      "achieve"
    ],
    "correct_index": 1,
    "explanation_vi": "Chủ ngữ ''We'' số nhiều đi với ''have'' và quá khứ phân từ để chỉ sự hoàn thành.",
    "old_id": "e75a4684-028a-59fc-b1c9-1811c0c6a4fc",
    "new_id": "de78bcbe-762e-5051-bced-e6266136475a"
  },
  {
    "prompt": "Our team has already proposed a time. Now we need to ________ the meeting by booking a room and sending invitations.",
    "choices": [
      "available",
      "arrange",
      "suggest"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''arrange'' phù hợp nhất trong ngữ cảnh lên kế hoạch và sắp xếp một cuộc họp.",
    "old_id": "acc64593-e9c8-5597-ab46-246173fa6a2f",
    "new_id": "51f7e879-7438-55d6-b754-85715a21e034"
  },
  {
    "prompt": "If you are not ________ on Saturday, we can reschedule our dinner to Sunday.",
    "choices": [
      "available",
      "arrange",
      "suggest"
    ],
    "correct_index": 0,
    "explanation_vi": "Tính từ ''available'' có nghĩa là rảnh rỗi để làm việc gì đó, phù hợp nhất với ngữ cảnh thời gian.",
    "old_id": "ac814be2-0798-5473-9741-e831c9d5e4e0",
    "new_id": "e3060255-51d7-509e-acdc-83f7264b5fbc"
  },
  {
    "prompt": "I would like to ________ that we start the project a day early to avoid any stress.",
    "choices": [
      "suggest",
      "available",
      "arrange"
    ],
    "correct_index": 0,
    "explanation_vi": "Động từ ''suggest'' dùng để đưa ra một ý kiến hoặc đề xuất thực hiện điều gì đó.",
    "old_id": "716e7884-781b-5d77-bc8c-97fa142e794a",
    "new_id": "563a1cde-28dd-5c41-97b3-8b6c7433c326"
  },
  {
    "prompt": "________ go to the park this afternoon; the weather looks perfect.",
    "choices": [
      "Should",
      "Could",
      "Let''s"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc ''Let''s'' được dùng để đưa ra một lời đề nghị cùng nhau làm việc gì đó.",
    "old_id": "0b424de9-4cfa-5efa-acc2-61b5103a8cfd",
    "new_id": "286685c1-3e95-5e8d-a816-86b5b261f15e"
  },
  {
    "prompt": "We ________ check the train schedule before booking. Choose the modal that gives advice, rather than just offering an option.",
    "choices": [
      "should",
      "let''s",
      "could"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''should'' được dùng để đưa ra lời khuyên về một hành động cần thiết.",
    "old_id": "bb2ce964-76a3-5f88-8da0-161f9236f7cd",
    "new_id": "b6a0ae58-f82c-5743-a214-75abcb9375a2"
  },
  {
    "prompt": "________ you please send me the agenda for tomorrow''s meeting?",
    "choices": [
      "Let''s",
      "Could",
      "Should"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''Could you'' là cách lịch sự để đưa ra yêu cầu hoặc đề nghị.",
    "old_id": "07373ec3-5a14-5c5b-864a-120b4fb7a381",
    "new_id": "d6b17340-9e51-597f-bb1a-47c7e7c7211d"
  },
  {
    "prompt": "The office is too noisy. To ask whether moving is possible, say: ''________ we find a quiet café instead?''",
    "choices": [
      "Let''s",
      "Should",
      "Could"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc ''Could we'' thường dùng để đưa ra một gợi ý lịch sự khi đối mặt với một vấn đề.",
    "old_id": "e4aed6c9-272d-5e5a-91c1-3451f363d837",
    "new_id": "63ed4581-aadc-596d-aa99-c9a37f127b71"
  },
  {
    "prompt": "Tell your friend you want both of you to ask Sarah''s sister for help. Complete this suggestion that does not begin with a question word or modal: ''________ ask her sister for some help.''",
    "choices": [
      "Why should",
      "Could we",
      "Let''s"
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời của Person B là một lời gợi ý hành động, phù hợp dùng ''Let''s''.",
    "old_id": "07172890-c7e4-5f47-bd32-d9c139d0dcd6",
    "new_id": "a48915a0-033f-5abe-a0c8-6f5132060720"
  },
  {
    "prompt": "Person A: ''I am not sure if I can finish this report by 5 PM.'' Person B: ''You ________ ask your manager for an extension.''",
    "choices": [
      "should",
      "let''s",
      "could we"
    ],
    "correct_index": 0,
    "explanation_vi": "''Should'' được dùng để đưa ra lời khuyên hữu ích cho khó khăn của người khác.",
    "old_id": "0928d1c9-a2bb-51f4-ab4b-d1d0c6129085",
    "new_id": "904b4625-c7ab-5355-94af-82942269654b"
  },
  {
    "prompt": "Which word means to make plans for a future event?",
    "choices": [
      "arrange",
      "available",
      "suggest"
    ],
    "correct_index": 0,
    "explanation_vi": "''Arrange'' nghĩa là sắp xếp, lên kế hoạch cho một sự kiện tương lai.",
    "old_id": "b83a9da5-85c8-5b24-b2aa-49fbb98775f0",
    "new_id": "e4fd321d-2183-5aff-b3f5-21db5734ba19"
  },
  {
    "prompt": "Choose the correct sentence to make a polite suggestion.",
    "choices": [
      "Let''s we go now.",
      "Could we go now?",
      "Should we go now? Actually."
    ],
    "correct_index": 1,
    "explanation_vi": "Câu ''Could we go now?'' là cấu trúc đúng để đưa ra một lời đề nghị lịch sự.",
    "old_id": "0e5af20f-f6b6-570c-bf95-24dd409ac506",
    "new_id": "d2808245-f8a1-5602-ae2b-3540fbfa94b6"
  },
  {
    "prompt": "I am free all day tomorrow, so I am ________ for a meeting.",
    "choices": [
      "arrange",
      "available",
      "suggest"
    ],
    "correct_index": 1,
    "explanation_vi": "Khi bạn rảnh rỗi, bạn có thể nói mình ''available'' cho một sự kiện.",
    "old_id": "effd8f16-0259-5744-895b-acb2ea2baae4",
    "new_id": "9208335c-3cb8-5367-be12-8f0486e543d1"
  },
  {
    "prompt": "Which option is best for advising someone on their study plan?",
    "choices": [
      "Let''s study more.",
      "You should study more.",
      "You could study more."
    ],
    "correct_index": 1,
    "explanation_vi": "''Should'' là từ phù hợp nhất khi đưa ra lời khuyên chân thành và mạnh mẽ.",
    "old_id": "dbaf9565-b183-53f9-b46c-c0e61393fb9c",
    "new_id": "e0b36e07-008d-56d4-9e8f-7e33b475b89f"
  },
  {
    "prompt": "We agreed to meet at two. Please ________ the meeting by reserving a room.",
    "choices": [
      "available",
      "suggest",
      "arrange"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''arrange a time'' là cụm từ cố định phổ biến khi nói về việc hẹn gặp.",
    "old_id": "05c2fda7-4f6d-5b83-9b87-874be60fa63c",
    "new_id": "be1bb313-838e-56f0-a293-dd39ef16b168"
  },
  {
    "prompt": "Which invitation suggests a group activity without asking a question?",
    "choices": [
      "Could we play?",
      "Should we play?",
      "Let''s play."
    ],
    "correct_index": 2,
    "explanation_vi": "''Let''s'' thường được sử dụng để đề xuất một hoạt động nhóm tích cực.",
    "old_id": "dd08a0a1-d6ed-518a-9619-d78a8e1c4589",
    "new_id": "c05744fe-5c59-566a-bfaa-57604a21c57d"
  },
  {
    "prompt": "I don''t think this restaurant is very good. What is the main ______ for your opinion?",
    "choices": [
      "reason",
      "prefer",
      "believe"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''reason'' có nghĩa là lý do, phù hợp để hỏi về nguyên nhân đằng sau một ý kiến.",
    "old_id": "c092df30-a8f2-571d-8812-80ddc0bfffbb",
    "new_id": "54f86246-d9e5-5afe-8465-92b5808fba03"
  },
  {
    "prompt": "Many people ______ that learning a second language helps improve memory.",
    "choices": [
      "prefer",
      "reason",
      "believe"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''believe'' diễn tả niềm tin hoặc quan điểm của mọi người về một vấn đề.",
    "old_id": "99760027-6973-548f-8697-0121d73a236a",
    "new_id": "92be58d5-5e68-5947-935d-e6378e3b9eb3"
  },
  {
    "prompt": "Do you ______ to travel by train or by plane for long distances?",
    "choices": [
      "believe",
      "reason",
      "prefer"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''prefer'' dùng để hỏi về sự yêu thích hay lựa chọn giữa hai phương án.",
    "old_id": "2e30f082-8d60-569d-a6c2-280d8025bb5e",
    "new_id": "fcda3f36-deaf-5091-bbf8-724306ac63a0"
  },
  {
    "prompt": "I think ______ public transportation is better for the environment than driving a car.",
    "choices": [
      "that",
      "which",
      "what"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''that'' được dùng làm liên từ để bắt đầu mệnh đề nêu ý kiến sau động từ ''think''.",
    "old_id": "2d6b2712-7d49-57d1-9337-a25f435487f0",
    "new_id": "7cf8fa36-c0d9-5eea-b8f0-a7a6f076dd0d"
  },
  {
    "prompt": "In my opinion, ______ movies at home is more relaxing than going to the theater.",
    "choices": [
      "watched",
      "watching",
      "watch"
    ],
    "correct_index": 1,
    "explanation_vi": "Danh động từ ''watching'' đóng vai trò là chủ ngữ của mệnh đề nêu ý kiến.",
    "old_id": "b9b37a41-0980-5e47-af39-f64800c47f30",
    "new_id": "e7c2f62a-0b6b-56b9-b8c2-1314c0c35c8c"
  },
  {
    "prompt": "I believe that online shopping ______ more convenient than visiting local stores.",
    "choices": [
      "are",
      "is",
      "be"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''is'' chia ở số ít để hòa hợp với chủ ngữ số ít ''online shopping''.",
    "old_id": "221f9add-5051-525a-91f6-7b9d051be911",
    "new_id": "e423787a-75cb-593d-8338-3508bfbfa5ce"
  },
  {
    "prompt": "A: Why do you dislike this new office design? B: ______, it looks too dark and small.",
    "choices": [
      "The reason",
      "To me",
      "I believe"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm ''To me'' là cách diễn đạt phổ biến để bắt đầu đưa ra ý kiến cá nhân.",
    "old_id": "0af0aae7-581a-5971-9962-632e3bf1e5b7",
    "new_id": "66819a07-e41a-5349-a09f-822494a14660"
  },
  {
    "prompt": "A: Which type of music do you like best? B: I ______ jazz because it helps me focus.",
    "choices": [
      "prefer",
      "believe",
      "reason"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''prefer'' phù hợp khi đưa ra sự lựa chọn yêu thích cá nhân.",
    "old_id": "989831fb-087b-58a6-9e24-c365f111b530",
    "new_id": "1fa17de9-a360-53e5-95f8-4baa231425ea"
  },
  {
    "prompt": "A: Is it important to exercise every day? B: Yes, I ______ that daily exercise is essential for health.",
    "choices": [
      "prefer",
      "believe",
      "reason"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''believe'' đi với mệnh đề ''that'' để khẳng định một quan điểm.",
    "old_id": "b3b10294-e932-5dcb-a943-0909602d6e29",
    "new_id": "17b8c7dc-81fe-53a1-8857-076657c52a08"
  },
  {
    "prompt": "I believe ______ the government should invest more in parks and recreation areas.",
    "choices": [
      "that",
      "what",
      "so"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''believe that'' dùng để dẫn dắt mệnh đề quan điểm.",
    "old_id": "1b205b93-403e-5b11-96fa-eee155b3ff11",
    "new_id": "3e65ef73-f859-530f-b9e9-ccd383e415e3"
  },
  {
    "prompt": "The main ______ I like this book is that the characters feel very realistic.",
    "choices": [
      "preference",
      "belief",
      "reason"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc ''the reason... is that'' dùng để giải thích rõ nguyên nhân.",
    "old_id": "5d659d8b-8304-5e10-babf-cf16574c48cc",
    "new_id": "81d59989-3b40-5f3c-8f52-35ef5c9b9979"
  },
  {
    "prompt": "In my opinion, ______ more time outdoors makes people feel much happier.",
    "choices": [
      "spend",
      "spending",
      "to spend"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng danh động từ ''spending'' làm chủ ngữ cho hành động nêu ý kiến.",
    "old_id": "442aa326-9995-5b44-aee5-24e133ef6013",
    "new_id": "f1d214ec-e30a-52c9-8c71-4a3aaa995c16"
  },
  {
    "prompt": "Some people ______ that robots will perform all household chores in the future.",
    "choices": [
      "prefer",
      "reason",
      "believe"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''believe'' diễn tả một suy đoán hoặc niềm tin về tương lai.",
    "old_id": "990648a3-4249-5fda-a268-8a29ea7e9775",
    "new_id": "d8251d1d-a3e4-517c-9571-f97633fd3290"
  },
  {
    "prompt": "Do you have any specific ______ for choosing this particular college?",
    "choices": [
      "reasons",
      "prefers",
      "believes"
    ],
    "correct_index": 0,
    "explanation_vi": "Danh từ ''reasons'' được dùng để hỏi về những nguyên nhân cụ thể.",
    "old_id": "60157623-4c7a-53b7-b582-527d6f4514d3",
    "new_id": "98d192e7-c03c-59cc-a269-21b57790bf7b"
  },
  {
    "prompt": "I ______ to walk to work rather than drive because it is great exercise.",
    "choices": [
      "reason",
      "believe",
      "prefer"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''prefer'' thể hiện sự ưu tiên giữa hai hành động khác nhau.",
    "old_id": "e32ab5cc-f28f-52fe-b983-aa08321cec53",
    "new_id": "e9f16c58-7f7c-550b-ad6c-d6a141ed6281"
  },
  {
    "prompt": "Our manager is very strict with deadlines. ________, she is always willing to help us if we fall behind.",
    "choices": [
      "Point",
      "Exactly",
      "However"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''However'' dùng để nối hai mệnh đề mang ý nghĩa trái ngược nhau trong câu.",
    "old_id": "20f822c3-1888-5f83-8696-d5fb5614593b",
    "new_id": "1e05cea2-1dd3-54c2-9d9a-27e82fd846e3"
  },
  {
    "prompt": "A: I think we should start the meeting at nine. B: ________! That gives everyone enough time to arrive.",
    "choices": [
      "Exactly",
      "Point",
      "However"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''Exactly'' dùng để khẳng định sự đồng tình hoàn toàn với ý kiến của người khác.",
    "old_id": "336be372-98e9-577c-b000-08dbe033a27d",
    "new_id": "daa291cb-fb61-5868-827e-60a084d9ebb0"
  },
  {
    "prompt": "I see your ________ about the budget, but we really need to invest in new software this year.",
    "choices": [
      "point",
      "however",
      "exactly"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''I see your point'' được dùng để công nhận ý kiến của người đối diện trước khi đưa ra quan điểm phản biện.",
    "old_id": "40709137-f660-51b9-8a0b-8442220ef6bd",
    "new_id": "38462124-0583-567d-8578-1bf11af984c5"
  },
  {
    "prompt": "The team finished the project early; ________, they decided to start the next one immediately.",
    "choices": [
      "although",
      "because",
      "furthermore"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ nối ''furthermore'' được dùng để bổ sung thêm thông tin cùng chiều với mệnh đề trước đó.",
    "old_id": "4a129404-3c7a-5a13-ba97-cacfa456e571",
    "new_id": "d6142e8c-1a88-5944-aca6-b35cbe775325"
  },
  {
    "prompt": "I wanted to go for lunch, ________ the heavy rain made us stay in the office.",
    "choices": [
      "and",
      "but",
      "so"
    ],
    "correct_index": 1,
    "explanation_vi": "Liên từ ''but'' phù hợp nhất để diễn tả sự tương phản giữa mong muốn đi ăn và thực tế thời tiết.",
    "old_id": "7d995bc8-6173-5b68-8b0d-d6e5a70049a1",
    "new_id": "e876fffc-9d49-5556-b953-d45bc8d3c1f7"
  },
  {
    "prompt": "We missed our target for this month. ________, we are still ahead of our annual goal.",
    "choices": [
      "Nevertheless",
      "Therefore",
      "Moreover"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''Nevertheless'' diễn tả sự nhượng bộ, dùng khi mệnh đề sau làm giảm nhẹ ý nghĩa của mệnh đề trước.",
    "old_id": "dd4faea2-3021-5cc6-b931-c9578b456434",
    "new_id": "d8705929-e1c9-5c3b-97a7-357a167afb06"
  },
  {
    "prompt": "A: I feel like we are spending too much on paper. B: ________. We should switch to digital documents.",
    "choices": [
      "I am not sure",
      "That is a bad idea",
      "I agree with that"
    ],
    "correct_index": 2,
    "explanation_vi": "Câu khẳng định ''I agree with that'' là phản hồi phù hợp nhất cho lời đề nghị thay đổi sang tài liệu điện tử.",
    "old_id": "885a27e5-d322-538a-b23c-4b90df2d4fea",
    "new_id": "e8614583-0baf-5cf1-9bc0-4941f019dc57"
  },
  {
    "prompt": "A: What do you think about the new office layout? B: ________, but it might be too noisy for the design team.",
    "choices": [
      "It is very expensive",
      "I really like it",
      "I see the benefits"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''I see the benefits, but'' thể hiện kỹ năng đồng ý một phần trước khi đưa ra ý kiến phản biện về tiếng ồn.",
    "old_id": "53588a94-1123-5802-820a-c02aa8c5e2b3",
    "new_id": "1a85910c-3150-5410-af3c-285181ccacfd"
  },
  {
    "prompt": "A: Let''s postpone the training session until Friday. B: ________, as most staff are attending a conference then.",
    "choices": [
      "You are right",
      "I am afraid I disagree",
      "That sounds great"
    ],
    "correct_index": 1,
    "explanation_vi": "Vì đa số nhân viên bận vào thứ Sáu, việc từ chối lịch hẹn là phản ứng logic nhất.",
    "old_id": "b4f2ad06-5324-5c46-a309-fea873be8529",
    "new_id": "60e10df2-92e2-5b97-98a4-80b923dd22d2"
  },
  {
    "prompt": "I believe this marketing strategy will increase our sales. Does everyone ________?",
    "choices": [
      "however",
      "agree",
      "point"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''agree'' là từ chính xác nhất để hỏi về sự đồng thuận của mọi người trong ngữ cảnh cuộc họp.",
    "old_id": "e45b3b7a-7e7f-5b48-b396-37c15b320526",
    "new_id": "37292b9c-7130-5028-942a-c0877ebfd22e"
  },
  {
    "prompt": "The clients were unhappy with the delay; ________, they were pleased with the quality of the final product.",
    "choices": [
      "on the other hand",
      "therefore",
      "consequently"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm từ ''on the other hand'' dùng để giới thiệu khía cạnh tích cực đối lập với khía cạnh tiêu cực trước đó.",
    "old_id": "50dd8a98-46eb-541e-bbad-f5e7a1611368",
    "new_id": "08e3391c-c53c-5ce5-96d1-28c36c600886"
  },
  {
    "prompt": "She is an excellent presenter. ________, her slides are always very easy to read and understand.",
    "choices": [
      "Instead",
      "In addition",
      "Otherwise"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''In addition'' dùng để bổ sung thông tin hỗ trợ cho việc tại sao cô ấy là người thuyết trình xuất sắc.",
    "old_id": "0ae8ca49-0f55-5606-ac26-ab9b19c2a25a",
    "new_id": "86e7f518-967a-5878-9539-d4629a311baa"
  },
  {
    "prompt": "Many people argue that working from home is better. ________, some employees feel lonely without social contact.",
    "choices": [
      "So",
      "However",
      "Consequently"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''However'' được dùng để chỉ ra một khía cạnh trái ngược hoặc nhược điểm của việc làm việc tại nhà.",
    "old_id": "24681520-9449-5615-8369-7968834209ef",
    "new_id": "d34b83d8-ae7f-5999-9724-4ede8b78c040"
  },
  {
    "prompt": "We need to hire more staff to meet the deadline. ________, we could ask the current team to work overtime.",
    "choices": [
      "Similarly",
      "In fact",
      "Alternatively"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''Alternatively'' dùng để giới thiệu một phương án giải quyết khác thay vì phương án thuê thêm người.",
    "old_id": "6169d192-ef7c-5971-a37e-1c9e6a2d3946",
    "new_id": "7ef51791-e7cc-5ccc-b16e-c8da100957d4"
  },
  {
    "prompt": "The budget is limited. ________, we should prioritize the most essential tasks first.",
    "choices": [
      "Therefore",
      "On the contrary",
      "Nevertheless"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''Therefore'' chỉ kết quả, vì ngân sách hạn hẹp nên việc ưu tiên các nhiệm vụ thiết yếu là kết quả logic.",
    "old_id": "fe109e94-440d-5a82-a86f-4581cbb396f6",
    "new_id": "ee16165d-24a7-509c-940b-30e3ff89f0d4"
  },
  {
    "prompt": "Our internet at home is very slow today. Does anyone know how to fix this technical _______?",
    "choices": [
      "connection",
      "issue",
      "solution"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''issue'' (vấn đề) phù hợp nhất với ngữ cảnh đang gặp rắc rối kỹ thuật.",
    "old_id": "ebf508f3-fcff-5309-a4ff-95b73302e3ca",
    "new_id": "22d6a0d6-b177-5221-b560-e9b31c8f8166"
  },
  {
    "prompt": "I can''t hear you clearly because there is a bad ________. Can you call me back later?",
    "choices": [
      "solution",
      "connection",
      "issue"
    ],
    "correct_index": 1,
    "explanation_vi": "Trong ngữ cảnh điện thoại, ''bad connection'' có nghĩa là kết nối mạng hoặc sóng bị chập chờn.",
    "old_id": "0c9f3e8f-8502-55ab-9929-434785a08797",
    "new_id": "1c1b396f-c8b0-5ac7-8caf-6cdd811df2f0"
  },
  {
    "prompt": "We have discussed the problem for an hour, but we haven''t found a good ________ yet.",
    "choices": [
      "connection",
      "solution",
      "issue"
    ],
    "correct_index": 1,
    "explanation_vi": "Sau khi thảo luận vấn đề, chúng ta cần tìm kiếm một ''solution'' (giải pháp).",
    "old_id": "b544d0d4-c3d1-598b-ab79-e1852a39a85d",
    "new_id": "598ec52c-e36b-5dac-9b6b-9ce2254bda9d"
  },
  {
    "prompt": "A: I''m having trouble with the app. B: ________ do you mean by ''trouble''?",
    "choices": [
      "What",
      "Which",
      "How"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''What do you mean by...'' dùng để yêu cầu làm rõ ý nghĩa của từ ngữ.",
    "old_id": "14a68972-84f9-5eec-9d52-b0d0290e57d8",
    "new_id": "bb8c7c01-a205-5ae2-914c-9a9f583914e9"
  },
  {
    "prompt": "A: My computer keeps freezing. B: ________ exactly does it happen, during video calls?",
    "choices": [
      "Why",
      "Who",
      "When"
    ],
    "correct_index": 2,
    "explanation_vi": "Câu hỏi bắt đầu bằng ''When'' để làm rõ thời điểm xảy ra vấn đề.",
    "old_id": "a0d906b5-b952-52d6-8459-cb575fca24f6",
    "new_id": "749e72f0-8bad-5b6f-a721-880eb20ab6f3"
  },
  {
    "prompt": "A: I can''t log in. B: Are you ________ your password correctly?",
    "choices": [
      "typing",
      "typed",
      "to type"
    ],
    "correct_index": 0,
    "explanation_vi": "Sau động từ ''are'' trong thì hiện tại tiếp diễn, ta dùng V-ing.",
    "old_id": "4a47ef24-ee17-581f-8be3-867453ec2ba2",
    "new_id": "cfcb0ed0-8072-5f32-a082-72bc95eb03ea"
  },
  {
    "prompt": "A: The screen is blank. B: Did you try pressing the power button?",
    "choices": [
      "I will buy a new one.",
      "No, it is broken.",
      "Yes, I did that twice."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời trực tiếp xác nhận hành động đã thực hiện để khắc phục lỗi.",
    "old_id": "71dbc769-8d2f-5a67-b449-e82139bd2bf4",
    "new_id": "8c9d121c-b56b-50d7-9893-b58384469d04"
  },
  {
    "prompt": "A: My messages aren''t sending. B: Is your Wi-Fi turned on?",
    "choices": [
      "Let me check, wait a second.",
      "I don''t like messaging.",
      "It''s very expensive."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời phản hồi hợp lý với câu hỏi về tình trạng mạng Wi-Fi.",
    "old_id": "05755286-81ac-5e38-9cda-db04e0bea035",
    "new_id": "f6e81b1d-df73-5822-bd92-2c615fcc4812"
  },
  {
    "prompt": "A: Sorry, you''re breaking up. B: ________ I repeat that again?",
    "choices": [
      "Do",
      "Shall",
      "Are"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng ''Shall'' để đề nghị thực hiện một hành động (nhắc lại).",
    "old_id": "70eb4c9b-2cf3-5c0e-ab84-5ce1d3934be9",
    "new_id": "a264c8ee-5b0a-5b6e-81c0-5f28526862e7"
  },
  {
    "prompt": "When you ________ a problem with your tablet, try restarting it first.",
    "choices": [
      "speak",
      "solve",
      "encounter"
    ],
    "correct_index": 2,
    "explanation_vi": "''Encounter a problem'' là cụm từ chỉ việc gặp phải một vấn đề.",
    "old_id": "6a7df25f-821b-52aa-9d57-6c5f7d7203bb",
    "new_id": "aacff4c7-f7a0-5c0a-9f59-398778ec7cd9"
  },
  {
    "prompt": "If the online meeting has no sound, check your audio ________ in the settings menu.",
    "choices": [
      "connection",
      "talk",
      "settings"
    ],
    "correct_index": 0,
    "explanation_vi": "Trong ngữ cảnh kỹ thuật, ''connection'' hoặc thiết lập âm thanh là điều cần kiểm tra.",
    "old_id": "faa9575c-d710-576c-a9bf-a5745891da53",
    "new_id": "c97287af-fdb5-5e98-8947-bf74bcbd3c6c"
  },
  {
    "prompt": "A: I don''t understand the error code. B: ________ you explain what it looks like?",
    "choices": [
      "Could",
      "Do",
      "Are"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''Could'' để đưa ra yêu cầu lịch sự nhằm làm rõ thông tin.",
    "old_id": "3da32237-51de-5e18-b4e4-897a122e7072",
    "new_id": "7a2567c3-7319-5a4c-9af2-953a9b2513db"
  },
  {
    "prompt": "Please wait a moment while I ________ to a stronger network.",
    "choices": [
      "explain",
      "repair",
      "switch"
    ],
    "correct_index": 2,
    "explanation_vi": "''Switch to'' có nghĩa là chuyển sang một mạng khác để cải thiện kết nối.",
    "old_id": "e7366440-3221-54fe-89cb-02d93bca8294",
    "new_id": "036be2a3-6399-5ba6-b38d-298180f85419"
  },
  {
    "prompt": "To ________ the issue, we should first identify the main cause of the error.",
    "choices": [
      "connect",
      "talk",
      "resolve"
    ],
    "correct_index": 2,
    "explanation_vi": "''Resolve the issue'' là cách diễn đạt phổ biến để chỉ việc giải quyết vấn đề.",
    "old_id": "3a6dd35b-77e4-5cdc-a8f2-553d5618ff37",
    "new_id": "9067fe32-536f-5ae5-a459-0b60d0d0b89f"
  },
  {
    "prompt": "A: Can you hear me? B: No, your voice is very ________. Please speak louder.",
    "choices": [
      "fast",
      "faint",
      "clear"
    ],
    "correct_index": 1,
    "explanation_vi": "''Faint'' mô tả âm thanh nhỏ hoặc yếu, khiến người nghe khó nhận biết.",
    "old_id": "af4e45dd-cd88-54fd-b91e-c1b60f51db5b",
    "new_id": "abf2fd4f-4e47-5b02-976f-bb50e83ef737"
  },
  {
    "prompt": "The newspaper article had a catchy ________ that made people want to read the entire story about the city festival.",
    "choices": [
      "notice",
      "detail",
      "headline"
    ],
    "correct_index": 2,
    "explanation_vi": "Headline là tiêu đề bài báo thường dùng để thu hút người đọc.",
    "old_id": "98adfe95-9f56-57c1-813d-f2922f1bfb1f",
    "new_id": "73032c75-b22d-5503-9f86-2c4bc86a58ef"
  },
  {
    "prompt": "I saw a ________ on the wall saying that the library will be closed for renovations starting next Monday.",
    "choices": [
      "headline",
      "notice",
      "detail"
    ],
    "correct_index": 1,
    "explanation_vi": "Notice là một thông báo ngắn gọn dán ở nơi công cộng.",
    "old_id": "908cf2b2-25d0-5387-a932-4fd4aa080c44",
    "new_id": "cded0cf8-906d-53bb-afb6-0497eafc29e2"
  },
  {
    "prompt": "The report was too long, but she managed to find every important ________ regarding the budget cuts.",
    "choices": [
      "notice",
      "headline",
      "detail"
    ],
    "correct_index": 2,
    "explanation_vi": "Detail dùng để chỉ các thông tin chi tiết cụ thể trong văn bản.",
    "old_id": "6151d658-f3e1-5da2-a1aa-a5d27229627c",
    "new_id": "7fb46b60-2b16-5b70-8c4b-e95f8eaab340"
  },
  {
    "prompt": "When you ________ the text, you move your eyes quickly over the page to get the general idea without reading every word.",
    "choices": [
      "scan",
      "skim",
      "summarize"
    ],
    "correct_index": 1,
    "explanation_vi": "Skimming là đọc lướt để lấy ý chính thay vì đọc chi tiết.",
    "old_id": "000e04fe-a11d-53ab-8234-d62e4b5fe861",
    "new_id": "f1a7310c-1829-51a3-b2df-8643b4284dae"
  },
  {
    "prompt": "If you need to ________ the document to find the specific date of the meeting, look for numbers and names.",
    "choices": [
      "scan",
      "edit",
      "skim"
    ],
    "correct_index": 0,
    "explanation_vi": "Scanning là phương pháp đọc quét để tìm kiếm một dữ kiện cụ thể.",
    "old_id": "d4980c58-3f0d-5f80-a7b3-741bc3fbd138",
    "new_id": "56da1246-2691-51e0-a43b-82bc6e3f0bf6"
  },
  {
    "prompt": "After I ________ the brochure for five minutes, I decided it was not the right tour for my family.",
    "choices": [
      "noticed",
      "scanned",
      "skimmed"
    ],
    "correct_index": 2,
    "explanation_vi": "Đọc lướt (skimmed) là hành động phù hợp để nhanh chóng đưa ra quyết định dựa trên ý chính.",
    "old_id": "962b9cca-c3d4-5d2c-8cf0-450f21bd88fc",
    "new_id": "a24de9f9-2828-5ca3-83fb-d478e3e768f3"
  },
  {
    "prompt": "A: Excuse me, can you tell me what time the train arrives? B: ________",
    "choices": [
      "Please notice the clock on the wall.",
      "I will skim the ticket for you later.",
      "Let me scan the departure board for you."
    ],
    "correct_index": 2,
    "explanation_vi": "Scanning là kỹ năng tìm kiếm thông tin cụ thể như giờ tàu trên bảng tin.",
    "old_id": "c12df4f5-337b-5a3d-8bd0-c8518779159b",
    "new_id": "e4a932a9-85cd-53f6-ad35-277847419aaf"
  },
  {
    "prompt": "A: Did you read the whole report? B: No, I just ________ to see if it mentioned the new policy.",
    "choices": [
      "skimmed it to look for details",
      "scanned it for the main topic",
      "read the notice on the front"
    ],
    "correct_index": 0,
    "explanation_vi": "Skim là đọc lướt để hiểu ý chính trước khi tìm chi tiết.",
    "old_id": "02c63c80-1973-5c2b-add0-96f32c5c320c",
    "new_id": "3c2a4fc0-a9b5-5c9b-96b4-34c2124883a6"
  },
  {
    "prompt": "A: Why is the store closed today? B: There is a ________ on the door explaining the emergency plumbing work.",
    "choices": [
      "notice",
      "headline",
      "detail"
    ],
    "correct_index": 0,
    "explanation_vi": "Thông tin về việc cửa hàng đóng cửa thường được ghi trên một tờ thông báo (notice).",
    "old_id": "407587a8-0f5d-5ed5-bd7d-eb0e3b476563",
    "new_id": "492d0ad3-a547-5f47-ac17-c55bad9a3462"
  },
  {
    "prompt": "Which strategy should you use if you only want to know the general topic of an article?",
    "choices": [
      "noticing",
      "skimming",
      "scanning"
    ],
    "correct_index": 1,
    "explanation_vi": "Skimming là kỹ thuật đọc lấy ý chính (general topic).",
    "old_id": "b37d3b87-d51f-547e-97ac-18ee894baf51",
    "new_id": "0b3190b2-3717-59e4-95f1-7d1b9aee49fa"
  },
  {
    "prompt": "When looking for a specific phone number in a long directory, which technique is most effective?",
    "choices": [
      "skimming",
      "scanning",
      "noticing"
    ],
    "correct_index": 1,
    "explanation_vi": "Scanning được dùng để tìm kiếm các thông tin dữ liệu cụ thể như số điện thoại.",
    "old_id": "45845ae1-7531-5f1a-8ddf-f4a5ef930cd3",
    "new_id": "f806262e-3520-5d69-8348-83478412f327"
  },
  {
    "prompt": "Which part of a newspaper article is usually written in large, bold letters?",
    "choices": [
      "the headline",
      "the notice",
      "the detail"
    ],
    "correct_index": 0,
    "explanation_vi": "Headline thường được in đậm và to để làm nổi bật chủ đề bài báo.",
    "old_id": "dacae6f1-e855-50c2-8b58-736fc0767b03",
    "new_id": "0c8b11aa-8a85-5952-a787-36e11edc8323"
  },
  {
    "prompt": "If you are reading a menu to quickly find the price of a burger, what are you doing?",
    "choices": [
      "skimming",
      "scanning",
      "noticing"
    ],
    "correct_index": 1,
    "explanation_vi": "Tìm kiếm giá tiền là tìm một chi tiết cụ thể, nên dùng kỹ năng scanning.",
    "old_id": "c29ca0a8-8f4f-58ee-aa8d-a1cc16719651",
    "new_id": "b5f2c016-53a7-5cb4-84e2-40d507216c23"
  },
  {
    "prompt": "Why do writers include a headline at the beginning of an article?",
    "choices": [
      "To give the reader an idea of the content",
      "To summarize all the technical details",
      "To list the names of all the people interviewed"
    ],
    "correct_index": 0,
    "explanation_vi": "Tiêu đề giúp người đọc nắm bắt sơ bộ về nội dung của bài viết.",
    "old_id": "02f79185-eff5-5916-b124-bdfb2bf8d9b7",
    "new_id": "fe045d3a-3202-54aa-977b-3e96f3a5c03e"
  },
  {
    "prompt": "What is the best way to understand the structure of a long document before you start reading?",
    "choices": [
      "Scan every sentence for keywords",
      "Write down a notice about the text",
      "Skim the headings and subheadings"
    ],
    "correct_index": 2,
    "explanation_vi": "Đọc lướt các tiêu đề là cách tốt nhất để hiểu cấu trúc tổng quát của một văn bản dài.",
    "old_id": "59705723-f5e9-599c-998d-2d2a6a1b544e",
    "new_id": "926aac8c-9bdf-596d-a836-a8ef10d76d0f"
  },
  {
    "prompt": "The journalist had to verify every single detail before she could ______ the story to the public.",
    "choices": [
      "event",
      "report",
      "source"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''report'' có nghĩa là đưa tin hoặc tường thuật lại một sự kiện cho công chúng.",
    "old_id": "d1a4246a-de01-52ec-8d26-c68f34097123",
    "new_id": "f055315d-63de-5c95-944e-8ff77057aefa"
  },
  {
    "prompt": "The local charity organized a fundraising ______ to help families affected by the recent floods.",
    "choices": [
      "event",
      "report",
      "source"
    ],
    "correct_index": 0,
    "explanation_vi": "Danh từ ''event'' dùng để chỉ một sự kiện hoặc hoạt động được tổ chức cụ thể.",
    "old_id": "39ab7b30-96e9-5f8a-806d-b055d6361284",
    "new_id": "ff931f00-a175-5f21-aa17-96b149e48443"
  },
  {
    "prompt": "The investigator searched for a reliable ______ to confirm whether the rumors about the company were true.",
    "choices": [
      "source",
      "report",
      "event"
    ],
    "correct_index": 0,
    "explanation_vi": "Danh từ ''source'' được dùng để chỉ nguồn tin hoặc nơi cung cấp thông tin đáng tin cậy.",
    "old_id": "396e0202-948f-5875-a9bd-fecc1e138fcb",
    "new_id": "773d44eb-b3d6-534e-a702-0bc32e3cfb32"
  },
  {
    "prompt": "Mark told me, ''I saw the accident.'' He said that he ______ the accident.",
    "choices": [
      "sees",
      "has seen",
      "had seen"
    ],
    "correct_index": 2,
    "explanation_vi": "Khi chuyển sang câu tường thuật, thì quá khứ đơn (saw) lùi thì thành quá khứ hoàn thành (had seen).",
    "old_id": "9efa5b37-1c57-50e0-adef-4099fec61b3f",
    "new_id": "bf8973f1-ed7a-5fbf-a725-8f669a9672f2"
  },
  {
    "prompt": "Sarah said, ''I am reading the news now.'' Sarah said that she ______ the news then.",
    "choices": [
      "is reading",
      "was reading",
      "has been reading"
    ],
    "correct_index": 1,
    "explanation_vi": "Khi lùi thì, thì hiện tại tiếp diễn (am reading) chuyển thành quá khứ tiếp diễn (was reading).",
    "old_id": "3ee47a8e-e6c2-58c0-9e67-faa12f189070",
    "new_id": "dd873d1a-78b5-57b1-a127-3c163f6a3cee"
  },
  {
    "prompt": "The reporter announced, ''The fire will be extinguished soon.'' He announced that the fire ______ extinguished soon.",
    "choices": [
      "would be",
      "will be",
      "is"
    ],
    "correct_index": 0,
    "explanation_vi": "Trong câu tường thuật, ''will'' được chuyển đổi thành ''would'' để phù hợp với quy tắc lùi thì.",
    "old_id": "f7c87a43-c8bb-5101-b407-c5871f28ff98",
    "new_id": "b236c7c3-aa67-57ca-81d0-4d011685d267"
  },
  {
    "prompt": "A: Did you hear about the train delay? B: Yes, the news ______ that a technical issue caused it.",
    "choices": [
      "reports",
      "sources",
      "events"
    ],
    "correct_index": 0,
    "explanation_vi": "Động từ ''reports'' phù hợp ngữ cảnh để chỉ bản tin thông báo về nguyên nhân sự cố.",
    "old_id": "08e9862e-ba62-50a0-8b90-6a0c8ae129ea",
    "new_id": "d8413a9f-e1df-503e-96f7-365ea84922b1"
  },
  {
    "prompt": "A: Is this information from a trustworthy place? B: Yes, it is a primary ______ cited by many journalists.",
    "choices": [
      "source",
      "report",
      "event"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''source'' được sử dụng để chỉ nguồn tài liệu gốc đáng tin cậy.",
    "old_id": "1c5a97e7-1243-5110-84f7-01a67779e86c",
    "new_id": "ff2b0219-fe8e-5243-b031-4ab1a041098a"
  },
  {
    "prompt": "A: What did the official say at the meeting? B: He ______ that the road closure would last two days.",
    "choices": [
      "asked",
      "said",
      "reported"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''reported'' phù hợp với ngữ cảnh một quan chức đưa ra thông báo chính thức.",
    "old_id": "10a55d8f-6bff-5009-8ac3-c574a6fd00c0",
    "new_id": "364262b2-73e6-56c6-be01-d52f31ea3662"
  },
  {
    "prompt": "The editor confirmed that the journalist ______ the story yesterday afternoon.",
    "choices": [
      "will submit",
      "submits",
      "had submitted"
    ],
    "correct_index": 2,
    "explanation_vi": "Hành động đã xảy ra trước thời điểm tường thuật nên cần dùng quá khứ hoàn thành.",
    "old_id": "7c5d1400-6609-5bdc-bdea-5418bafbd0f4",
    "new_id": "36d42da4-3c43-5ab4-91a1-c964a8a9b0ad"
  },
  {
    "prompt": "She told the police that she ______ the suspicious man near the bank earlier that morning.",
    "choices": [
      "has seen",
      "sees",
      "had seen"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc câu tường thuật yêu cầu lùi thì từ quá khứ đơn sang quá khứ hoàn thành.",
    "old_id": "0441692b-5986-5a0d-b7ec-64692ec5dafb",
    "new_id": "f2a3b15a-30e9-505c-9f96-817f5e41d7f6"
  },
  {
    "prompt": "The local newspaper ______ a special section about the upcoming music festival last week.",
    "choices": [
      "reports",
      "event",
      "published"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''published'' diễn tả hành động xuất bản một phần đặc biệt trên báo.",
    "old_id": "9a5c8ecd-4b90-5a71-98aa-7d9cf8f64242",
    "new_id": "8c9d0dc2-832b-58e7-af3d-e7586a8bfb84"
  },
  {
    "prompt": "He mentioned that he ______ the information from an anonymous government official.",
    "choices": [
      "has received",
      "had received",
      "receives"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc câu tường thuật với động từ tường thuật ở quá khứ đòi hỏi thì quá khứ hoàn thành.",
    "old_id": "f58eb0b5-f5d2-5c37-9429-6d7f373e53ca",
    "new_id": "0b332b5a-b66d-524f-b634-1034da38f61d"
  },
  {
    "prompt": "The government ______ a full report regarding the environmental impact of the new factory.",
    "choices": [
      "sourced",
      "released",
      "evented"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''released'' thường được dùng đi kèm với ''report'' khi công bố thông tin.",
    "old_id": "8a808b9f-5b13-5ab3-9ff4-5d31f01c29df",
    "new_id": "68f4096c-83a5-58c3-a191-5036db228f12"
  },
  {
    "prompt": "They ______ that the charity gala was the most successful event of the year.",
    "choices": [
      "to claim",
      "claimed",
      "claim"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ tường thuật nên chia ở thì quá khứ để hòa hợp với ngữ cảnh sự kiện đã diễn ra.",
    "old_id": "54a33dbd-719d-5121-a706-3782d04247f8",
    "new_id": "ecbde2d2-8dff-55f8-a1a1-978d5a93df09"
  },
  {
    "prompt": "The hiker was walking through the thick forest when ________ a bear appeared behind a tree.",
    "choices": [
      "eventually",
      "suddenly",
      "meanwhile"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''suddenly'' diễn tả một hành động xảy ra bất ngờ ngắt quãng một hành động đang tiếp diễn.",
    "old_id": "0a5230cb-88cd-5160-8b8a-79f807f7627e",
    "new_id": "d216ef62-fe0f-5183-904d-8b2380d61cb5"
  },
  {
    "prompt": "I spent hours looking for my keys; ________, I found them inside my own coat pocket.",
    "choices": [
      "suddenly",
      "eventually",
      "meanwhile"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''eventually'' được dùng để chỉ kết quả sau một quá trình nỗ lực hoặc chờ đợi lâu.",
    "old_id": "3b7f9de8-11c3-530c-8c15-d2258d2903b7",
    "new_id": "122f3831-8a80-5863-822b-1ca04412a861"
  },
  {
    "prompt": "Mom was cooking dinner in the kitchen, and ________, Dad was cleaning the garage.",
    "choices": [
      "meanwhile",
      "suddenly",
      "eventually"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''meanwhile'' dùng để chỉ hai hành động xảy ra cùng lúc tại các địa điểm khác nhau.",
    "old_id": "2cf0d23f-1cd8-5f9a-91cb-3a5e743c5551",
    "new_id": "3eacaa8e-4aac-5c2a-813e-ea2cbdcf9879"
  },
  {
    "prompt": "While the children ________, the rain started to fall heavily.",
    "choices": [
      "were playing",
      "are playing",
      "played"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''while'' đi với thì quá khứ tiếp diễn để tả hành động đang diễn ra khi có hành động khác xen vào.",
    "old_id": "a5e04b34-d150-5cb4-a71d-fd78c54fcf62",
    "new_id": "0bbc38f9-df45-55d8-943e-3a90fbb71da8"
  },
  {
    "prompt": "I ________ my homework when the phone rang loudly.",
    "choices": [
      "was doing",
      "have done",
      "did"
    ],
    "correct_index": 0,
    "explanation_vi": "Sử dụng thì quá khứ tiếp diễn để chỉ hành động đang xảy ra thì bị gián đoạn.",
    "old_id": "5739689c-2694-5047-9837-10121bb4ddaf",
    "new_id": "f5d8ae3d-8719-5b0c-a0c9-2f83e4cca87c"
  },
  {
    "prompt": "We ________ lunch when the waiter dropped a tray of glasses.",
    "choices": [
      "eating",
      "were eating",
      "ate"
    ],
    "correct_index": 1,
    "explanation_vi": "Hành động ăn trưa đang diễn ra thì bị ngắt quãng bởi một sự kiện khác.",
    "old_id": "71809c32-7441-5e39-a6f5-c759fada3a82",
    "new_id": "80b91d7c-0637-58fd-9239-a85c51ae0b39"
  },
  {
    "prompt": "A: Did you see the thief run away? B: No, I ________ a book in the living room.",
    "choices": [
      "was reading",
      "did read",
      "read"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời cần dùng quá khứ tiếp diễn để giải thích hành động đang diễn ra tại thời điểm đó.",
    "old_id": "7d5ff33e-e357-54e0-a366-1507a692d773",
    "new_id": "9d28ffc5-d6d1-5aaf-9d70-dcf847dd4106"
  },
  {
    "prompt": "A: What happened to your bike? B: I ________ to school when I hit a bump.",
    "choices": [
      "cycled",
      "was cycling",
      "cycle"
    ],
    "correct_index": 1,
    "explanation_vi": "Hành động đang đạp xe là nền tảng cho việc gặp sự cố, nên dùng quá khứ tiếp diễn.",
    "old_id": "c70d6042-3b5c-5a17-ae4c-bda90a491868",
    "new_id": "3f55312a-2617-545d-abf7-b72a57fe2e08"
  },
  {
    "prompt": "A: Why was the house so messy? B: Because we ________ for the party all day.",
    "choices": [
      "prepare",
      "prepared",
      "were preparing"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng quá khứ tiếp diễn để nhấn mạnh tính kéo dài của hành động trước khi có kết quả.",
    "old_id": "ab70bbfe-4aab-55c3-b189-ddd92e474b27",
    "new_id": "a08720c7-ee98-5f47-8452-c2946126fba0"
  },
  {
    "prompt": "She ________ the flowers when it suddenly began to snow.",
    "choices": [
      "watered",
      "was watering",
      "waters"
    ],
    "correct_index": 1,
    "explanation_vi": "Hành động tưới cây đang xảy ra thì bị sự kiện tuyết rơi làm gián đoạn.",
    "old_id": "23ac2878-c0ca-5603-97c6-4068e0591db4",
    "new_id": "500560ee-565e-5566-b1a3-e80957638f1d"
  },
  {
    "prompt": "I ________ to the store, and my sister was waiting at home.",
    "choices": [
      "walk",
      "was walking",
      "walked"
    ],
    "correct_index": 2,
    "explanation_vi": "Đây là hai hành động độc lập trong quá khứ, không phải hành động ngắt quãng.",
    "old_id": "39f20077-65f3-522a-a022-436cd8abe393",
    "new_id": "e2cf27e9-7410-5aff-802d-efec6411c530"
  },
  {
    "prompt": "________ the teacher was explaining the lesson, a student opened the window.",
    "choices": [
      "Eventually",
      "Suddenly",
      "While"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ nối ''while'' phù hợp nhất để giới thiệu một mệnh đề đang diễn ra.",
    "old_id": "75e0174a-c5b6-5dbc-9b76-9f6f3c519781",
    "new_id": "7eb8e4b8-cb28-583d-9fa5-a5b8b3e24d0d"
  },
  {
    "prompt": "The sun ________ when we arrived at the beach.",
    "choices": [
      "was shining",
      "shine",
      "shone"
    ],
    "correct_index": 0,
    "explanation_vi": "Thời tiết là bối cảnh đang diễn ra khi hành động khác (đến nơi) xảy ra.",
    "old_id": "2abe3707-7b21-554b-9f41-62a650688c84",
    "new_id": "13d8baf4-8d8f-5e80-91a5-6afcfddea90b"
  },
  {
    "prompt": "They tried to open the locked door for ten minutes; ________, they decided to call a locksmith.",
    "choices": [
      "suddenly",
      "meanwhile",
      "eventually"
    ],
    "correct_index": 2,
    "explanation_vi": "Sau một thời gian cố gắng không thành, kết quả đạt được được diễn tả bằng ''eventually''.",
    "old_id": "ab3f0ce6-0c5a-5cf4-b74d-87e90cf033d6",
    "new_id": "db3d8024-91dc-5f09-adfe-173069096e18"
  },
  {
    "prompt": "I was checking my emails ________ my brother was washing the dishes.",
    "choices": [
      "meanwhile",
      "suddenly",
      "while"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''while'' liên kết hai mệnh đề cùng diễn ra trong quá khứ.",
    "old_id": "fd7c9da8-d5e2-560f-abc4-0712f85aef4a",
    "new_id": "56ab856d-f6ae-548e-bd7b-29fe7ca7ee91"
  },
  {
    "prompt": "Climbing the highest mountain in the country was a major _______ for the young hiker.",
    "choices": [
      "challenge",
      "achievement",
      "memorable"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''achievement'' (thành tựu) phù hợp nhất với ngữ cảnh nói về việc vượt qua một cột mốc quan trọng.",
    "old_id": "cb7baf9d-0550-561d-a912-81d53dc8a533",
    "new_id": "f8fd455a-931d-5c20-8a57-80ebf740cdbc"
  },
  {
    "prompt": "Traveling through the desert without a guide was a difficult _______, but he learned a lot.",
    "choices": [
      "achievement",
      "challenge",
      "memorable"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''challenge'' (thử thách) diễn tả một trải nghiệm khó khăn cần vượt qua.",
    "old_id": "e1c9f761-ab6e-57c3-bfc0-fe7fda6ad2b5",
    "new_id": "92206009-524e-5e8e-a098-d9cde88ed4ac"
  },
  {
    "prompt": "Our sunset cruise in the Mediterranean was a truly _______ experience that we will never forget.",
    "choices": [
      "achievement",
      "challenge",
      "memorable"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''memorable'' (đáng nhớ) dùng để chỉ một sự kiện khó quên.",
    "old_id": "a9df202e-e84d-5084-b7e2-415b0e1dde5f",
    "new_id": "3c4980cd-4402-56a1-9fa9-2ee42ce850e9"
  },
  {
    "prompt": "I _______ to Japan three times since I started working for this international company.",
    "choices": [
      "have traveled",
      "did travel",
      "traveled"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng thì hiện tại hoàn thành với ''since'' để chỉ hành động lặp lại trong một khoảng thời gian đến hiện tại.",
    "old_id": "3c59a22b-c1d0-543c-b9ab-d6a79469637b",
    "new_id": "41d61c60-8367-5337-be08-5c1d63da710e"
  },
  {
    "prompt": "She _______ her backpack in the lobby when she checked into the hotel yesterday afternoon.",
    "choices": [
      "was leaving",
      "left",
      "has left"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng thì quá khứ đơn vì hành động xảy ra tại một thời điểm xác định trong quá khứ là ''yesterday afternoon''.",
    "old_id": "5f51b0e8-6252-5ef5-bcce-b28b121d060e",
    "new_id": "9e0b993c-e878-5e01-a9ae-65fdfc4222e6"
  },
  {
    "prompt": "We _______ the museum yet, so we are planning to go there tomorrow morning.",
    "choices": [
      "didn''t visit",
      "haven''t visited",
      "don''t visit"
    ],
    "correct_index": 1,
    "explanation_vi": "Thì hiện tại hoàn thành đi với ''yet'' dùng để nói về trải nghiệm chưa xảy ra tính đến thời điểm hiện tại.",
    "old_id": "5d7ac25a-5e11-59a9-9aa0-2f35d9064928",
    "new_id": "179ee2c1-1e5d-556a-ad99-e9354d127cd3"
  },
  {
    "prompt": "A: Have you ever been to a desert? B: Yes, I _______ to the Sahara last summer.",
    "choices": [
      "go",
      "went",
      "have gone"
    ],
    "correct_index": 1,
    "explanation_vi": "Người B trả lời cụ thể về ''last summer'' nên phải dùng quá khứ đơn.",
    "old_id": "d36df448-4019-53ac-b3b7-7cad2a9bc8a9",
    "new_id": "3bbb52f5-8df6-50b6-a97c-a637070d6546"
  },
  {
    "prompt": "A: How was the festival? B: It was incredible! I _______ so many interesting people.",
    "choices": [
      "meet",
      "have met",
      "met"
    ],
    "correct_index": 2,
    "explanation_vi": "Sự kiện lễ hội đã kết thúc nên dùng thì quá khứ đơn để kể lại.",
    "old_id": "7a2f62fe-1cc7-57e5-bdda-87b07afe3cd7",
    "new_id": "85cb9447-8577-5d53-a41f-f509c6344c0a"
  },
  {
    "prompt": "A: Are you excited about the trip? B: Definitely. I _______ all the necessary preparations already.",
    "choices": [
      "have finished",
      "finish",
      "finished"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng thì hiện tại hoàn thành với ''already'' để chỉ một việc vừa hoàn thành xong.",
    "old_id": "057e4d43-ed78-51d5-aca6-503f0654fbd0",
    "new_id": "db884c0e-aeef-5f0c-a18c-081932e63edf"
  },
  {
    "prompt": "Learning to scuba dive was a significant _______ that helped her overcome her fear of water.",
    "choices": [
      "memorable",
      "challenge",
      "achievement"
    ],
    "correct_index": 2,
    "explanation_vi": "Việc vượt qua nỗi sợ hãi được coi là một thành tựu cá nhân.",
    "old_id": "4eb3fbc0-18c2-5868-9bbb-8de1910508f5",
    "new_id": "83f8793e-add0-57e1-a78e-ce3516ae0430"
  },
  {
    "prompt": "The rainy weather during our hike turned out to be a real _______ for our group.",
    "choices": [
      "challenge",
      "achievement",
      "memorable"
    ],
    "correct_index": 0,
    "explanation_vi": "Thời tiết xấu tạo ra những khó khăn cần khắc phục, đó là một thử thách.",
    "old_id": "94ec8537-047d-5f9e-81be-7cb1eec3db16",
    "new_id": "794d430d-3c61-57ff-ae43-4eb4d42b0e1f"
  },
  {
    "prompt": "I will always cherish the _______ photos we took during our backpacking trip through Europe.",
    "choices": [
      "challenge",
      "achievement",
      "memorable"
    ],
    "correct_index": 2,
    "explanation_vi": "Những bức ảnh gợi nhắc về những kỷ niệm đáng nhớ.",
    "old_id": "7df29fe4-71de-56e5-8f6f-cdded7fa8a08",
    "new_id": "22ef521d-8f09-51e9-a83b-4c432a36fa6f"
  },
  {
    "prompt": "He _______ his passport in the taxi, so he couldn''t board the plane.",
    "choices": [
      "has lost",
      "lose",
      "lost"
    ],
    "correct_index": 2,
    "explanation_vi": "Hành động mất hộ chiếu xảy ra tại một thời điểm cụ thể dẫn đến hậu quả trong quá khứ nên dùng quá khứ đơn.",
    "old_id": "2cdff475-c9db-5525-827d-2021f4b62baf",
    "new_id": "8d463545-2135-5ae5-aebd-3332cb4c7470"
  },
  {
    "prompt": "They _______ to three different continents since they retired last year.",
    "choices": [
      "have flown",
      "flew",
      "fly"
    ],
    "correct_index": 0,
    "explanation_vi": "Hành động kéo dài từ quá khứ đến hiện tại cần dùng hiện tại hoàn thành.",
    "old_id": "b893cd79-9872-5d0c-a961-05d6d7db5c9e",
    "new_id": "320ed0ea-8e7b-56bb-8426-a257e3685e13"
  },
  {
    "prompt": "My sister _______ an award for her photography work last month.",
    "choices": [
      "won",
      "has won",
      "wins"
    ],
    "correct_index": 0,
    "explanation_vi": "Trạng từ chỉ thời gian ''last month'' yêu cầu sử dụng thì quá khứ đơn.",
    "old_id": "a8056737-2044-5346-9fc1-66b326f75318",
    "new_id": "963fb9ba-44f8-5cd9-83ef-c380add1b67e"
  },
  {
    "prompt": "Our new manager is very keen on building a strong sense of _____ among the staff, often organizing team lunches and group projects.",
    "choices": [
      "cooperate",
      "community",
      "responsibility"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''community'' (cộng đồng) phù hợp nhất với ngữ cảnh xây dựng sự gắn kết trong tập thể.",
    "old_id": "8bb82bc6-f3e8-5c72-bdd7-631de7deb313",
    "new_id": "6ed32479-dd64-5d28-ad62-201f70109f36"
  },
  {
    "prompt": "It is your _____ to ensure all reports are submitted to the finance department by the end of the working day.",
    "choices": [
      "cooperate",
      "community",
      "responsibility"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''responsibility'' (trách nhiệm) phù hợp với nghĩa vụ công việc cần phải hoàn thành.",
    "old_id": "16e7316e-f463-52bc-a5b6-26bfacbe22b0",
    "new_id": "10cf5f7b-d4cd-5079-b572-1cca7fc09f99"
  },
  {
    "prompt": "If we want to finish the building project on time, we must learn to _____ with the architects and local contractors.",
    "choices": [
      "cooperate",
      "community",
      "responsibility"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''cooperate'' (hợp tác) là một động từ cần thiết để thực hiện công việc chung với người khác.",
    "old_id": "be41141d-c61b-5f5f-bd3c-28797f21a7b0",
    "new_id": "3b88c019-586f-5ece-8812-f3eb9d44beb3"
  },
  {
    "prompt": "The colleague _____ works at the front desk is responsible for greeting all new visitors.",
    "choices": [
      "who",
      "which",
      "whose"
    ],
    "correct_index": 0,
    "explanation_vi": "Đại từ quan hệ ''who'' được dùng để chỉ người làm chủ ngữ cho mệnh đề quan hệ.",
    "old_id": "4bd848ce-ffa3-51b7-885e-9df9a8cb29df",
    "new_id": "fe38eadf-52ef-5699-a695-a228b755a82a"
  },
  {
    "prompt": "The factory, _____ was built over fifty years ago, is finally undergoing a major renovation.",
    "choices": [
      "which",
      "that",
      "where"
    ],
    "correct_index": 0,
    "explanation_vi": "Đại từ quan hệ ''which'' được dùng cho vật trong mệnh đề quan hệ không xác định.",
    "old_id": "454a46e6-af00-59d5-94e9-09aef97c824e",
    "new_id": "4447055c-e80c-54b7-a030-d070c6df79a7"
  },
  {
    "prompt": "Employees _____ ideas are selected for the new marketing campaign will receive a special bonus.",
    "choices": [
      "that",
      "whose",
      "who"
    ],
    "correct_index": 1,
    "explanation_vi": "Đại từ quan hệ ''whose'' biểu thị sự sở hữu cho danh từ theo sau.",
    "old_id": "82d8a489-d0f9-558d-a06f-618276a9f994",
    "new_id": "2709fac5-c457-55d6-9a0f-53da23bbf8b5"
  },
  {
    "prompt": "A: I really struggle to balance my personal life and my job. B: _____",
    "choices": [
      "It is a heavy responsibility to manage.",
      "I hope you cooperate with the schedule.",
      "You should join our local community group."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời thừa nhận trách nhiệm công việc là lời đáp hợp lý cho việc khó cân bằng cuộc sống.",
    "old_id": "f0371438-57b4-5213-b323-465e4b93086b",
    "new_id": "d47bd83f-4693-5517-a74f-39c60085083b"
  },
  {
    "prompt": "A: How are you finding the new department? B: It is great! Everyone is very willing to _____, so the work moves quickly.",
    "choices": [
      "community",
      "cooperate",
      "responsibility"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''cooperate'' giải thích lý do tại sao công việc tiến triển nhanh chóng.",
    "old_id": "00c4a81b-c3d9-51a6-bbd7-0dfd50147a93",
    "new_id": "94a09428-f367-5212-91e1-bd65288f8ef8"
  },
  {
    "prompt": "A: Why do you think this neighborhood is so popular? B: It is because of the strong sense of _____ among the residents.",
    "choices": [
      "cooperate",
      "responsibility",
      "community"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''community'' mô tả đặc điểm xã hội của một khu dân cư.",
    "old_id": "0b1fa5be-0c5a-589d-bb6e-718a2dae8082",
    "new_id": "3946164c-b2f9-50e9-9b19-f4388c7c1b06"
  },
  {
    "prompt": "The office _____ I started my career has recently moved to the city center.",
    "choices": [
      "who",
      "which",
      "where"
    ],
    "correct_index": 2,
    "explanation_vi": "Trạng từ quan hệ ''where'' được dùng để chỉ địa điểm văn phòng nơi người nói bắt đầu sự nghiệp.",
    "old_id": "15eef6b6-2e8b-581f-9bf7-33343ec84ebb",
    "new_id": "dc96d5a0-4271-5c5b-b9d1-ea76d483b5ba"
  },
  {
    "prompt": "The tasks _____ you were assigned last week must be completed before the client meeting.",
    "choices": [
      "who",
      "that",
      "whose"
    ],
    "correct_index": 1,
    "explanation_vi": "Đại từ ''that'' thay thế cho vật (tasks) trong mệnh đề quan hệ xác định.",
    "old_id": "41562cd0-e9c9-53c6-aa49-d22aaf33d915",
    "new_id": "e3e0ed86-efc8-5ab0-ae81-e2affb5271c4"
  },
  {
    "prompt": "Everyone in the company feels a shared _____ to protect the environment by reducing paper waste.",
    "choices": [
      "cooperate",
      "responsibility",
      "community"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''responsibility'' kết hợp đúng với ngữ cảnh về nghĩa vụ bảo vệ môi trường.",
    "old_id": "c0e9c362-4458-5109-a9ea-6e7f24f069ec",
    "new_id": "91c670df-b3bd-5574-88a6-3a26a84bd31c"
  },
  {
    "prompt": "The staff members _____ work overtime will be compensated with additional leave days.",
    "choices": [
      "where",
      "which",
      "who"
    ],
    "correct_index": 2,
    "explanation_vi": "Đại từ quan hệ ''who'' thay thế cho danh từ chỉ người ''staff members''.",
    "old_id": "c2d744f1-aeca-51f8-8fdf-9607ca370e56",
    "new_id": "44d58a44-a3cf-53f5-9151-b1a9eb1b5a8e"
  },
  {
    "prompt": "We need to _____ more effectively if we want to solve these complex societal issues.",
    "choices": [
      "cooperate",
      "community",
      "responsibility"
    ],
    "correct_index": 0,
    "explanation_vi": "Động từ ''cooperate'' là hành động cần thiết để giải quyết các vấn đề phức tạp.",
    "old_id": "4aa68620-c81e-52d7-8dce-a6b972e27e86",
    "new_id": "f9a84e8d-beee-5699-96f8-c80ef9aee485"
  },
  {
    "prompt": "The project, _____ was led by our director, resulted in a significant increase in local support.",
    "choices": [
      "whose",
      "that",
      "which"
    ],
    "correct_index": 2,
    "explanation_vi": "Mệnh đề quan hệ không xác định về một sự việc cần dùng đại từ ''which''.",
    "old_id": "65f93a3a-88ad-51e1-946d-a5dcb6ee5ab9",
    "new_id": "fd92283c-f458-5a29-9614-e9debda84ed1"
  },
  {
    "prompt": "I spent an hour staring at the map, but I just couldn''t ____ how to reach the remote village before sunset.",
    "choices": [
      "carry on",
      "figure out",
      "pick up"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ ''figure out'' có nghĩa là tìm ra hoặc hiểu ra giải pháp cho một vấn đề khó khăn.",
    "old_id": "8d491973-f0e5-5ae0-8043-ea23dc535522",
    "new_id": "1da80891-b19f-5a74-a1f2-4aeac1c593fe"
  },
  {
    "prompt": "The teacher told the students to ____ with their essay writing even though the fire alarm sounded in the distance.",
    "choices": [
      "carry on",
      "figure out",
      "pick up"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm từ ''carry on'' được dùng để chỉ việc tiếp tục làm một việc gì đó.",
    "old_id": "8a7ad83e-83b3-5a2c-8594-fb61178e3466",
    "new_id": "42a2031f-7dfc-5d53-8f46-166d09acd08b"
  },
  {
    "prompt": "It is quite impressive how quickly she managed to ____ the local dialect after living in the mountains for only a month.",
    "choices": [
      "figure out",
      "carry on",
      "pick up"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''pick up'' ở đây mang nghĩa học một kỹ năng hoặc ngôn ngữ một cách tự nhiên qua trải nghiệm thực tế.",
    "old_id": "71372e4a-eee1-5e7f-87c5-024970b65544",
    "new_id": "2b31ba93-c7df-512e-858d-9f10aba57ce8"
  },
  {
    "prompt": "If you don''t understand the instructions, you should try to ____ the meaning by looking at the pictures.",
    "choices": [
      "picked up",
      "carrying on",
      "figure out"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc sau ''try to'' cần một động từ nguyên mẫu (infinitive), nên ''figure out'' là lựa chọn chính xác.",
    "old_id": "ef7e5b70-5870-5456-b7dc-fe13e61bc988",
    "new_id": "ce46c8bd-4f9e-5057-910b-67d3d84bbf44"
  },
  {
    "prompt": "Despite the harsh weather conditions, the rescue team decided to ____ searching for the missing hikers.",
    "choices": [
      "figure out",
      "carry on",
      "carrying on"
    ],
    "correct_index": 1,
    "explanation_vi": "Sau động từ ''decided to'', ta cần một động từ nguyên mẫu, vì vậy ''carry on'' là lựa chọn đúng.",
    "old_id": "b9791c9b-5a5d-5f28-b71f-55ae35744ae3",
    "new_id": "6608e0e7-501e-5ea7-8aae-9bfaff69fe07"
  },
  {
    "prompt": "She ____ many new phrases from the podcast she listened to during her daily commute.",
    "choices": [
      "pick up",
      "picked up",
      "figure out"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu diễn tả một hành động đã xảy ra trong quá khứ nên ta cần chia động từ ở dạng quá khứ ''picked up''.",
    "old_id": "c2242b82-3057-5d67-a763-f1864b7d3c04",
    "new_id": "1f94f77c-9dc1-5f12-872a-27e664008ec8"
  },
  {
    "prompt": "Person A: ''I have been staring at this math problem for ages.'' Person B: ''Don''t worry, you will ____ the logic behind it eventually.''",
    "choices": [
      "pick up",
      "figure out",
      "carry on"
    ],
    "correct_index": 1,
    "explanation_vi": "Trong ngữ cảnh giải bài toán, ''figure out'' là cụm từ phù hợp nhất để chỉ việc tìm ra lời giải.",
    "old_id": "0722800e-ecf2-5654-90cd-8e662f4e973d",
    "new_id": "08f965f2-a14f-550d-9199-338d44563100"
  },
  {
    "prompt": "Person A: ''Should I stop the meeting now?'' Person B: ''No, please ____; we have a lot more to discuss regarding the budget.''",
    "choices": [
      "carry on",
      "pick up",
      "figure out"
    ],
    "correct_index": 0,
    "explanation_vi": "Khi được hỏi liệu có nên dừng lại không, phản hồi ''No, please carry on'' có nghĩa là hãy tiếp tục.",
    "old_id": "b08c61e5-accd-51d7-92e2-684b4f1ab9d2",
    "new_id": "367b07e7-a8f9-5181-aa3c-1f20ab55aaf1"
  },
  {
    "prompt": "Person A: ''Your French is excellent!'' Person B: ''Thanks, I managed to ____ some basics while I was backpacking in Paris.''",
    "choices": [
      "carry on",
      "pick up",
      "figure out"
    ],
    "correct_index": 1,
    "explanation_vi": "Việc học ngôn ngữ thông qua trải nghiệm thực tế thường được diễn tả bằng cụm ''pick up''.",
    "old_id": "c7284ac9-4305-545f-b43b-8ca1da2c35d3",
    "new_id": "4039df97-23f9-559c-80c7-b20dcdb025d5"
  },
  {
    "prompt": "The puzzle was so complex that it took the entire group three hours to ____ the secret code.",
    "choices": [
      "figure out",
      "carry on",
      "pick up"
    ],
    "correct_index": 0,
    "explanation_vi": "Để giải mã một mật mã phức tạp, người ta dùng ''figure out'' để diễn đạt quá trình tìm ra đáp án.",
    "old_id": "b35f6155-43a4-54a1-8939-f2fadcc1054a",
    "new_id": "810c0d87-6e52-500c-8936-020a89141590"
  },
  {
    "prompt": "He wasn''t feeling well, but he decided to ____ with his presentation so he wouldn''t disappoint the audience.",
    "choices": [
      "figure out",
      "pick up",
      "carry on"
    ],
    "correct_index": 2,
    "explanation_vi": "Dù cảm thấy không khỏe, việc anh ấy vẫn làm tiếp bài thuyết trình phù hợp với cụm ''carry on''.",
    "old_id": "4c847e2c-df43-5030-bf48-f6fb7f62129e",
    "new_id": "1a31231f-c4cf-5fac-b799-7b04a1ccd1c2"
  },
  {
    "prompt": "It''s amazing how kids can ____ new games just by watching their older siblings play.",
    "choices": [
      "carry on",
      "figure out",
      "pick up"
    ],
    "correct_index": 2,
    "explanation_vi": "Việc học cách chơi trò chơi thông qua quan sát thường dùng ''pick up''.",
    "old_id": "9886727d-9377-5d30-8c1b-a764eff96183",
    "new_id": "4ddfa0a4-ddff-5452-945f-71fc5eeb202d"
  },
  {
    "prompt": "I need a moment to ____ the best way to handle this complicated situation.",
    "choices": [
      "carry on",
      "pick up",
      "figure out"
    ],
    "correct_index": 2,
    "explanation_vi": "Để tìm ra phương án xử lý tình huống, ''figure out'' là lựa chọn từ vựng chuẩn xác.",
    "old_id": "10bd5e52-9632-536b-bf94-bc85b17399e0",
    "new_id": "b23b6623-f79d-543e-96da-97743f44afbb"
  },
  {
    "prompt": "The teacher told us to ____ reading the chapter even if we encounter words we don''t recognize.",
    "choices": [
      "carry on",
      "figure out",
      "pick up"
    ],
    "correct_index": 0,
    "explanation_vi": "Yêu cầu tiếp tục đọc bài bất chấp các từ khó được diễn tả bằng ''carry on''.",
    "old_id": "08259f5c-4755-5840-9533-4c55603f9ede",
    "new_id": "04c3c41b-c425-5269-80f9-437e7db18efd"
  },
  {
    "prompt": "After spending years in a cafe, he started to ____ the gossip from the regular customers.",
    "choices": [
      "pick up",
      "figure out",
      "carry on"
    ],
    "correct_index": 0,
    "explanation_vi": "Việc vô tình nghe được hoặc nắm bắt được thông tin từ xung quanh phù hợp với cụm ''pick up''.",
    "old_id": "ec35e928-7743-528e-9d1d-59704d084ef3",
    "new_id": "34116901-18f2-53b1-a2a6-c945bdb9043a"
  },
  {
    "prompt": "After reading the editorial, the critic noted that the author''s primary __________ was that remote work is ultimately harmful to long-term company culture.",
    "choices": [
      "gossip",
      "claim",
      "rumor"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''claim'' dùng để chỉ một khẳng định hoặc lập luận chính trong văn bản nghị luận.",
    "old_id": "ba67232f-e625-5d62-bb26-271b4623c9bb",
    "new_id": "0c707bf6-8c29-5a69-9e90-bc79487e2550"
  },
  {
    "prompt": "The editorial board maintained a firm __________ on the issue of renewable energy, refusing to print articles that promoted fossil fuel subsidies.",
    "choices": [
      "stance",
      "posture",
      "viewpoint"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''stance'' thường được dùng để chỉ một lập trường hoặc quan điểm kiên định về một vấn đề cụ thể.",
    "old_id": "a7edb0ad-b5f5-5367-a645-05253252ef0d",
    "new_id": "35c36572-9aba-538a-97ba-a0c5363a7b1e"
  },
  {
    "prompt": "While many experts agree on the data, they differ significantly in their __________ regarding how the new policy will impact the local economy.",
    "choices": [
      "claim",
      "viewpoint",
      "stance"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''viewpoint'' phù hợp nhất để chỉ góc nhìn hoặc cách nhìn nhận vấn đề của các chuyên gia.",
    "old_id": "5e38cea5-346d-52e3-a8fb-9d31be024c61",
    "new_id": "1910a7c2-ae7f-546f-8c4f-8ab920d3b8b5"
  },
  {
    "prompt": "Which of the following is the most effective thesis statement for a persuasive essay about plastic pollution?",
    "choices": [
      "Plastic pollution is a very serious problem that affects many people and the ocean animals living there.",
      "People are using too much plastic, so we should try to change our daily habits to help the environment.",
      "Governments should implement stricter regulations on single-use plastics to protect marine ecosystems and human health."
    ],
    "correct_index": 2,
    "explanation_vi": "Đây là một luận điểm rõ ràng, cụ thể và đề xuất hướng giải quyết cụ thể cho bài viết nghị luận.",
    "old_id": "a3c7025d-ee66-5b32-9980-ebb47b12bdef",
    "new_id": "12d64013-dd5a-5ebc-98f5-90ed337f9888"
  },
  {
    "prompt": "Identify the thesis statement that best sets a clear direction for an argumentative essay.",
    "choices": [
      "Although remote learning offers flexibility, it negatively impacts student engagement and social development in primary education.",
      "Remote learning has both positive aspects and negative aspects that students and teachers experience daily.",
      "Many schools switched to remote learning during the pandemic, which caused a lot of controversy among parents."
    ],
    "correct_index": 0,
    "explanation_vi": "Luận điểm này thể hiện rõ ràng quan điểm cá nhân và phạm vi thảo luận của bài viết.",
    "old_id": "86435943-ecd6-5593-809f-0da9b8bf6b69",
    "new_id": "7bd35516-c94a-5128-bd3d-365572035407"
  },
  {
    "prompt": "Which sentence functions best as a thesis statement for an essay about urban planning?",
    "choices": [
      "The city of the future needs to integrate more green spaces to improve resident well-being and air quality.",
      "Urban planning is a complicated subject that many architects and politicians discuss in their meetings.",
      "Green spaces are good, but some people think that building more apartments is more important for the city."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu này đưa ra một khẳng định mạnh mẽ và mục đích cụ thể cho nội dung bài viết.",
    "old_id": "a04cbcf6-4d06-50b5-af4a-19cd6d02c0e4",
    "new_id": "9a9c11e6-62e0-55a4-8c37-62222a79cc3e"
  },
  {
    "prompt": "Person A: ''Do you think we should prioritize public transport over highway expansion?'' Person B: ''__________ I believe public transport is the only sustainable way to reduce urban congestion.''",
    "choices": [
      "To be honest,",
      "My stance is that,",
      "I heard that,"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ ''My stance is that'' là cách diễn đạt trang trọng để khẳng định lập trường cá nhân.",
    "old_id": "78ca6ca8-b281-5308-883a-a86aba8ecd59",
    "new_id": "34b147ef-58c6-533e-9f47-28c352f87801"
  },
  {
    "prompt": "Person A: ''What is your perspective on the new tax laws?'' Person B: ''__________ the current system unfairly penalizes small business owners.''",
    "choices": [
      "I have a viewpoint that",
      "I am of the view that",
      "It is my claim that"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm ''I am of the view that'' là cách diễn đạt tự nhiên và đúng ngữ pháp để trình bày quan điểm.",
    "old_id": "bf3eb913-e077-5d48-8b15-8302765f1c89",
    "new_id": "ccbcb8bc-aa31-52ef-9177-fc42f11aa249"
  },
  {
    "prompt": "Person A: ''Should the company adopt a four-day work week?'' Person B: ''__________ research suggests that productivity actually increases with fewer hours.''",
    "choices": [
      "I argue that",
      "It is my stance,",
      "My viewpoint is"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm ''I argue that'' được dùng để dẫn dắt một lập luận dựa trên bằng chứng.",
    "old_id": "2cc7650e-cc5c-58f7-bbb6-314e7c9ca725",
    "new_id": "dc6f140c-297f-5da8-ae15-8cb2f211a783"
  },
  {
    "prompt": "Which word best completes the sentence: ''The author makes a compelling __________ that digital literacy is now a fundamental human right''?",
    "choices": [
      "stance",
      "viewpoint",
      "claim"
    ],
    "correct_index": 2,
    "explanation_vi": "Trong ngữ cảnh này, ''claim'' là từ phù hợp nhất để chỉ một luận điểm cần được chứng minh.",
    "old_id": "88e2df9b-8593-5bb4-82fa-11c385fe3247",
    "new_id": "598912f4-9155-5fe9-9e81-23dfc5779b64"
  },
  {
    "prompt": "What is the primary purpose of a thesis statement in an opinion piece?",
    "choices": [
      "To include all the evidence supporting the topic.",
      "To provide a summary of the background information.",
      "To present the author''s main argument clearly."
    ],
    "correct_index": 2,
    "explanation_vi": "Luận đề có mục đích chính là giới thiệu quan điểm chính của tác giả.",
    "old_id": "c1f9a5e9-c4e8-599f-a88a-950f96622521",
    "new_id": "758dd531-90a2-5ae8-b5ec-a8cda77e6849"
  },
  {
    "prompt": "Choose the correct phrase to introduce a strong personal viewpoint.",
    "choices": [
      "I guess that it might be...",
      "It is my firm belief that...",
      "Some people might agree that..."
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ này thể hiện sự kiên định và rõ ràng trong quan điểm cá nhân.",
    "old_id": "a52ee16d-3c64-5aac-898a-be05a37c5055",
    "new_id": "af4301c6-04a6-593a-a4cc-dba6b59dd42e"
  },
  {
    "prompt": "Which option represents a clear and defensible stance?",
    "choices": [
      "Taxing industrial carbon emissions is essential to curbing global climate change.",
      "The issue of pollution is very important to discuss.",
      "Pollution is mostly caused by factories, but not always."
    ],
    "correct_index": 0,
    "explanation_vi": "Đây là một lập trường cụ thể, có thể tranh luận và bảo vệ bằng lập luận.",
    "old_id": "82bf5526-4ade-5b91-8fac-6de82c07a5a6",
    "new_id": "67f39578-6eaf-5b0f-a93e-886603d201e5"
  },
  {
    "prompt": "In an argumentative essay, a ''claim'' is best described as:",
    "choices": [
      "A question that the reader should answer by the end.",
      "A casual observation about the topic of the essay.",
      "A statement that needs to be supported by evidence."
    ],
    "correct_index": 2,
    "explanation_vi": "Một lập luận (claim) luôn cần được hỗ trợ bằng bằng chứng để thuyết phục người đọc.",
    "old_id": "f05e1598-fc9a-56d6-b8d7-40331dcf196e",
    "new_id": "d1aebdf0-1684-53fc-847c-542f435dccd8"
  },
  {
    "prompt": "Which of these is a synonym for ''stance'' in the context of writing an opinion piece?",
    "choices": [
      "Posture",
      "Placement",
      "Position"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''position'' đồng nghĩa với ''stance'' trong việc chỉ lập trường của người viết.",
    "old_id": "974f0a6b-4a27-576e-b9ef-0be7e0acc2ad",
    "new_id": "f05c28c0-a180-52c7-8b98-5eaddd6ea3c9"
  },
  {
    "prompt": "The detective presented a piece of physical ____ that linked the suspect to the crime scene.",
    "choices": [
      "example",
      "evidence",
      "reliable"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''evidence'' là danh từ phù hợp nhất để chỉ một vật chứng liên quan đến hiện trường vụ án.",
    "old_id": "d894f983-f873-53c1-aad9-5c046620a174",
    "new_id": "73527abb-067f-58dd-b4c3-b427cd424269"
  },
  {
    "prompt": "Can you give me another ____ of how this new software helps improve efficiency?",
    "choices": [
      "example",
      "reliable",
      "evidence"
    ],
    "correct_index": 0,
    "explanation_vi": "Trong ngữ cảnh này, người hỏi muốn một ví dụ minh họa cụ thể cho một tình huống.",
    "old_id": "6ae37756-aa49-53d2-bdca-c17c4732a313",
    "new_id": "d4c68480-b8b2-5c09-8e9b-b1104e5b6829"
  },
  {
    "prompt": "We need to ensure that the data we collect is ____ before we include it in the report.",
    "choices": [
      "evidence",
      "reliable",
      "example"
    ],
    "correct_index": 1,
    "explanation_vi": "Tính từ ''reliable'' (đáng tin cậy) dùng để bổ nghĩa cho dữ liệu trước khi đưa vào báo cáo.",
    "old_id": "00355cb6-12f9-5a80-abd1-6c7565354427",
    "new_id": "d313f38c-9355-57de-b9fd-7bc55015fede"
  },
  {
    "prompt": "____ he had finished his research, the scientist double-checked all his calculations.",
    "choices": [
      "Although",
      "Once",
      "Because"
    ],
    "correct_index": 1,
    "explanation_vi": "Mệnh đề phụ bắt đầu bằng ''Once'' diễn tả một hành động xảy ra ngay sau khi hành động trước đó hoàn thành.",
    "old_id": "7ee8c773-b15b-5215-9d91-b680bd205457",
    "new_id": "4395b369-e872-5064-8bb0-062a3efd0474"
  },
  {
    "prompt": "The team decided to proceed with the project ____ the initial results were very promising.",
    "choices": [
      "given that",
      "in case",
      "so that"
    ],
    "correct_index": 0,
    "explanation_vi": "Liên từ ''given that'' được dùng để nêu lý do hoặc căn cứ cho một quyết định.",
    "old_id": "5abc920f-df2f-517f-a6d5-0238975fb3e3",
    "new_id": "2b38bb3a-c5cd-55ef-9f9a-21bd424cdd17"
  },
  {
    "prompt": "She organized her notes carefully ____ she could easily find references during the presentation.",
    "choices": [
      "even though",
      "as soon as",
      "so that"
    ],
    "correct_index": 2,
    "explanation_vi": "''So that'' chỉ mục đích, phù hợp với ngữ cảnh chuẩn bị kỹ lưỡng để đạt kết quả tốt.",
    "old_id": "d2bd5d62-db31-545f-b749-0d537fc6bf37",
    "new_id": "96b0af1b-e19e-53a2-af8f-e907d8c1cb83"
  },
  {
    "prompt": "A: Why are you so certain about these figures?\nB: Because I checked them against several ____ sources.",
    "choices": [
      "example",
      "evidence",
      "reliable"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''reliable'' mô tả các nguồn thông tin tin cậy để xác minh số liệu.",
    "old_id": "88f9eba2-d9a7-5826-b94b-5b6837560416",
    "new_id": "30c85d47-22dc-5e20-98a4-fa6e2196c76e"
  },
  {
    "prompt": "A: Is there any proof that the product is actually effective?\nB: Yes, we have gathered plenty of ____ to support our claim.",
    "choices": [
      "evidence",
      "example",
      "reliable"
    ],
    "correct_index": 0,
    "explanation_vi": "Trong ngữ cảnh này, ''evidence'' dùng để chỉ bằng chứng khẳng định hiệu quả của sản phẩm.",
    "old_id": "42e6c807-2979-5fec-afc5-11f5a6e8d1a6",
    "new_id": "fe77bb4f-3f8a-51a3-9293-e4f166fba3d0"
  },
  {
    "prompt": "A: I''m not sure how to structure this essay.\nB: You should use a clear ____ for each point you try to argue.",
    "choices": [
      "evidence",
      "example",
      "reliable"
    ],
    "correct_index": 1,
    "explanation_vi": "''Example'' là từ phù hợp nhất để bổ trợ cho việc giải thích các quan điểm trong bài luận.",
    "old_id": "9d56ae4b-556c-5c6e-ac50-338d85defc70",
    "new_id": "14484e11-3d70-57e0-a1e3-c3e21b52244d"
  },
  {
    "prompt": "The study was published ____ the researchers provided sufficient documentation for their findings.",
    "choices": [
      "even if",
      "only if",
      "in spite of"
    ],
    "correct_index": 1,
    "explanation_vi": "''Only if'' thiết lập một điều kiện tiên quyết để nghiên cứu được công bố.",
    "old_id": "5094e758-510b-5bbb-bf0f-eeedc271a8ff",
    "new_id": "5cfd40d2-59ac-5bc6-9769-ab17e720f0c1"
  },
  {
    "prompt": "____ the weather forecast was unfavorable, the group decided to continue the hike.",
    "choices": [
      "Even though",
      "Once",
      "Since"
    ],
    "correct_index": 0,
    "explanation_vi": "''Even though'' dùng để diễn tả sự đối lập giữa dự báo thời tiết và quyết định của nhóm.",
    "old_id": "f78c024c-81bc-545e-84ef-70bcad281073",
    "new_id": "8ecfc244-c8d2-59c6-9af4-8ce0a4292c49"
  },
  {
    "prompt": "The editor asked for more ____ before agreeing to publish the controversial article.",
    "choices": [
      "reliable",
      "example",
      "evidence"
    ],
    "correct_index": 2,
    "explanation_vi": "Biên tập viên thường yêu cầu bằng chứng (evidence) để đảm bảo tính xác thực trước khi xuất bản.",
    "old_id": "e6860ceb-e7e3-560a-8eaa-53232e373a2d",
    "new_id": "9664f675-4cba-596d-8518-53c7006fa984"
  },
  {
    "prompt": "You should verify this information because the source may not be ____.",
    "choices": [
      "example",
      "evidence",
      "reliable"
    ],
    "correct_index": 2,
    "explanation_vi": "Tính từ ''reliable'' (đáng tin cậy) dùng để chỉ độ tin cậy của nguồn tin.",
    "old_id": "b71c65b2-c1a3-563f-a9f7-984410426789",
    "new_id": "ebb8e23e-cc41-50b3-a691-3ec2beb060e1"
  },
  {
    "prompt": "____ you have the primary documents, you can start building your argument.",
    "choices": [
      "Although",
      "Even though",
      "Since"
    ],
    "correct_index": 2,
    "explanation_vi": "''Since'' được dùng ở đây với nghĩa chỉ nguyên nhân hoặc căn cứ để thực hiện công việc tiếp theo.",
    "old_id": "42157999-0516-560e-b464-ea7c8b804cb9",
    "new_id": "b62438f5-a5ac-5ef2-9037-d15205b1ef9b"
  },
  {
    "prompt": "He provided a real-life ____ of how climate change is affecting the local coastline.",
    "choices": [
      "example",
      "evidence",
      "reliable"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm từ ''real-life example'' diễn tả một ví dụ thực tế được đưa ra để chứng minh vấn đề.",
    "old_id": "e2d0ade8-517d-5689-b518-5806d5d47283",
    "new_id": "cfbd5b8b-c5b6-5eba-aa1d-ea31cfc43b7f"
  },
  {
    "prompt": "One major benefit of remote work is the flexibility it provides, yet many employees find it difficult to maintain a healthy work-life balance.",
    "choices": [
      "cost",
      "requirement",
      "advantage"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''benefit'' đồng nghĩa với ''advantage'' trong ngữ cảnh lợi ích của công việc từ xa.",
    "old_id": "f73f298d-e925-5c2c-abd8-7e9c019b57af",
    "new_id": "3c83c2f3-7c26-5076-b27c-ff0486509c91"
  },
  {
    "prompt": "Although the new software has several useful features, the primary drawback is that it requires a very expensive subscription fee.",
    "choices": [
      "disadvantage",
      "improvement",
      "opportunity"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''drawback'' có nghĩa là nhược điểm hoặc mặt hạn chế, tương đương với ''disadvantage''.",
    "old_id": "22077d25-ab0c-5be9-ba4e-b24be1e37e04",
    "new_id": "93f950c6-7113-5fce-8102-e6b0f4664093"
  },
  {
    "prompt": "Some people enjoy the excitement of living in a busy city, whereas others prefer the peace and quiet of a small rural village.",
    "choices": [
      "because",
      "while",
      "instead"
    ],
    "correct_index": 1,
    "explanation_vi": "Liên từ ''whereas'' được dùng để so sánh hai ý đối lập, có nghĩa tương tự như ''while'' trong trường hợp này.",
    "old_id": "f5eef030-2868-5b70-a46c-0feca0a14003",
    "new_id": "7545acfa-00e5-517d-8d4b-cc53d9bad1f5"
  },
  {
    "prompt": "Electric cars are environmentally friendly; ________, they can be quite inconvenient on long trips due to limited charging stations.",
    "choices": [
      "because",
      "however",
      "although"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''however'' được dùng để nối hai mệnh đề đối lập và đứng sau dấu chấm phẩy.",
    "old_id": "0711012e-a042-5df3-9281-1214ceb64459",
    "new_id": "94683765-75d8-5a23-a161-f6e5be079f5d"
  },
  {
    "prompt": "________ public transport is often cheaper, many commuters still choose to drive their own cars for the sake of convenience.",
    "choices": [
      "Although",
      "Despite",
      "However"
    ],
    "correct_index": 0,
    "explanation_vi": "''Although'' là liên từ dùng để dẫn dắt mệnh đề nhượng bộ trước khi nêu ý đối lập.",
    "old_id": "40f04495-3ad7-522e-b965-1cb8fecc9a59",
    "new_id": "ad6c0cc3-ce50-5d12-9e6a-2509de85dabe"
  },
  {
    "prompt": "Despite ________, the team managed to finish the project on time and within the original budget.",
    "choices": [
      "the weather was bad",
      "the heavy rain",
      "it was raining"
    ],
    "correct_index": 1,
    "explanation_vi": "Sau ''despite'' phải là một danh từ hoặc cụm danh từ.",
    "old_id": "e4506bd9-62e5-53cf-8f3f-04694a564c89",
    "new_id": "6d6589f9-9dd5-511f-ac63-6214c933af98"
  },
  {
    "prompt": "Person A: ''Should we move to the countryside for a cheaper life?'' Person B: ''Well, it’s affordable, ________ there are very few job opportunities there.''",
    "choices": [
      "but",
      "whereas",
      "despite"
    ],
    "correct_index": 0,
    "explanation_vi": "''But'' là liên từ phù hợp nhất để nối hai mệnh đề có nội dung trái ngược trong giao tiếp hàng ngày.",
    "old_id": "bc775ca1-b4cf-534d-891a-3854164fc41a",
    "new_id": "817312e3-ac17-54a2-9fd6-1aa467809411"
  },
  {
    "prompt": "Person A: ''Is it worth buying a fast computer?'' Person B: ''It has great speed, ________ the drawback is its short battery life.''",
    "choices": [
      "while",
      "although",
      "whereas"
    ],
    "correct_index": 2,
    "explanation_vi": "''Whereas'' được dùng để so sánh hai mặt lợi và hại một cách rõ ràng trong câu.",
    "old_id": "277ac1e8-ac66-56e0-8459-b5b42dcfc05a",
    "new_id": "76a2f913-d770-5709-98e9-53d9c883346b"
  },
  {
    "prompt": "Person A: ''Why do you prefer digital books?'' Person B: ''The main benefit is portability, ________ paper books still feel better to hold.''",
    "choices": [
      "despite",
      "while",
      "because"
    ],
    "correct_index": 1,
    "explanation_vi": "''While'' được sử dụng để nêu sự đối lập giữa hai ý kiến hoặc tính chất.",
    "old_id": "59f7125a-bbb5-52c2-8ee5-d3cb72dda749",
    "new_id": "3a176c62-dc88-502e-8b35-d03655b84bf5"
  },
  {
    "prompt": "Which sentence correctly uses the word ''whereas'' to contrast two different hobbies?",
    "choices": [
      "She likes reading whereas she plays sports.",
      "Whereas she likes sports, but she also likes reading.",
      "I love reading, whereas she prefers playing sports."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu này sử dụng ''whereas'' đúng cách để nối hai vế đối lập với cấu trúc ngữ pháp chính xác.",
    "old_id": "96c8351f-cf24-5207-8a5e-56542a48da10",
    "new_id": "54924766-85eb-5ad2-aab0-21e002ac3e18"
  },
  {
    "prompt": "Identify the sentence that shows a clear ''drawback''.",
    "choices": [
      "The main drawback is that I feel isolated from my colleagues.",
      "The fast internet allows me to work from anywhere.",
      "I find that working from home has many benefits."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu này trực tiếp chỉ ra một khía cạnh tiêu cực (sự cô lập) của một tình huống.",
    "old_id": "af7a7d96-33a9-5949-9b63-eb86575f3537",
    "new_id": "697ce7de-12f3-5c54-9187-5b9e97cea1ac"
  },
  {
    "prompt": "Choose the correct structure to express a contrast.",
    "choices": [
      "Although the rain, we went for a walk.",
      "Despite it was raining, we went for a walk.",
      "In spite of the rain, we went for a walk."
    ],
    "correct_index": 2,
    "explanation_vi": "''In spite of'' phải đi kèm với danh từ (the rain), nên đây là câu đúng ngữ pháp.",
    "old_id": "b9c4161d-cef7-5f57-a65c-97fa3e7e2037",
    "new_id": "d368d2be-9890-5c0c-b31c-241f34c41bcf"
  },
  {
    "prompt": "Which option correctly identifies a ''benefit'' of online shopping?",
    "choices": [
      "You can compare prices between stores instantly.",
      "You cannot try on the clothes before buying them.",
      "You have to pay for shipping if the order is small."
    ],
    "correct_index": 0,
    "explanation_vi": "Việc so sánh giá nhanh chóng là một lợi ích thực tế của mua sắm trực tuyến.",
    "old_id": "6ba2372c-995b-5f92-a202-9f12ee458348",
    "new_id": "2220db99-343d-5a89-a4e4-1787a3eadd73"
  },
  {
    "prompt": "Complete the thought: ''Owning a car offers freedom, ________ it comes with high maintenance costs.''",
    "choices": [
      "despite",
      "but",
      "whereas"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''but'' là cách nối thông dụng nhất để đưa ra ý kiến trái ngược trong một mệnh đề.",
    "old_id": "f8dcd7f5-32b8-5d1b-b3a5-5c9c0358051f",
    "new_id": "6c3d4761-3aaa-57a7-8f83-00fb4cffbb25"
  },
  {
    "prompt": "Which sentence best uses the word ''benefit''?",
    "choices": [
      "Regular exercise has the drawback of being a benefit.",
      "Regular exercise is a benefit of being very tired.",
      "The biggest benefit of regular exercise is improved health."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu này sử dụng từ ''benefit'' theo nghĩa tích cực và hợp lý nhất về mặt logic.",
    "old_id": "908aa095-4c3a-5368-aa07-172661f64cc7",
    "new_id": "81db1430-52d9-591f-b143-f4f069f7bdde"
  },
  {
    "prompt": "The primary ______ of the factory closure was the unexpected decline in consumer demand for our products.",
    "choices": [
      "cause",
      "impact",
      "solution"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''cause'' phù hợp để chỉ nguyên nhân dẫn đến việc đóng cửa nhà máy.",
    "old_id": "c03dd2d9-576a-5b89-9b04-6e69860d4700",
    "new_id": "574c5e4e-f6e3-5f59-a779-459ce31e8675"
  },
  {
    "prompt": "We need to analyze the long-term ______ of this strategy on our company''s profitability before moving forward.",
    "choices": [
      "cause",
      "impact",
      "solution"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''impact'' mô tả tác động hoặc ảnh hưởng lâu dài của một chiến lược lên lợi nhuận.",
    "old_id": "29a52752-6c5e-551c-8a17-c46db6754875",
    "new_id": "13acc627-10a7-576c-9d5f-f9db0d18796d"
  },
  {
    "prompt": "After discussing several ideas, the team finally proposed a creative ______ to the recurring software bug.",
    "choices": [
      "cause",
      "solution",
      "impact"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''solution'' được dùng để chỉ giải pháp cho một vấn đề kỹ thuật.",
    "old_id": "164a6702-c051-5076-a6bf-cc7d516d7ff7",
    "new_id": "6183e129-78ca-5a27-983a-1cd7d6708859"
  },
  {
    "prompt": "If the project manager ______ more time to review the documents, he would have noticed the error.",
    "choices": [
      "takes",
      "had taken",
      "took"
    ],
    "correct_index": 1,
    "explanation_vi": "Đây là câu điều kiện loại 3 diễn tả một giả thiết trái ngược với quá khứ.",
    "old_id": "70a36ac6-675f-520d-82f9-666de0deff6e",
    "new_id": "dd62b976-3d5a-58e9-a385-162c208d1c51"
  },
  {
    "prompt": "Unless you ______ a clear plan to the board, they will not approve your budget request.",
    "choices": [
      "presented",
      "will present",
      "present"
    ],
    "correct_index": 2,
    "explanation_vi": "Trong câu điều kiện loại 1 với ''unless'', mệnh đề phụ sử dụng thì hiện tại đơn.",
    "old_id": "c7335645-0855-5d99-b5ca-7ee1d6d4b505",
    "new_id": "c560ed1d-90e7-5915-a13a-1db9095acc21"
  },
  {
    "prompt": "If we ______ our marketing strategy now, we would see better results by the end of the quarter.",
    "choices": [
      "changed",
      "had changed",
      "will change"
    ],
    "correct_index": 0,
    "explanation_vi": "Đây là câu điều kiện loại 2 dùng để chỉ một tình huống giả định ở hiện tại.",
    "old_id": "5c2a6a5e-5b16-542d-a298-2ac111cebd43",
    "new_id": "8055f3e3-9901-5d7d-9d8a-8e53d9219f97"
  },
  {
    "prompt": "Client: ''Our customer support response time has doubled this month.'' Agent: ''______''",
    "choices": [
      "We are looking for the cause of the solution.",
      "I believe the cause is a shortage of support staff.",
      "That is a very positive impact on our growth."
    ],
    "correct_index": 1,
    "explanation_vi": "Câu trả lời đưa ra nguyên nhân hợp lý cho vấn đề khách hàng nêu.",
    "old_id": "7ec4b383-8bbb-5d84-9f00-55f2a0125196",
    "new_id": "aa0fc2de-c75b-5401-9f3b-8f2453d518f0"
  },
  {
    "prompt": "Manager: ''What do you think is the best solution for the warehouse storage issue?'' Employee: ''______''",
    "choices": [
      "The cause is that we have too many boxes.",
      "The impact of the boxes is very significant.",
      "Implementing an automated inventory system would be efficient."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời đề xuất một giải pháp thực tế cho vấn đề kho bãi.",
    "old_id": "c8485008-7c6f-5123-92a0-e82e4e5c40dd",
    "new_id": "bb7ae5ef-0e35-5945-ac7e-6b5e431e8b15"
  },
  {
    "prompt": "Supervisor: ''We have to reduce the environmental impact of our waste disposal.'' Colleague: ''______''",
    "choices": [
      "The cause is simply too much trash produced.",
      "Let''s ignore the solution and look at the cause.",
      "Agreed, we should invest in better recycling technology."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời đưa ra một giải pháp cụ thể để giảm tác động môi trường.",
    "old_id": "13178288-e312-5670-bc7c-fb7a5031d55d",
    "new_id": "4df4500b-5137-569a-90b9-1598a7ce6777"
  },
  {
    "prompt": "If the team ______ the data earlier, they would have avoided the mistake.",
    "choices": [
      "had reviewed",
      "reviewed",
      "would review"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu điều kiện loại 3 dùng ''had + V3'' trong mệnh đề ''if'' để nói về quá khứ.",
    "old_id": "34f5d5bd-2a5e-5a71-ac15-4edc6f91e8f8",
    "new_id": "c1a40cfd-9750-5ec7-a83e-0eaa5d954609"
  },
  {
    "prompt": "The primary ______ for the delay in shipping was a supply chain disruption.",
    "choices": [
      "impact",
      "cause",
      "solution"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''cause'' phù hợp để giải thích lý do dẫn đến sự chậm trễ.",
    "old_id": "86c67eb2-d937-5a24-bf0e-a1055dc9be21",
    "new_id": "323f010e-dac9-5625-82f7-4f9f14d7a300"
  },
  {
    "prompt": "We need to find a sustainable ______ to the rising energy costs in our production plant.",
    "choices": [
      "solution",
      "impact",
      "cause"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''solution'' là lựa chọn đúng khi nói đến việc xử lý vấn đề chi phí năng lượng.",
    "old_id": "38e25e2a-3f89-5ed2-8557-f4d6c8ceb6cc",
    "new_id": "176b60f8-16bc-5a7f-b09f-4909a7b3b76e"
  },
  {
    "prompt": "If we ______ our budget, we might need to cut back on some of our smaller projects.",
    "choices": [
      "had exceeded",
      "exceeded",
      "exceed"
    ],
    "correct_index": 2,
    "explanation_vi": "Câu điều kiện loại 1 diễn tả một sự việc có khả năng xảy ra trong tương lai.",
    "old_id": "f6938e0d-3145-58e5-8bd1-227e06d7dfa3",
    "new_id": "a2b2618d-a794-591e-85fa-306386f69d93"
  },
  {
    "prompt": "What kind of ______ will this new policy have on the daily routine of the employees?",
    "choices": [
      "impact",
      "cause",
      "solution"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''impact'' dùng để hỏi về sự ảnh hưởng của chính sách mới.",
    "old_id": "02a2499d-7e51-5020-a5c5-d2710a9be2b3",
    "new_id": "edcb7c7e-3ca1-5820-8072-c1fbf9272847"
  },
  {
    "prompt": "If I ______ you, I would propose a different approach to solve the problem.",
    "choices": [
      "will be",
      "am",
      "were"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc ''If I were you'' là dạng chuẩn của câu điều kiện loại 2.",
    "old_id": "93304713-b49f-59b3-bd21-a6acea9ba4e3",
    "new_id": "61fcf358-64ab-5b48-99e1-77e342d1370f"
  },
  {
    "prompt": "The first sentence of a paragraph, which introduces the main idea to be discussed, is known as the __________.",
    "choices": [
      "topic sentence",
      "conclusion",
      "cohesion"
    ],
    "correct_index": 0,
    "explanation_vi": "Topic sentence là câu chủ đề dùng để giới thiệu ý chính của đoạn văn.",
    "old_id": "b9981506-5a51-5c39-b6c0-e3c2220edeaa",
    "new_id": "c9134551-f238-5b69-a676-32a4dae124b0"
  },
  {
    "prompt": "To improve __________ in his writing, Mark used transition words like ''furthermore'' and ''consequently'' to link his ideas.",
    "choices": [
      "conclusion",
      "cohesion",
      "topic sentence"
    ],
    "correct_index": 1,
    "explanation_vi": "Cohesion (sự liên kết) là tính chất cần thiết để các câu trong đoạn văn mạch lạc với nhau.",
    "old_id": "a6b2c3eb-3308-56fc-afca-d974654ea7d3",
    "new_id": "f2ba0119-5dd5-5cc3-84e8-ae4526edcb24"
  },
  {
    "prompt": "After presenting all his arguments, Tom wrote a short __________ to summarize the key points of his discussion.",
    "choices": [
      "topic sentence",
      "conclusion",
      "cohesion"
    ],
    "correct_index": 1,
    "explanation_vi": "Conclusion là phần kết luận dùng để tóm tắt lại các luận điểm chính đã thảo luận.",
    "old_id": "d5e68e92-8acb-549f-b3a7-7c11349854d1",
    "new_id": "ec0800a5-5964-5800-b91b-f9641b5cabec"
  },
  {
    "prompt": "Choose the sentence that best maintains paragraph cohesion: ''Solar energy is becoming more popular. __________ it is a clean and renewable resource.''",
    "choices": [
      "Instead",
      "However",
      "Furthermore"
    ],
    "correct_index": 2,
    "explanation_vi": "Furthermore được dùng để thêm thông tin bổ sung cho ý chính đã nêu trước đó.",
    "old_id": "7793be3a-41b2-56a4-9211-aaa40a283874",
    "new_id": "de538123-f1fb-5667-a23c-b5989e0c0d8b"
  },
  {
    "prompt": "The team worked hard on the project; __________, they missed the final deadline due to a last-minute technical error.",
    "choices": [
      "similarly",
      "nevertheless",
      "consequently"
    ],
    "correct_index": 1,
    "explanation_vi": "Nevertheless được dùng để chỉ sự đối lập giữa nỗ lực làm việc và kết quả thất bại.",
    "old_id": "3f2112f5-9672-52fb-83e7-14e1ad4a342d",
    "new_id": "91f913ba-711f-5bdd-842d-e9e8b578f21c"
  },
  {
    "prompt": "She organized her points clearly; __________, she provided evidence to support each claim.",
    "choices": [
      "for instance",
      "in contrast",
      "in addition"
    ],
    "correct_index": 2,
    "explanation_vi": "In addition dùng để chỉ việc thêm vào một hành động hỗ trợ cho ý chính trước đó.",
    "old_id": "ff77ec84-17f8-5d25-96af-bdd81df5ccaa",
    "new_id": "5e4a1a31-899f-583f-8607-7778d4140be5"
  },
  {
    "prompt": "Person A: ''Why do you think remote work is beneficial?'' Person B: ''__________ it allows employees to save time and money on commuting.''",
    "choices": [
      "First of all",
      "On the contrary",
      "In conclusion"
    ],
    "correct_index": 0,
    "explanation_vi": "First of all là cách mở đầu hợp lý khi liệt kê lý do cho một quan điểm.",
    "old_id": "f59f3f5e-759c-5fd8-9ce1-0af4ff91a4f2",
    "new_id": "74b0fd57-c0f4-56c4-9293-30488a3b2927"
  },
  {
    "prompt": "Person A: ''Should we include the statistics in the summary?'' Person B: ''__________! They help prove our argument effectively.''",
    "choices": [
      "No way",
      "Certainly",
      "Not really"
    ],
    "correct_index": 1,
    "explanation_vi": "Certainly là phản hồi đồng ý phù hợp với lý do hỗ trợ cho lập luận.",
    "old_id": "292e6690-f336-5598-8d45-c0593e3fa262",
    "new_id": "8013e39b-8232-5ae7-9fba-06827b0e78fc"
  },
  {
    "prompt": "Person A: ''Is the paragraph structure clear enough?'' Person B: ''Yes, the transition words help maintain __________ throughout.''",
    "choices": [
      "cohesion",
      "the topic sentence",
      "a conclusion"
    ],
    "correct_index": 0,
    "explanation_vi": "Cohesion là từ phù hợp nhất để mô tả sự mạch lạc thông qua các từ nối trong đoạn văn.",
    "old_id": "1d216692-7f54-5b1c-8bbd-960276010eae",
    "new_id": "c09bb067-d4df-5479-9af4-d7567479ea2c"
  },
  {
    "prompt": "A paragraph lacks a __________ when the sentences do not follow a logical order or connect properly.",
    "choices": [
      "conclusion",
      "topic sentence",
      "cohesion"
    ],
    "correct_index": 2,
    "explanation_vi": "Sự liên kết (cohesion) là yếu tố khiến các câu văn kết nối chặt chẽ với nhau.",
    "old_id": "e15acf22-40b3-5f67-9b6d-ef8f0a975c83",
    "new_id": "7c35cdd1-c199-5999-ad56-b5b10b1358e6"
  },
  {
    "prompt": "Which of these is the most effective way to end a discussion paragraph?",
    "choices": [
      "Adding a list of questions",
      "Introducing a new, unrelated topic",
      "Summarizing the main takeaway"
    ],
    "correct_index": 2,
    "explanation_vi": "Việc tóm tắt ý chính là cách tốt nhất để kết thúc một đoạn văn thảo luận.",
    "old_id": "5d6283c5-04bf-5a89-86c5-f681ba22ee9f",
    "new_id": "4f9a5ab9-07a4-5e3d-a43f-f4bb2e6241a5"
  },
  {
    "prompt": "When writing a discussion, a __________ should state the main argument clearly to guide the reader.",
    "choices": [
      "cohesion",
      "topic sentence",
      "conclusion"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu chủ đề (topic sentence) đóng vai trò định hướng cho người đọc hiểu về nội dung chính.",
    "old_id": "486828ed-5a2b-5c57-b4fa-d1b18fce98d1",
    "new_id": "e0cbe2b7-300b-53cc-a9d0-cd3fef96ba2e"
  },
  {
    "prompt": "Which transition word shows a cause-and-effect relationship in a discussion?",
    "choices": [
      "Therefore",
      "Moreover",
      "Likewise"
    ],
    "correct_index": 0,
    "explanation_vi": "Therefore là từ nối dùng để diễn tả mối quan hệ nguyên nhân - kết quả.",
    "old_id": "6c633ea5-eead-5dc3-82a4-05f54a3f89ba",
    "new_id": "f845ab71-aa0a-5d10-90ba-8ed382971301"
  },
  {
    "prompt": "If you want to contrast two ideas in a paragraph, which word is most appropriate?",
    "choices": [
      "However",
      "Similarly",
      "Furthermore"
    ],
    "correct_index": 0,
    "explanation_vi": "However được sử dụng để chỉ sự đối lập giữa hai ý tưởng.",
    "old_id": "556bc818-a5c8-59a9-8b5c-24edf07cff73",
    "new_id": "0399db00-a5d2-5d33-9ed2-c674fc29d3ef"
  },
  {
    "prompt": "What is the primary role of a ''cohesive device'' in a paragraph?",
    "choices": [
      "To introduce a new topic sentence",
      "To change the paragraph length",
      "To link ideas together smoothly"
    ],
    "correct_index": 2,
    "explanation_vi": "Các từ nối (cohesive devices) có vai trò liên kết các ý tưởng một cách mượt mà.",
    "old_id": "04f8ecee-6253-5290-9364-a4f637ea7340",
    "new_id": "e604b9aa-ff7b-542b-bf64-e96c26a75475"
  },
  {
    "prompt": "After reading the meeting notes, please ensure the __________ line clearly indicates the project name so the recipient knows what the message concerns.",
    "choices": [
      "subject",
      "request",
      "attachment"
    ],
    "correct_index": 0,
    "explanation_vi": "Subject line là thành phần bắt buộc để người nhận biết nội dung email là gì.",
    "old_id": "d6231ea4-32b5-5b35-9db4-ac4386d04310",
    "new_id": "bc3baf70-49f9-56c7-b473-d434929abcff"
  },
  {
    "prompt": "I have included the updated budget proposal as an __________ to this email for your review.",
    "choices": [
      "request",
      "subject",
      "attachment"
    ],
    "correct_index": 2,
    "explanation_vi": "Attachment là từ dùng để chỉ tệp tin đính kèm trong email.",
    "old_id": "09deeebd-7dd3-508a-bb88-73362d6dca54",
    "new_id": "a924c1a3-5486-5e8c-b7f6-6d8b7a4f1e0d"
  },
  {
    "prompt": "Could you please process my __________ for an extension on the project deadline due to the recent system issues?",
    "choices": [
      "attachment",
      "subject",
      "request"
    ],
    "correct_index": 2,
    "explanation_vi": "Request mang nghĩa là yêu cầu, phù hợp trong ngữ cảnh xin gia hạn thời hạn dự án.",
    "old_id": "eb14251c-c2f6-592b-9dd9-51382409da6d",
    "new_id": "7c745568-1792-5782-bd18-e152f91b8b1b"
  },
  {
    "prompt": "__________ you have any questions regarding the proposal, please feel free to contact me at your earliest convenience.",
    "choices": [
      "If",
      "Do",
      "Should"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc đảo ngữ ''Should + S + V'' được dùng trong văn phong trang trọng thay cho ''If you have''.",
    "old_id": "81cd8ab2-efb5-5e19-a63c-a8af51afb488",
    "new_id": "f3e6bb7a-09c7-5bc6-8b5e-c4369f66a6d7"
  },
  {
    "prompt": "We __________ the revised contract for your signature yesterday afternoon.",
    "choices": [
      "sending",
      "sent",
      "send"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng thì quá khứ đơn vì hành động đã xảy ra vào thời điểm xác định là chiều hôm qua.",
    "old_id": "7be9b9a4-9ba9-5b0d-bc84-e09f4fc78a68",
    "new_id": "3deb7b6e-c1e3-5368-ba5a-c4057014f8f7"
  },
  {
    "prompt": "It is __________ that all employees complete the security training by the end of the week.",
    "choices": [
      "required",
      "requiring",
      "require"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc bị động sau ''It is'' cần một phân từ hai (quá khứ phân từ) để bổ nghĩa.",
    "old_id": "4dae677b-b09f-5af0-bd5b-679b67ca1efc",
    "new_id": "e68cbe60-bb79-5c21-b6f8-1823f2fd26af"
  },
  {
    "prompt": "Sender: I have attached the quarterly report. \nRecipient: Thank you for sending it; __________.",
    "choices": [
      "I have received it safely",
      "I will get it soon",
      "I want to send one"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời lịch sự và phù hợp nhất để xác nhận đã nhận được tệp tin đính kèm.",
    "old_id": "b5bc2e8f-7a35-54b0-907b-7af036089b70",
    "new_id": "6eb62163-42c3-5028-b135-0ffdefcc109b"
  },
  {
    "prompt": "Sender: Could you please clarify the instructions for the new software? \nRecipient: __________, I would be happy to explain them further.",
    "choices": [
      "Of course",
      "Never mind",
      "Not really"
    ],
    "correct_index": 0,
    "explanation_vi": "Of course là cách phản hồi tích cực và chuyên nghiệp khi đồng ý hỗ trợ người khác.",
    "old_id": "53ac8ce1-b43b-5cdf-85b5-ed13d9a5c3b2",
    "new_id": "d68cba1c-1366-5ff6-989f-d95cd7d761fc"
  },
  {
    "prompt": "Sender: I am writing to apologize for the delay in my response. \nRecipient: __________, we appreciate you getting back to us.",
    "choices": [
      "Go ahead",
      "No problem",
      "I agree"
    ],
    "correct_index": 1,
    "explanation_vi": "No problem là cách phản hồi thông dụng để chấp nhận lời xin lỗi và duy trì mối quan hệ công việc.",
    "old_id": "9d54b9f0-6533-5c2c-bc60-aeb93683034b",
    "new_id": "4c003349-dd63-55c7-b6e4-3f49c668c973"
  },
  {
    "prompt": "When writing a formal email, which of the following is the most appropriate closing?",
    "choices": [
      "Best wishes",
      "Sincerely",
      "Talk soon"
    ],
    "correct_index": 1,
    "explanation_vi": "Sincerely là cách kết thư trang trọng nhất phù hợp với môi trường chuyên nghiệp.",
    "old_id": "1cb0dd67-855f-586d-b7cf-2ba841873c64",
    "new_id": "5c7bab93-6426-547e-b12a-d987ee285d48"
  },
  {
    "prompt": "What is the primary function of a clear subject line in a professional email?",
    "choices": [
      "To summarize the main purpose",
      "To introduce the sender''s history",
      "To provide a long list of dates"
    ],
    "correct_index": 0,
    "explanation_vi": "Tiêu đề cần tóm tắt mục đích chính để người nhận nắm bắt thông tin nhanh chóng.",
    "old_id": "4093fc88-2881-5d0f-8286-d1432a2b34a8",
    "new_id": "80bcdfdb-4c6e-537b-8beb-1dd4ae802d43"
  },
  {
    "prompt": "If you need to ask for a favor in an email, which phrase is most professional?",
    "choices": [
      "Do this for me now",
      "Could you please assist me",
      "I need you to do this"
    ],
    "correct_index": 1,
    "explanation_vi": "Cách đặt câu hỏi với ''Could you please'' thể hiện sự lịch thiệp và tôn trọng trong công việc.",
    "old_id": "a7b8d74d-4716-59aa-bad0-31259718d751",
    "new_id": "4e9ee3a4-da7d-5d35-8652-62207794f4cc"
  },
  {
    "prompt": "Which grammar structure is most common for formal professional requests?",
    "choices": [
      "Informal slang",
      "Direct commands",
      "Polite modal verbs"
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng các động từ khuyết thiếu như ''could'', ''would'' giúp yêu cầu trở nên nhẹ nhàng và chuyên nghiệp hơn.",
    "old_id": "cdddb4f2-3c17-5b18-b69a-5deb2578c593",
    "new_id": "ec095600-581d-57de-b1cf-0ee28181a88b"
  },
  {
    "prompt": "When referring to a file sent with your email, what is the best verb to use?",
    "choices": [
      "Attaching",
      "Hold",
      "Enclosing"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''enclosing'' (đính kèm) thường được dùng trong các văn bản và email trang trọng.",
    "old_id": "5daf022f-ee5c-55b9-a310-a238b07e4982",
    "new_id": "5e1f8e1a-2c98-51fc-92e7-b2b957943cae"
  },
  {
    "prompt": "How should you address someone whose name you do not know in a formal email?",
    "choices": [
      "Hey you",
      "To whom it may concern",
      "Dear person"
    ],
    "correct_index": 1,
    "explanation_vi": "To whom it may concern là cụm từ chuẩn mực khi viết email cho một người chưa xác định danh tính.",
    "old_id": "cfb2d43d-9cf4-57cc-8941-ae8b2f650349",
    "new_id": "4a1d7771-a450-5ff9-abf1-ea38cf84b67f"
  },
  {
    "prompt": "Despite the initial challenges, the team managed to __________ in their research project, bringing them closer to the final discovery.",
    "choices": [
      "do progress",
      "take progress",
      "make progress"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''make progress'' là collocation cố định trong tiếng Anh để chỉ sự tiến bộ.",
    "old_id": "94df8fe7-33e6-5c92-aadd-db964e03cf31",
    "new_id": "4246978e-dce5-5a03-9c33-04f843fafd82"
  },
  {
    "prompt": "The local community decided to __________ in the annual marathon to raise funds for the hospital''s new wing.",
    "choices": [
      "do part",
      "take part",
      "make part"
    ],
    "correct_index": 1,
    "explanation_vi": "Collocation ''take part'' mang nghĩa tham gia vào một sự kiện hoặc hoạt động.",
    "old_id": "00426424-bae0-5f41-ba93-6df700e075ba",
    "new_id": "959f6f11-3b5c-595f-bd8e-a7781f0f1771"
  },
  {
    "prompt": "The detective presented __________ that the suspect was not at the scene of the crime during the incident.",
    "choices": [
      "hard evidence",
      "strong evidence",
      "heavy evidence"
    ],
    "correct_index": 1,
    "explanation_vi": "Trong ngữ cảnh này, ''strong evidence'' là cụm từ tự nhiên nhất để diễn tả bằng chứng thuyết phục.",
    "old_id": "186c26ea-3c25-5a6b-b060-21f692bb286d",
    "new_id": "8bb91e79-e354-5207-b54f-fecfde46cd78"
  },
  {
    "prompt": "The students __________ their homework before the teacher arrived, which was a huge relief for them.",
    "choices": [
      "had finished",
      "have finished",
      "were finished"
    ],
    "correct_index": 0,
    "explanation_vi": "Thì quá khứ hoàn thành dùng để chỉ hành động hoàn tất trước một thời điểm khác trong quá khứ.",
    "old_id": "2920a1b6-e6d2-5f15-86aa-6031cbcaf653",
    "new_id": "57a1a880-514f-5168-9384-25e965cee09f"
  },
  {
    "prompt": "If she __________ more effort into her presentation, she would have received a higher grade from the committee.",
    "choices": [
      "had put",
      "puts",
      "would put"
    ],
    "correct_index": 0,
    "explanation_vi": "Đây là câu điều kiện loại 3 dùng để diễn tả sự tiếc nuối về một hành động không xảy ra trong quá khứ.",
    "old_id": "369d7f8d-cd16-5f6d-9ee6-a830c6eb5183",
    "new_id": "441f420f-0c0f-5898-b5ad-c709b6a51bb0"
  },
  {
    "prompt": "By the time we reach the summit, we __________ for over six hours without a proper break.",
    "choices": [
      "are climbing",
      "climbed",
      "will have climbed"
    ],
    "correct_index": 2,
    "explanation_vi": "Thì tương lai hoàn thành tiếp diễn nhấn mạnh khoảng thời gian kéo dài của hành động đến một thời điểm tương lai.",
    "old_id": "a7b3c3ad-744a-57de-bbd7-efd3d0ed6090",
    "new_id": "4c5d0133-38e1-51d8-82db-5b8fac0bc69f"
  },
  {
    "prompt": "Speaker A: ''I''m afraid I won''t be able to finish the report by five.'' Speaker B: ''Don''t worry, just __________ and do your best.''",
    "choices": [
      "do a start",
      "take a start",
      "make a start"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''make a start'' diễn tả việc bắt đầu thực hiện một công việc nào đó.",
    "old_id": "8a297866-554f-56d1-9dbc-559fa2976881",
    "new_id": "d487c156-1158-5fcc-8946-bbc07639fa4b"
  },
  {
    "prompt": "Speaker A: ''Did you enjoy the workshop yesterday?'' Speaker B: ''Yes, it was fascinating to __________ in such a collaborative environment.''",
    "choices": [
      "take part",
      "make part",
      "do part"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''take part in'' là lựa chọn chính xác về mặt từ vựng cho ngữ cảnh tham gia sự kiện.",
    "old_id": "db8e05c8-faf5-5019-99e7-be9371bbc2e1",
    "new_id": "f8d4feef-c027-5f54-9741-f1d515a8ea31"
  },
  {
    "prompt": "Speaker A: ''Do you think they will release the results today?'' Speaker B: ''Probably not, since there is no __________ to support their current theory.''",
    "choices": [
      "hard evidence",
      "strong evidence",
      "firm evidence"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm ''strong evidence'' phù hợp nhất để trả lời cho câu hỏi về sự hỗ trợ của lý thuyết.",
    "old_id": "059076aa-302f-5469-bcb9-0779deb8bd8a",
    "new_id": "b2de4ff0-2b17-5fe8-a707-64388c0b897f"
  },
  {
    "prompt": "We need to __________ a decision soon if we want to secure the venue for the wedding.",
    "choices": [
      "take",
      "do",
      "make"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ ''make'' luôn đi với danh từ ''decision'' để tạo thành collocation cố định.",
    "old_id": "40abe16f-b487-56c1-b573-9e6a1e11cd93",
    "new_id": "4cfa569f-142a-5abe-8a5e-ae2e544af27b"
  },
  {
    "prompt": "The government is trying to __________ changes to the education system to improve student performance.",
    "choices": [
      "take",
      "make",
      "do"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ ''make changes'' được sử dụng phổ biến để diễn tả việc thực hiện thay đổi.",
    "old_id": "209562f6-b6c6-518c-897f-ccd28c66c628",
    "new_id": "ea280d04-862a-575f-a8b3-1db6a06b8d2d"
  },
  {
    "prompt": "It is important to __________ a break every hour when you are working on a computer screen for a long time.",
    "choices": [
      "take",
      "have",
      "make"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm từ ''take a break'' là collocation tự nhiên trong tiếng Anh để chỉ việc nghỉ giải lao.",
    "old_id": "0d905e71-4790-54e5-9984-2544ea0a8e9e",
    "new_id": "bdfeb15b-d7be-5032-b98a-b1791734adff"
  },
  {
    "prompt": "She always __________ an effort to help her colleagues whenever they are struggling with their tasks.",
    "choices": [
      "takes",
      "does",
      "makes"
    ],
    "correct_index": 2,
    "explanation_vi": "Collocation ''make an effort'' nghĩa là nỗ lực làm việc gì đó.",
    "old_id": "f5375a9e-a625-5fb4-93fb-4b798a1fb58a",
    "new_id": "bafa5097-ab64-59c3-8014-744b85e139c5"
  },
  {
    "prompt": "After the long discussion, they finally __________ a conclusion that satisfied everyone in the room.",
    "choices": [
      "reached",
      "did",
      "took"
    ],
    "correct_index": 0,
    "explanation_vi": "Động từ ''reach'' đi với ''a conclusion'' để tạo thành cụm từ đi đến kết luận.",
    "old_id": "6420d388-8b2c-5715-8f50-c47273ded9ea",
    "new_id": "1707bbe0-19e4-5f0e-a166-7bc86a0d3842"
  },
  {
    "prompt": "The manager asked the employees to __________ notes during the meeting so they wouldn''t forget the key points.",
    "choices": [
      "do",
      "take",
      "make"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ ''take notes'' là collocation phổ biến dùng để chỉ việc ghi chép lại.",
    "old_id": "51c85435-d327-5698-abbc-572122b64553",
    "new_id": "fdc96872-48be-5689-99c5-9f0ca7c7c1f3"
  },
  {
    "prompt": "Although the team had several disagreements during the meeting, they managed to ________ a solution that satisfied everyone.",
    "choices": [
      "turn down",
      "bring up",
      "work out"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm động từ ''work out'' có nghĩa là tìm ra giải pháp cho một vấn đề khó khăn.",
    "old_id": "d06c87d0-ee9d-52c8-832b-ae96e7e51356",
    "new_id": "1bca3c98-b323-565f-a769-d730d0721131"
  },
  {
    "prompt": "She was hesitant to ________ the issue of salary during the interview, fearing it might seem unprofessional.",
    "choices": [
      "turn down",
      "work out",
      "bring up"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm động từ ''bring up'' có nghĩa là bắt đầu thảo luận hoặc đề cập đến một chủ đề nào đó.",
    "old_id": "614e5c0c-678c-5020-8d60-2a607902c6a7",
    "new_id": "58fb4ee3-a828-5f13-abb4-d0ca4d889a31"
  },
  {
    "prompt": "Despite their impressive qualifications, the committee decided to ________ the applicant because he lacked specific technical experience.",
    "choices": [
      "turn down",
      "bring up",
      "work out"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm động từ ''turn down'' có nghĩa là từ chối một lời đề nghị hoặc một ứng viên.",
    "old_id": "8b6ddc2f-2503-5332-9df9-18064b409b4d",
    "new_id": "b471926d-206e-5006-8a22-8071c6d0c6d5"
  },
  {
    "prompt": "The particle ''up'' in ''bring up'' often suggests bringing a topic ________ the surface for others to see.",
    "choices": [
      "up to",
      "away from",
      "out of"
    ],
    "correct_index": 0,
    "explanation_vi": "Trong trường hợp này, ''up'' ám chỉ việc đưa một chủ đề từ trạng thái ẩn lên bề mặt để thảo luận.",
    "old_id": "5447c646-72b6-57a2-8636-5918e3e1e576",
    "new_id": "1ed34b76-ff93-54e8-bd9d-d9799c5a368c"
  },
  {
    "prompt": "The particle ''out'' in ''work out'' emphasizes the completion or total ________ of a logical process.",
    "choices": [
      "reduction",
      "reflection",
      "resolution"
    ],
    "correct_index": 2,
    "explanation_vi": "Hạt từ ''out'' thường mang nghĩa hoàn tất một quá trình tư duy hoặc giải quyết vấn đề đến cùng.",
    "old_id": "1891ce80-fdb1-58b0-817d-49f443d7509b",
    "new_id": "c91c54e7-df1d-59e4-bc47-1149a0202f5b"
  },
  {
    "prompt": "The particle ''down'' in ''turn down'' signals a negative response, effectively ________ the request being made.",
    "choices": [
      "extending",
      "lowering",
      "advancing"
    ],
    "correct_index": 1,
    "explanation_vi": "Hạt từ ''down'' trong ngữ cảnh này mang nghĩa tiêu cực, làm thấp đi hoặc từ chối sự chấp nhận.",
    "old_id": "322327f8-d555-5789-94b5-9ea2c0f7e49e",
    "new_id": "03811cca-eeda-51e9-a921-4ac482722eae"
  },
  {
    "prompt": "A: ''Do you think we should mention the budget cuts to the staff?'' B: ''Yes, but be careful how you ________ it; they are already stressed.''",
    "choices": [
      "work out",
      "bring up",
      "turn down"
    ],
    "correct_index": 1,
    "explanation_vi": "Cần sử dụng ''bring up'' để nói về việc bắt đầu một chủ đề nhạy cảm trong cuộc trò chuyện.",
    "old_id": "42a9d4ff-9709-5b73-83c2-0fc3d6b91d71",
    "new_id": "ebbe72bc-5d84-5f7b-a6d0-9b53af51a874"
  },
  {
    "prompt": "A: ''Did you get the job at the design firm?'' B: ''No, they ________ my application because I didn''t have enough portfolio examples.''",
    "choices": [
      "brought up",
      "worked out",
      "turned down"
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng ''turned down'' để mô tả việc bị từ chối đơn ứng tuyển.",
    "old_id": "27a41ddc-cf9c-5994-b39c-9b977161a948",
    "new_id": "f75b2b15-2f39-531d-93d1-987ad112a48c"
  },
  {
    "prompt": "A: ''We have a massive scheduling conflict for the conference.'' B: ''Don''t worry, I''m sure we can ________ a plan that covers everyone''s availability.''",
    "choices": [
      "bring up",
      "work out",
      "turn down"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng ''work out'' để nói về việc lên kế hoạch hoặc tìm giải pháp cho một vấn đề.",
    "old_id": "09a8fb48-e46a-55d5-98bc-2b43b9a1b084",
    "new_id": "fc920923-fd64-5e3f-b0d8-101151386101"
  },
  {
    "prompt": "The manager decided to ________ the idea of remote work during the board meeting.",
    "choices": [
      "work out",
      "bring up",
      "turn down"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng ''bring up'' để chỉ việc nêu lên một ý tưởng trong cuộc họp.",
    "old_id": "bb706596-573c-590f-90fd-b5ecc7239b81",
    "new_id": "a07d63c0-b282-5988-a794-993c6daca000"
  },
  {
    "prompt": "If you don''t like the terms of the contract, you have the right to ________ the offer.",
    "choices": [
      "bring up",
      "turn down",
      "work out"
    ],
    "correct_index": 1,
    "explanation_vi": "Dùng ''turn down'' để diễn tả việc từ chối một lời đề nghị trong hợp đồng.",
    "old_id": "9e0408e4-1fa5-5c9e-84fe-f15176723db1",
    "new_id": "0d9ced13-60f4-5255-935c-6911dfed1a28"
  },
  {
    "prompt": "We spent all afternoon trying to ________ the details of our upcoming international trip.",
    "choices": [
      "work out",
      "turn down",
      "bring up"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''work out'' để chỉ việc sắp xếp, giải quyết các chi tiết cụ thể của một kế hoạch.",
    "old_id": "64895a46-8b42-516c-bc49-39d823706a10",
    "new_id": "dde256ba-517e-528b-9869-cd2cb0471375"
  },
  {
    "prompt": "It is never a good idea to ________ personal grievances during a professional presentation.",
    "choices": [
      "bring up",
      "work out",
      "turn down"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''bring up'' để nói về việc nhắc đến các vấn đề cá nhân không phù hợp.",
    "old_id": "7e39d144-2033-560b-b675-faaaa71b9f3a",
    "new_id": "3837a0f8-0932-52d8-8712-e4bf583d15f9"
  },
  {
    "prompt": "After hours of calculation, the accountant was finally able to ________ the final cost of the project.",
    "choices": [
      "work out",
      "turn down",
      "bring up"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''work out'' khi đề cập đến việc tính toán ra kết quả cuối cùng.",
    "old_id": "8b8c4870-8205-5ea7-9f6c-29869902b05f",
    "new_id": "b1ef86a8-8872-56f7-a7f9-ecf0e54a6d4f"
  },
  {
    "prompt": "The landlord had to ________ the tenant''s request for a lower monthly rent.",
    "choices": [
      "bring up",
      "work out",
      "turn down"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''turn down'' để nói về việc từ chối một yêu cầu giảm giá thuê nhà.",
    "old_id": "46bd3b07-436d-561a-b01e-5d423b46aaa4",
    "new_id": "798203a2-9244-5b39-9ad2-db24ae57e0c6"
  },
  {
    "prompt": "Read the following sentence: ''Before we present the final project to the board, let’s hold a quick meeting to ensure we are all on the same page.'' What does the phrase ''on the same page'' imply in this context?",
    "choices": [
      "To be working at the same physical desk",
      "To share the same understanding or opinion",
      "To read from the identical project document"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ này có nghĩa là mọi người cùng đồng thuận hoặc có chung một cách hiểu về vấn đề.",
    "old_id": "bed405fe-80af-5fef-be6c-3f54b3a4cf44",
    "new_id": "22532dc2-6c03-580f-a0e3-f82911d5ce8c"
  },
  {
    "prompt": "If an entrepreneur says that applying for a massive government grant is a long shot, what are they suggesting?",
    "choices": [
      "The chances of successfully receiving the grant are slim",
      "The task will take a very long time to complete",
      "The application process is extremely expensive"
    ],
    "correct_index": 0,
    "explanation_vi": "Thành ngữ ''a long shot'' diễn tả một việc khó có khả năng thành công.",
    "old_id": "7908c9a3-fcfe-574a-8796-36426de6d53b",
    "new_id": "f649d552-3aea-5c90-a4f7-8548826edbe2"
  },
  {
    "prompt": "Context: ''Sarah wanted to surprise her team with a fancy office lunch, but they were not on the same page regarding the date.'' Based on the context, what happened?",
    "choices": [
      "The team members had conflicting expectations about when the lunch would be",
      "The team members refused to look at the office calendar together",
      "The team members forgot to bring their lunch schedules to the meeting"
    ],
    "correct_index": 0,
    "explanation_vi": "Ngữ cảnh cho thấy có sự bất đồng về thời gian, tức là họ không có cùng suy nghĩ.",
    "old_id": "afe6cca0-17e2-5dfa-bc6a-2acfc532cd3a",
    "new_id": "2bfa233d-2653-5efa-89a1-6ef7bf693889"
  },
  {
    "prompt": "Choose the sentence that uses the idiom ''a long shot'' grammatically and logically correctly.",
    "choices": [
      "I am a long shot to finish this report by five o''clock today.",
      "Winning the lottery is a long shot, but people buy tickets anyway.",
      "The new manager is a long shot for the company''s growth strategy."
    ],
    "correct_index": 1,
    "explanation_vi": "Câu đầu tiên sử dụng đúng nghĩa về một sự việc ít có khả năng xảy ra.",
    "old_id": "2eef4c6f-80a2-5e10-8f97-b1df7bd9e70e",
    "new_id": "525a4fed-44e7-5771-a994-b9f80c18015d"
  },
  {
    "prompt": "Before signing a contract, the department heads need to agree on its terms. Which sentence expresses that meaning?",
    "choices": [
      "The students stayed on the same page while the teacher explained the lesson.",
      "The actors were reading from the same page during the final rehearsal.",
      "The department heads need to be on the same page before signing the contract."
    ],
    "correct_index": 2,
    "explanation_vi": "Đây là cách sử dụng thành ngữ đúng để chỉ sự thống nhất ý kiến giữa các bên.",
    "old_id": "152fb6a9-347a-5af1-9b8f-5f47339aa8a5",
    "new_id": "457d4677-2904-5d1c-97c8-9f91a4e62a05"
  },
  {
    "prompt": "Which pairing correctly explains the figurative meaning of the idiom?",
    "choices": [
      "On the same page: a state of agreement regarding a specific plan or idea.",
      "A long shot: a strategy that requires a very long-term commitment.",
      "On the same page: a situation where two people are reading the same source material."
    ],
    "correct_index": 0,
    "explanation_vi": "Giải thích này phản ánh chính xác nghĩa bóng của thành ngữ trong giao tiếp.",
    "old_id": "b0887fcd-2f37-56ce-9ee6-7e3f9f59cf48",
    "new_id": "3ba973e9-f91a-5e94-abe6-629817ebaff1"
  },
  {
    "prompt": "Person A: ''Do you think our proposal will be accepted by the investors?'' Person B: ''Honestly, given the current market volatility, it’s __________.''",
    "choices": [
      "a long shot",
      "on the same page",
      "a short process"
    ],
    "correct_index": 0,
    "explanation_vi": "Dựa vào bối cảnh thị trường bất ổn, câu trả lời phù hợp nhất là việc được chấp thuận rất khó xảy ra.",
    "old_id": "99635aa6-34a8-5d39-9449-4df4bce64cca",
    "new_id": "570a5cdb-d26c-5167-8108-e6414a93fec1"
  },
  {
    "prompt": "Person A: ''I am worried that our advertising team and the sales department are pulling in different directions.'' Person B: ''I agree. We really need to get them __________ before the launch.''",
    "choices": [
      "a quick result",
      "on the same page",
      "a long shot"
    ],
    "correct_index": 1,
    "explanation_vi": "Khi các bộ phận không cùng định hướng, họ cần được thống nhất ý kiến.",
    "old_id": "e90e22a2-1712-5893-8f53-4e9c07bf5104",
    "new_id": "66f5b1d7-e301-5a35-b530-402275f64d74"
  },
  {
    "prompt": "Person A: ''I''m thinking of asking for a promotion after only two months here.'' Person B: ''That’s __________, but it doesn''t hurt to try if you have the evidence.''",
    "choices": [
      "a common practice",
      "on the same page",
      "a long shot"
    ],
    "correct_index": 2,
    "explanation_vi": "Việc xin tăng lương sau thời gian quá ngắn là một việc khó thành công.",
    "old_id": "4fac3603-b4f0-5791-b4d5-3fb87adfbe21",
    "new_id": "d3194eec-bfd5-5480-8a46-5613887ced20"
  },
  {
    "prompt": "Which scenario best illustrates the idiom ''on the same page''?",
    "choices": [
      "Two coworkers realize they are both assigned the same desk.",
      "Two business partners reach a consensus on the project budget.",
      "Two friends buy the exact same book to read at the same time."
    ],
    "correct_index": 1,
    "explanation_vi": "Thành ngữ này nhấn mạnh vào sự đồng thuận về mặt ý tưởng và kế hoạch.",
    "old_id": "40b716b6-4e45-5658-8ff8-583df5c41e13",
    "new_id": "33014e7b-a3f9-5ad6-88d0-a3382a7041fe"
  },
  {
    "prompt": "Which scenario best illustrates the idiom ''a long shot''?",
    "choices": [
      "A struggling actor auditions for a role he is clearly unqualified for.",
      "A student studies for weeks to pass an easy exam with a high score.",
      "An athlete attempts a shot from the other end of the basketball court."
    ],
    "correct_index": 0,
    "explanation_vi": "Việc thử sức với một vai diễn không phù hợp là một việc rất khó thành công.",
    "old_id": "2b4f57de-5324-5b8a-a56c-fbaa2bc7d459",
    "new_id": "35cc3a99-8ab1-5a6c-a6b2-d9176bfa9267"
  },
  {
    "prompt": "When two people are ''on the same page'', what are they essentially doing?",
    "choices": [
      "Consulting the same reference book for accuracy.",
      "Sharing physical space to complete a document.",
      "Aligning their perspectives to avoid misunderstanding."
    ],
    "correct_index": 2,
    "explanation_vi": "Nghĩa bóng của thành ngữ này là sự hòa hợp về tư tưởng và quan điểm.",
    "old_id": "1c8ae441-428b-55f0-a14d-c51df5ec0ca9",
    "new_id": "34546fd3-a87b-5e6d-94f6-f002c74b49ba"
  },
  {
    "prompt": "If you describe an outcome as ''a long shot'', what are you emphasizing?",
    "choices": [
      "The physical distance between the goal and the attempt.",
      "The high level of uncertainty and low probability of success.",
      "The duration of time needed to reach the goal."
    ],
    "correct_index": 1,
    "explanation_vi": "Thành ngữ này nhấn mạnh vào độ rủi ro và xác suất thành công thấp.",
    "old_id": "e874b989-dbd2-52cc-a6b2-c754c2026cb0",
    "new_id": "2bb7f061-82cd-559b-ab9a-2c2e27e0212b"
  },
  {
    "prompt": "Complete the logic: A team working ''on the same page'' is to synergy as a plan that is ''a long shot'' is to __________.",
    "choices": [
      "certainty",
      "optimism",
      "risk"
    ],
    "correct_index": 2,
    "explanation_vi": "Cả hai vế đều so sánh đặc tính của thành ngữ với trạng thái tương ứng, ''a long shot'' đồng nghĩa với rủi ro cao.",
    "old_id": "724fc0ff-5bfc-57e1-b146-76d188918cfc",
    "new_id": "92b4ed35-7aa1-5ec9-85a8-c681f49a60d3"
  },
  {
    "prompt": "Select the correct usage of the idiom ''on the same page'' in a professional setting.",
    "choices": [
      "The files are on the same page, so you can easily compare them.",
      "I am on the same page as you because we share the same office floor.",
      "We need to get the stakeholders on the same page to approve the merger."
    ],
    "correct_index": 2,
    "explanation_vi": "Việc đạt được sự đồng thuận giữa các bên liên quan là cách sử dụng đúng nhất của thành ngữ này.",
    "old_id": "11f17d88-4d09-5181-9a6c-b3a5fcb18e6c",
    "new_id": "eff1d322-b355-5f87-964d-847714e2814d"
  },
  {
    "prompt": "I thought the concert was sold out, but I managed to get a ticket. - Oh, really? I ______ thought it was fully booked as well.",
    "choices": [
      "by the way",
      "fair enough",
      "actually"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''actually'' được dùng ở đây để bày tỏ sự ngạc nhiên hoặc xác nhận một thông tin trái ngược với giả định ban đầu.",
    "old_id": "1cd54c48-787b-5c4f-800a-14b7f89107cb",
    "new_id": "ef1353d8-f9a3-5b92-9eac-6a3e22b04e9f"
  },
  {
    "prompt": "We are going to be late because of the traffic. - ______, we should have left the house twenty minutes earlier.",
    "choices": [
      "Fair enough",
      "Actually",
      "By the way"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm ''fair enough'' dùng để thừa nhận rằng ý kiến hoặc lập luận của người kia là hợp lý.",
    "old_id": "4ff25d61-4cb5-59dc-92a3-a4b10728ff8a",
    "new_id": "ac822160-b669-599a-99bd-165e255eee4c"
  },
  {
    "prompt": "I love your new bag! ______, where did you buy it?",
    "choices": [
      "Fair enough",
      "By the way",
      "Actually"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm ''by the way'' được sử dụng để chuyển đổi chủ đề hoặc giới thiệu một thông tin thêm trong hội thoại.",
    "old_id": "354e0395-262e-5f34-ade2-4eaa7f2c5332",
    "new_id": "8da15f70-e578-513c-ac89-7a625be86db2"
  },
  {
    "prompt": "You haven''t finished the report, ______?",
    "choices": [
      "did you",
      "have you",
      "do you"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc câu hỏi đuôi cần đồng nhất với thì của động từ chính và dạng khẳng định/phủ định.",
    "old_id": "e0a828ae-1022-55ad-9d61-f2c7ad7801d0",
    "new_id": "8c6d06ba-09e0-5b2c-8a97-dcb857ffca19"
  },
  {
    "prompt": "I''m sorry, I can''t attend the meeting. - ______, I understand. We can reschedule for tomorrow.",
    "choices": [
      "So as",
      "Right so",
      "That''s fine"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm ''that''s fine'' là cách phản hồi lịch sự để chấp nhận lời xin lỗi hoặc sự thay đổi kế hoạch.",
    "old_id": "435b9e2c-cf16-5fef-878b-70adb47b939d",
    "new_id": "9cf1d3c2-c5d0-549b-9928-6a060b5dc037"
  },
  {
    "prompt": "So, ______ you are saying is that we need more time to complete the project?",
    "choices": [
      "what",
      "which",
      "that"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''what... is...'' dùng để nhấn mạnh nội dung được nhắc lại trong quá trình giao tiếp.",
    "old_id": "0889e7f6-7d33-5d39-8555-22112d8162f0",
    "new_id": "8aa68e8d-7e08-5108-922b-612a6c14eedd"
  },
  {
    "prompt": "I don''t think we should walk there; it''s too far. - ______. Let''s just take a taxi instead.",
    "choices": [
      "I see your point",
      "Actually it is",
      "I''m sorry for you"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm ''I see your point'' được dùng để thể hiện sự đồng tình với lập luận của người đối diện.",
    "old_id": "97c1250a-1337-5cbb-bd05-832ef54ec8c5",
    "new_id": "099bfdf4-9b8d-5b4e-be17-d0b26290fc52"
  },
  {
    "prompt": "If you don''t mind, could you help me move this table? - ______, I''d be happy to.",
    "choices": [
      "Not at all",
      "By the way",
      "Fair enough"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu ''Not at all'' là cách đáp lại lịch sự khi ai đó xin phép hoặc nhờ vả mình.",
    "old_id": "c0ecbff9-90c8-5482-b680-5cb724dc4357",
    "new_id": "35cbb1a7-8563-5cc7-929e-6bd44c2694a0"
  },
  {
    "prompt": "The cafe is closed today. - Oh, I didn''t know that. ______, we can go to the one down the street.",
    "choices": [
      "By the way",
      "Anyway",
      "Actually"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''anyway'' được dùng để kết thúc một chủ đề không còn hữu ích và chuyển sang hướng giải quyết khác.",
    "old_id": "4ead031c-8f5f-5cd6-9c99-320fdae60381",
    "new_id": "5c931517-aa85-5465-b0d5-66ea39f83302"
  },
  {
    "prompt": "I really don''t feel like cooking tonight. - ______. Let''s just order a pizza.",
    "choices": [
      "Actually",
      "Fair enough",
      "By the way"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng ''fair enough'' để đồng ý với quan điểm hoặc cảm xúc của người kia một cách tự nhiên.",
    "old_id": "9b3e3c0f-f7e5-5b7f-8556-c7bb7489ae72",
    "new_id": "3dd690e2-d738-5c5c-a1a5-d507967c61a8"
  },
  {
    "prompt": "It''s quite cold outside. You should wear a jacket. - ______, I didn''t even realize the temperature had dropped.",
    "choices": [
      "Actually",
      "Fair enough",
      "By the way"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''actually'' để phản hồi lại thông tin mới mà người nói chưa biết trước đó.",
    "old_id": "5ddbe9f5-fae9-55c8-a6b0-467f9ea8fc3c",
    "new_id": "d34abd4f-5b8a-5577-af84-6c83e1b24329"
  },
  {
    "prompt": "We need to finish this presentation by Friday. ______, did you talk to the manager about the deadline extension?",
    "choices": [
      "Fair enough",
      "Actually",
      "By the way"
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng ''by the way'' để hỏi thêm một chi tiết liên quan đến chủ đề chính.",
    "old_id": "fca7ab39-b167-5c4f-8329-e3de0b8c9d11",
    "new_id": "db37f30f-c262-558c-9926-757cd083b5ef"
  },
  {
    "prompt": "The bus is always late on Mondays. - ______. It''s really frustrating for commuters.",
    "choices": [
      "Actually",
      "By the way",
      "Fair enough"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''fair enough'' để công nhận thực trạng hoặc ý kiến của người nói là đúng.",
    "old_id": "38cd1ab4-f30c-5f4f-99ad-d0a909f070de",
    "new_id": "185e90b7-0165-5fd4-9378-dd35606e7ffc"
  },
  {
    "prompt": "I thought this movie was a comedy, but it turned out to be quite sad. - ______, the director said it was a drama in the interview.",
    "choices": [
      "By the way",
      "Fair enough",
      "Actually"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng ''actually'' để đưa ra thông tin đính chính lại suy nghĩ ban đầu của người nghe.",
    "old_id": "3fd0616d-f490-5f21-b182-c599a3770c35",
    "new_id": "edd2a508-b688-5e45-b7f8-20e0ec87cfc7"
  },
  {
    "prompt": "I''m heading to the grocery store now. ______, do we need milk?",
    "choices": [
      "Actually",
      "By the way",
      "Fair enough"
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng ''by the way'' để nhắc đến một vấn đề mới phát sinh trong cuộc hội thoại.",
    "old_id": "87d3bc48-c28b-5af3-b433-30a903d6dfbb",
    "new_id": "d627fbb5-696b-5aa0-8f7d-722bcc87683d"
  },
  {
    "prompt": "In a professional email, which word is the most appropriate replacement for ''about'' to maintain a formal tone?",
    "choices": [
      "concerningly",
      "around",
      "regarding"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''regarding'' là một trạng từ trang trọng phổ biến được dùng trong email công việc để thay thế cho ''about''.",
    "old_id": "69634488-79e1-526f-8e52-4493e69416c0",
    "new_id": "7e80f34f-7767-5fde-9256-9eab8ecf71b0"
  },
  {
    "prompt": "If a colleague sends you a report, which phrase best expresses your gratitude in a formal business context?",
    "choices": [
      "I appreciate your help",
      "Thanks a bunch",
      "Cheers for that"
    ],
    "correct_index": 0,
    "explanation_vi": "''I appreciate'' là cách diễn đạt trang trọng và lịch sự để cảm ơn ai đó trong môi trường chuyên nghiệp.",
    "old_id": "b9b73721-7a10-55d7-b902-dc87f3b92ff3",
    "new_id": "ac656bc6-c26b-587b-b91f-c1f7f78c1b50"
  },
  {
    "prompt": "Which of these expressions is strictly informal and should be avoided in a formal letter to a client?",
    "choices": [
      "regards",
      "sincerely",
      "cheers"
    ],
    "correct_index": 2,
    "explanation_vi": "''Cheers'' là từ thân mật thường dùng trong văn nói hoặc giao tiếp xã hội, không phù hợp với văn phong thư tín trang trọng.",
    "old_id": "6d0c18a5-1bb1-5aca-96dc-2fbe659afc59",
    "new_id": "11b0e833-82ea-52c3-aee2-224e47af2d3c"
  },
  {
    "prompt": "Select the sentence that demonstrates a formal register suitable for a job application cover letter.",
    "choices": [
      "Just wanted to say I want this job.",
      "I am writing to inquire about the position.",
      "I''m checking out the job you guys posted."
    ],
    "correct_index": 1,
    "explanation_vi": "Câu này sử dụng cấu trúc đầy đủ, từ vựng chuẩn mực và tránh các từ viết tắt hoặc ngôn ngữ xuồng xã.",
    "old_id": "d90dd04e-078b-510e-a6a1-4aab7093c7c3",
    "new_id": "d4684a68-fac7-5dd9-b2a9-77456a282c75"
  },
  {
    "prompt": "Choose the most appropriate way to address a stranger in a formal email.",
    "choices": [
      "Dear Mr. Anderson,",
      "Hi everyone,",
      "Hey there,"
    ],
    "correct_index": 0,
    "explanation_vi": "Việc sử dụng ''Dear'' đi kèm tên riêng là quy chuẩn lịch sự nhất khi gửi email cho người chưa thân thiết.",
    "old_id": "359e06bd-6c36-58cd-b229-9d47456397d2",
    "new_id": "5bc0dbfc-4698-5c24-be74-09f90626c20e"
  },
  {
    "prompt": "Which sentence structure is typical of an informal register?",
    "choices": [
      "I cannot come to the meeting.",
      "I''m not gonna make it to the meeting.",
      "It is imperative that we attend."
    ],
    "correct_index": 1,
    "explanation_vi": "Việc sử dụng từ viết tắt ''I''m'' và dạng rút gọn ''gonna'' là đặc trưng của văn nói và văn phong không trang trọng.",
    "old_id": "4d8e8b43-04f3-55dd-8e1e-82c617d77084",
    "new_id": "80255530-5630-582c-8d66-be1e5fe03ba6"
  },
  {
    "prompt": "Manager: ''Could you please submit the quarterly report by Friday?'' Employee: ''__________''",
    "choices": [
      "Yeah, I''ll get it to you later.",
      "I will certainly have it ready by then.",
      "Sure thing, boss!"
    ],
    "correct_index": 1,
    "explanation_vi": "Phản hồi này giữ thái độ chuyên nghiệp, khẳng định rõ thời gian hoàn thành theo yêu cầu của cấp trên.",
    "old_id": "c3742bc8-cb62-5241-8e4a-426e568211e1",
    "new_id": "1907a2ff-e0c2-588b-af32-06011f4b3d50"
  },
  {
    "prompt": "Client: ''Is there any flexibility with the project deadline?'' You: ''__________''",
    "choices": [
      "I''ll see what I can do.",
      "Regarding your request, I will check the schedule and let you know.",
      "Nah, that''s not possible."
    ],
    "correct_index": 1,
    "explanation_vi": "Câu trả lời này sử dụng từ nối chuyên nghiệp và thái độ phục vụ khách hàng lịch sự.",
    "old_id": "cd414ec6-8f92-5f0c-ba10-1e9518a66b0e",
    "new_id": "daf0d80a-c8f0-54c1-84ff-d3fe0b88e650"
  },
  {
    "prompt": "Colleague: ''Do you want to grab lunch at the canteen?'' You: ''__________''",
    "choices": [
      "Regarding lunch, I must decline.",
      "I would be delighted to accompany you.",
      "That sounds great, let''s go."
    ],
    "correct_index": 2,
    "explanation_vi": "Với đồng nghiệp trong môi trường thoải mái, cách trả lời ngắn gọn và thân thiện là lựa chọn phù hợp nhất.",
    "old_id": "ac7e9e45-2a94-54de-8ec0-99891a4e7391",
    "new_id": "469eda8b-9ad1-5806-a84c-db4a0aa2d6ef"
  },
  {
    "prompt": "Which of these words is most suitable for a formal report when describing a problem?",
    "choices": [
      "a bummer",
      "messed up",
      "an issue"
    ],
    "correct_index": 2,
    "explanation_vi": "''An issue'' là thuật ngữ trung lập và chuyên nghiệp dùng để chỉ vấn đề trong báo cáo.",
    "old_id": "c771e8ba-9665-53ef-a215-96b913523ba6",
    "new_id": "da46f309-8e64-5cd8-90b4-847c61f321dc"
  },
  {
    "prompt": "How should you start a formal email if the recipient''s name is unknown?",
    "choices": [
      "Dear Sir or Madam,",
      "Hi there,",
      "Hey you,"
    ],
    "correct_index": 0,
    "explanation_vi": "''Dear Sir or Madam'' là cách chào hỏi chuẩn mực trong trường hợp không biết tên người nhận trong văn phong trang trọng.",
    "old_id": "812230fd-fbb7-5210-a452-ed817d9f8627",
    "new_id": "300fc5d6-2b3e-5dae-b457-17e652bec0cb"
  },
  {
    "prompt": "Which verb is most appropriate for a formal business presentation?",
    "choices": [
      "tell",
      "demonstrate",
      "show"
    ],
    "correct_index": 1,
    "explanation_vi": "''Demonstrate'' mang sắc thái học thuật và chuyên môn hơn so với các từ ''show'' hay ''tell'' trong thuyết trình.",
    "old_id": "7ffc835d-0d5d-5996-acfb-9e51c81fd714",
    "new_id": "adb951a9-f21a-547e-b476-67ba7cb20e91"
  },
  {
    "prompt": "What is the most professional way to sign off an email to a potential employer?",
    "choices": [
      "Sincerely,",
      "Best,",
      "Talk later,"
    ],
    "correct_index": 0,
    "explanation_vi": "''Sincerely'' là từ kết thư mang tính trang trọng cao, phù hợp nhất cho các mục đích tuyển dụng.",
    "old_id": "06bd4908-b3f4-5ba0-af26-7e9571758f8d",
    "new_id": "a501c2a9-e198-5fdd-9fd9-64e403b652a4"
  },
  {
    "prompt": "Choose the most appropriate phrase to request information politely.",
    "choices": [
      "Need those files, thanks.",
      "Send me the files right now.",
      "I would appreciate it if you could send the files."
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc ''I would appreciate it if...'' là cách diễn đạt yêu cầu một cách lịch thiệp và trang trọng nhất.",
    "old_id": "1a0d129b-a746-52a3-bec9-31fa97bf8b8d",
    "new_id": "dc2ae88d-fbee-5da9-9035-2911129898b0"
  },
  {
    "prompt": "When writing to a colleague you see every day, what tone is expected?",
    "choices": [
      "Semi-formal or neutral",
      "Strictly formal",
      "Legalistic"
    ],
    "correct_index": 0,
    "explanation_vi": "Với đồng nghiệp thân quen, việc sử dụng tông giọng trung lập, thân thiện là đủ để duy trì mối quan hệ công việc tốt.",
    "old_id": "9f116e5a-3574-5142-8e1c-f522c066fdd9",
    "new_id": "79c4ff06-47b7-5d36-a4a8-05ba915408c6"
  },
  {
    "prompt": "Although the manager never said he was unhappy, his silence seemed to _____ that he disagreed with our plan.",
    "choices": [
      "elicit",
      "infer",
      "imply"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''imply'' được dùng khi người nói đưa ra một gợi ý gián tiếp, trái ngược với ''infer'' là khi người nghe rút ra kết luận.",
    "old_id": "65c56491-fff0-5702-8e5e-f46173c2dc7e",
    "new_id": "12c9365a-8b54-5ee7-8345-1e6a2a39f9fa"
  },
  {
    "prompt": "The difference between the two color shades is so _____ that most people would never notice them side by side.",
    "choices": [
      "vivid",
      "subtle",
      "obvious"
    ],
    "correct_index": 1,
    "explanation_vi": "Tính từ ''subtle'' mô tả một sự khác biệt rất nhỏ và khó nhận thấy.",
    "old_id": "d5235828-6c13-5857-bdb0-6e829bfd0e50",
    "new_id": "29524509-1528-58a8-8f75-27490bc494ed"
  },
  {
    "prompt": "I had to _____ from her frustrated tone that she had been waiting for a long time, even though she didn''t complain directly.",
    "choices": [
      "convey",
      "infer",
      "imply"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''infer'' chỉ hành động suy luận ra một ý nghĩa từ dữ kiện đã có.",
    "old_id": "14d049f1-ad75-5e78-b887-f14a36aa4d35",
    "new_id": "c357b0de-ad12-5343-bd4f-26d7e7a40349"
  },
  {
    "prompt": "Instead of saying ''he is cheap,'' using the word ''frugal'' changes the _____ of the statement from negative to positive.",
    "choices": [
      "definition",
      "connotation",
      "precision"
    ],
    "correct_index": 1,
    "explanation_vi": "''Connotation'' dùng để chỉ sắc thái cảm xúc hoặc ý nghĩa gợi liên tưởng đi kèm với một từ.",
    "old_id": "0a5607e5-2393-520c-a04e-06e117970f88",
    "new_id": "1185db72-7873-5e03-ad22-b6d1c2953d27"
  },
  {
    "prompt": "For the sake of _____, could you specify exactly which document you are referring to in the report?",
    "choices": [
      "ambiguity",
      "precision",
      "fluency"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''precision'' được chọn vì yêu cầu cần sự chính xác trong việc định danh tài liệu.",
    "old_id": "691fdc7e-1e9a-56f6-b45f-fee03bafc7aa",
    "new_id": "f3731974-042b-5679-afc9-59468b332c42"
  },
  {
    "prompt": "Using ''childlike'' instead of ''childish'' provides a more positive _____ when describing someone''s sense of wonder.",
    "choices": [
      "synonym",
      "antonym",
      "nuance"
    ],
    "correct_index": 2,
    "explanation_vi": "''Nuance'' mô tả sắc thái khác biệt nhỏ giữa các từ có nghĩa gần giống nhau.",
    "old_id": "c3b50d6e-0ed3-5719-9f2e-c45b4cb7cbc4",
    "new_id": "8ff9155b-9b53-5b9b-a036-55a2a3bf45bc"
  },
  {
    "prompt": "A: ''Do you think my outfit is too formal for the party?'' B: ''It''s a bold choice. _____''",
    "choices": [
      "It might be better to dress down.",
      "I love how you dressed.",
      "You look exactly like everyone else."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời gợi ý một sự tinh tế khi đưa ra lời khuyên tránh xung đột trực tiếp.",
    "old_id": "9b423235-ec1e-50ed-bd6c-f7d20a7e33d1",
    "new_id": "4a1ad45d-a87e-56b3-97f6-c6dcf57fcd07"
  },
  {
    "prompt": "A: ''Is the boss angry about the delay?'' B: ''He didn''t say anything, but _____''",
    "choices": [
      "he was smiling the whole time.",
      "I am very happy with the results.",
      "his short emails suggest he is stressed."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời thể hiện việc suy luận từ các dấu hiệu gián tiếp là email ngắn gọn.",
    "old_id": "2b9e57c1-faa3-51df-bd35-75240b54ab21",
    "new_id": "0d78af18-8aca-5452-a28f-d40c1ac6a9f0"
  },
  {
    "prompt": "A: ''Why did she use such strong language in the email?'' B: ''I think she wanted to ensure there was no _____ about the new deadlines.''",
    "choices": [
      "ambiguity",
      "clarity",
      "nuance"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''ambiguity'' phù hợp trong ngữ cảnh muốn loại bỏ sự mơ hồ trong các thông báo quan trọng.",
    "old_id": "c383570a-c122-532e-b39a-81dc6b5d8408",
    "new_id": "d3754b37-10ab-59c8-a6b8-abdf45e45c40"
  },
  {
    "prompt": "Which sentence demonstrates a positive connotation when describing a person''s behavior?",
    "choices": [
      "He is very stubborn about his ideas.",
      "He is very determined to reach his goals.",
      "He is very pig-headed when challenged."
    ],
    "correct_index": 1,
    "explanation_vi": "''Determined'' mang sắc thái tích cực, trong khi các từ còn lại mang sắc thái tiêu cực.",
    "old_id": "be62f29f-2ebf-5f5b-a55c-d5f80f487853",
    "new_id": "cd2e524c-7709-549b-bffd-cfd6f821a8a6"
  },
  {
    "prompt": "If a writer wants to avoid being blunt, they might use _____ language to soften the impact of their message.",
    "choices": [
      "direct",
      "harsh",
      "subtle"
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng ngôn ngữ ''subtle'' giúp thông điệp trở nên khéo léo và bớt gay gắt.",
    "old_id": "e5661d3f-689a-5342-887d-843f483b6955",
    "new_id": "b8a9bb08-2a8c-515c-b98e-a9471892a772"
  },
  {
    "prompt": "When you _____ something, you are gathering information from evidence rather than direct statements.",
    "choices": [
      "infer",
      "state",
      "imply"
    ],
    "correct_index": 0,
    "explanation_vi": "Định nghĩa chính xác của ''infer'' là suy luận từ các bằng chứng sẵn có.",
    "old_id": "2d2a2a99-ba9e-5bff-8ced-0c9ffb2c2c4c",
    "new_id": "4071a9a0-0f2f-5d18-b990-23300ee6a672"
  },
  {
    "prompt": "Which choice represents the most precise way to describe a very small, barely noticeable change?",
    "choices": [
      "A dramatic shift",
      "A massive improvement",
      "A subtle adjustment"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''subtle adjustment'' diễn tả chính xác sự thay đổi rất nhỏ.",
    "old_id": "2cec781e-32f2-55c9-8d71-c96f4bd12898",
    "new_id": "0d6bbf3e-0874-5b69-ae8f-5198c10291c6"
  },
  {
    "prompt": "If a speaker says, ''It''s getting quite late, isn''t it?'' they are likely trying to _____ that it is time for the guest to leave.",
    "choices": [
      "imply",
      "insist",
      "infer"
    ],
    "correct_index": 0,
    "explanation_vi": "Người nói đang ám chỉ (imply) việc khách nên về thay vì nói thẳng ra.",
    "old_id": "27e1ae1e-0a8d-5c60-81ee-289c8f195242",
    "new_id": "af5289b4-a1a5-5523-bc4e-a97b3296588e"
  },
  {
    "prompt": "Selecting words with the right connotation helps a speaker convey the intended _____ of their message.",
    "choices": [
      "nuance",
      "speed",
      "volume"
    ],
    "correct_index": 0,
    "explanation_vi": "Việc chọn từ có sắc thái phù hợp giúp truyền tải chính xác tinh thần (nuance) của thông điệp.",
    "old_id": "38d5ec7b-5137-5f64-8ef8-30e787ad79ab",
    "new_id": "c050e9d5-b7ea-5bce-a520-ccc76040e652"
  },
  {
    "prompt": "The expert offered a unique _____ on the economic crisis, suggesting that traditional models were failing to account for global digital shifts.",
    "choices": [
      "perspective",
      "assumption",
      "implication"
    ],
    "correct_index": 0,
    "explanation_vi": "Perspective là danh từ phù hợp nhất để chỉ cách nhìn nhận hoặc góc độ đánh giá một vấn đề.",
    "old_id": "f2d11912-b675-5ed8-a01f-d66980e2cd05",
    "new_id": "69e135a0-1104-5bbc-94eb-6d9761ec6425"
  },
  {
    "prompt": "We need to re-examine our underlying _____ that the current software will remain compatible with future hardware updates.",
    "choices": [
      "implication",
      "perspective",
      "assumption"
    ],
    "correct_index": 2,
    "explanation_vi": "Assumption dùng để chỉ một niềm tin hoặc giả định được coi là đúng mà không cần bằng chứng.",
    "old_id": "aeafb8d7-62e2-5f29-92a6-6bb89c1af82c",
    "new_id": "5507006d-ad19-5b4c-816a-f566e6b8db23"
  },
  {
    "prompt": "If we implement these policy changes, the immediate _____ will be a significant increase in administrative paperwork for all staff members.",
    "choices": [
      "perspective",
      "implication",
      "assumption"
    ],
    "correct_index": 1,
    "explanation_vi": "Implication chỉ hệ quả hoặc tác động logic dẫn đến từ một quyết định hoặc sự kiện.",
    "old_id": "b6304f5c-61e1-5c01-b2a3-5445fd418131",
    "new_id": "18b27382-01b4-5269-b4fe-560bed3a5804"
  },
  {
    "prompt": "Choose the sentence that uses hedging correctly to sound more professional and less absolute.",
    "choices": [
      "This strategy is definitely the only way to save the company''s reputation.",
      "You must change the strategy immediately because it is failing the team.",
      "It would appear that this strategy might be the most effective way to address the concerns."
    ],
    "correct_index": 2,
    "explanation_vi": "Việc sử dụng ''would appear'' và ''might'' giúp giảm tính khẳng định, tạo sự chuyên nghiệp trong giao tiếp.",
    "old_id": "0041b5f3-f7e9-59fb-be9b-1892aeb8b63b",
    "new_id": "ef242e76-84b1-5eff-ad6a-c2d9b1c411f6"
  },
  {
    "prompt": "Which phrasing shows a cautious approach when presenting a controversial finding?",
    "choices": [
      "The data proves that the project is a complete disaster.",
      "It tends to suggest that the project faces some significant challenges.",
      "The project is failing and everyone knows it."
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ ''tends to suggest'' là một cách diễn đạt tránh né (hedging) để trình bày quan điểm một cách thận trọng.",
    "old_id": "11f91b4f-8b97-50ca-870a-83e790d85fb7",
    "new_id": "acdb46bb-1b7f-58d3-ae4b-7a9f0a0e4466"
  },
  {
    "prompt": "Select the sentence that uses a hedging device to soften a critique.",
    "choices": [
      "You failed to include the budget factors in your report.",
      "Your report seems to overlook some key factors regarding the budget.",
      "Your report is completely missing the main budget factors."
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''seems to'' làm giảm nhẹ tính chất phê bình, giúp người nghe dễ tiếp nhận thông tin hơn.",
    "old_id": "b3ce09a0-cbd2-597a-a852-63f57baec292",
    "new_id": "54b09692-bcb2-5d19-ace7-216959119839"
  },
  {
    "prompt": "Person A: ''Do you think this merger will succeed?'' Person B: ''_____ it is possible, though there are several variables we cannot yet control.''",
    "choices": [
      "It strikes me that",
      "I am certain",
      "Without a doubt"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''It strikes me that'' là một cách diễn đạt quan điểm cá nhân mang tính thăm dò.",
    "old_id": "e18a0fd7-dcbb-53f4-aff0-bed2c638586b",
    "new_id": "7ccaab2b-235b-58d4-ad30-f4d3655fdcf6"
  },
  {
    "prompt": "Person A: ''We need to fire the entire marketing team.'' Person B: ''That''s a strong claim. _____ we should evaluate their recent performance data before making such a move?''",
    "choices": [
      "Don''t you think",
      "I demand that",
      "I know for a fact"
    ],
    "correct_index": 0,
    "explanation_vi": "Câu hỏi tu từ ''Don''t you think'' là cách dùng hedging để gợi ý một hướng giải quyết khác thay vì đối đầu trực tiếp.",
    "old_id": "43f635c2-8c31-5d2c-ae19-05999d5de1f7",
    "new_id": "825c277d-49ca-55b9-bbd2-415d31c50479"
  },
  {
    "prompt": "Person A: ''Is the new regulation going to increase costs?'' Person B: ''It is, in some respects, _____ to lead to higher operational expenses.''",
    "choices": [
      "likely",
      "guaranteed",
      "impossible"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''likely'' giúp diễn đạt khả năng xảy ra cao mà không khẳng định chắc chắn 100%.",
    "old_id": "002002d9-672b-5db5-a4f7-84de1ee3de44",
    "new_id": "a419679b-dc00-5e0a-a903-31f277551a4f"
  },
  {
    "prompt": "When discussing complex systemic issues, why is hedging often preferred in professional settings?",
    "choices": [
      "It prevents the speaker from being held accountable for their words.",
      "It is a way to manipulate the audience into agreeing with false facts.",
      "It allows for nuanced debate and maintains professional decorum."
    ],
    "correct_index": 2,
    "explanation_vi": "Hedging giúp duy trì thái độ chuyên nghiệp và cởi mở đối với các ý kiến phản biện khác nhau.",
    "old_id": "dd76f7cc-1237-56bf-995b-ccc03717541a",
    "new_id": "090e3cc8-8e42-5727-a8a9-3f4d90cf9a76"
  },
  {
    "prompt": "If a colleague says, ''My assumption is that the project will finish on time,'' what are they signaling?",
    "choices": [
      "An absolute guarantee of the delivery date.",
      "A confirmed schedule based on verified milestones.",
      "A belief based on incomplete information."
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''assumption'' ngụ ý rằng đó chỉ là niềm tin cá nhân chưa có sự xác nhận hoàn toàn từ thực tế.",
    "old_id": "31ed272a-48e2-5bbc-9d9c-6825b45f5ae8",
    "new_id": "ff1aeb70-db0a-5ef0-848f-8f0553459472"
  },
  {
    "prompt": "Which sentence demonstrates the most sophisticated use of vocabulary to describe an implication?",
    "choices": [
      "The fact that we lost money is a bad implication.",
      "The implication of this data is that a budget deficit is foreseeable.",
      "The result means we will lose money."
    ],
    "correct_index": 1,
    "explanation_vi": "Cách diễn đạt này dùng từ vựng chính xác và cấu trúc câu trang trọng phù hợp với trình độ C1.",
    "old_id": "5f92da3d-16f3-5a3e-aa3e-4b5231c1749c",
    "new_id": "10c6c14c-b3b6-50e3-b6b8-f96606d0353a"
  },
  {
    "prompt": "When asked for a ''perspective'' on a sensitive topic, a professional should aim to be:",
    "choices": [
      "Vague and unhelpful.",
      "Aggressive and dominant.",
      "Objective and considered."
    ],
    "correct_index": 2,
    "explanation_vi": "Một quan điểm (perspective) chuyên nghiệp cần thể hiện sự khách quan và có suy xét kỹ lưỡng.",
    "old_id": "df60d0b8-87c1-5c9d-b5e1-1f60424b451a",
    "new_id": "f8566ac1-2f45-5f02-936e-dcc465579d40"
  },
  {
    "prompt": "Which phrase is an example of ''hedging'' used to maintain a relationship during a disagreement?",
    "choices": [
      "You clearly do not understand the complexity of the issue.",
      "I see where you are coming from, but I might have a different take.",
      "That is entirely incorrect."
    ],
    "correct_index": 1,
    "explanation_vi": "Sử dụng ''might have a different take'' giúp giảm sự xung đột trực diện trong khi vẫn nêu được chính kiến.",
    "old_id": "3dbab3d0-9a3f-5306-b1fc-dd7c8ad129b1",
    "new_id": "31adddfc-bce1-5cf6-ac73-ef0e40428a09"
  },
  {
    "prompt": "What is the primary function of acknowledging an ''assumption'' in a complex discussion?",
    "choices": [
      "To clarify the foundation upon which an argument is built.",
      "To invalidate the opponent''s previous points.",
      "To end the conversation early."
    ],
    "correct_index": 0,
    "explanation_vi": "Việc thừa nhận giả định giúp làm rõ cơ sở của lập luận, từ đó tranh luận trở nên minh bạch hơn.",
    "old_id": "c89c40f4-6aae-591b-b0a2-2abc82d70534",
    "new_id": "339754fc-cf11-5fd0-acd7-d2fb447add41"
  },
  {
    "prompt": "During the formal debate, Sarah offered a brilliant ________ that dismantled her opponent''s claim about urban infrastructure.",
    "choices": [
      "concede",
      "rebuttal",
      "compelling"
    ],
    "correct_index": 1,
    "explanation_vi": "Rebuttal là danh từ chỉ sự phản bác, phù hợp với ngữ cảnh tranh luận.",
    "old_id": "05dc4069-4034-53d1-bac0-bc39b68d8820",
    "new_id": "e2bc0b6e-1c6b-56d7-b883-28042851dce7"
  },
  {
    "prompt": "The expert witness was forced to ________ that the new evidence might indeed change the outcome of the case.",
    "choices": [
      "rebuttal",
      "compelling",
      "concede"
    ],
    "correct_index": 2,
    "explanation_vi": "Concede là động từ có nghĩa là thừa nhận, phù hợp để mô tả việc chấp nhận bằng chứng đối nghịch.",
    "old_id": "116bb462-d5ae-5ee5-8684-2fa313a83ea9",
    "new_id": "14516340-661d-553f-837d-85fdaac5f902"
  },
  {
    "prompt": "The committee found the candidate’s vision for the company to be highly ________, leading them to offer her the position immediately.",
    "choices": [
      "rebuttal",
      "compelling",
      "concede"
    ],
    "correct_index": 1,
    "explanation_vi": "Compelling là tính từ có nghĩa là thuyết phục, phù hợp để mô tả một tầm nhìn có sức ảnh hưởng.",
    "old_id": "070e15aa-58a6-5acc-990c-55045225471c",
    "new_id": "05419a46-cc7e-508e-a832-679e8aed9f15"
  },
  {
    "prompt": "Choose the sentence that demonstrates a logical progression from premise to conclusion.",
    "choices": [
      "Since renewable energy is cheaper, we must ban all fossil fuels immediately regardless of economic fallout.",
      "Unless we see economic fallout, we should conclude that solar energy is the only way to save the planet.",
      "Given that solar energy costs have plummeted, investing in solar infrastructure is a financially prudent strategy for the city."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu này thể hiện cấu trúc lập luận logic từ dữ liệu chi phí đến kết luận chiến lược.",
    "old_id": "5d60283d-215f-5565-ad47-92edcdd53ccf",
    "new_id": "12f3b7b8-f023-5975-a308-5a3cfb0baeb7"
  },
  {
    "prompt": "Select the correct transition to strengthen an argument by adding weight to a prior point.",
    "choices": [
      "The policy is flawed; furthermore, it fails to address the needs of the community entirely.",
      "The policy is flawed; nevertheless, it fails to address the needs of the community entirely.",
      "The policy is flawed; alternatively, it fails to address the needs of the community entirely."
    ],
    "correct_index": 0,
    "explanation_vi": "Furthermore dùng để thêm ý bổ trợ làm mạnh thêm cho luận điểm đã nêu.",
    "old_id": "b574609a-1bd9-597e-8bdc-c683291c9708",
    "new_id": "9ef09026-fa61-5478-8284-b3017b77b94d"
  },
  {
    "prompt": "Identify the statement that uses a concessive clause to acknowledge an opposing view before pivoting.",
    "choices": [
      "Digital learning offers flexibility because students prefer to learn from home during the pandemic.",
      "Digital learning offers flexibility, so it should replace the physical classroom to save costs.",
      "Although digital learning offers flexibility, it cannot fully replace the interpersonal benefits of a physical classroom."
    ],
    "correct_index": 2,
    "explanation_vi": "Mệnh đề ''Although'' giúp thừa nhận ý kiến trái chiều trước khi đưa ra luận điểm chính.",
    "old_id": "f7981bf5-96d7-5fc1-b1c3-b865feea495d",
    "new_id": "6559f522-c74c-594e-9d48-41b05e4c9fbd"
  },
  {
    "prompt": "Person A: ''I believe we should increase the minimum wage to boost local spending.'' Person B: ''________, but we must consider the potential rise in operational costs for small businesses.''",
    "choices": [
      "That is a valid point",
      "I absolutely disagree",
      "That is a fair assessment"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm ''That is a valid point'' là cách lịch sự để thừa nhận quan điểm trước khi đưa ra phản biện.",
    "old_id": "645ff54c-5db9-5077-9707-e1dfe62995d4",
    "new_id": "e282054f-1188-5711-9a90-8479791f59bc"
  },
  {
    "prompt": "Person A: ''The statistics prove that remote work increases productivity.'' Person B: ''________, recent studies show that social isolation can actually lower long-term output.''",
    "choices": [
      "I see your perspective",
      "On the contrary",
      "That makes sense"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm ''On the contrary'' dùng để giới thiệu thông tin trái ngược với ý kiến vừa đưa ra.",
    "old_id": "bf6d4b54-dc9a-5507-96c1-f8bc15f82ab2",
    "new_id": "0959ce0f-5beb-510c-9745-96745cccf83a"
  },
  {
    "prompt": "Person A: ''Should we prioritize environmental regulations over industrial expansion?'' Person B: ''It is a complex trade-off, but ________ long-term sustainability is essential for survival.''",
    "choices": [
      "I am not interested",
      "I tend to think that",
      "I refuse to believe"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm ''I tend to think that'' giúp bày tỏ quan điểm cá nhân một cách chừng mực trong tranh luận.",
    "old_id": "8d3729c5-02f7-5039-8216-abf3a659ff24",
    "new_id": "4bb2e681-4b2f-5de0-8aa9-cadf22c55aca"
  },
  {
    "prompt": "Which element is most essential when constructing a persuasive argument for a skeptical audience?",
    "choices": [
      "A highly emotional tone that discourages questioning.",
      "A long list of personal anecdotes without external validation.",
      "Data-driven evidence that addresses potential counter-arguments."
    ],
    "correct_index": 2,
    "explanation_vi": "Việc dùng dữ liệu và phản hồi các ý kiến trái chiều là cách thuyết phục người nghe đa nghi tốt nhất.",
    "old_id": "29f72aeb-fd4b-535b-9fbd-b28adf5fb497",
    "new_id": "077ff98b-4ba9-5517-a98e-2b169a5f15f2"
  },
  {
    "prompt": "How does a speaker maintain credibility during a heated debate?",
    "choices": [
      "By addressing opposing points with respect and logical analysis.",
      "By avoiding the mention of weaknesses in their own argument.",
      "By consistently using complex jargon to overwhelm the opponent."
    ],
    "correct_index": 0,
    "explanation_vi": "Sự tôn trọng và phân tích logic giúp duy trì uy tín của người tranh luận.",
    "old_id": "b24b091b-6310-595b-beba-c9e6c65009d0",
    "new_id": "29ec2dce-8f89-5e1c-a589-a02c2ca80d43"
  },
  {
    "prompt": "What is the primary function of a rebuttal in a formal debate?",
    "choices": [
      "To identify and weaken the logic of the opposing side''s claims.",
      "To summarize the speaker''s own opening statement.",
      "To dismiss the opponent''s right to speak on the topic."
    ],
    "correct_index": 0,
    "explanation_vi": "Mục đích của phản biện là chỉ ra lỗ hổng logic trong lập luận của đối phương.",
    "old_id": "3dc63f65-1078-59e8-948b-4dd8e2f4e3cd",
    "new_id": "ebe179c4-bf08-55f2-bd77-aa37b46cf69a"
  },
  {
    "prompt": "When is it most appropriate to use a concession in a persuasive speech?",
    "choices": [
      "When you need to build trust by validating a minor truth in the opposition''s argument.",
      "When you are running out of time and need to finish the speech quickly.",
      "When you want to show your argument is flawless."
    ],
    "correct_index": 0,
    "explanation_vi": "Thừa nhận một sự thật nhỏ ở phe đối lập giúp tăng độ tin cậy của bài nói.",
    "old_id": "aa9180d4-f29c-545b-876b-b9b8aa2e24f1",
    "new_id": "04b674db-b53b-5d46-ad71-42ae756ae2b7"
  },
  {
    "prompt": "Which strategy describes an effective ''pathos'' appeal in a debate?",
    "choices": [
      "Listing the mathematical probability of a policy failing next year.",
      "Using a poignant story that illustrates the real-world impact of a policy.",
      "Referencing the historical credentials of the person who proposed the idea."
    ],
    "correct_index": 1,
    "explanation_vi": "Pathos là yếu tố cảm xúc, thường được thể hiện qua các câu chuyện có tính tác động cao.",
    "old_id": "838a9bdd-2aec-51df-8f69-1ed08d130803",
    "new_id": "66a61ee6-4056-5556-911f-fe99fe566d84"
  },
  {
    "prompt": "If a speaker says, ''While I respect the budget constraints mentioned, we cannot ignore the human cost,'' what are they doing?",
    "choices": [
      "They are ending the debate because they cannot find a solution.",
      "They are shifting the topic to avoid discussing the budget entirely.",
      "They are conceding to the opponent''s logic but prioritizing their own values."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu này thể hiện sự thừa nhận (concede) một ý kiến đối lập trước khi nêu lên quan điểm chính.",
    "old_id": "4e0a074c-b5e6-511d-abb1-ef0f3b5ec3bf",
    "new_id": "72607228-ad4f-52f9-984b-f5f0e5d96c11"
  },
  {
    "prompt": "Before diving into the detailed data analysis, the speaker provided a high-level ________ of the company''s quarterly performance.",
    "choices": [
      "overview",
      "takeaway",
      "transition"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''overview'' phù hợp nhất để chỉ một cái nhìn tổng quan trước khi đi sâu vào chi tiết.",
    "old_id": "db3c2bf8-e61d-5ff0-8d0b-ae346c3b0e0a",
    "new_id": "41d8e1c0-7449-505d-b3a1-7f5da494006c"
  },
  {
    "prompt": "After discussing the budget cuts, we need a smooth ________ to the next section regarding our new marketing strategies.",
    "choices": [
      "takeaway",
      "overview",
      "transition"
    ],
    "correct_index": 2,
    "explanation_vi": "''Transition'' là từ chính xác để chỉ sự chuyển tiếp mượt mà giữa hai phần của bài thuyết trình.",
    "old_id": "2130c9f7-00ad-5f6a-87db-7bf047fc5a21",
    "new_id": "105e4e87-09ed-5c20-9a05-226119b4d170"
  },
  {
    "prompt": "If you remember only one thing from today''s meeting, let the main ________ be that customer satisfaction is our top priority.",
    "choices": [
      "overview",
      "transition",
      "takeaway"
    ],
    "correct_index": 2,
    "explanation_vi": "''Takeaway'' được dùng để chỉ điểm mấu chốt hoặc thông điệp quan trọng nhất cần ghi nhớ.",
    "old_id": "02187804-1fc8-576c-b341-f14337f8008b",
    "new_id": "19ef04d3-955f-5ff7-8679-6e923a0f7791"
  },
  {
    "prompt": "________, I''d like to thank everyone for joining us this morning.",
    "choices": [
      "To start with",
      "To being with",
      "To starting with"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm từ ''To start with'' là cách dùng đúng để bắt đầu một bài nói.",
    "old_id": "c2ce03cd-9b90-53e1-b987-b884cedce925",
    "new_id": "b848fe15-8c59-5854-b060-d29318023497"
  },
  {
    "prompt": "Now that we''ve covered the obstacles, ________ move on to the proposed solutions.",
    "choices": [
      "let us be",
      "let''s",
      "let us to"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''let''s'' (viết tắt của let us) theo sau bởi động từ nguyên mẫu là cách dùng chuẩn để chuyển ý.",
    "old_id": "5a5af96d-4007-5b59-be9c-74c0f6603cd2",
    "new_id": "626b95d1-31c5-54ff-a7ac-85d855f23aa3"
  },
  {
    "prompt": "________ to the final point, we must consider the environmental impact of this project.",
    "choices": [
      "Turned",
      "Turn",
      "Turning"
    ],
    "correct_index": 2,
    "explanation_vi": "Dạng V-ing ''Turning'' được dùng trong cụm từ ''Turning to...'' để giới thiệu một ý mới.",
    "old_id": "5734cf4e-1c2b-5576-bd12-d63c1e9ee749",
    "new_id": "7767f421-de01-553c-a2f8-dfca37b9c451"
  },
  {
    "prompt": "Presenter A: ''Our production costs have risen significantly.'' Presenter B: ''________, are we planning to adjust our retail pricing to maintain margins?''",
    "choices": [
      "In light of this",
      "In view to this",
      "In light to this"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm từ ''In light of this'' là cách diễn đạt đúng để kết nối hệ quả của thông tin vừa nêu.",
    "old_id": "efe99e9a-6891-5ea3-a07e-dc82221df9ef",
    "new_id": "75708b68-d634-590c-a41d-79d0ea12f98f"
  },
  {
    "prompt": "Colleague A: ''Should we include the technical specifications in the slides?'' Colleague B: ''No, let''s keep it simple and ________ for the Q&A session.''",
    "choices": [
      "save them",
      "save those",
      "save that"
    ],
    "correct_index": 0,
    "explanation_vi": "Dùng ''them'' để thay thế cho danh từ số nhiều ''specifications'' đã nhắc đến trước đó.",
    "old_id": "a96a64d5-4ac8-5493-8782-9520fa381e5e",
    "new_id": "02a92e9e-a889-5314-9ecc-fcb33e89f39d"
  },
  {
    "prompt": "Speaker: ''We have analyzed the current market trends.'' Audience member: ''________, how do these trends affect our local competitors?''",
    "choices": [
      "Touching on that",
      "By the way",
      "Looking on that"
    ],
    "correct_index": 0,
    "explanation_vi": "''Touching on that'' là cụm từ lịch sự để yêu cầu làm rõ thêm một ý vừa được đề cập.",
    "old_id": "02890fc3-e968-5e18-bdb5-fc2da0a4ceb3",
    "new_id": "b01f9394-35a5-55c8-beae-1f73ee3863f3"
  },
  {
    "prompt": "Which phrase is most effective for signaling the end of a specific section in a formal presentation?",
    "choices": [
      "That finishes for now",
      "That is all for here",
      "That''s all for now"
    ],
    "correct_index": 2,
    "explanation_vi": "''That''s all for now'' là cách diễn đạt tự nhiên và chuẩn mực nhất để kết thúc một phần.",
    "old_id": "74489be2-8919-5059-9db7-ee09d1c87f06",
    "new_id": "da3be72c-a50d-5ef9-abbb-35418c5bc52b"
  },
  {
    "prompt": "Which signposting language is best used to elaborate on a point previously made?",
    "choices": [
      "In another words",
      "In other words",
      "In different words"
    ],
    "correct_index": 1,
    "explanation_vi": "''In other words'' là cụm từ cố định chuẩn xác để diễn giải lại một ý.",
    "old_id": "461d09c0-2b4e-526b-b214-deee52aeb4e4",
    "new_id": "f0e4c425-bf17-5a2b-a4bc-b0c4d505c212"
  },
  {
    "prompt": "When a presenter says ''I''d like to draw your attention to...'', they are typically ________.",
    "choices": [
      "ending the presentation",
      "introducing a new visual or fact",
      "summarizing the entire talk"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ này được dùng để hướng sự tập trung của khán giả vào một chi tiết cụ thể.",
    "old_id": "586aa216-439e-5159-83ed-adc9a0a05543",
    "new_id": "fd041217-42b3-5e66-b824-3563917b118c"
  },
  {
    "prompt": "If a speaker wants to indicate a contrast with a previous point, which connector is most appropriate?",
    "choices": [
      "Having said so",
      "Having said this",
      "Having said that"
    ],
    "correct_index": 2,
    "explanation_vi": "''Having said that'' là cấu trúc dùng để đưa ra ý kiến ngược lại hoặc bổ sung sau một mệnh đề trước đó.",
    "old_id": "3b40e72a-de79-53c0-bdd8-2b07e87454af",
    "new_id": "9085db57-c47f-5e7c-ada8-79ac7651e0ea"
  },
  {
    "prompt": "What is the primary function of a ''roadmap'' slide at the beginning of a presentation?",
    "choices": [
      "To list every takeaway",
      "To provide an overview",
      "To detail the conclusion"
    ],
    "correct_index": 1,
    "explanation_vi": "Roadmap giúp khán giả hình dung lộ trình và cấu trúc tổng quan của bài thuyết trình.",
    "old_id": "c6d2b13d-1aec-5843-b18d-c053aa59c246",
    "new_id": "8e36cd40-fa27-58c0-a676-4178786f05dc"
  },
  {
    "prompt": "Which option is the most professional way to handle a question you cannot answer immediately?",
    "choices": [
      "I don''t have the takeaway.",
      "I''ll get back to you on that.",
      "I''ll transition that later."
    ],
    "correct_index": 1,
    "explanation_vi": "Câu ''I''ll get back to you on that'' là cách phản hồi chuyên nghiệp khi cần kiểm tra thông tin.",
    "old_id": "c3341dc4-2279-535a-8805-9b86385d48e7",
    "new_id": "843c472f-13e9-5c42-be0f-9ecaacb2f7f9"
  },
  {
    "prompt": "The editorial is filled with such extreme bias that it is impossible to view the author as a neutral observer of the political landscape.",
    "choices": [
      "a strong personal inclination",
      "a deliberate attempt to lie",
      "a lack of strong evidence"
    ],
    "correct_index": 0,
    "explanation_vi": "Bias trong ngữ cảnh này ám chỉ sự thiên vị hoặc khuynh hướng cá nhân thay vì là sự khách quan.",
    "old_id": "a6c52854-3eb6-5ecb-b2e6-b6bc088c52eb",
    "new_id": "7edd81be-5d65-5037-99ac-418068651467"
  },
  {
    "prompt": "Before citing this study in your final paper, you must evaluate the credibility of the sources cited by the researchers.",
    "choices": [
      "the accuracy and reliability",
      "the length and formatting",
      "the popularity and reach"
    ],
    "correct_index": 0,
    "explanation_vi": "Credibility liên quan đến tính đáng tin cậy và chính xác của một nguồn thông tin.",
    "old_id": "9e9775fe-1630-5988-a804-77d780a734df",
    "new_id": "3fe840c9-c97c-5907-9ac2-5140bf95317e"
  },
  {
    "prompt": "While the article does not state the decline explicitly, the data allows us to make a logical inference about the company''s financial future.",
    "choices": [
      "a direct factual observation",
      "a wild speculative guess",
      "a reasonable conclusion drawn"
    ],
    "correct_index": 2,
    "explanation_vi": "Inference là quá trình rút ra kết luận dựa trên thông tin có sẵn và logic.",
    "old_id": "956fd099-4f53-5c3e-bdd0-14a1a33504eb",
    "new_id": "bee16e88-0ca4-57d7-9237-cc04d1b21d7d"
  },
  {
    "prompt": "The reporter''s decision to describe the protest as ''a chaotic riot'' rather than ''a peaceful demonstration'' is a clear example of _____ language.",
    "choices": [
      "objective",
      "technical",
      "evaluative"
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng các tính từ mang tính phán xét để mô tả sự việc là đặc điểm của ngôn ngữ đánh giá.",
    "old_id": "2397da90-61a9-5be6-80eb-4321fe6e8cbf",
    "new_id": "fef8af3f-8668-5231-98dc-6236c69b2609"
  },
  {
    "prompt": "Readers should be wary of articles that _____ use emotive adjectives to manipulate their emotional response to the topic.",
    "choices": [
      "deliberation",
      "deliberately",
      "deliberate"
    ],
    "correct_index": 1,
    "explanation_vi": "Trạng từ ''deliberately'' được dùng để bổ nghĩa cho động từ ''use''.",
    "old_id": "e67e9b19-d18f-51f0-b759-a6d0874d1a4e",
    "new_id": "93854a7d-a5ff-59e0-b8aa-71c567685f55"
  },
  {
    "prompt": "By choosing to emphasize the negative outcomes, the author _____ a specific perspective that favors his own agenda.",
    "choices": [
      "promote",
      "is promoting",
      "promoted"
    ],
    "correct_index": 1,
    "explanation_vi": "Thì hiện tại tiếp diễn được sử dụng để mô tả một hành động đang diễn ra xuyên suốt trong bài viết.",
    "old_id": "97c07fc5-40e0-505c-9e32-851c220c41d7",
    "new_id": "0a0b6ef4-eb66-5499-a523-922a27556205"
  },
  {
    "prompt": "Person A: ''Why are you so skeptical about this report?'' Person B: ''_____ The methodology seems completely flawed to me.''",
    "choices": [
      "The evidence is simply not credible.",
      "I find the data quite compelling.",
      "It is written in a very neutral tone."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời của B phải giải thích lý do tại sao họ hoài nghi về báo cáo.",
    "old_id": "d0d91a5e-a8d3-5c16-94ea-a697926b13c4",
    "new_id": "8d136307-b27f-52ba-9c5b-7c1aa064340b"
  },
  {
    "prompt": "Person A: ''Do you think this author is being objective?'' Person B: ''_____ He clearly favors one side through his choice of loaded words.''",
    "choices": [
      "Perhaps. It depends on the reader.",
      "Absolutely. He is very fair.",
      "Hardly. His bias is obvious."
    ],
    "correct_index": 2,
    "explanation_vi": "Người B đồng ý rằng tác giả không khách quan nên phải phủ định ý kiến của người A.",
    "old_id": "1326e1c6-bfa3-5fab-ae6a-47f0301b3ea0",
    "new_id": "b5a6d653-a729-515c-9a5a-c3be603e60ab"
  },
  {
    "prompt": "Person A: ''What should we look for to detect bias in a news article?'' Person B: ''_____ Look for words that evoke strong feelings rather than simple facts.''",
    "choices": [
      "Check the length of the paragraph.",
      "Focus on the publication date.",
      "Pay attention to the author''s tone."
    ],
    "correct_index": 2,
    "explanation_vi": "Giọng văn chứa các từ gợi cảm xúc mạnh là dấu hiệu của sự thiên vị.",
    "old_id": "82fc0e14-24af-5b1a-844e-eeb3a8c7bc02",
    "new_id": "b17fb991-0219-509f-9d18-27ba5c2df0dd"
  },
  {
    "prompt": "Which of these is the most effective way to identify hidden bias in a persuasive essay?",
    "choices": [
      "Reading only the concluding paragraph.",
      "Comparing the claims with diverse, reputable sources.",
      "Counting the total number of sentences used."
    ],
    "correct_index": 1,
    "explanation_vi": "Đối chiếu với các nguồn uy tín khác giúp xác định tính khách quan của thông tin.",
    "old_id": "77bfe5bc-641d-5bf7-be5a-4399d4f59e07",
    "new_id": "c853c3c7-9cfe-52cf-b7ef-b49b2a2f1003"
  },
  {
    "prompt": "What does it mean to ''read critically'' in an academic context?",
    "choices": [
      "Analyzing the text for logic, evidence, and intent.",
      "Accepting all information provided as fact.",
      "Memorizing the main arguments for a test."
    ],
    "correct_index": 0,
    "explanation_vi": "Đọc phản biện đòi hỏi việc phân tích sâu sắc về logic, bằng chứng và mục đích của văn bản.",
    "old_id": "f72350d2-defb-55c8-bc3d-c7fa0132ee4a",
    "new_id": "c695fef7-c0e0-5d8b-bb47-b129cc1b3bef"
  },
  {
    "prompt": "Why is it important to recognize evaluative language when reading news?",
    "choices": [
      "To improve your own vocabulary for creative writing tasks.",
      "To help you summarize the article in fewer words.",
      "To distinguish between established facts and the author''s opinion."
    ],
    "correct_index": 2,
    "explanation_vi": "Ngôn ngữ đánh giá thường là công cụ để người viết lồng ghép quan điểm cá nhân thay vì thông tin khách quan.",
    "old_id": "ab827f41-2a84-541d-b940-8b42a9a78ca2",
    "new_id": "be87e4a7-990b-5ef1-92eb-41dba5dc5beb"
  },
  {
    "prompt": "If a source has low credibility, how should a researcher handle the information?",
    "choices": [
      "Discard it or find corroborating evidence.",
      "Rewrite the content to make it sound better.",
      "Cite it but add a disclaimer."
    ],
    "correct_index": 0,
    "explanation_vi": "Nếu nguồn tin không đáng tin cậy, cách an toàn nhất là bỏ qua hoặc tìm bằng chứng xác thực khác.",
    "old_id": "5800409d-ca38-5a66-9b1e-05a481dd3bf8",
    "new_id": "52f5f01a-2066-5c86-a23c-7354b02f8f20"
  },
  {
    "prompt": "Which action constitutes a logical inference based on the statement: ''The store has been empty every time I walked by this week.''?",
    "choices": [
      "The store only opens for one hour a day.",
      "The store may be experiencing very low foot traffic.",
      "The store is definitely going out of business."
    ],
    "correct_index": 1,
    "explanation_vi": "Suy luận logic là đưa ra khả năng hợp lý nhất dựa trên dữ liệu quan sát được.",
    "old_id": "0033fc10-aa0c-59fc-8f30-6dddb8ab0d4d",
    "new_id": "a6f534fe-18e6-5136-86bd-73d0072ffc26"
  },
  {
    "prompt": "Which of the following phrases represents the most evaluative tone?",
    "choices": [
      "The senator summarized his points in three sections.",
      "The senator delivered a tedious and repetitive speech.",
      "The senator spoke for three hours."
    ],
    "correct_index": 1,
    "explanation_vi": "Các từ ''tedious'' và ''repetitive'' mang tính chất phán xét cá nhân, không phải là dữ liệu khách quan.",
    "old_id": "071b4df6-40d7-5c63-b8c4-442169113190",
    "new_id": "f40ba874-948e-55e4-b24b-79cc76c2add1"
  },
  {
    "prompt": "After reviewing the various reports, the analyst managed to ________ the findings into a single, cohesive strategic plan.",
    "choices": [
      "demonstrate",
      "nevertheless",
      "synthesize"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''synthesize'' có nghĩa là tổng hợp các phần rời rạc thành một chỉnh thể, phù hợp với ngữ cảnh tạo ra một kế hoạch chiến lược từ nhiều báo cáo.",
    "old_id": "1b83fbee-755d-59d9-a43f-be78a8dfbbba",
    "new_id": "fc1ab2b8-7907-5c8e-b571-a6f508cfba6f"
  },
  {
    "prompt": "The candidate sought to ________ their technical proficiency by highlighting several complex projects completed during their tenure.",
    "choices": [
      "demonstrate",
      "synthesize",
      "nevertheless"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''demonstrate'' có nghĩa là chứng minh hoặc thể hiện năng lực thông qua các ví dụ thực tế.",
    "old_id": "41d2ae4c-aa30-5e29-b93a-b9a00c6aee7f",
    "new_id": "521ae070-8b9f-53cd-9e98-83adda51cf3a"
  },
  {
    "prompt": "The budget was significantly reduced; ________, the project goals remained ambitious and the team was expected to deliver high-quality results.",
    "choices": [
      "demonstrate",
      "synthesize",
      "nevertheless"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ nối ''nevertheless'' được dùng để chỉ sự tương phản bất chấp một điều kiện khó khăn đã nêu trước đó.",
    "old_id": "4d570b0f-c58d-5641-8d8b-b5cada7bb032",
    "new_id": "81539090-67a7-5782-b2ed-0b4d309c2df4"
  },
  {
    "prompt": "Having completed the primary research phase, ________ to begin the drafting of the final manuscript.",
    "choices": [
      "the team was decided",
      "it was decided to",
      "they decided it"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc bị động khách quan ''it was decided to'' phù hợp với phong cách viết học thuật trang trọng.",
    "old_id": "6c2fea09-118e-56b6-a4a7-6a0c3c46222c",
    "new_id": "7c16d770-c102-53d9-9322-445a7a55fd2d"
  },
  {
    "prompt": "Not only did the manager propose a new strategy, ________.",
    "choices": [
      "but she also implemented it effectively",
      "but also did she implement it",
      "and she implemented it as well"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc đảo ngữ ''Not only... but also'' yêu cầu sự đồng nhất về thì và cấu trúc mệnh đề sau đó.",
    "old_id": "0c6397dc-3937-51aa-9117-73f286d06140",
    "new_id": "57eb81f3-c9fe-5a83-8c3b-94384c5a341c"
  },
  {
    "prompt": "Rarely ________ encountered such a well-structured proposal in all my years of professional editing.",
    "choices": [
      "I have",
      "have I",
      "do I"
    ],
    "correct_index": 1,
    "explanation_vi": "Khi câu bắt đầu bằng trạng từ phủ định như ''Rarely'', ta cần đảo trợ động từ lên trước chủ ngữ.",
    "old_id": "46641bf5-219d-5f4f-b133-da060181d3d7",
    "new_id": "5d50ff99-e8ee-5b6e-aa44-879de39db170"
  },
  {
    "prompt": "Manager: ''Do you believe our quarterly projections are too optimistic given the current market volatility?'' Colleague: ''________, I believe they are grounded in a conservative analysis of recent data.''",
    "choices": [
      "In the meantime",
      "For that matter",
      "On the contrary"
    ],
    "correct_index": 2,
    "explanation_vi": "''On the contrary'' là cụm từ nối phù hợp để phản bác lại một nhận định tiêu cực bằng một quan điểm đối lập.",
    "old_id": "d3a2bf21-dfe7-51d5-b437-2a4b7f455dfd",
    "new_id": "66f74acf-fd7e-5cb6-8deb-4151d26221c3"
  },
  {
    "prompt": "Editor: ''Is the concluding paragraph strong enough to summarize your main arguments?'' Author: ''________. I plan to rephrase the final sentence to add more impact.''",
    "choices": [
      "To a certain extent",
      "In accordance with",
      "As a result"
    ],
    "correct_index": 0,
    "explanation_vi": "''To a certain extent'' là cách diễn đạt trang trọng để biểu đạt sự đồng ý có điều kiện hoặc sự thận trọng.",
    "old_id": "8ce8195f-8c9b-5e21-93bf-4b6eac86bec5",
    "new_id": "6fa04a04-e7db-5088-a0c1-b1caea2d5122"
  },
  {
    "prompt": "Peer Reviewer: ''Your methodology is quite innovative; however, is it reproducible?'' Author: ''________, we have included a detailed appendix explaining each step.''",
    "choices": [
      "Indeed",
      "In view of",
      "Despite the fact"
    ],
    "correct_index": 0,
    "explanation_vi": "''Indeed'' được sử dụng để nhấn mạnh và xác nhận lại một thông tin đã được đề cập hoặc đặt câu hỏi trước đó.",
    "old_id": "be7a266f-0f7c-5fc1-8317-c5c392452825",
    "new_id": "161c426c-2e8a-5e7f-b575-22c9b823dc8b"
  },
  {
    "prompt": "The board members ________ the importance of transparency in their latest corporate governance statement.",
    "choices": [
      "demonstrated",
      "synthesized",
      "underscored"
    ],
    "correct_index": 2,
    "explanation_vi": "''Underscored'' mang nghĩa nhấn mạnh tầm quan trọng, phù hợp nhất với ngữ cảnh về thông cáo quản trị.",
    "old_id": "5b6d6a23-eb4a-52f8-926e-fd4e1f0bbb82",
    "new_id": "d188c701-31df-5523-b751-0bfae0968358"
  },
  {
    "prompt": "Success in this role ________ a deep understanding of market trends combined with exceptional analytical skills.",
    "choices": [
      "synthesizes",
      "demonstrates",
      "necessitates"
    ],
    "correct_index": 2,
    "explanation_vi": "''Necessitates'' (đòi hỏi/yêu cầu) là động từ chính xác nhất để nói về các yêu cầu của một vị trí công việc.",
    "old_id": "11b4538e-d7ce-5109-8607-5b2f63d9814e",
    "new_id": "8c6fdff4-cf37-5774-a1a7-7344e8b029a1"
  },
  {
    "prompt": "The author managed to ________ complex academic theories into a reader-friendly format for the general public.",
    "choices": [
      "distill",
      "demonstrate",
      "nevertheless"
    ],
    "correct_index": 0,
    "explanation_vi": "''Distill'' (chắt lọc) phù hợp với ngữ cảnh biến các lý thuyết phức tạp thành nội dung dễ tiếp cận.",
    "old_id": "b655defa-2865-5dba-a4d7-9982216b2070",
    "new_id": "661dccdb-5011-5fa0-8f44-aa9cd81f2860"
  },
  {
    "prompt": "It is essential that every participant ________ the registration form before the deadline expires.",
    "choices": [
      "submitting",
      "submit",
      "submits"
    ],
    "correct_index": 1,
    "explanation_vi": "Sau cấu trúc ''It is essential that'', động từ cần chia ở dạng giả định cách (base form) cho tất cả các ngôi.",
    "old_id": "df62b86f-96ce-598f-9bef-08dc7bb0fbec",
    "new_id": "7eea3b7d-f788-53a9-b7bd-a7b8bbb484a2"
  },
  {
    "prompt": "The findings were unexpected; ________, they provide a valuable insight into consumer behavior during economic downturns.",
    "choices": [
      "consequently",
      "nonetheless",
      "moreover"
    ],
    "correct_index": 1,
    "explanation_vi": "''Nonetheless'' dùng để nối hai ý trái ngược nhau về mặt logic, phù hợp với ngữ cảnh về các phát hiện bất ngờ nhưng hữu ích.",
    "old_id": "c31f17f8-71c5-5320-8384-01669f422cff",
    "new_id": "5e5bcd14-6042-504d-95d6-7127a46ca43f"
  },
  {
    "prompt": "Were the proposal to be approved, ________ to allocate additional resources to the marketing department.",
    "choices": [
      "it is necessary",
      "it would be necessary",
      "it will be necessary"
    ],
    "correct_index": 1,
    "explanation_vi": "Đây là câu điều kiện loại 2 dạng đảo ngữ (''Were...''), vế sau phải sử dụng ''would'' để duy trì sự phù hợp thì.",
    "old_id": "8bd67e6a-9fe7-5f91-bf7f-f4cc2e8e0566",
    "new_id": "b74c4c98-eb9b-5467-9441-20248bcd5010"
  },
  {
    "prompt": "The manager argued that the new policy was necessary, notwithstanding the concerns raised by the staff. What does ''notwithstanding'' mean in this context?",
    "choices": [
      "Despite the existence of",
      "In total agreement with",
      "Because of the impact of"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''notwithstanding'' được sử dụng để thể hiện sự đối lập, tương đương với ''in spite of'' hoặc ''despite''.",
    "old_id": "d49d07bd-7de4-5e9b-b8e3-ac7ee4d7e8d4",
    "new_id": "6959233e-8219-5a66-8b55-05e0d89dbfca"
  },
  {
    "prompt": "To what extent do you agree that remote work has permanently altered the corporate landscape? In this sentence, ''to what extent'' is used to inquire about:",
    "choices": [
      "The primary motivation for actions",
      "The degree or scope of something",
      "The specific time frame of events"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm ''to what extent'' dùng để hỏi về mức độ hoặc phạm vi ảnh hưởng của một sự việc.",
    "old_id": "863bc3f8-f043-58e9-bae9-422442ba12ab",
    "new_id": "30503c99-4800-561c-9165-698262262483"
  },
  {
    "prompt": "While the film received mixed reviews, it is arguably the most visually stunning production of the decade. What is the speaker implying by using ''arguably''?",
    "choices": [
      "That the critics were clearly wrong",
      "That the opinion is open to debate",
      "That the film is objectively superior"
    ],
    "correct_index": 1,
    "explanation_vi": "Trạng từ ''arguably'' ám chỉ rằng một ý kiến có thể tranh luận được và có cơ sở để chứng minh.",
    "old_id": "3f041019-657b-5763-bd99-883fdc65cadc",
    "new_id": "2bdf4613-9a1d-5e64-9bb0-93eb3ee00e0d"
  },
  {
    "prompt": "Not only did they finish the project ahead of schedule, __________ the quality was exceptional.",
    "choices": [
      "but also",
      "furthermore",
      "as well as"
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc đảo ngữ ''not only... but also'' yêu cầu vế thứ hai phải bắt đầu bằng ''but also''.",
    "old_id": "3ea91c3e-be7f-548e-893f-c9d39b9af3a6",
    "new_id": "f5a813ef-8a74-5eab-ada4-93868695dd01"
  },
  {
    "prompt": "Little __________ that the decision would lead to such significant long-term consequences for the company.",
    "choices": [
      "they had known",
      "have they known",
      "did they know"
    ],
    "correct_index": 2,
    "explanation_vi": "Đảo ngữ với các trạng từ mang nghĩa phủ định (Little) đòi hỏi trợ động từ đứng trước chủ ngữ.",
    "old_id": "2a581ed4-4e11-543c-9b34-03e20bde0487",
    "new_id": "afedae49-a489-58c7-abc2-63b128fed7f7"
  },
  {
    "prompt": "__________ had the meeting started when the fire alarm began to ring loudly.",
    "choices": [
      "Not once",
      "Hardly",
      "No sooner"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc ''No sooner... than'' thường được dùng để diễn tả sự việc xảy ra ngay sau sự việc khác.",
    "old_id": "be80b9e2-0af7-5c91-82be-4ff2acbcb16e",
    "new_id": "37b3f283-8c72-5fbc-9b49-0ab9a14729fc"
  },
  {
    "prompt": "A: Do you think the new regulations will actually improve safety? B: __________, they might make the process more cumbersome.",
    "choices": [
      "To a great extent",
      "In light of this",
      "To be perfectly honest"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ này giúp người nói nhấn mạnh ý kiến cá nhân khi đưa ra một góc nhìn phản biện.",
    "old_id": "2bbfacfe-2091-5830-aa68-2ec5a1df2462",
    "new_id": "9a53c253-2a81-5b2d-8d56-77fde9974dd5"
  },
  {
    "prompt": "A: The team has faced numerous setbacks this quarter. B: True, __________, they have remained focused on their primary objectives.",
    "choices": [
      "arguably",
      "notwithstanding",
      "nevertheless"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ nối ''nevertheless'' được dùng để diễn tả sự tương phản sau một mệnh đề thừa nhận khó khăn.",
    "old_id": "be5d3813-facc-5fe4-ac26-b92189942428",
    "new_id": "ac8143a7-7325-58b9-b663-51b63a189e14"
  },
  {
    "prompt": "A: How far should we push for these changes? B: We need to consider the __________ of the impact on our client base.",
    "choices": [
      "arguably",
      "extent",
      "notwithstanding"
    ],
    "correct_index": 1,
    "explanation_vi": "Danh từ ''extent'' đi với giới từ ''of'' để chỉ mức độ ảnh hưởng của một sự việc.",
    "old_id": "e17730c2-08b6-50d8-a515-315d867f97cc",
    "new_id": "86f85a84-bbf8-5dc6-9c40-1102d60aaf7a"
  },
  {
    "prompt": "Under no circumstances __________ to enter the laboratory without proper protective equipment.",
    "choices": [
      "students are allowed",
      "should students allow",
      "are students allowed"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ phủ định ''Under no circumstances'' yêu cầu đảo ngữ (động từ trước chủ ngữ).",
    "old_id": "61451518-0c5c-5816-a801-d251740d8358",
    "new_id": "182f2e1b-e3df-50f3-a5dd-e510096dd9f7"
  },
  {
    "prompt": "The proposal was accepted, __________ the fact that the budget was already over-stretched.",
    "choices": [
      "notwithstanding",
      "to the extent",
      "arguably"
    ],
    "correct_index": 0,
    "explanation_vi": "Giới từ ''notwithstanding'' phù hợp để nối mệnh đề với cụm danh từ ''the fact that''.",
    "old_id": "80d36f0c-bc06-5eec-bdc9-1687e58e4c6b",
    "new_id": "cf65484b-ee5c-5335-baad-6e02e3f0086d"
  },
  {
    "prompt": "Rarely __________ such a high level of dedication from a junior department.",
    "choices": [
      "have we seen",
      "we have seen",
      "we did see"
    ],
    "correct_index": 0,
    "explanation_vi": "Trạng từ chỉ tần suất mang nghĩa phủ định ''Rarely'' đứng đầu câu bắt buộc phải đảo ngữ.",
    "old_id": "0fbfee3d-ef97-5ea3-b89c-2c9000252724",
    "new_id": "2e205c19-2c2c-59bc-a5e0-e7d0ce37f895"
  },
  {
    "prompt": "It is __________ one of the most innovative startups to emerge in the sector this year.",
    "choices": [
      "extent",
      "arguably",
      "notwithstanding"
    ],
    "correct_index": 1,
    "explanation_vi": "Trạng từ ''arguably'' bổ nghĩa cho tính từ và thường đứng trước cụm danh từ/tính từ trong ngữ cảnh này.",
    "old_id": "8a29d4c8-1708-54c1-9534-0f57b6df1bed",
    "new_id": "df28ef4c-0c98-5677-8496-891a5fb151e0"
  },
  {
    "prompt": "Only by working together __________ to solve this complex logistical challenge.",
    "choices": [
      "will we be able",
      "we will be able",
      "are we able"
    ],
    "correct_index": 0,
    "explanation_vi": "Mệnh đề bắt đầu bằng ''Only by...'' đòi hỏi đảo ngữ ở vế chính của câu.",
    "old_id": "c66ae49c-725d-57e2-ad1c-355f65f7c4cd",
    "new_id": "3b0a1fac-29b6-5006-9991-4b3a44c19df4"
  },
  {
    "prompt": "The report was detailed, __________ it failed to address the core issue of sustainability.",
    "choices": [
      "to the extent",
      "nevertheless",
      "notwithstanding"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ nối ''nevertheless'' được dùng để thể hiện sự tương phản giữa hai mệnh đề độc lập.",
    "old_id": "76d7adb1-6f07-5139-b9c5-6228bdf3085d",
    "new_id": "347a49b9-eb86-5de1-bd96-4c5e7d8ca2f2"
  },
  {
    "prompt": "After reading the article and listening to the lecture, the student was able to ________ the findings from both media into a cohesive summary.",
    "choices": [
      "compare",
      "synthesize",
      "source"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''synthesize'' có nghĩa là tổng hợp thông tin từ nhiều nguồn để tạo ra một nội dung thống nhất.",
    "old_id": "94f59a17-ba39-59d6-968b-a20343dddb11",
    "new_id": "2604b195-4ff2-57ae-8020-50e960fbda1d"
  },
  {
    "prompt": "When preparing for the debate, you must ________ the author''s opinion in the essay with the expert''s testimony from the interview to find common ground.",
    "choices": [
      "source",
      "compare",
      "synthesize"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''compare'' phù hợp nhất để chỉ hành động đối chiếu ý kiến giữa văn bản và bài phỏng vấn.",
    "old_id": "48be075d-192a-5d2f-bbb6-26be32fa39c6",
    "new_id": "90fbedf4-bd15-51e5-96fd-7269deb79bdf"
  },
  {
    "prompt": "Always verify the ________ of your information by checking if the data provided in the podcast matches the credentials listed on the official website.",
    "choices": [
      "compare",
      "synthesize",
      "source"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''source'' (nguồn gốc/độ tin cậy của nguồn) là lựa chọn chính xác khi đề cập đến việc kiểm chứng thông tin.",
    "old_id": "7d6a618c-d739-5c37-b114-24147673f373",
    "new_id": "c18223c5-5220-57d3-a31d-f8cda77b68e9"
  },
  {
    "prompt": "Select the sentence that correctly uses cross-source synthesis to connect ideas.",
    "choices": [
      "While the article argues for remote work, the lecture implies a similar conclusion by highlighting increased productivity.",
      "The article argues for remote work because the lecture highlights increased productivity.",
      "The article argues for remote work, although the lecture highlights increased productivity."
    ],
    "correct_index": 0,
    "explanation_vi": "Cấu trúc ''While... [main clause]'' thể hiện sự đối chiếu và tổng hợp thông tin từ hai nguồn một cách logic nhất.",
    "old_id": "a2e3a2c0-49ee-55b4-bbb0-5e21f067e982",
    "new_id": "39cc6029-32fc-50aa-9a02-640b76439370"
  },
  {
    "prompt": "Identify the most effective way to integrate information from two differing reports.",
    "choices": [
      "The text focuses on costs, whereas the podcast suggests that the long-term benefits outweigh them.",
      "The text focuses on costs, and the podcast suggests that the long-term benefits outweigh them.",
      "Although the text focuses on costs, the podcast suggests that the long-term benefits outweigh them."
    ],
    "correct_index": 0,
    "explanation_vi": "Từ nối ''whereas'' được dùng để làm nổi bật sự khác biệt giữa hai luồng thông tin một cách chuyên nghiệp.",
    "old_id": "ecaf0c96-b385-5b0c-911e-7a79d67361b1",
    "new_id": "63292f81-4897-5890-9752-1d68a3ebc298"
  },
  {
    "prompt": "Choose the best structure to synthesize concurring points from a textbook and a speech.",
    "choices": [
      "The textbook supports this theory, and the guest speaker provides empirical data.",
      "Not only does the textbook support this theory, but the guest speaker also provides empirical data.",
      "The textbook supports this theory, so the guest speaker provides empirical data."
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''Not only... but also'' là cách diễn đạt trang trọng và hiệu quả để tổng hợp các thông tin bổ trợ cho nhau.",
    "old_id": "ef375506-6b21-557f-9c13-c3a4668aae8b",
    "new_id": "c90fefc5-c5ff-5dc2-80ed-112fd3e62f47"
  },
  {
    "prompt": "Speaker A: ''The professor’s lecture suggests the market will crash, but the report says it’s stable.'' Speaker B: ''________''",
    "choices": [
      "It is important to source the lecture properly.",
      "I will synthesize the two points to find the truth.",
      "I see your point about the conflicting data."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời của Speaker B xác nhận sự mâu thuẫn giữa hai nguồn thông tin đã được nêu ra.",
    "old_id": "b52e9b17-4e0b-53cc-999f-79c7a4253d7b",
    "new_id": "a57cae5b-bcf9-56d4-8cd5-2c723aeb7cbb"
  },
  {
    "prompt": "Speaker A: ''How did you manage to write such a comprehensive essay?'' Speaker B: ''I had to ________.''",
    "choices": [
      "synthesize insights from both the article and the audio clip",
      "compare the lecture to the reading constantly",
      "source the author correctly in every paragraph"
    ],
    "correct_index": 0,
    "explanation_vi": "Việc ''synthesize insights'' là kỹ năng cốt lõi để tạo ra một bài viết tổng hợp sâu sắc.",
    "old_id": "6927db9b-34a9-5cfc-9576-fadde295862c",
    "new_id": "072612c8-3425-5e8f-92bf-f33b436ac6ee"
  },
  {
    "prompt": "Speaker A: ''Do you think the podcast is a reliable source for our research?'' Speaker B: ''________''",
    "choices": [
      "I believe we need to source the interviewees.",
      "It is easy to synthesize the audio information.",
      "We should compare it with the peer-reviewed journal to be sure."
    ],
    "correct_index": 2,
    "explanation_vi": "Việc đối chiếu với một nguồn uy tín (peer-reviewed) là cách kiểm chứng độ tin cậy của thông tin tốt nhất.",
    "old_id": "5264eb38-8d7e-5f58-b9e1-2f570a8d0fc5",
    "new_id": "f3203192-66d4-5786-aa2a-af8dea2b4eeb"
  },
  {
    "prompt": "When analyzing conflicting information from two sources, what is the best first step?",
    "choices": [
      "Discard the information that seems the most complicated.",
      "Choose the source that has the most professional tone.",
      "Identify the specific areas where the sources contradict each other."
    ],
    "correct_index": 2,
    "explanation_vi": "Để tổng hợp thông tin, bước đầu tiên cần làm là xác định các điểm khác biệt hoặc mâu thuẫn giữa các nguồn.",
    "old_id": "90ef3640-6040-5e59-aa47-95e143e6a054",
    "new_id": "0c13b77e-229b-562b-9868-5d1e66dd06cd"
  },
  {
    "prompt": "Why is it important to cite multiple sources when synthesizing information?",
    "choices": [
      "To make the essay longer and meet the word count requirement.",
      "To provide a balanced view and increase the credibility of the argument.",
      "To avoid the effort of writing original conclusions."
    ],
    "correct_index": 1,
    "explanation_vi": "Việc sử dụng nhiều nguồn giúp luận điểm của bạn khách quan và đáng tin cậy hơn.",
    "old_id": "d39763ac-09f8-5b24-a3fb-9796514be2ee",
    "new_id": "35402493-7f66-5cd4-a69b-3c6f624152a1"
  },
  {
    "prompt": "Which of the following describes a synthesis of information?",
    "choices": [
      "Combining ideas from different sources to create a new, broader perspective.",
      "Copying large sections of text directly from the sources.",
      "Summarizing each source separately in different paragraphs."
    ],
    "correct_index": 0,
    "explanation_vi": "Tổng hợp (synthesis) là quá trình kết hợp các ý tưởng riêng lẻ để tạo ra một cái nhìn tổng quát mới.",
    "old_id": "173e279d-1a20-5fa1-8e0c-3c2ae5fcbb52",
    "new_id": "e6dd2d0e-9e46-5969-a4ba-35b993f244b3"
  },
  {
    "prompt": "If an article and a lecture present different data, how should you report this?",
    "choices": [
      "State both findings and note the discrepancy between them.",
      "Ignore the lecture data as it is harder to verify.",
      "Choose the source that supports your personal opinion."
    ],
    "correct_index": 0,
    "explanation_vi": "Cách làm đúng đắn là trình bày cả hai dữ liệu và chỉ ra sự khác biệt để đảm bảo tính minh bạch.",
    "old_id": "cb2290f0-26ec-52a3-a469-8081805e4fec",
    "new_id": "df167f0d-00f6-5fa1-ada0-6d8dbbe3f1b0"
  },
  {
    "prompt": "What does it mean to ''cross-source'' in academic writing?",
    "choices": [
      "Using only the most popular search engines for information.",
      "Comparing or linking information derived from various distinct documents or media.",
      "Translating information from a foreign language source."
    ],
    "correct_index": 1,
    "explanation_vi": "Cross-source là thuật ngữ chỉ việc liên kết hoặc so sánh thông tin từ nhiều nguồn khác nhau.",
    "old_id": "b370f343-2288-5122-b42f-390703948f46",
    "new_id": "491fd590-3d57-5421-8f10-353022def463"
  },
  {
    "prompt": "When asked to synthesize information for a presentation, what should you avoid?",
    "choices": [
      "Including evidence from both the provided reading and the audio lecture.",
      "Creating a clear connection between disparate facts.",
      "Presenting a singular source without mentioning any others."
    ],
    "correct_index": 2,
    "explanation_vi": "Chỉ trình bày một nguồn duy nhất không thể hiện được kỹ năng tổng hợp thông tin từ đa nguồn.",
    "old_id": "4aaab5d7-8d9c-5abf-b37d-af129ea0a1b7",
    "new_id": "1c9a1f60-6a9e-5151-b37e-7e59265c4662"
  },
  {
    "prompt": "The team lead asked me to respond to the client''s complaint. What is the most accurate meaning of ''respond'' in this scenario?",
    "choices": [
      "To provide an answer or reaction to a prompt",
      "To ignore the message until a later date",
      "To forward the email to another department"
    ],
    "correct_index": 0,
    "explanation_vi": "Respond mang nghĩa là phản hồi hoặc trả lời lại một thông tin được đưa ra.",
    "old_id": "8adf0258-3e72-5f53-a53c-082f654c091d",
    "new_id": "4ccae0f5-fca0-5fbe-a6ba-66aa44d008b5"
  },
  {
    "prompt": "During the meeting, the instructions were vague. I needed to clarify them. What did I do?",
    "choices": [
      "I decided to guess the meaning and proceed",
      "I asked questions to ensure I understood the details",
      "I wrote a summary based on my own assumptions"
    ],
    "correct_index": 1,
    "explanation_vi": "Clarify có nghĩa là làm rõ thông tin thông qua việc đặt câu hỏi để tránh hiểu nhầm.",
    "old_id": "03dc8be2-168d-51e1-bd0d-6c0112aced0c",
    "new_id": "da9396ca-7cde-585b-aefb-1f9b759bf80f"
  },
  {
    "prompt": "The project deadline was too tight. I had to negotiate a new timeline with my manager. What does ''negotiate'' imply here?",
    "choices": [
      "I demanded the deadline be canceled",
      "I accepted the deadline without sharing my concerns",
      "I discussed options to reach a mutually acceptable agreement"
    ],
    "correct_index": 2,
    "explanation_vi": "Negotiate mô tả quá trình thảo luận để đạt được thỏa thuận chung giữa các bên.",
    "old_id": "f1f54942-3631-5b33-b5f6-bbbedf064ae1",
    "new_id": "7536f7c9-6a13-57c0-af5e-73ce019957c2"
  },
  {
    "prompt": "Choose the most strategically phrased sentence to soften a disagreement with a colleague.",
    "choices": [
      "You are wrong about the budget calculations.",
      "That is a terrible idea for our current project budget.",
      "I see your point, but perhaps we could look at the budget differently."
    ],
    "correct_index": 2,
    "explanation_vi": "Sử dụng cấu trúc ''I see your point, but'' là cách tiếp cận mang tính chiến lược để bất đồng một cách lịch sự.",
    "old_id": "aee68b43-15d8-5fb0-8def-db9840350210",
    "new_id": "4094b9e1-50be-5995-9812-f5da851a94b3"
  },
  {
    "prompt": "Which sentence demonstrates the best use of conditional language for professional negotiation?",
    "choices": [
      "I might finish if you stop bothering me about it.",
      "If we extend the deadline, I will be able to complete the report properly.",
      "Extend the deadline or I am not finishing the report."
    ],
    "correct_index": 1,
    "explanation_vi": "Câu điều kiện giúp trình bày yêu cầu một cách chuyên nghiệp và có lập luận rõ ràng.",
    "old_id": "4b9813d8-2aa0-5b51-a69d-dc985dc7d2e0",
    "new_id": "b381be30-9117-5493-a017-2dde7278adcb"
  },
  {
    "prompt": "Select the phrase that uses assertive but polite communication during a client meeting.",
    "choices": [
      "I do not know, I guess you should decide what to do.",
      "Maybe we can try to do this if it is not too much trouble.",
      "I am confident that this approach will meet your current goals."
    ],
    "correct_index": 2,
    "explanation_vi": "Việc khẳng định sự tự tin một cách lịch sự thể hiện kỹ năng giao tiếp chiến lược.",
    "old_id": "3c38d5c5-a4c3-5bde-9fca-d9c460e9100c",
    "new_id": "12f101cf-ca30-5bea-9a51-d77b7dc2059e"
  },
  {
    "prompt": "Colleague: ''I don''t think this strategy will work for the launch.'' You: ''__________''",
    "choices": [
      "You are just being negative about my work.",
      "Could you explain which part of the strategy concerns you most?",
      "It works perfectly fine, so please stop complaining."
    ],
    "correct_index": 1,
    "explanation_vi": "Đặt câu hỏi làm rõ là cách phản hồi chuyên nghiệp để giải quyết bất đồng.",
    "old_id": "92f52e23-614c-5755-aba1-eb8b6faea1eb",
    "new_id": "999d638f-6b17-5342-b94b-25b3b3053127"
  },
  {
    "prompt": "Manager: ''We need this project finished by Friday.'' You: ''__________''",
    "choices": [
      "I understand the urgency; could we prioritize the essential tasks to meet that date?",
      "Why do you always give me the hard work?",
      "That is impossible, I am not doing it."
    ],
    "correct_index": 0,
    "explanation_vi": "Đưa ra giải pháp thay vì từ chối thẳng thừng là kỹ năng thương thảo cần thiết.",
    "old_id": "cb4e317d-d99f-5983-a8e1-2d9394cb13fb",
    "new_id": "13f7ca09-080c-5ab8-97d8-ca5700967f0f"
  },
  {
    "prompt": "Client: ''The quality of the final draft is not what we expected.'' You: ''__________''",
    "choices": [
      "I am sorry to hear that; could you highlight the specific areas that need improvement?",
      "You probably just misunderstood the instructions.",
      "Well, you should have told me that earlier."
    ],
    "correct_index": 0,
    "explanation_vi": "Việc cầu thị và yêu cầu thông tin cụ thể giúp duy trì mối quan hệ tốt với khách hàng.",
    "old_id": "92febff4-f366-5bd1-9f59-0e8e5509f279",
    "new_id": "8385269c-6998-5bd7-97ff-324f5fefb255"
  },
  {
    "prompt": "When managing a conflict in a meeting, which strategy is most effective?",
    "choices": [
      "Avoiding the topic entirely until the meeting ends",
      "Focusing on the person''s personality flaws",
      "Finding common ground and objective goals"
    ],
    "correct_index": 2,
    "explanation_vi": "Tập trung vào mục tiêu chung là cách giải quyết mâu thuẫn chuyên nghiệp nhất.",
    "old_id": "99f5a675-279e-5941-aa1c-b987849b8dcc",
    "new_id": "cd2d706c-6cfb-54ba-b12d-f89093547b88"
  },
  {
    "prompt": "Why is ''clarifying'' important in cross-departmental communication?",
    "choices": [
      "It prevents wasting time on tasks based on misunderstandings",
      "It allows you to assert dominance over other teams",
      "It makes the conversation last longer for the report"
    ],
    "correct_index": 0,
    "explanation_vi": "Làm rõ giúp tiết kiệm thời gian và đảm bảo các bên hiểu đúng nhiệm vụ.",
    "old_id": "20e9b4c7-72c7-5305-8cc9-12537f3946bb",
    "new_id": "b044a01a-2f4a-53e1-8c3c-28397a599e67"
  },
  {
    "prompt": "What is the primary goal of strategic communication in a professional scenario?",
    "choices": [
      "To confuse the listener with complex vocabulary",
      "To convey information effectively to achieve a specific result",
      "To talk as much as possible to fill the time"
    ],
    "correct_index": 1,
    "explanation_vi": "Giao tiếp chiến lược tập trung vào việc đạt được kết quả mong muốn thông qua việc truyền đạt hiệu quả.",
    "old_id": "b8aac5f5-3dac-5ecb-bb57-f67f5d950794",
    "new_id": "d1bdf62b-30a5-5339-983f-875e179fb6f3"
  },
  {
    "prompt": "If a negotiation reaches a stalemate, what should be your next move?",
    "choices": [
      "Leave the room and refuse to speak further",
      "Suggest a break or explore alternative compromises",
      "Insist on your original terms without change"
    ],
    "correct_index": 1,
    "explanation_vi": "Việc tạm nghỉ hoặc tìm kiếm phương án thay thế giúp tháo gỡ bế tắc trong thương lượng.",
    "old_id": "16906f96-4a4c-5a9c-9853-f1118cc76362",
    "new_id": "265a849d-df13-5051-8a50-cc181278ebb2"
  },
  {
    "prompt": "How can you show active listening while someone is explaining their point?",
    "choices": [
      "Interrupting frequently to share your opinion",
      "Looking at your phone until they finish talking",
      "Using verbal cues like ''I see'' or ''Go on'' to encourage them"
    ],
    "correct_index": 2,
    "explanation_vi": "Các tín hiệu phản hồi bằng lời nói cho thấy bạn đang thực sự lắng nghe đối phương.",
    "old_id": "931735d5-6b53-5df7-ae95-e940d4a28c2a",
    "new_id": "91d8d047-73d0-5e22-9966-d0f05240a41b"
  },
  {
    "prompt": "When responding to feedback, what is the best approach?",
    "choices": [
      "Listen, thank the person, and ask for specific examples",
      "Defend your work immediately without listening",
      "Agree with everything without evaluating the input"
    ],
    "correct_index": 0,
    "explanation_vi": "Tiếp nhận phản hồi một cách cởi mở và cầu tiến là dấu hiệu của sự chuyên nghiệp.",
    "old_id": "2f240b14-23c3-5434-a3a1-1be6ec210ddd",
    "new_id": "90f9fc14-08c7-5fd3-8371-66266e8ff0fb"
  },
  {
    "prompt": "Before submitting the final version, the author spent hours creating a rough ________ to organize the main ideas and structural flow.",
    "choices": [
      "revise",
      "audience",
      "draft"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''draft'' (bản thảo) phù hợp nhất với ngữ cảnh chuẩn bị một phiên bản sơ bộ trước khi hoàn thiện.",
    "old_id": "7e4db4de-9da3-5784-9c6d-db3c23118ee1",
    "new_id": "c1705865-59e6-5b2c-a496-9c76bc2c1453"
  },
  {
    "prompt": "When preparing the technical report, the team had to consider their target ________ to ensure the language used was appropriate for their level of expertise.",
    "choices": [
      "revise",
      "draft",
      "audience"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''audience'' (độc giả/khán giả) là đối tượng mà người viết cần cân nhắc để chọn ngôn ngữ phù hợp.",
    "old_id": "827446ef-e664-5a74-b18a-0d77675c47d2",
    "new_id": "d95e7bfc-2d68-5a5f-b034-b1ac8b894c6c"
  },
  {
    "prompt": "It is essential to ________ your paper after receiving feedback to correct logical errors and improve clarity.",
    "choices": [
      "revise",
      "audience",
      "draft"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''revise'' (chỉnh sửa) mô tả hành động cải thiện bài viết sau khi nhận phản hồi.",
    "old_id": "77ca57df-44ef-5d3c-ac29-a0a7f1eb99ec",
    "new_id": "0b155442-d013-576f-94cd-acc0a428d036"
  },
  {
    "prompt": "The editor asked me to ________ my thesis statement because it was too broad to be supported by the evidence in the following paragraphs.",
    "choices": [
      "tightening",
      "tighten",
      "have tightened"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc ''ask someone to do something'' yêu cầu động từ nguyên thể (tighten) đi sau tân ngữ.",
    "old_id": "7b7ae929-f0ba-580e-adfc-e5b23c84611b",
    "new_id": "91653c8b-d66b-558b-9518-ff3551513bcb"
  },
  {
    "prompt": "By the time we ________ the outline tomorrow, we will have a clearer picture of how to structure the entire project.",
    "choices": [
      "are finishing",
      "finish",
      "will finish"
    ],
    "correct_index": 1,
    "explanation_vi": "Trong mệnh đề trạng ngữ chỉ thời gian với ''by the time'', ta dùng thì hiện tại đơn để diễn tả tương lai.",
    "old_id": "d235a114-95f1-5526-a48e-142b9a4e726f",
    "new_id": "8598dad9-d2bb-534c-9060-79737d935442"
  },
  {
    "prompt": "Having ________ the draft twice, she felt confident that the arguments were presented logically and effectively.",
    "choices": [
      "review",
      "to review",
      "reviewed"
    ],
    "correct_index": 2,
    "explanation_vi": "Cấu trúc phân từ hoàn thành ''Having + V3/ed'' được dùng để diễn tả hành động đã hoàn tất trước một hành động khác.",
    "old_id": "4bb247d2-024b-5972-a5cb-add4cefb9f6f",
    "new_id": "64b1599f-5c92-5db9-872d-cee403f36cac"
  },
  {
    "prompt": "A: Why did you decide to change the tone of the introduction? B: ________.",
    "choices": [
      "I want to make sure it matches the academic expectations of my audience.",
      "It is important to revise the documents before the deadline ends.",
      "The draft is already printed and ready for the final presentation."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời trực tiếp giải thích lý do thay đổi tông giọng dựa trên đối tượng đọc giả (audience).",
    "old_id": "4a4f687a-9422-53a9-85c9-1360242a1389",
    "new_id": "d782cabe-91d2-589c-855c-e6d88526a6ee"
  },
  {
    "prompt": "A: Is the current draft ready for the final submission? B: ________.",
    "choices": [
      "The audience expects a very detailed and long-winded explanation.",
      "Writing a project requires a lot of careful planning and brainstorming.",
      "I have already revised the grammar and checked the formatting."
    ],
    "correct_index": 2,
    "explanation_vi": "Câu trả lời khẳng định việc đã hoàn tất các bước chỉnh sửa (revise) để sẵn sàng nộp bài.",
    "old_id": "efeb07ed-0fce-5e5f-a8b6-2f935a6069c7",
    "new_id": "47e4a4ff-e8f3-5fd9-adf0-b2c484d35195"
  },
  {
    "prompt": "A: Did you remember to adjust the argument based on the professor''s comments? B: ________.",
    "choices": [
      "Yes, I have already revised those sections to address his concerns.",
      "I think the audience is very large for this kind of project.",
      "I will start to draft the introduction by the end of this week."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời xác nhận hành động đã chỉnh sửa (revise) dựa trên yêu cầu cụ thể của giảng viên.",
    "old_id": "76ee7226-d9eb-5480-b996-43d193cd954e",
    "new_id": "735cdc5c-38ba-5a51-83cb-1ba53d64a9c5"
  },
  {
    "prompt": "Effective writers often perform a structural analysis to ensure that every paragraph ________ to the central theme of the project.",
    "choices": [
      "contributing",
      "contributes",
      "contribute"
    ],
    "correct_index": 1,
    "explanation_vi": "Chủ ngữ số ít ''every paragraph'' yêu cầu động từ chia ở dạng số ít (contributes).",
    "old_id": "cce82f0f-057d-5268-82f7-15d6fd40eab6",
    "new_id": "a75e22a1-fef8-52cd-8191-b2301b0d5dad"
  },
  {
    "prompt": "During the planning phase, creating a detailed ________ helps authors avoid writer''s block and maintain consistent momentum.",
    "choices": [
      "outline",
      "audience",
      "revision"
    ],
    "correct_index": 0,
    "explanation_vi": "Trong giai đoạn lập kế hoạch, ''outline'' (dàn ý) là công cụ hữu ích để duy trì mạch viết.",
    "old_id": "beeb176d-a209-5d62-8874-086e2ad82405",
    "new_id": "bc6d0ba2-9aa1-5c3a-ab32-659ad35bf731"
  },
  {
    "prompt": "When the feedback is contradictory, the writer must ________ which suggestions are most helpful for improving the overall quality.",
    "choices": [
      "drafting",
      "evaluate",
      "audience"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''evaluate'' (đánh giá) là lựa chọn hợp lý nhất khi cần quyết định giá trị của các phản hồi.",
    "old_id": "a1a42c70-cfa8-5b12-9f2d-d7b9ca380671",
    "new_id": "05de924a-129f-5701-bcda-42c2268a61df"
  },
  {
    "prompt": "The ________ between the initial idea and the final product is often bridged by several rounds of rigorous editing.",
    "choices": [
      "draft",
      "audience",
      "gap"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''gap'' (khoảng cách) diễn tả sự khác biệt giữa ý tưởng ban đầu và sản phẩm cuối cùng.",
    "old_id": "7c90e008-389f-5437-9aa5-897770b63fb3",
    "new_id": "6803c1e2-13f5-53a6-a8c0-1c046620d22f"
  },
  {
    "prompt": "Once you have completed your ________, make sure to read it aloud to identify awkward phrasing or grammatical inconsistencies.",
    "choices": [
      "draft",
      "audience",
      "plan"
    ],
    "correct_index": 0,
    "explanation_vi": "Việc đọc to bản thảo (draft) giúp nhận diện các lỗi diễn đạt chưa tự nhiên.",
    "old_id": "03bf8265-2935-589d-a77a-e14987905502",
    "new_id": "6a51266e-66ec-5d32-b407-56dfd2e3af6b"
  },
  {
    "prompt": "Professional writing requires that the author maintain a consistent voice so that the ________ can easily follow the narrative flow.",
    "choices": [
      "draft",
      "audience",
      "revision"
    ],
    "correct_index": 1,
    "explanation_vi": "Người đọc (audience) cần sự nhất quán trong giọng văn để theo dõi nội dung bài viết dễ dàng hơn.",
    "old_id": "d7ba2c77-e38e-5c9a-847e-e3d803ac9f4c",
    "new_id": "e6046c31-a729-52a9-9b5f-b646e580091e"
  },
  {
    "prompt": "After reviewing the project data, the committee had to _______ the feasibility of the proposal before approving the budget.",
    "choices": [
      "evaluate",
      "alternative",
      "justify"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''evaluate'' phù hợp nhất để diễn tả hành động đánh giá mức độ khả thi của một đề xuất.",
    "old_id": "c7ce9ded-5f05-5875-b500-f88dcef51c88",
    "new_id": "e0abff51-0c7e-5b99-97fc-63a8883250bc"
  },
  {
    "prompt": "The manager asked the team to provide a _______ for their decision to delay the launch, as it had significant financial implications.",
    "choices": [
      "justify",
      "alternative",
      "evaluate"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''justify'' được dùng để yêu cầu đưa ra lý do hoặc bằng chứng xác đáng cho một quyết định quan trọng.",
    "old_id": "0cdc4fbc-cae6-5470-a1f3-e4948e0e63c1",
    "new_id": "d02f07b1-a933-56db-8272-d08e57a598e3"
  },
  {
    "prompt": "Since the original plan failed, we must urgently consider an _______ approach to meet our year-end targets.",
    "choices": [
      "justify",
      "evaluate",
      "alternative"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''alternative'' được dùng để chỉ một phương án hoặc hướng đi thay thế cho kế hoạch ban đầu.",
    "old_id": "e125bc3b-de17-5c18-8b28-eef26fce1f1b",
    "new_id": "541c1287-7ea6-5337-9de3-58da1c6a3817"
  },
  {
    "prompt": "It is widely _______ that the strategy will succeed, provided the team remains focused on the primary objectives.",
    "choices": [
      "reasoned to evaluate",
      "a reasoned evaluation",
      "reasoning evaluated"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm danh từ ''a reasoned evaluation'' đóng vai trò là tân ngữ hoặc trạng ngữ chỉ kết quả đánh giá có cơ sở.",
    "old_id": "d31b816b-ad0b-5679-b635-139374ffe36b",
    "new_id": "80cc8b2e-d78c-52e7-a9d4-a4cb87cc1a12"
  },
  {
    "prompt": "The consultant presented a _______ of the current market trends, noting that the growth is purely speculative.",
    "choices": [
      "reasoned evaluating",
      "reasoned evaluation",
      "reasoning evaluate"
    ],
    "correct_index": 1,
    "explanation_vi": "Cụm từ ''reasoned evaluation'' là cấu trúc chính xác để mô tả một quá trình đánh giá dựa trên suy luận logic.",
    "old_id": "ec8812fe-54a2-5cce-a91b-4dd814d3fce2",
    "new_id": "37d7f3db-0216-5501-8737-ae709fb65740"
  },
  {
    "prompt": "Their success is based on a _______ of the risks involved, which allowed them to pivot before the market crashed.",
    "choices": [
      "evaluating reasoned",
      "reasoned evaluation",
      "reason evaluation"
    ],
    "correct_index": 1,
    "explanation_vi": "Cần một danh từ được bổ nghĩa bởi tính từ ''reasoned'' để tạo thành cụm danh từ hợp lệ trong ngữ cảnh này.",
    "old_id": "8f9a0e5e-4c73-5d90-8bbf-c93cc8e559b2",
    "new_id": "16ce3054-278d-550d-852b-3c3b5646f58b"
  },
  {
    "prompt": "A: Why did you reject the software upgrade? B: I needed to _______ the system stability first.",
    "choices": [
      "alternatives",
      "justified",
      "evaluate"
    ],
    "correct_index": 2,
    "explanation_vi": "Động từ nguyên mẫu ''evaluate'' cần thiết sau ''needed to'' để chỉ hành động cần thực hiện.",
    "old_id": "867cc5bd-1ab0-522f-9721-b9adebe461cd",
    "new_id": "1ae29cad-d7ce-562e-a831-f3c639b6f80f"
  },
  {
    "prompt": "A: Can you explain why the client chose this path? B: They believe the current path is unsustainable, so they need a viable ______.",
    "choices": [
      "alternative",
      "justification",
      "evaluation"
    ],
    "correct_index": 0,
    "explanation_vi": "Ngữ cảnh đề cập đến việc thay đổi lộ trình, nên danh từ ''alternative'' (phương án thay thế) là hợp lý nhất.",
    "old_id": "c1f20cb4-4619-5f8a-9d4f-2725cb845c6c",
    "new_id": "dff73650-8688-5a25-87bf-a343ce337bba"
  },
  {
    "prompt": "A: Did you approve the changes? B: Only after I could _______ the extra cost with projected long-term savings.",
    "choices": [
      "evaluate",
      "justify",
      "alternated"
    ],
    "correct_index": 1,
    "explanation_vi": "Động từ ''justify'' phù hợp khi nói về việc giải trình chi phí bằng các lợi ích dài hạn.",
    "old_id": "b56d2b5c-70af-5b90-929b-08e7456bc1af",
    "new_id": "2c91ec89-fa9d-5ba2-9e26-c9ff8f0e662d"
  },
  {
    "prompt": "Which of these best describes the process of examining evidence to reach a sound conclusion?",
    "choices": [
      "evaluating alternative",
      "justifying alternative",
      "reasoned evaluation"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''reasoned evaluation'' mô tả chính xác quá trình tư duy dựa trên bằng chứng.",
    "old_id": "98bbbfdc-d181-56af-b5e0-0d52b554d41b",
    "new_id": "72d064ac-e6bf-5d09-a57d-7df1dfd95b08"
  },
  {
    "prompt": "When a person says they have an ''alternative view,'' they mean they have:",
    "choices": [
      "an identical belief",
      "a different perspective",
      "a failed evaluation"
    ],
    "correct_index": 1,
    "explanation_vi": "Từ ''alternative'' mang nghĩa là khác biệt hoặc là một lựa chọn khác so với quan điểm hiện tại.",
    "old_id": "3d089f96-4cff-5948-b5bc-43663cd73867",
    "new_id": "e150d00c-a439-5fed-966d-e4c73052eb6f"
  },
  {
    "prompt": "If you are asked to ''justify your position,'' you should:",
    "choices": [
      "ignore the critique",
      "provide a simple evaluation",
      "offer a reason for your stance"
    ],
    "correct_index": 2,
    "explanation_vi": "Yêu cầu ''justify your position'' nghĩa là cần đưa ra lập luận hoặc lý do bảo vệ quan điểm của mình.",
    "old_id": "997613d5-1e6f-5ad2-9a4d-7748a7e05e56",
    "new_id": "32e7908d-d2ee-5102-aa52-7a2c462e3a21"
  },
  {
    "prompt": "What is the primary purpose of conducting a reasoned evaluation of a claim?",
    "choices": [
      "To avoid further analysis",
      "To confirm personal bias",
      "To determine the claim''s validity"
    ],
    "correct_index": 2,
    "explanation_vi": "Mục đích của việc đánh giá có cơ sở là để xác định độ chính xác hoặc tính hợp lệ của một khẳng định.",
    "old_id": "fe9e69a0-e513-5f31-8b58-c57752e4318e",
    "new_id": "30ecbf60-8726-5b18-8570-be340fabeef8"
  },
  {
    "prompt": "Which scenario best reflects the need for an alternative?",
    "choices": [
      "The current solution is not achieving the desired outcomes.",
      "The task is already finished ahead of schedule.",
      "The data confirms that the plan is perfectly efficient."
    ],
    "correct_index": 0,
    "explanation_vi": "Khi giải pháp hiện tại không hiệu quả, ta cần một phương án thay thế.",
    "old_id": "8d599c83-d597-5014-b817-f22feea32a4b",
    "new_id": "084837cc-1c07-5668-8362-5d5273615364"
  },
  {
    "prompt": "Which phrasing best completes the sentence: ''The committee provided a _______ regarding the proposal''s potential impact.''",
    "choices": [
      "reasoned evaluation",
      "justified evaluate",
      "alternative evaluate"
    ],
    "correct_index": 0,
    "explanation_vi": "Cụm danh từ ''reasoned evaluation'' là thành phần bổ ngữ chính xác sau động từ ''provided''.",
    "old_id": "d8db71ad-837b-5ee4-bab2-7f23ea9a64e3",
    "new_id": "f97d796e-173d-5923-aca0-e5505fa024c3"
  },
  {
    "prompt": "After months of research, the team finally submitted a formal ________ to the board of directors outlining the new project timeline.",
    "choices": [
      "proposal",
      "stakeholder",
      "outcome"
    ],
    "correct_index": 0,
    "explanation_vi": "Từ ''proposal'' phù hợp nhất trong ngữ cảnh gửi một bản kế hoạch hoặc đề xuất chính thức cho ban giám đốc.",
    "old_id": "bebc6f8c-7b7d-564e-85fa-7dfd04933d9a",
    "new_id": "19070d24-780f-5d3f-9658-dac7d5d22580"
  },
  {
    "prompt": "It is crucial to identify every ________ early in the project to ensure that everyone''s interests and expectations are addressed.",
    "choices": [
      "outcome",
      "proposal",
      "stakeholder"
    ],
    "correct_index": 2,
    "explanation_vi": "Các bên liên quan (stakeholders) cần được xác định sớm để đảm bảo quyền lợi của họ được xem xét.",
    "old_id": "4dc23b1a-b413-55de-a1eb-80a45fa4f67b",
    "new_id": "390fa5e5-f8c3-5ff0-a4e5-d9cd1953813a"
  },
  {
    "prompt": "The primary ________ of the negotiation was a significant reduction in production costs, which satisfied all parties involved.",
    "choices": [
      "proposal",
      "stakeholder",
      "outcome"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''outcome'' mô tả kết quả cuối cùng đạt được sau một quá trình đàm phán.",
    "old_id": "f6f9715b-5ef7-5485-b08b-c3bba7676e40",
    "new_id": "0cfa58b7-7a8b-5c68-9995-9e7dd6a5e584"
  },
  {
    "prompt": "Select the most appropriate formal register for an email to a potential client: \"________ you have any questions regarding the attached document, please do not hesitate to contact me.\"",
    "choices": [
      "Could",
      "Should",
      "Would"
    ],
    "correct_index": 1,
    "explanation_vi": "Cấu trúc đảo ngữ ''Should you have...'' mang tính trang trọng và chuyên nghiệp hơn so với các lựa chọn còn lại.",
    "old_id": "7cdfd37e-7400-5afc-b3f2-539962da8746",
    "new_id": "01270af7-01cf-5838-8e54-3370d4b29151"
  },
  {
    "prompt": "Choose the correct professional phrasing to acknowledge a mistake: \"I realize that our previous report was incomplete, and I ________ apologize for the inconvenience caused.\"",
    "choices": [
      "am truly",
      "am having to",
      "would like to"
    ],
    "correct_index": 2,
    "explanation_vi": "Cụm từ ''would like to'' thể hiện sự lịch thiệp và chuyên nghiệp trong giao tiếp công sở.",
    "old_id": "86bb1862-2d0d-55e2-a1d5-2e023847db63",
    "new_id": "af2b859b-dc14-5fee-9ee1-bdca10a6cd25"
  },
  {
    "prompt": "Which sentence follows standard professional register when requesting a deadline extension?",
    "choices": [
      "I need more time for this.",
      "Could we possibly extend the deadline to Friday?",
      "Can you give me until Friday to finish it?"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu thứ hai sử dụng cấu trúc cầu khiến nhẹ nhàng, lịch sự phù hợp với ngữ cảnh công việc.",
    "old_id": "59f72e82-5139-5e8e-a9ff-2e68cd01bba6",
    "new_id": "69113fe1-0534-5279-864e-54f8dec0d83f"
  },
  {
    "prompt": "Colleague: ''We really need to finalize the budget by this afternoon.'' You: ''________. I will prioritize this immediately.''",
    "choices": [
      "That sounds like a fun task.",
      "I understand the urgency.",
      "No way, I am too busy."
    ],
    "correct_index": 1,
    "explanation_vi": "Câu trả lời này thể hiện sự chuyên nghiệp bằng cách xác nhận mức độ ưu tiên của công việc.",
    "old_id": "40e01d34-5505-51e3-b30c-7dbda4fafe41",
    "new_id": "8b6e3960-911d-53ed-97f4-7bd867af5146"
  },
  {
    "prompt": "Manager: ''The client was quite disappointed with the initial presentation.'' You: ''________. What specific areas should we improve?''",
    "choices": [
      "That is their problem.",
      "Why did they complain?",
      "I see. Thank you for the feedback."
    ],
    "correct_index": 2,
    "explanation_vi": "Cách phản hồi này thể hiện thái độ cầu thị và chuyên nghiệp đối với những đóng góp ý kiến.",
    "old_id": "a72a2a4f-ce01-5bbc-af26-69f342598945",
    "new_id": "707ec83f-9fbd-574f-917b-a46ba6da686a"
  },
  {
    "prompt": "Partner: ''Are you available for a quick sync at 2 PM?'' You: ''________, but I can make time if it is critical.''",
    "choices": [
      "My schedule is quite tight",
      "I have nothing to do",
      "I am totally slammed"
    ],
    "correct_index": 0,
    "explanation_vi": "Cách diễn đạt ''My schedule is quite tight'' mang tính chuyên nghiệp hơn khi từ chối khéo léo.",
    "old_id": "95f3dded-8c57-56c1-899c-202dc7ab31d3",
    "new_id": "43670f5b-cd74-582c-9221-5abaf695ad19"
  },
  {
    "prompt": "When providing constructive feedback to a peer, it is most effective to focus on ________ rather than personal attributes.",
    "choices": [
      "emotional reactions",
      "specific behaviors",
      "general frustrations"
    ],
    "correct_index": 1,
    "explanation_vi": "Trong giao tiếp chuyên nghiệp, việc tập trung vào các hành vi cụ thể giúp phản hồi mang tính xây dựng và ít gây xung đột.",
    "old_id": "17c8e9a8-0039-5bfa-bacc-d4cebcc4fefe",
    "new_id": "c458b2d3-7037-5966-93ff-78571d6219bc"
  },
  {
    "prompt": "Which method is best for ensuring clarity in a complex email exchange?",
    "choices": [
      "Summarizing key points in bullet points.",
      "Writing everything in one large paragraph.",
      "Using long, complex sentences."
    ],
    "correct_index": 0,
    "explanation_vi": "Sử dụng các ý gạch đầu dòng giúp thông tin trở nên rõ ràng và dễ nắm bắt hơn cho người đọc.",
    "old_id": "8e21740a-3a02-530c-98e6-2d6db54d83ce",
    "new_id": "a16810e3-faec-5942-a67d-dff3d0a3e594"
  },
  {
    "prompt": "What is the most appropriate action when you do not understand a task assigned by your supervisor?",
    "choices": [
      "Ask for a brief clarification.",
      "Wait for someone else to explain it.",
      "Guess what they mean to avoid bother."
    ],
    "correct_index": 0,
    "explanation_vi": "Việc chủ động yêu cầu làm rõ giúp tránh sai sót và thể hiện trách nhiệm trong công việc.",
    "old_id": "334b0c58-d129-5a5d-8441-5bb849034cd5",
    "new_id": "511d1f6b-acc0-5671-ab39-afe7a6c7c6e9"
  },
  {
    "prompt": "When conducting a virtual meeting, what demonstrates professional engagement?",
    "choices": [
      "Keeping your camera off at all times.",
      "Checking your personal email during pauses.",
      "Maintaining eye contact by looking at the camera."
    ],
    "correct_index": 2,
    "explanation_vi": "Nhìn vào camera trong các cuộc họp trực tuyến tạo ra kết nối và thể hiện sự tôn trọng với người đối thoại.",
    "old_id": "8c5487f3-6ed0-5a96-a0ab-26c1228e080c",
    "new_id": "255137a1-18a7-548a-a218-cdea7841a367"
  },
  {
    "prompt": "Which of the following is considered a best practice when writing a professional email subject line?",
    "choices": [
      "Keep it brief and descriptive.",
      "Use all capital letters for visibility.",
      "Leave it empty to spark curiosity."
    ],
    "correct_index": 0,
    "explanation_vi": "Tiêu đề ngắn gọn và mô tả đúng nội dung giúp người nhận dễ dàng quản lý email.",
    "old_id": "f7eb6185-3fdb-55ea-9f27-069aaa94a3d2",
    "new_id": "ff5e48af-e024-5134-b0b6-587e5308a2f0"
  },
  {
    "prompt": "If you need to report a delay to a client, what is the best approach?",
    "choices": [
      "Wait until the deadline has passed.",
      "Inform them as soon as the delay is anticipated.",
      "Blame the technical department for the issue."
    ],
    "correct_index": 1,
    "explanation_vi": "Thông báo sớm về sự chậm trễ cho thấy sự chuyên nghiệp và giúp khách hàng có phương án dự phòng.",
    "old_id": "4c672a37-1361-5045-b705-3b006abfc467",
    "new_id": "49388175-6343-57a9-8061-5442456b7bdb"
  },
  {
    "prompt": "After the project failed, the manager asked the team to analyze each internal ________ to understand why the timeline slipped.",
    "choices": [
      "strength",
      "strategy",
      "weakness"
    ],
    "correct_index": 2,
    "explanation_vi": "Từ ''weakness'' phù hợp với ngữ cảnh phân tích thất bại của dự án.",
    "old_id": "1a4ff09e-89ff-5ebb-9a50-062b1c2776a9",
    "new_id": "6ee15b2f-16d3-5e5a-abb7-314c8be45f28"
  },
  {
    "prompt": "To remain competitive, our primary ________ is to expand into international markets before the end of the fiscal year.",
    "choices": [
      "strength",
      "strategy",
      "weakness"
    ],
    "correct_index": 1,
    "explanation_vi": "Câu này nói về kế hoạch hành động, vì vậy ''strategy'' là từ chính xác nhất.",
    "old_id": "84a03439-1c4d-5c67-9022-e97e91390050",
    "new_id": "e2038571-ee3f-59d8-a243-b442665b7879"
  },
  {
    "prompt": "The lead developer identified the software''s core ________ as its exceptional security features, which attracted many enterprise clients.",
    "choices": [
      "weakness",
      "strength",
      "strategy"
    ],
    "correct_index": 1,
    "explanation_vi": "Đặc điểm thu hút khách hàng là một lợi thế, nên dùng ''strength''.",
    "old_id": "e424223b-ab12-5c83-a3ce-0be8dd1dd88c",
    "new_id": "cd7dfe43-3025-51f0-8188-47e8fe513efb"
  },
  {
    "prompt": "By the time the audit finishes next Friday, we ________ all of our financial records for the past three years.",
    "choices": [
      "will review",
      "are reviewing",
      "will have reviewed"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng thì tương lai hoàn thành để chỉ một hành động sẽ hoàn tất trước một thời điểm trong tương lai.",
    "old_id": "018a9848-5826-5692-9c18-6c61629e5a12",
    "new_id": "2c6d8be0-0c52-5a3f-9053-840f03ab8a18"
  },
  {
    "prompt": "If we ________ more time preparing the presentation, we would have been able to answer the board''s questions more effectively.",
    "choices": [
      "have had",
      "would have",
      "had had"
    ],
    "correct_index": 2,
    "explanation_vi": "Đây là câu điều kiện loại 3, diễn tả giả định trái ngược với quá khứ.",
    "old_id": "1ea05ab0-1391-5159-a359-8e5ed1df29e8",
    "new_id": "6a36e881-4bb8-5393-971f-4e3a93da4d26"
  },
  {
    "prompt": "The complex report ________ by the research department is expected to be delivered to the executives by tomorrow morning.",
    "choices": [
      "compiled",
      "was compiled",
      "compiling"
    ],
    "correct_index": 0,
    "explanation_vi": "Cần một mệnh đề quan hệ rút gọn ở dạng bị động để bổ nghĩa cho ''report''.",
    "old_id": "5db69f8f-9ce7-5909-bfc8-77830403dc09",
    "new_id": "3cb25cfc-2f18-5fca-b85e-01d934a8faba"
  },
  {
    "prompt": "A: How do you feel about our current marketing approach? B: ________.",
    "choices": [
      "The weakness was already fixed by someone else.",
      "It shows great strength in reaching our target audience.",
      "We should have been doing it earlier today."
    ],
    "correct_index": 1,
    "explanation_vi": "Lựa chọn này đưa ra ý kiến trực tiếp về chiến lược marketing hiện tại.",
    "old_id": "074334ba-4786-5826-829d-e8b2d672a94f",
    "new_id": "f8738ebb-538c-50c0-a91b-2fadfe2ea12d"
  },
  {
    "prompt": "A: Why did the client decide to cancel the contract? B: ________.",
    "choices": [
      "They felt our communication was a significant weakness.",
      "We will review the documents later this afternoon.",
      "Their main strategy is to minimize risks."
    ],
    "correct_index": 0,
    "explanation_vi": "Câu trả lời giải thích nguyên nhân hủy hợp đồng là một điểm yếu trong giao tiếp.",
    "old_id": "1a7f0168-795a-584e-a879-4e37212aadb1",
    "new_id": "0c6c18c0-4534-5c9c-b68e-608c86ff748c"
  },
  {
    "prompt": "A: What is the next step for our team expansion? B: ________.",
    "choices": [
      "We are strengthening our recruitment strategy.",
      "I have reviewed the weakness of the plan.",
      "The strategy has been already finalized."
    ],
    "correct_index": 0,
    "explanation_vi": "Đây là câu trả lời hợp lý nhất cho câu hỏi về các bước phát triển đội ngũ.",
    "old_id": "9d2cd8b7-33d3-566a-adf2-b17485be378c",
    "new_id": "c613eaf1-9829-59c2-9fb6-6f0e65ea61b4"
  },
  {
    "prompt": "To succeed in the negotiation, you must demonstrate the unique ________ of our proposal.",
    "choices": [
      "weakness",
      "strength",
      "strategy"
    ],
    "correct_index": 1,
    "explanation_vi": "Trong đàm phán, người ta thường muốn nhấn mạnh lợi thế của đề xuất.",
    "old_id": "42d7543a-fe84-5f65-a2c7-c1560775d0ca",
    "new_id": "773136e3-e976-581e-91c5-2826519090da"
  },
  {
    "prompt": "We ________ that the new regulations might impact our production speed significantly.",
    "choices": [
      "were anticipating",
      "have anticipated",
      "had anticipated"
    ],
    "correct_index": 1,
    "explanation_vi": "Thì hiện tại hoàn thành phù hợp để nói về một nhận định có ảnh hưởng đến hiện tại.",
    "old_id": "b0a9b74b-558c-58cf-ba1b-af5b1f29be3f",
    "new_id": "6f589f96-4ce5-5e61-9557-b34e0c946894"
  },
  {
    "prompt": "The team ________ the project plan three times before it was finally approved by the director.",
    "choices": [
      "revised",
      "was revising",
      "had revised"
    ],
    "correct_index": 2,
    "explanation_vi": "Dùng thì quá khứ hoàn thành để chỉ hành động xảy ra trước một hành động khác trong quá khứ.",
    "old_id": "35a02018-8ebb-52d4-9106-24f709fa9bfd",
    "new_id": "d753546e-9e28-5cf6-8f7e-0d1d2b6666b1"
  },
  {
    "prompt": "A successful business constantly evaluates its ________ to ensure it does not become stagnant.",
    "choices": [
      "weakness",
      "strength",
      "strategy"
    ],
    "correct_index": 0,
    "explanation_vi": "Doanh nghiệp đánh giá điểm yếu để cải thiện và không bị trì trệ.",
    "old_id": "8f3d817d-62f4-5f2f-bdb0-824fe842a68b",
    "new_id": "c957ce58-30b7-5186-9be0-7d264af2aa12"
  },
  {
    "prompt": "Unless the team ________ their performance, the company will likely look for external consultants.",
    "choices": [
      "will improve",
      "improved",
      "improves"
    ],
    "correct_index": 2,
    "explanation_vi": "Trong mệnh đề với ''unless'', chúng ta sử dụng thì hiện tại đơn để diễn tả điều kiện tương lai.",
    "old_id": "f952ec0e-a252-5a33-9ff4-12473d4e5d23",
    "new_id": "1a555ae6-9358-5f41-95dd-7ffc1f85e01b"
  },
  {
    "prompt": "The board members discussed the long-term ________ to ensure our company remains profitable in the coming decade.",
    "choices": [
      "strategy",
      "strength",
      "weakness"
    ],
    "correct_index": 0,
    "explanation_vi": "Để đảm bảo lợi nhuận dài hạn, công ty cần một chiến lược cụ thể.",
    "old_id": "149d2947-91b1-552c-8941-6573afe80577",
    "new_id": "fcf3408d-6e83-52ee-a691-389063ce70ce"
  }
]'::jsonb)
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
