-- Ejecuta esto en Supabase → SQL Editor
ALTER TABLE vitrina_productos
  ADD COLUMN IF NOT EXISTS precio_oferta         NUMERIC,
  ADD COLUMN IF NOT EXISTS descuento_porcentaje  NUMERIC,
  ADD COLUMN IF NOT EXISTS disponibilidad        TEXT DEFAULT 'stock',
  ADD COLUMN IF NOT EXISTS fecha_disponibilidad  DATE;
