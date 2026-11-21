import { useAppPalette } from "@/constants/app-theme";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import {
  AppState,
  Pressable,
  TextInput,
  View,
  useWindowDimensions,
} from "react-native";
import { SymbolView } from "expo-symbols";
import Animated, { FadeIn } from "react-native-reanimated";
import { designTokens } from "@englify/shared";
import { router, type Href } from "expo-router";
import { Page, NavLink } from "@/components/page";
import { useAuth } from "@/auth/provider";
import { usePendingDestination } from "@/auth/access";
import { ApiError } from "@/lib/api";
import {
  AppButton,
  AppCard,
  AppText,
  EmptyState,
  ErrorState,
  LoadingSkeleton,
} from "@/ui";
import { useReducedMotion } from "@/ui/use-reduced-motion";
import {
  getCachedSavedWords,
  getRecentSearches,
  cacheSavedWords,
  cacheWords,
  rememberSearch,
  searchCachedWords,
} from "./cache";
import {
  listSavedWords,
  removeSavedWord,
  saveWord,
  searchDictionary,
} from "./api";
import {
  filterCachedWords,
  type DictionaryWord,
  type SavedWord,
} from "./types";
import * as Crypto from "expo-crypto";
import { listEvents, queueEvent } from "@/features/offline/storage";
import { SyncStatus } from "@/features/offline/sync-status";
import { paginateDictionary } from "./pagination";
import { usePronunciation } from "@/features/translation/use-pronunciation";
import { translateText } from "@/features/translation/api";
import { useI18n } from "@/i18n/context";
import { loadDailyVocabulary } from "./daily";
import { curatedWords, duckVerb } from "./curated-words";
import { useGuestRecent } from "./guest-recent";

type Tab = "search" | "saved" | "recent" | "flashcards";
const { spacing, radius, typography, motion } = designTokens;
const shortcuts = [
  {
    id: "saved",
    label: "Saved",
    icon: {
      ios: "bookmark",
      android: "bookmark_border",
      web: "bookmark_border",
    },
  },
  {
    id: "recent",
    label: "Recent",
    icon: { ios: "clock", android: "history", web: "history" },
  },
  {
    id: "flashcards",
    label: "Flashcards",
    icon: { ios: "rectangle.on.rectangle", android: "style", web: "style" },
  },
] as const;

function WordCard({
  word,
  saved,
  saveDisabled,
  onSave,
  onSpeak,
  account,
}: {
  word: DictionaryWord;
  saved: boolean;
  saveDisabled: boolean;
  onSave: () => void;
  onSpeak: () => void;
  account: string | null;
}) {
  const palette = useAppPalette();
  const [definitionVi, setDefinitionVi] = useState("");
  const [translationError, setTranslationError] = useState("");
  const [translating, setTranslating] = useState(false);
  const translationPending = useRef(false);
  async function translateDefinition() {
    if (translationPending.current) return;
    translationPending.current = true;
    setTranslating(true);
    setTranslationError("");
    try {
      const result = await translateText(
        { text: word.definition, source: "en", target: "vi" },
        account,
      );
      if (result.translated_text) setDefinitionVi(result.translated_text);
      else
        setTranslationError(
          "No Vietnamese translation was returned for this definition.",
        );
    } catch (cause) {
      setTranslationError(
        cause instanceof Error
          ? cause.message
          : "Translation is temporarily unavailable.",
      );
    } finally {
      translationPending.current = false;
      setTranslating(false);
    }
  }
  return (
    <View
      style={{
        gap: spacing.md,
        padding: spacing.lg,
        borderWidth: 1,
        borderColor: palette.border,
        borderRadius: radius.xl,
        backgroundColor: palette.surface,
      }}
    >
      <View
        style={{
          flexDirection: "row",
          flexWrap: "wrap",
          alignItems: "flex-start",
          gap: spacing.sm,
        }}
      >
        <View style={{ flex: 1, minWidth: 120 }}>
          <AppText variant="title" accessibilityRole="header">
            {word.term}
          </AppText>
          {word.ipa ? <AppText tone="muted">{word.ipa}</AppText> : null}
        </View>
        <View style={{ flexDirection: "row", gap: spacing.sm }}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={`Pronounce ${word.term}`}
            accessibilityHint={
              word.audio_url
                ? "Plays dictionary audio with the device English voice as fallback"
                : "Uses the device English voice"
            }
            onPress={onSpeak}
            style={({ pressed }) => ({
              width: 48,
              height: 48,
              borderRadius: radius.md,
              alignItems: "center",
              justifyContent: "center",
              backgroundColor: palette.primary,
              opacity: pressed ? 0.75 : 1,
            })}
          >
            <SymbolView
              name={{
                ios: "speaker.wave.2.fill",
                android: "volume_up",
                web: "volume_up",
              }}
              size={22}
              tintColor={palette.primaryOn}
              fallback={
                <AppText style={{ color: palette.primaryOn }}>▶</AppText>
              }
            />
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={saved ? "Remove from saved words" : "Save word"}
            accessibilityState={{ selected: saved, disabled: saveDisabled }}
            disabled={saveDisabled}
            onPress={onSave}
            style={({ pressed }) => ({
              width: 48,
              height: 48,
              borderRadius: radius.md,
              alignItems: "center",
              justifyContent: "center",
              backgroundColor:
                saved || pressed ? palette.primarySoft : palette.elevated,
              borderWidth: 1,
              borderColor: saved ? palette.primary : palette.border,
              opacity: saveDisabled ? 0.6 : 1,
            })}
          >
            <SymbolView
              name={
                saved
                  ? {
                      ios: "bookmark.fill",
                      android: "bookmark",
                      web: "bookmark",
                    }
                  : shortcuts[0].icon
              }
              size={22}
              tintColor={palette.primary}
              fallback={<AppText tone="primary">{saved ? "★" : "☆"}</AppText>}
            />
          </Pressable>
        </View>
      </View>
      <View
        style={{
          gap: spacing.xs,
          paddingTop: spacing.md,
          borderTopWidth: 1,
          borderColor: palette.border,
        }}
      >
        {word.part_of_speech ? (
          <AppText variant="caption" tone="muted">
            {word.part_of_speech}
          </AppText>
        ) : null}
        {word.translation ? (
          <AppText variant="heading" tone="primary">
            {word.translation}
          </AppText>
        ) : null}
        {word.suggested_translation ? (
          <AppText variant="heading" tone="primary">
            {word.suggested_translation}
          </AppText>
        ) : null}
        {word.suggested_translation ? (
          <AppText variant="caption" tone="muted">
            Suggested translation of the word
          </AppText>
        ) : null}
        <AppText>{word.definition}</AppText>
        {!word.translation ? (
          <View style={{ gap: spacing.xs }}>
            {definitionVi ? (
              <>
                <AppText variant="caption" tone="primary">
                  Vietnamese definition
                </AppText>
                <AppText>{definitionVi}</AppText>
              </>
            ) : (
              <AppButton
                label="Translate definition"
                variant="secondary"
                loading={translating}
                onPress={() => {
                  void translateDefinition();
                }}
              />
            )}
            {translationError ? (
              <AppText tone="error" accessibilityRole="alert">
                {translationError}
              </AppText>
            ) : null}
          </View>
        ) : null}
        {word.additional_senses?.map((sense, i) => (
          <View key={i} style={{ gap: spacing.xs, paddingTop: spacing.sm }}>
            <AppText variant="caption" tone="muted">
              {sense.partOfSpeech}
            </AppText>
            <AppText>{sense.definition}</AppText>
            {sense.example ? (
              <AppText tone="muted">{sense.example}</AppText>
            ) : null}
          </View>
        ))}
      </View>
      {word.example ? (
        <View
          style={{
            padding: spacing.md,
            borderRadius: radius.md,
            backgroundColor: palette.primarySoft,
          }}
        >
          <AppText weight="semibold">“{word.example}”</AppText>
        </View>
      ) : null}
    </View>
  );
}

function DictionaryPagination({
  page,
  totalPages,
  onChange,
}: {
  page: number;
  totalPages: number;
  onChange: (page: number) => void;
}) {
  const { l } = useI18n();
  if (totalPages <= 1) return null;
  return (
    <View style={{ flexDirection: "row", alignItems: "center", gap: 8 }}>
      <AppButton
        label="Previous"
        variant="secondary"
        disabled={page <= 1}
        style={{ flex: 1 }}
        onPress={() => onChange(page - 1)}
      />
      <AppText variant="caption" tone="muted" accessibilityRole="text">
        {l(`Page ${page} of ${totalPages}`)}
      </AppText>
      <AppButton
        label="Next"
        variant="secondary"
        disabled={page >= totalPages}
        style={{ flex: 1 }}
        onPress={() => onChange(page + 1)}
      />
    </View>
  );
}

export function DictionaryScreen({
  previewWords,
}: {
  previewWords?: DictionaryWord[];
}) {
  const { phase, profile } = useAuth();
  const userId = phase === "authenticated" ? (profile?.id ?? "") : "";
  return (
    <DictionaryContent
      key={userId || "guest"}
      userId={userId}
      previewWords={previewWords}
    />
  );
}

function lookupFailureMessage(
  cause: unknown,
  userId: string,
  hasCachedWords: boolean,
) {
  if (
    cause instanceof ApiError &&
    !userId &&
    (cause.status === 401 || cause.status === 403)
  ) {
    return hasCachedWords
      ? "Guest lookup is unavailable. Showing words stored on this device."
      : "Guest lookup is unavailable. Try again later or sign in to search.";
  }
  if (cause instanceof ApiError && cause.status === 0) {
    return hasCachedWords
      ? null
      : "Could not reach the dictionary. This word has not been cached yet.";
  }
  return "Dictionary lookup failed. Please try again.";
}

function DictionaryContent({
  userId,
  previewWords,
}: {
  userId: string;
  previewWords?: DictionaryWord[];
}) {
  const { signOut } = useAuth();
  const palette = useAppPalette();
  const { l } = useI18n();
  const { fontScale } = useWindowDimensions();
  const reducedMotion = useReducedMotion();
  const pronunciation = usePronunciation();
  const personal = Boolean(userId || previewWords);
  const [tab, setTab] = useState<Tab>("search");
  const [query, setQuery] = useState("");
  const [searchFocused, setSearchFocused] = useState(false);
  const [results, setResults] = useState<DictionaryWord[]>(previewWords ?? []);
  const [saved, setSaved] = useState<SavedWord[]>([]);
  const [memberRecent, setRecent] = useState<string[]>([]);
  const guestRecent = useGuestRecent((state) => state.words);
  const recent = userId ? memberRecent : guestRecent;
  const [daily, setDaily] = useState<DictionaryWord[]>([]);
  const [dailyDetail, setDailyDetail] = useState<DictionaryWord | null>(null);
  const request = useRef({ version: 0, term: null as string | null });
  useLayoutEffect(
    () => () => {
      request.current.version++;
    },
    [],
  );
  useEffect(() => {
    let live = true;
    let timer: ReturnType<typeof setTimeout>;
    function update() {
      clearTimeout(timer);
      const now = new Date();
      const nextDay = new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate() + 1,
      );
      void loadDailyVocabulary(now).then((words) => {
        if (live) setDaily(words);
      });
      timer = setTimeout(update, nextDay.getTime() - now.getTime());
    }
    update();
    const subscription = AppState.addEventListener("change", (state) => {
      if (state === "active") update();
    });
    return () => {
      live = false;
      clearTimeout(timer);
      subscription.remove();
    };
  }, []);
  const [loading, setLoading] = useState(!previewWords);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [lookupError, setLookupError] = useState<string | null>(null);
  const [offline, setOffline] = useState(false);
  const [flashcardIndex, setFlashcardIndex] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [searchPage, setSearchPage] = useState(1);
  const [savedPage, setSavedPage] = useState(1);

  async function loadSaved(id: string) {
    const cached = await getCachedSavedWords(id);
    setSaved(cached);
    try {
      const remote = await listSavedWords();
      const pendingIds = new Set(
        (await listEvents(id))
          .filter(
            (event) => event.status === "pending" && event.kind === "save_word",
          )
          .map((event) => (event.payload as { wordId: string }).wordId),
      );
      const merged = [
        ...remote,
        ...cached.filter(
          (item) =>
            pendingIds.has(item.word.id) &&
            !remote.some((entry) => entry.word.id === item.word.id),
        ),
      ];
      setSaved(merged);
      await cacheSavedWords(id, merged);
    } catch (cause) {
      if (cause instanceof ApiError && cause.status === 401) {
        void signOut();
        return;
      }
      setOffline(true);
    }
  }

  useEffect(() => {
    if (previewWords) return;
    let live = true;
    const initial = request.current.version;
    const isInitial = () => live && request.current.version === initial;
    void (async () => {
      try {
        const [cached, past, stored] = await Promise.all([
          searchCachedWords(""),
          userId ? getRecentSearches(userId) : [],
          userId ? getCachedSavedWords(userId) : [],
        ]);
        if (!live) return;
        if (isInitial()) setResults(cached);
        setRecent(past);
        setSaved(stored);
        try {
          const [remoteWords, remoteSaved] = await Promise.all([
            searchDictionary("", Boolean(userId)),
            userId ? listSavedWords() : [],
          ]);
          if (!live) return;
          const events = userId ? await listEvents(userId) : [];
          const pendingIds = new Set(
            events
              .filter(
                (event) =>
                  event.status === "pending" && event.kind === "save_word",
              )
              .map((event) => (event.payload as { wordId: string }).wordId),
          );
          const merged = [
            ...remoteSaved,
            ...stored.filter(
              (item) =>
                pendingIds.has(item.word.id) &&
                !remoteSaved.some((entry) => entry.word.id === item.word.id),
            ),
          ];
          if (isInitial()) {
            setResults(remoteWords);
            setOffline(false);
          }
          setSaved(merged);
          await Promise.all([
            cacheWords(remoteWords),
            userId ? cacheSavedWords(userId, merged) : undefined,
          ]);
        } catch (cause) {
          if (
            live &&
            userId &&
            cause instanceof ApiError &&
            cause.status === 401
          ) {
            void signOut();
            return;
          }
          if (isInitial()) {
            setOffline(cause instanceof ApiError && cause.status === 0);
            setLookupError(
              lookupFailureMessage(cause, userId, cached.length > 0),
            );
          }
        }
      } catch {
        if (isInitial())
          setLookupError(
            "Could not open the dictionary cache. Please try again.",
          );
      } finally {
        if (isInitial()) setLoading(false);
      }
    })();
    return () => {
      live = false;
    };
  }, [userId, signOut, previewWords]);

  async function search(value = query) {
    const term = value.trim().toLocaleLowerCase();
    if (request.current.term === term) return;
    const version = ++request.current.version;
    request.current.term = term;
    const current = () => request.current.version === version;
    setTab("search");
    setDailyDetail(null);
    setQuery(value);
    setSearchPage(1);
    setLoading(true);
    setError(null);
    setLookupError(null);
    async function record(words: DictionaryWord[]) {
      if (!current() || !term || !words.length) return;
      if (userId) {
        await rememberSearch(userId, term);
        const history = await getRecentSearches(userId);
        if (current()) setRecent(history);
      } else useGuestRecent.getState().add(term);
    }
    try {
      if (previewWords) {
        const words = filterCachedWords(previewWords, term);
        setResults(words);
        await record(words);
        return;
      }
      const cached = await searchCachedWords(term).catch(() => []);
      if (!current()) return;
      const editorial = curatedWords.filter(
        (word) =>
          word.term === term || word.translation?.toLocaleLowerCase() === term,
      );
      if (term === duckVerb.term) editorial.push(duckVerb);
      const fallback = [
        ...cached,
        ...editorial.filter(
          (word) =>
            !cached.some(
              (entry) =>
                entry.id === word.id ||
                (entry.term === word.term &&
                  entry.translation === word.translation &&
                  entry.part_of_speech === word.part_of_speech),
            ),
        ),
      ];
      setResults(fallback);
      let words: DictionaryWord[];
      try {
        const remote = await searchDictionary(term, Boolean(userId));
        if (!current()) return;
        words = remote.length ? remote : editorial;
        setResults(words);
        setOffline(false);
        void cacheWords(words).catch(() => undefined);
      } catch (cause) {
        if (!current()) return;
        if (userId && cause instanceof ApiError && cause.status === 401) {
          void signOut();
          return;
        }
        words = fallback;
        setOffline(cause instanceof ApiError && cause.status === 0);
        setLookupError(
          lookupFailureMessage(cause, userId, fallback.length > 0),
        );
      }
      await record(words).catch(() => undefined);
    } finally {
      if (current()) {
        request.current.term = null;
        setLoading(false);
      }
    }
  }

  async function toggleSaved(word: DictionaryWord) {
    if (previewWords) {
      setSaved((previous) =>
        previous.some((item) => item.word.id === word.id)
          ? previous.filter((item) => item.word.id !== word.id)
          : [
              {
                id: word.id,
                word,
                created_at: new Date().toISOString(),
                next_review_at: null,
              },
              ...previous,
            ],
      );
      return;
    }
    if (!userId) {
      usePendingDestination.getState().set("/dictionary");
      router.push("/login-required");
      return;
    }
    if (word.id.startsWith("curated:") || word.id.startsWith("public-lookup:"))
      return;
    setBusyId(word.id);
    setError(null);
    try {
      const alreadySaved = saved.some((item) => item.word.id === word.id);
      if (offline && alreadySaved) {
        setError("Removing saved words requires a connection.");
        return;
      }
      if (offline && !alreadySaved) {
        await queueOfflineSave(word);
        return;
      }
      if (alreadySaved) await removeSavedWord(word.id);
      else await saveWord(word.id);
      await loadSaved(userId);
    } catch (cause) {
      if (cause instanceof ApiError && cause.status === 401) {
        void signOut();
        return;
      }
      if (
        cause instanceof ApiError &&
        cause.status === 0 &&
        !saved.some((item) => item.word.id === word.id)
      ) {
        setOffline(true);
        await queueOfflineSave(word);
        return;
      }
      setError(
        cause instanceof Error ? cause.message : "Could not change saved words",
      );
    } finally {
      setBusyId(null);
    }
  }

  async function queueOfflineSave(word: DictionaryWord) {
    const existing = saved.find((item) => item.word.id === word.id);
    if (existing) return;
    const next = [
      {
        id: Crypto.randomUUID(),
        word,
        created_at: new Date().toISOString(),
        next_review_at: null,
      },
      ...saved,
    ];
    await queueEvent({
      id: Crypto.randomUUID(),
      userId,
      kind: "save_word",
      payload: { wordId: word.id },
      status: "pending",
      attempts: 0,
      nextRetryAt: 0,
      message: null,
      createdAt: new Date().toISOString(),
      result: null,
    });
    setSaved(next);
    await cacheSavedWords(userId, next);
  }

  function speak(word: DictionaryWord) {
    setError(null);
    void pronunciation.play(word.term, word.audio_url);
  }

  const card = saved[Math.min(flashcardIndex, Math.max(saved.length - 1, 0))];
  const pagedResults = paginateDictionary(results, searchPage);
  const pagedSaved = paginateDictionary(saved, savedPage);
  const section =
    tab === "search"
      ? "Dictionary results"
      : tab === "recent"
        ? "Recent searches"
        : shortcuts.find((item) => item.id === tab)?.label;
  return (
    <Page title="Dictionary" compact>
      <View
        style={{
          flexDirection: "row",
          alignItems: "center",
          gap: spacing.sm,
          padding: spacing.xs,
          paddingLeft: spacing.lg,
          backgroundColor: palette.input,
          borderWidth: 1,
          borderRadius: radius.xl,
          borderColor: searchFocused ? palette.primary : palette.border,
        }}
      >
        <TextInput
          accessibilityLabel={l("English word or Vietnamese meaning")}
          placeholder={l("Try curious or tò mò")}
          placeholderTextColor={palette.muted}
          value={query}
          onChangeText={(value) => {
            setQuery(value);
            setSearchPage(1);
          }}
          onFocus={() => setSearchFocused(true)}
          onBlur={() => setSearchFocused(false)}
          onSubmitEditing={() => {
            void search();
          }}
          returnKeyType="search"
          autoCapitalize="none"
          autoCorrect={false}
          style={{
            flex: 1,
            minWidth: 0,
            minHeight: 48,
            color: palette.text,
            fontFamily: typography.family.regular,
            fontSize: typography.size.md,
          }}
        />
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={l("Search dictionary")}
          onPress={() => {
            void search();
          }}
          style={({ pressed }) => ({
            width: 48,
            height: 48,
            alignItems: "center",
            justifyContent: "center",
            borderRadius: radius.lg,
            backgroundColor: palette.primary,
            opacity: pressed ? 0.72 : 1,
          })}
        >
          <SymbolView
            name={{ ios: "magnifyingglass", android: "search", web: "search" }}
            size={23}
            tintColor={palette.primaryOn}
            fallback={<AppText style={{ color: palette.primaryOn }}>⌕</AppText>}
          />
        </Pressable>
      </View>
      <View style={{ flexDirection: "row", flexWrap: "wrap", gap: spacing.sm }}>
        {shortcuts.map((item) => {
          const selected = tab === item.id;
          return (
            <Pressable
              key={item.id}
              accessibilityRole="button"
              accessibilityLabel={
                item.id === "saved"
                  ? `${l(item.label)} (${saved.length})`
                  : l(item.label)
              }
              accessibilityState={{ selected }}
              onPress={() => {
                if (!personal && item.id !== "recent") {
                  usePendingDestination.getState().set("/dictionary");
                  router.push("/login-required");
                  return;
                }
                setTab(selected ? "search" : item.id);
                setError(null);
              }}
              style={({ pressed }) => ({
                flexGrow: 1,
                flexBasis: fontScale > 1.45 ? "46%" : "29%",
                minHeight: 62,
                alignItems: "center",
                justifyContent: "center",
                padding: spacing.sm,
                gap: spacing.xs,
                borderRadius: radius.lg,
                borderWidth: 1,
                borderColor: selected ? palette.primary : palette.border,
                backgroundColor:
                  selected || pressed ? palette.primarySoft : palette.surface,
              })}
            >
              <SymbolView
                name={item.icon}
                size={19}
                tintColor={selected ? palette.primary : palette.muted}
              />
              <AppText
                variant="caption"
                tone={selected ? "primary" : "default"}
                style={{ textAlign: "center" }}
              >
                {l(item.label)}
                {item.id === "saved" ? ` (${saved.length})` : ""}
              </AppText>
            </Pressable>
          );
        })}
      </View>
      {offline && (
        <AppCard tone="reward">
          <AppText variant="label">Offline cache</AppText>
          <AppText tone="muted">
            Showing cached words. New saves wait for synchronization; removing
            words needs a connection.
          </AppText>
        </AppCard>
      )}
      {!!error && (
        <ErrorState
          title="Dictionary unavailable"
          message={error}
          retry={() => {
            void (tab === "search" ? search() : loadSaved(userId));
          }}
        />
      )}
      {tab === "search" && lookupError ? (
        <ErrorState
          title="Dictionary unavailable"
          message={lookupError}
          retry={() => {
            void search();
          }}
        />
      ) : null}
      {pronunciation.error ? (
        <AppText tone="error" accessibilityRole="alert">
          {pronunciation.error}
        </AppText>
      ) : null}
      <Animated.View
        key={tab}
        entering={reducedMotion ? undefined : FadeIn.duration(motion.quick)}
        style={{ gap: spacing.md }}
      >
        {tab === "search" ? (
          <View style={{ gap: spacing.sm }}>
            <AppText variant="heading" accessibilityRole="header">
              Daily Vocabulary
            </AppText>
            <AppText tone="muted">5 new words to learn today</AppText>
            {!daily.length ? (
              <LoadingSkeleton lines={2} />
            ) : (
              daily.map((word) => (
                <View
                  key={word.id}
                  style={{
                    flexDirection: "row",
                    alignItems: "center",
                    gap: spacing.sm,
                    paddingHorizontal: spacing.md,
                    borderRadius: radius.md,
                    borderWidth: 1,
                    borderColor: palette.border,
                    backgroundColor: palette.surface,
                  }}
                >
                  <Pressable
                    accessibilityRole="button"
                    accessibilityState={{
                      expanded: dailyDetail?.id === word.id,
                    }}
                    onPress={() =>
                      setDailyDetail(dailyDetail?.id === word.id ? null : word)
                    }
                    style={{
                      flex: 1,
                      minHeight: 52,
                      justifyContent: "center",
                      paddingVertical: spacing.xs,
                    }}
                  >
                    <AppText variant="label">{word.term}</AppText>
                    <AppText variant="caption" tone="muted">
                      {[word.ipa, word.part_of_speech, word.translation]
                        .filter(Boolean)
                        .join(" · ")}
                    </AppText>
                  </Pressable>
                  <Pressable
                    accessibilityRole="button"
                    accessibilityLabel={`Pronounce ${word.term}`}
                    onPress={() => speak(word)}
                    style={{
                      width: 48,
                      height: 48,
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                  >
                    <SymbolView
                      name={{
                        ios: "speaker.wave.2.fill",
                        android: "volume_up",
                        web: "volume_up",
                      }}
                      size={20}
                      tintColor={palette.primary}
                    />
                  </Pressable>
                </View>
              ))
            )}
            {dailyDetail ? (
              <AppCard style={{ gap: spacing.sm }}>
                <AppText variant="heading">{dailyDetail.term}</AppText>
                <AppText>{dailyDetail.definition}</AppText>
                <AppText tone="muted">{dailyDetail.example}</AppText>
                {dailyDetail.id.startsWith("daily-online:") ? (
                  <>
                    <AppText variant="caption" tone="muted">
                      {dailyDetail.source_name}
                    </AppText>
                    <AppButton
                      label="Look up Vietnamese meaning"
                      variant="secondary"
                      onPress={() => {
                        void search(dailyDetail.term);
                      }}
                    />
                  </>
                ) : null}
              </AppCard>
            ) : null}
          </View>
        ) : null}
        <AppText variant="heading" accessibilityRole="header">
          {section}
        </AppText>
        {tab === "search" && (
          <>
            {loading ? (
              <LoadingSkeleton lines={4} />
            ) : results.length ? (
              <>
                {pagedResults.items.map((word) => (
                  <WordCard
                    key={word.id}
                    word={word}
                    account={userId || null}
                    saved={saved.some((item) => item.word.id === word.id)}
                    saveDisabled={
                      Boolean(busyId) ||
                      (Boolean(userId) &&
                        (word.id.startsWith("curated:") ||
                          word.id.startsWith("public-lookup:")))
                    }
                    onSave={() => {
                      void toggleSaved(word);
                    }}
                    onSpeak={() => speak(word)}
                  />
                ))}
                <DictionaryPagination
                  page={pagedResults.page}
                  totalPages={pagedResults.totalPages}
                  onChange={setSearchPage}
                />
              </>
            ) : lookupError || !query.trim() ? null : (
              <EmptyState
                title="No matching word"
                message="Try another English word or Vietnamese meaning."
              />
            )}
          </>
        )}
        {tab === "saved" &&
          (saved.length ? (
            <>
              {pagedSaved.items.map((item) => (
                <WordCard
                  key={item.id}
                  word={item.word}
                  account={userId || null}
                  saved
                  saveDisabled={Boolean(busyId)}
                  onSave={() => {
                    void toggleSaved(item.word);
                  }}
                  onSpeak={() => speak(item.word)}
                />
              ))}
              <DictionaryPagination
                page={pagedSaved.page}
                totalPages={pagedSaved.totalPages}
                onChange={setSavedPage}
              />
            </>
          ) : (
            <EmptyState
              title="No saved words"
              message="Save a word from search to make it available for flashcards."
              actionLabel="Find a word"
              onAction={() => setTab("search")}
            />
          ))}
        {tab === "recent" ? (
          <>
            {!userId ? (
              <AppText tone="muted">
                Words you&apos;ve looked up this session
              </AppText>
            ) : null}
            {recent.length ? (
              recent.map((term) => (
                <View
                  key={term}
                  style={{
                    flexDirection: "row",
                    alignItems: "center",
                    gap: spacing.sm,
                  }}
                >
                  <AppCard
                    style={{ flex: 1 }}
                    onPress={() => {
                      void search(term);
                    }}
                  >
                    <AppText variant="label">{term}</AppText>
                  </AppCard>
                  {!userId ? (
                    <Pressable
                      accessibilityRole="button"
                      accessibilityLabel={`Remove ${term}`}
                      onPress={() => useGuestRecent.getState().remove(term)}
                      style={{
                        width: 48,
                        height: 48,
                        alignItems: "center",
                        justifyContent: "center",
                      }}
                    >
                      <SymbolView
                        name={{ ios: "xmark", android: "close", web: "close" }}
                        size={20}
                        tintColor={palette.muted}
                      />
                    </Pressable>
                  ) : null}
                </View>
              ))
            ) : (
              <EmptyState
                title="No recent searches yet."
                message="Search for a word to see it here."
              />
            )}
            {!userId && recent.length > 0 ? (
              <AppButton
                label="Clear all"
                variant="secondary"
                onPress={() => useGuestRecent.getState().clear()}
              />
            ) : null}
          </>
        ) : null}
        {tab === "flashcards" &&
          (card ? (
            <AppCard tone="primary" style={{ gap: 14 }}>
              <AppText variant="caption" tone="primary">
                CARD {Math.min(flashcardIndex + 1, saved.length)} /{" "}
                {saved.length}
              </AppText>
              <AppText variant="display" style={{ textAlign: "center" }}>
                {card.word.term}
              </AppText>
              <AppText tone="muted" style={{ textAlign: "center" }}>
                {card.word.ipa}
              </AppText>
              {revealed ? (
                <>
                  <AppText variant="heading" style={{ textAlign: "center" }}>
                    {card.word.translation}
                  </AppText>
                  <AppText style={{ textAlign: "center" }}>
                    {card.word.definition}
                  </AppText>
                  <AppText tone="muted" style={{ textAlign: "center" }}>
                    {card.word.example}
                  </AppText>
                </>
              ) : (
                <AppButton
                  label="Reveal meaning"
                  onPress={() => setRevealed(true)}
                  variant="reward"
                />
              )}
              <AppButton
                label="Pronounce word"
                onPress={() => speak(card.word)}
                variant="secondary"
              />
              <AppButton
                label="Next card"
                onPress={() => {
                  setFlashcardIndex((flashcardIndex + 1) % saved.length);
                  setRevealed(false);
                }}
                variant="secondary"
              />
            </AppCard>
          ) : (
            <EmptyState
              title="Your deck is empty"
              message="Save vocabulary first to build your personal flashcards."
              actionLabel="Search words"
              onAction={() => setTab("search")}
            />
          ))}
      </Animated.View>
      <NavLink
        href={"/vocabulary-review" as Href}
        label="Review due vocabulary"
      />
      {personal ? <SyncStatus /> : null}
      <NavLink href="/home" label="Back to dashboard" />
    </Page>
  );
}
