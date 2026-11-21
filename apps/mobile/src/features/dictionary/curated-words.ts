import type { DictionaryWord } from './types';

export const curatedWords: DictionaryWord[] = [
  ['light', '/laɪt/', 'noun', 'ánh sáng', 'Visible energy that makes it possible to see.', 'Light entered through the window.'],
  ['dark', '/dɑːrk/', 'adjective', 'tối', 'Having little or no light.', 'The room was dark after sunset.'],
  ['confident', '/ˈkɑːnfɪdənt/', 'adjective', 'tự tin', 'Sure of your ability to do something.', 'She feels confident speaking English.'],
  ['curious', '/ˈkjʊriəs/', 'adjective', 'tò mò', 'Eager to learn or know about something.', 'He was curious about the new book.'],
  ['journey', '/ˈdʒɜːrni/', 'noun', 'hành trình', 'An act of travelling from one place to another.', 'Their journey took two days.'],
  ['improve', '/ɪmˈpruːv/', 'verb', 'cải thiện', 'To make or become better.', 'Practice can improve your pronunciation.'],
  ['explore', '/ɪkˈsplɔːr/', 'verb', 'khám phá', 'To travel around a place to learn about it.', 'We explored the old town.'],
  ['patient', '/ˈpeɪʃənt/', 'adjective', 'kiên nhẫn', 'Able to wait calmly without becoming annoyed.', 'Be patient while the water heats up.'],
  ['notice', '/ˈnoʊtɪs/', 'verb', 'để ý', 'To become aware of something.', 'Did you notice the blue door?'],
  ['prepare', '/prɪˈper/', 'verb', 'chuẩn bị', 'To get ready for something.', 'They prepared for the meeting.'],
  ['honest', '/ˈɑːnɪst/', 'adjective', 'trung thực', 'Willing to tell the truth.', 'She gave an honest answer.'],
  ['choose', '/tʃuːz/', 'verb', 'chọn', 'To decide which thing you want.', 'Choose a book to read tonight.'],
  ['server', '/ˈsɜːrvər/', 'noun', 'máy chủ', 'A computer or program that provides services to other computers or programs over a network.', 'The server hosts the company website.'],
  ['duck', '/dʌk/', 'noun', 'con vịt', 'A water bird with a broad, flat bill.', 'A duck swam across the pond.'],
].map(([term, ipa, part_of_speech, translation, definition, example]) => ({
  id: `curated:${term}`, term, ipa, part_of_speech, translation, definition, example,
  audio_url: null, source_name: 'Englify Quest editorial', license_id: 'project-owned',
}));

export const duckVerb: DictionaryWord = {
  id: 'curated:duck:verb', term: 'duck', ipa: '/dʌk/', part_of_speech: 'verb', translation: 'cúi xuống, né',
  definition: 'To lower your head or body quickly to avoid being hit.',
  example: 'Duck when you walk under the low beam.', audio_url: null,
  source_name: 'Englify Quest editorial', license_id: 'project-owned',
};

