-- =====================================================================
-- Migration 12 — last price quoted to the customer (up to 3 units + price)
-- =====================================================================
alter table public.leads add column if not exists last_quote jsonb;   -- { units:[{unit,price}], at }
