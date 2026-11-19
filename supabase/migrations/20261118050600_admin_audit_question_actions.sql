-- Preserve precise V2.5 lifecycle actions in the shared immutable audit ledger.
ALTER TABLE public.admin_audit_logs DROP CONSTRAINT admin_audit_logs_action_check;
ALTER TABLE public.admin_audit_logs ADD CONSTRAINT admin_audit_logs_action_check CHECK(action IN (
 'create','update','delete','publish','unpublish',
 'transition:draft','transition:in_review','transition:published','transition:archived',
 'resolve:resolved','resolve:dismissed'
));
