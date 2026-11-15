import assert from 'node:assert/strict';
import { test } from 'node:test';
import { checkGeminiModel, GenerationError } from '../supabase/functions/_shared/real-english-generator.ts';

const model = 'gemini-2.5-flash-lite';
const stub = (status, body, expectedModel = model) => async (url, options) => {
  assert.equal(url, `https://generativelanguage.googleapis.com/v1beta/models/${expectedModel}`);
  assert.equal(options.headers['x-goog-api-key'], 'test-only');
  return new Response(JSON.stringify(body), { status });
};

test('available model supports generation without invoking generateContent', async () => {
  await checkGeminiModel(model, 'test-only', stub(200, {
    name: `models/${model}`, supportedGenerationMethods: ['generateContent'],
  }));
});

test('unavailable model is rejected before spending a generation attempt', async () => {
  await assert.rejects(() => checkGeminiModel(model, 'test-only', stub(404, {})),
    (error) => error instanceof GenerationError && error.kind === 'configuration');
});

test('model without generateContent is rejected', async () => {
  await assert.rejects(() => checkGeminiModel(model, 'test-only', stub(200, {
    name: `models/${model}`, supportedGenerationMethods: ['countTokens'],
  })), (error) => error instanceof GenerationError && error.kind === 'configuration');
});

test('newer Free tier model is accepted when available to this key', async () => {
  const newer = 'gemini-3.5-flash-lite';
  await checkGeminiModel(newer, 'test-only', stub(200, {
    name: `models/${newer}`, supportedGenerationMethods: ['generateContent'],
  }, newer));
});
