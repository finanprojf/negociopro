-- =============================================
-- VITRINA DIGITAL — NegocioPro
-- Ejecutar en Supabase SQL Editor
-- =============================================

-- 1. Tabla de configuración de vitrina
CREATE TABLE IF NOT EXISTS vitrina_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  activa BOOLEAN DEFAULT false,
  slug TEXT UNIQUE, -- ej: "colmado-pedro" → negociopro.vercel.app/t/colmado-pedro
  delivery_disponible BOOLEAN DEFAULT false,
  precio_delivery NUMERIC(10,2) DEFAULT 0,
  zona_delivery TEXT, -- ej: "Solo sector Los Mina"
  horario TEXT,       -- ej: "Lun-Sáb 8am-8pm"
  mensaje_bienvenida TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(empresa_id)
);

-- 2. Tabla de productos visibles en vitrina
-- (relación entre empresa y qué productos mostrar)
CREATE TABLE IF NOT EXISTS vitrina_productos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  producto_id UUID NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  visible BOOLEAN DEFAULT true,
  orden INT DEFAULT 0,
  UNIQUE(empresa_id, producto_id)
);

-- 3. RLS — Lectura pública (sin auth) para la vitrina web
ALTER TABLE vitrina_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE vitrina_productos ENABLE ROW LEVEL SECURITY;

-- Cualquiera puede leer vitrina_config (solo la activa)
CREATE POLICY "vitrina_config_public_read" ON vitrina_config
  FOR SELECT USING (activa = true);

-- El dueño puede leer/escribir su propia config
CREATE POLICY "vitrina_config_owner" ON vitrina_config
  FOR ALL USING (
    empresa_id IN (
      SELECT empresa_id FROM usuarios WHERE id = auth.uid()
    )
  );

-- Lectura pública de vitrina_productos
CREATE POLICY "vitrina_productos_public_read" ON vitrina_productos
  FOR SELECT USING (visible = true);

-- El dueño puede gestionar sus productos en vitrina
CREATE POLICY "vitrina_productos_owner" ON vitrina_productos
  FOR ALL USING (
    empresa_id IN (
      SELECT empresa_id FROM usuarios WHERE id = auth.uid()
    )
  );

-- 4. Lectura pública de productos (para la vitrina)
-- Si ya tienes RLS en productos, agrega esta policy:
CREATE POLICY "productos_public_vitrina" ON productos
  FOR SELECT USING (
    activo = true AND empresa_id IN (
      SELECT empresa_id FROM vitrina_config WHERE activa = true
    )
  );

-- 5. Lectura pública de empresas (solo campos necesarios para vitrina)
-- La vitrina necesita nombre, whatsapp, direccion, logo_url, lema
CREATE POLICY "empresas_public_vitrina" ON empresas
  FOR SELECT USING (
    id IN (SELECT empresa_id FROM vitrina_config WHERE activa = true)
  );
