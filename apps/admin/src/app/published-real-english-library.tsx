'use client';

import { useCallback, useEffect, useState } from 'react';
import { getSupabase } from '@/lib/client';
import { normalizeLessonRelations, relationItems } from './real-english-relations';
import styles from './published-real-english-library.module.css';

type Phrase = {
  id: string;
  english_text: string;
  vietnamese_translation: string;
  formality: string;
  usage_context: string;
};

type Lesson = {
  id: string;
  title: string;
  description: string;
  difficulty: string;
  content_type: string;
  published_at: string | null;
  generation_source: string;
  real_english_topics: { title: string }[];
  real_english_phrases: Phrase[];
};

type Props = { onOpenReview: () => void };

function normalizePublishedLesson(row: Record<string, unknown>): Lesson {
  const lesson = normalizeLessonRelations(row);
  return {
    ...lesson,
    real_english_topics: relationItems(
      row.real_english_topics as { title: string } | { title: string }[] | null,
    ),
  } as unknown as Lesson;
}

export function PublishedRealEnglishLibrary({ onOpenReview }: Props) {
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [selected, setSelected] = useState<Lesson | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    const { data, error: queryError } = await getSupabase()
      .from('real_english_lessons')
      .select('id,title,description,difficulty,content_type,published_at,generation_source,real_english_topics(title),real_english_phrases(id,english_text,vietnamese_translation,formality,usage_context)')
      .eq('status', 'published')
      .order('published_at', { ascending: false });

    if (queryError) {
      setError(queryError.message);
      setLessons([]);
    } else {
      const nextLessons = (data ?? []).map((row) => normalizePublishedLesson(row as Record<string, unknown>));
      setLessons(nextLessons);
      setSelected((current) => nextLessons.find((lesson) => lesson.id === current?.id) ?? null);
      setError('');
    }
    setLoading(false);
  }, []);

  useEffect(() => { queueMicrotask(() => { void load(); }); }, [load]);

  return <section className={styles.library} aria-labelledby="published-ai-lessons-title">
    <div className={styles.heading}>
      <div>
        <p className={styles.eyebrow}>LEARNER LIBRARY</p>
        <h2 id="published-ai-lessons-title">Published AI lessons</h2>
        <p>These reviewed lessons are available to learners in the Real English reading feed.</p>
      </div>
      <div className={styles.actions}>
        <span className={styles.count}>{lessons.length} published</span>
        <button className={styles.secondary} type="button" onClick={() => { void load(); }} disabled={loading}>
          {loading ? 'Refreshing…' : 'Refresh'}
        </button>
        <button type="button" onClick={onOpenReview}>Open review queue</button>
      </div>
    </div>

    {error ? <div className={styles.error} role="alert">
      <strong>Could not load published lessons.</strong><span>{error}</span>
      <button type="button" onClick={() => { void load(); }}>Try again</button>
    </div> : null}

    {!error && !loading && lessons.length === 0 ? <div className={styles.empty}>
      <strong>No published AI lessons yet</strong>
      <span>Approve a reviewed lesson to make it appear here and in the learner feed.</span>
      <button type="button" onClick={onOpenReview}>Review AI lessons</button>
    </div> : null}

    {lessons.length > 0 ? <div className={styles.layout}>
      <div className={styles.list}>
        {lessons.map((lesson) => <button key={lesson.id} type="button"
          className={`${styles.lesson} ${selected?.id === lesson.id ? styles.active : ''}`}
          aria-pressed={selected?.id === lesson.id} onClick={() => setSelected(lesson)}>
          <span className={styles.meta}>{lesson.difficulty} · {lesson.real_english_topics[0]?.title ?? lesson.content_type}</span>
          <strong>{lesson.title}</strong>
          <span>{lesson.description}</span>
          <small>{lesson.published_at ? `Published ${new Date(lesson.published_at).toLocaleString()}` : 'Published'}</small>
        </button>)}
      </div>
      <article className={styles.preview}>
        {selected ? <>
          <p className={styles.eyebrow}>LEARNER PREVIEW</p>
          <h3>{selected.title}</h3>
          <p>{selected.description}</p>
          <div className={styles.tags}><span>{selected.difficulty}</span><span>{selected.content_type.replaceAll('_', ' ')}</span><span>Human reviewed</span></div>
          <div className={styles.phrases}>
            {selected.real_english_phrases.length > 0 ? selected.real_english_phrases.map((phrase) => <div key={phrase.id}>
              <strong>{phrase.english_text}</strong>
              <span>{phrase.vietnamese_translation}</span>
              <small>{phrase.formality} · {phrase.usage_context}</small>
            </div>) : <p>No active phrases are attached to this lesson.</p>}
          </div>
        </> : <div className={styles.previewEmpty}><strong>Select a lesson</strong><span>Inspect exactly what has been released to learners.</span></div>}
      </article>
    </div> : null}
  </section>;
}
