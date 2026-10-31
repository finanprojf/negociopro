-- ================================================================
-- NEGOCIOPRO - Row Level Security (RLS)
-- Ejecutar en Supabase → SQL Editor
-- ================================================================

-- ── 1. FUNCIÓN HELPER ──────────────────────────────────────────
-- usuarios.id = UUID, empresa_id = UUID → devuelve UUID
-- Casi todas las tablas tienen empresa_id como UUID
CREATE OR REPLACE FUNCTION get_mi_empresa_id()
RETURNS UUID AS $$
  SELECT empresa_id FROM usuarios WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;


-- ================================================================
-- 2. TABLAS PRINCIPALES
-- ================================================================

-- ── empresas (id = UUID) ──
ALTER TABLE empresas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "empresas_owner" ON empresas;
CREATE POLICY "empresas_owner" ON empresas
  USING (id = get_mi_empresa_id())
  WITH CHECK (id = get_mi_empresa_id());

-- ── usuarios (id = UUID) ──
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "usuarios_self" ON usuarios;
CREATE POLICY "usuarios_self" ON usuarios
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ── suscripciones (empresa_id = UUID) ──
ALTER TABLE suscripciones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "suscripciones_empresa" ON suscripciones;
CREATE POLICY "suscripciones_empresa" ON suscripciones
  USING (empresa_id = get_mi_empresa_id());

-- ── categorias (empresa_id = UUID) ──
ALTER TABLE categorias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "categorias_empresa" ON categorias;
CREATE POLICY "categorias_empresa" ON categorias
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── productos (empresa_id = UUID) ──
ALTER TABLE productos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "productos_empresa" ON productos;
CREATE POLICY "productos_empresa" ON productos
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── clientes (empresa_id = UUID) ──
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "clientes_empresa" ON clientes;
CREATE POLICY "clientes_empresa" ON clientes
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── ventas (empresa_id = UUID) ──
ALTER TABLE ventas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ventas_empresa" ON ventas;
CREATE POLICY "ventas_empresa" ON ventas
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── detalle_ventas (venta_id = UUID) ──
ALTER TABLE detalle_ventas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "detalle_ventas_empresa" ON detalle_ventas;
CREATE POLICY "detalle_ventas_empresa" ON detalle_ventas
  USING (EXISTS (
    SELECT 1 FROM ventas v
    WHERE v.id = venta_id AND v.empresa_id = get_mi_empresa_id()
  ));

-- ── fiados (empresa_id = UUID) ──
ALTER TABLE fiados ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "fiados_empresa" ON fiados;
CREATE POLICY "fiados_empresa" ON fiados
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── abonos_fiado (fiado_id = UUID, empresa_id = UUID) ──
ALTER TABLE abonos_fiado ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "abonos_fiado_empresa" ON abonos_fiado;
CREATE POLICY "abonos_fiado_empresa" ON abonos_fiado
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── apartados (empresa_id = UUID) ──
ALTER TABLE apartados ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "apartados_empresa" ON apartados;
CREATE POLICY "apartados_empresa" ON apartados
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── abonos_apartado (empresa_id = UUID) ──
ALTER TABLE abonos_apartado ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "abonos_apartado_empresa" ON abonos_apartado;
CREATE POLICY "abonos_apartado_empresa" ON abonos_apartado
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── apartado_productos (sin empresa_id → join con apartados) ──
ALTER TABLE apartado_productos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "apartado_productos_empresa" ON apartado_productos;
CREATE POLICY "apartado_productos_empresa" ON apartado_productos
  USING (EXISTS (
    SELECT 1 FROM apartados a
    WHERE a.id = apartado_id AND a.empresa_id = get_mi_empresa_id()
  ));

-- ── gastos (empresa_id = UUID) ──
ALTER TABLE gastos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "gastos_empresa" ON gastos;
CREATE POLICY "gastos_empresa" ON gastos
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── encargos (empresa_id = UUID) ──
ALTER TABLE encargos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "encargos_empresa" ON encargos;
CREATE POLICY "encargos_empresa" ON encargos
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── cierres_dia (empresa_id = TEXT → castear) ──
ALTER TABLE cierres_dia ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cierres_dia_empresa" ON cierres_dia;
CREATE POLICY "cierres_dia_empresa" ON cierres_dia
  USING (empresa_id::uuid = get_mi_empresa_id())
  WITH CHECK (empresa_id::uuid = get_mi_empresa_id());

-- ── recordatorios (empresa_id = TEXT → castear) ──
ALTER TABLE recordatorios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "recordatorios_empresa" ON recordatorios;
CREATE POLICY "recordatorios_empresa" ON recordatorios
  USING (empresa_id::uuid = get_mi_empresa_id())
  WITH CHECK (empresa_id::uuid = get_mi_empresa_id());

-- ── config_puntos (empresa_id = UUID) ──
ALTER TABLE config_puntos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "config_puntos_empresa" ON config_puntos;
CREATE POLICY "config_puntos_empresa" ON config_puntos
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── configuracion (empresa_id = UUID) ──
ALTER TABLE configuracion ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "configuracion_empresa" ON configuracion;
CREATE POLICY "configuracion_empresa" ON configuracion
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── movimientos_inventario (empresa_id = UUID) ──
ALTER TABLE movimientos_inventario ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "mov_inventario_empresa" ON movimientos_inventario;
CREATE POLICY "mov_inventario_empresa" ON movimientos_inventario
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── movimientos_puntos (empresa_id = UUID) ──
ALTER TABLE movimientos_puntos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "mov_puntos_empresa" ON movimientos_puntos;
CREATE POLICY "mov_puntos_empresa" ON movimientos_puntos
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── log_actividad (empresa_id = UUID) ──
ALTER TABLE log_actividad ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "log_actividad_empresa" ON log_actividad;
CREATE POLICY "log_actividad_empresa" ON log_actividad
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());


-- ================================================================
-- 3. VITRINA (lectura pública, escritura solo dueño)
-- ================================================================

-- ── vitrina_config (empresa_id = UUID) ──
ALTER TABLE vitrina_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vitrina_config_public_read" ON vitrina_config;
DROP POLICY IF EXISTS "vitrina_config_owner_write" ON vitrina_config;
CREATE POLICY "vitrina_config_public_read" ON vitrina_config
  FOR SELECT USING (true);
CREATE POLICY "vitrina_config_owner_write" ON vitrina_config
  FOR ALL USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── vitrina_productos (empresa_id = UUID) ──
ALTER TABLE vitrina_productos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vitrina_productos_public_read" ON vitrina_productos;
DROP POLICY IF EXISTS "vitrina_productos_owner_write" ON vitrina_productos;
CREATE POLICY "vitrina_productos_public_read" ON vitrina_productos
  FOR SELECT USING (true);
CREATE POLICY "vitrina_productos_owner_write" ON vitrina_productos
  FOR ALL USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());

-- ── vitrina_resenas (empresa_id = UUID) ──
ALTER TABLE vitrina_resenas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vitrina_resenas_public_read" ON vitrina_resenas;
DROP POLICY IF EXISTS "vitrina_resenas_public_insert" ON vitrina_resenas;
DROP POLICY IF EXISTS "vitrina_resenas_owner_manage" ON vitrina_resenas;
CREATE POLICY "vitrina_resenas_public_read" ON vitrina_resenas
  FOR SELECT USING (true);
CREATE POLICY "vitrina_resenas_public_insert" ON vitrina_resenas
  FOR INSERT WITH CHECK (true);
CREATE POLICY "vitrina_resenas_owner_manage" ON vitrina_resenas
  FOR ALL USING (empresa_id = get_mi_empresa_id());

-- ── pedidos_carta (empresa_id = UUID) ──
ALTER TABLE pedidos_carta ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pedidos_carta_public_insert" ON pedidos_carta;
DROP POLICY IF EXISTS "pedidos_carta_empresa_read" ON pedidos_carta;
DROP POLICY IF EXISTS "pedidos_carta_empresa_update" ON pedidos_carta;
CREATE POLICY "pedidos_carta_public_insert" ON pedidos_carta
  FOR INSERT WITH CHECK (true);
CREATE POLICY "pedidos_carta_empresa_read" ON pedidos_carta
  FOR SELECT USING (empresa_id = get_mi_empresa_id());
CREATE POLICY "pedidos_carta_empresa_update" ON pedidos_carta
  FOR UPDATE USING (empresa_id = get_mi_empresa_id());


-- ================================================================
-- LISTO ✓ - Todas las tablas protegidas
-- ================================================================
SELECT 'RLS habilitado correctamente en todas las tablas' AS resultado;
