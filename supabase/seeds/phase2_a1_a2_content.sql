-- Reviewed project-original A1-A2 starter batch. No external attribution is claimed.
BEGIN;
UPDATE public.dictionary_entries SET
  cefr_level=CASE WHEN normalized_term IN ('curious','confident','improve','conversation') THEN 'A2' ELSE 'A1' END,
  topic=CASE WHEN normalized_term IN ('journey','explore') THEN 'travel' WHEN normalized_term IN ('practice','listen','remember','improve') THEN 'school' ELSE 'introductions' END,
  example_vi=CASE normalized_term
    WHEN 'curious' THEN 'Tôi tò mò về câu chuyện này.' WHEN 'journey' THEN 'Mỗi hành trình bắt đầu bằng một bước.'
    WHEN 'practice' THEN 'Tôi luyện tiếng Anh mỗi ngày.' WHEN 'reward' THEN 'Hoàn thành bài học tự nó đã là một phần thưởng.'
    WHEN 'explore' THEN 'Chúng tôi khám phá một khu phố mới vào cuối tuần.' WHEN 'confident' THEN 'Cô ấy cảm thấy tự tin khi nói tiếng Anh.'
    WHEN 'listen' THEN 'Hãy lắng nghe câu hỏi thật kỹ.' WHEN 'improve' THEN 'Đọc mỗi ngày có thể cải thiện vốn từ của bạn.'
    WHEN 'conversation' THEN 'Chúng tôi đã có một cuộc trò chuyện ngắn sau giờ học.' ELSE 'Tôi ghi nhớ từ mới bằng cách dùng nó trong câu.' END,
  usage_notes='Project-original beginner vocabulary reviewed for concise everyday use.',quality_status='published'
WHERE source_name='Englify Quest editorial' AND license_id='project-owned';

INSERT INTO public.dictionary_entries
  (id,language,term,normalized_term,definition,translation,part_of_speech,example,example_vi,ipa,source_name,license_id,is_published,cefr_level,topic,usage_notes,quality_status)
VALUES
('12111111-1111-4111-8111-111111111101','en','hello','hello','A greeting used when meeting or speaking to someone.','xin chào','interjection','Hello, my name is Lan.','Xin chào, tôi tên là Lan.','/həˈləʊ/','Englify Quest editorial','project-owned',true,'A1','greetings','Use in neutral everyday greetings.','published'),
('12111111-1111-4111-8111-111111111102','en','family','family','A group of people related to one another.','gia đình','noun','My family eats dinner together.','Gia đình tôi ăn tối cùng nhau.','/ˈfæməli/','Englify Quest editorial','project-owned',true,'A1','family','Common countable noun.','published'),
('12111111-1111-4111-8111-111111111103','en','breakfast','breakfast','The first meal of the day.','bữa sáng','noun','I have breakfast at seven.','Tôi ăn sáng lúc bảy giờ.','/ˈbrekfəst/','Englify Quest editorial','project-owned',true,'A1','food-and-drinks','Usually used without an article for the meal.','published'),
('12111111-1111-4111-8111-111111111104','en','usually','usually','On most days or in most situations.','thường','adverb','I usually walk to school.','Tôi thường đi bộ đến trường.','/ˈjuːʒuəli/','Englify Quest editorial','project-owned',true,'A1','daily-routines','Place before most main verbs.','published'),
('12111111-1111-4111-8111-111111111105','en','classroom','classroom','A room where a class is taught.','phòng học','noun','Our classroom is on the second floor.','Phòng học của chúng tôi ở tầng hai.','/ˈklɑːsruːm/','Englify Quest editorial','project-owned',true,'A1','school','A compound noun: class + room.','published'),
('12111111-1111-4111-8111-111111111106','en','quarter','quarter','Fifteen minutes; one fourth of an hour.','mười lăm phút','noun','It is a quarter past nine.','Bây giờ là chín giờ mười lăm.','/ˈkwɔːtə/','Englify Quest editorial','project-owned',true,'A1','numbers-and-time','Used in common time expressions.','published'),
('12111111-1111-4111-8111-111111111107','en','where','where','Used to ask about a place or position.','ở đâu','question word','Where is the bus stop?','Trạm xe buýt ở đâu?','/weə/','Englify Quest editorial','project-owned',true,'A1','common-questions','Put before the auxiliary verb in questions.','published'),
('12111111-1111-4111-8111-111111111108','en','introduce','introduce','To tell people one another’s names.','giới thiệu','verb','Let me introduce my friend.','Để tôi giới thiệu bạn của tôi.','/ˌɪntrəˈdjuːs/','Englify Quest editorial','project-owned',true,'A1','introductions','Often followed by someone or yourself.','published'),
('12111111-1111-4111-8111-111111111109','en','receipt','receipt','A paper or digital record showing that you paid.','hóa đơn','noun','Could I have the receipt, please?','Cho tôi xin hóa đơn được không?','/rɪˈsiːt/','Englify Quest editorial','project-owned',true,'A2','shopping','The p is silent.','published'),
('12111111-1111-4111-8111-111111111110','en','platform','platform','The raised area where passengers wait for a train.','sân ga','noun','The train leaves from platform four.','Tàu rời sân ga số bốn.','/ˈplætfɔːm/','Englify Quest editorial','project-owned',true,'A2','travel','Check the platform number at the station.','published'),
('12111111-1111-4111-8111-111111111111','en','opposite','opposite','On the other side from something.','đối diện','preposition','The bank is opposite the pharmacy.','Ngân hàng ở đối diện hiệu thuốc.','/ˈɒpəzɪt/','Englify Quest editorial','project-owned',true,'A2','directions','Used for locations facing one another.','published'),
('12111111-1111-4111-8111-111111111112','en','appointment','appointment','An arranged time to meet someone, often a professional.','cuộc hẹn','noun','I have a doctor’s appointment tomorrow.','Ngày mai tôi có lịch hẹn với bác sĩ.','/əˈpɔɪntmənt/','Englify Quest editorial','project-owned',true,'A2','health-conversations','Common collocation: make an appointment.','published'),
('12111111-1111-4111-8111-111111111113','en','recommend','recommend','To say that something is good and worth choosing.','đề xuất','verb','What dish do you recommend?','Bạn đề xuất món nào?','/ˌrekəˈmend/','Englify Quest editorial','project-owned',true,'A2','restaurant-ordering','Can be followed by a noun or verb-ing.','published'),
('12111111-1111-4111-8111-111111111114','en','schedule','schedule','A plan showing when work or activities happen.','lịch trình','noun','My work schedule changes every week.','Lịch làm việc của tôi thay đổi mỗi tuần.','/ˈʃedjuːl/','Englify Quest editorial','project-owned',true,'A2','work-routines','Pronunciation varies by region.','published'),
('12111111-1111-4111-8111-111111111115','en','photography','photography','The activity or art of taking photographs.','nhiếp ảnh','noun','Photography is my favorite hobby.','Nhiếp ảnh là sở thích yêu thích của tôi.','/fəˈtɒɡrəfi/','Englify Quest editorial','project-owned',true,'A2','hobbies','Stress falls on the second syllable.','published'),
('12111111-1111-4111-8111-111111111116','en','experience','experience','Something that happened to you and affected you.','trải nghiệm','noun','It was an interesting travel experience.','Đó là một trải nghiệm du lịch thú vị.','/ɪkˈspɪəriəns/','Englify Quest editorial','project-owned',true,'A2','past-experiences','Countable for an event; uncountable for knowledge gained.','published')
ON CONFLICT(language,normalized_term) DO UPDATE SET definition=EXCLUDED.definition,translation=EXCLUDED.translation,
  part_of_speech=EXCLUDED.part_of_speech,example=EXCLUDED.example,example_vi=EXCLUDED.example_vi,ipa=EXCLUDED.ipa,
  cefr_level=EXCLUDED.cefr_level,topic=EXCLUDED.topic,usage_notes=EXCLUDED.usage_notes,quality_status=EXCLUDED.quality_status,is_published=true;

UPDATE public.real_english_expressions SET
  cefr_level=CASE WHEN kind IN ('idiom','phrasal_verb','movie_style_dialogue') THEN 'A2' ELSE 'A1' END,
  topic_slug=CASE slug WHEN 'could-i-get' THEN 'food-drinks' WHEN 'last-train-scene' THEN 'travel-directions'
    WHEN 'break-the-ice' THEN 'introductions' ELSE 'daily-life' END
WHERE source_name='Englify Quest editorial' AND license_id='project-original';

UPDATE public.real_english_phrases p SET dictionary_entry_id=d.id
FROM public.dictionary_entries d WHERE d.language='en' AND d.is_published AND d.archived_at IS NULL
  AND d.normalized_term=public.englify_normalize_search(p.english_text);
COMMIT;
