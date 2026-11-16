"use client";

import { useCallback, useEffect, useState } from "react";
import { getSupabase } from "@/lib/client";
import styles from "./content-import-review.module.css";

type ImportBatch = {
  id: string;
  content_type: string;
  source_name: string;
  license_id: string;
  source_url: string | null;
  status: string;
  record_count: number;
  validation_errors: unknown;
  created_at: string;
};
type ImportItem = {
  id: string;
  external_id: string;
  payload: Record<string, unknown>;
  status: string;
  validation_errors: unknown;
};
const PAGE_SIZE = 15;
const asMessages = (value: unknown) =>
  Array.isArray(value) ? value.map(String) : [];

export function ContentImportReview() {
  const [batches, setBatches] = useState<ImportBatch[]>([]),
    [selected, setSelected] = useState<ImportBatch | null>(null),
    [items, setItems] = useState<ImportItem[]>([]);
  const [page, setPage] = useState(1),
    [hasNext, setHasNext] = useState(false),
    [loading, setLoading] = useState(true),
    [message, setMessage] = useState("");
  const loadBatches = useCallback(async () => {
    setLoading(true);
    setMessage("");
    const from = (page - 1) * PAGE_SIZE;
    const { data, error } = await getSupabase()
      .from("content_import_batches")
      .select(
        "id,content_type,source_name,license_id,source_url,status,record_count,validation_errors,created_at",
      )
      .order("created_at", { ascending: false })
      .range(from, from + PAGE_SIZE);
    if (error) {
      setMessage(error.message);
      setBatches([]);
    } else {
      const rows = (data ?? []) as ImportBatch[];
      setBatches(rows.slice(0, PAGE_SIZE));
      setHasNext(rows.length > PAGE_SIZE);
      if (rows.length === 0) setItems([]);
      setSelected((current) =>
        current && rows.some((row) => row.id === current.id)
          ? current
          : (rows[0] ?? null),
      );
    }
    setLoading(false);
  }, [page]);
  useEffect(() => {
    queueMicrotask(() => { void loadBatches(); });
  }, [loadBatches]);
  useEffect(() => {
    if (!selected) return;
    let active = true;
    void getSupabase()
      .from("content_import_items")
      .select("id,external_id,payload,status,validation_errors")
      .eq("batch_id", selected.id)
      .order("created_at", { ascending: true })
      .limit(100)
      .then(({ data, error }) => {
        if (!active) return;
        if (error) {
          setMessage(error.message);
          setItems([]);
        } else setItems((data ?? []) as ImportItem[]);
      });
    return () => {
      active = false;
    };
  }, [selected]);
  return (
    <section className={styles.review}>
      <div className={styles.header}>
        <div>
          <p className="eyebrow">STAGED CONTENT</p>
          <h2>Import review</h2>
          <p>
            Inspect provenance, validation results and normalized records before
            any publishing workflow.
          </p>
        </div>
        <button
          className={styles.refresh}
          type="button"
          onClick={() => void loadBatches()}
          disabled={loading}
        >
          {loading ? "Loading…" : "Refresh"}
        </button>
      </div>
      {Boolean(message) ? (
        <div role="alert" className={styles.error}>
          {message}
        </div>
      ) : null}
      <div className={styles.layout}>
        <div className={styles.batchList}>
          {batches.map((batch) => (
            <button
              type="button"
              key={batch.id}
              onClick={() => setSelected(batch)}
              className={`${styles.batch} ${selected?.id === batch.id ? styles.active : ""}`}
            >
              <span>
                <strong>{batch.source_name}</strong>
                <small>
                  {batch.content_type.replaceAll("_", " ")} ·{" "}
                  {batch.record_count} records
                </small>
              </span>
              <em>{batch.status.replaceAll("_", " ")}</em>
            </button>
          ))}
          {!loading && batches.length === 0 ? (
            <div className={styles.empty}>
              <strong>No staged imports</strong>
              <span>Run the reviewed import script to create a batch.</span>
            </div>
          ) : null}
          <div className={styles.pager}>
            <button
              type="button"
              disabled={page === 1}
              onClick={() => setPage((value) => value - 1)}
            >
              Previous
            </button>
            <span>Page {page}</span>
            <button
              type="button"
              disabled={!hasNext}
              onClick={() => setPage((value) => value + 1)}
            >
              Next
            </button>
          </div>
        </div>
        <div className={styles.inspector}>
          {selected ? (
            <>
              <div className={styles.meta}>
                <div>
                  <span>License</span>
                  <strong>{selected.license_id}</strong>
                </div>
                <div>
                  <span>Created</span>
                  <strong>
                    {new Date(selected.created_at).toLocaleString()}
                  </strong>
                </div>
              </div>
              {selected.source_url ? (
                <a href={selected.source_url} target="_blank" rel="noreferrer">
                  Open declared source ↗
                </a>
              ) : null}
              {asMessages(selected.validation_errors).map((error) => (
                <p className={styles.validation} key={error}>
                  {error}
                </p>
              ))}
              <div className={styles.items}>
                {items.map((item) => (
                  <article key={item.id}>
                    <div>
                      <strong>{item.external_id}</strong>
                      <span>{item.status}</span>
                    </div>
                    <pre>{JSON.stringify(item.payload, null, 2)}</pre>
                    {asMessages(item.validation_errors).map((error) => (
                      <p className={styles.validation} key={error}>
                        {error}
                      </p>
                    ))}
                  </article>
                ))}
              </div>
              {items.length === 0 ? (
                <div className={styles.empty}>
                  <strong>No records in this batch</strong>
                  <span>Check the importer validation output.</span>
                </div>
              ) : null}
            </>
          ) : (
            <div className={styles.empty}>
              <strong>Select an import batch</strong>
              <span>Its staged records will appear here.</span>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
