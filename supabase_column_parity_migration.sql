-- ============================================================
-- NegocioPro — Column Parity Migration
-- Ejecutar en Supabase SQL Editor (Dashboard → SQL Editor)
-- Todas las sentencias usan IF NOT EXISTS / IF EXISTS
-- Es seguro ejecutar múltiples veces.
-- ============================================================

-- ------------------------------------------------------------
-- 1. detalle_ventas — precio_compra para calcular ganancias
-- (es posible que ya lo hayas corrido antes)
-- ------------------------------------------------------------
ALTER TABLE detalle_ventas ADD COLUMN IF NOT EXISTS precio_compra REAL DEFAULT 0;

-- Backfill: rellenar precio_compra desde productos donde falta
UPDATE detalle_ventas dv
SET precio_compra = p.precio_compra
FROM productos p
WHERE dv.producto_id = p.id
  AND p.precio_compra > 0
  AND (dv.precio_compra IS NULL OR dv.precio_compra = 0);

-- ------------------------------------------------------------
-- 2. productos — campos de productos elaborados y precios oferta
-- ------------------------------------------------------------
ALTER TABLE productos ADD COLUMN IF NOT EXISTS es_elaborado BOOLEAN DEFAULT false;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS costo_produccion REAL DEFAULT 0;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS unidades_producidas REAL DEFAULT 1;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS precio_oferta REAL;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS descuento_porcentaje REAL;

-- ------------------------------------------------------------
-- 3. cierres_dia — ganancia_real (diferencia venta - costo)
-- ------------------------------------------------------------
ALTER TABLE cierres_dia ADD COLUMN IF NOT EXISTS ganancia_real REAL DEFAULT 0;

-- ------------------------------------------------------------
-- 4. abonos_apartado — tipo (abono vs pago completo)
-- ------------------------------------------------------------
ALTER TABLE abonos_apartado ADD COLUMN IF NOT EXISTS tipo TEXT DEFAULT 'abono';

-- ------------------------------------------------------------
-- 5. encargos — cliente_nombre (desnormalizado) + costo_pedido
-- ------------------------------------------------------------
ALTER TABLE encargos ADD COLUMN IF NOT EXISTS cliente_nombre TEXT;
ALTER TABLE encargos ADD COLUMN IF NOT EXISTS costo_pedido REAL DEFAULT 0;

-- ------------------------------------------------------------
-- 6. fiados — cliente_nombre + cliente_telefono (desnormalizados)
-- ------------------------------------------------------------
ALTER TABLE fiados ADD COLUMN IF NOT EXISTS cliente_nombre TEXT;
ALTER TABLE fiados ADD COLUMN IF NOT EXISTS cliente_telefono TEXT;

-- ------------------------------------------------------------
-- 7. apartados — cliente_nombre + cliente_telefono (desnormalizados)
-- ------------------------------------------------------------
ALTER TABLE apartados ADD COLUMN IF NOT EXISTS cliente_nombre TEXT;
ALTER TABLE apartados ADD COLUMN IF NOT EXISTS cliente_telefono TEXT;

-- ------------------------------------------------------------
-- 8. apartado_productos — tabla completa (ítems de un apartado)
-- Copia exacta de la estructura local SQLite
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS apartado_productos (
  id          TEXT PRIMARY KEY,
  apartado_id TEXT NOT NULL,
  empresa_id  TEXT NOT NULL,
  producto_id TEXT,
  nombre      TEXT NOT NULL,
  cantidad    REAL NOT NULL DEFAULT 1,
  precio      REAL NOT NULL DEFAULT 0,
  costo       REAL,
  entregado   BOOLEAN DEFAULT false,
  fecha_entrega TEXT,
  created_at  TEXT
);

-- Índice para consultas rápidas por apartado
CREATE INDEX IF NOT EXISTS idx_apartado_productos_apartado
  ON apartado_productos (apartado_id);

CREATE INDEX IF NOT EXISTS idx_apartado_productos_empresa
  ON apartado_productos (empresa_id);

-- RLS (Row Level Security)
ALTER TABLE apartado_productos ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'apartado_productos' AND policyname = 'empresa_policy'
  ) THEN
    CREATE POLICY empresa_policy ON apartado_productos
      FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ------------------------------------------------------------
-- 9. recordatorios — tabla completa (con synced para multi-device)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recordatorios (
  id            TEXT PRIMARY KEY,
  empresa_id    TEXT NOT NULL,
  titulo        TEXT NOT NULL,
  cliente_id    TEXT,
  cliente_nombre TEXT,
  fecha         TEXT NOT NULL,
  hora          TEXT,
  completado    BOOLEAN DEFAULT false,
  created_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_recordatorios_empresa_fecha
  ON recordatorios (empresa_id, fecha);

ALTER TABLE recordatorios ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'recordatorios' AND policyname = 'empresa_policy'
  ) THEN
    CREATE POLICY empresa_policy ON recordatorios
      FOR ALL TO authenticated USING (true) WITH CHECK (true);
  END IF;
END $$;

-- ============================================================
-- FIN — verificar con:
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_name = 'productos' ORDER BY ordinal_position;
-- ============================================================
