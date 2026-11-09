-- ══════════════════════════════════════════════════════════════
-- TABLAS
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.avisos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  titulo      TEXT NOT NULL,
  mensaje     TEXT NOT NULL,
  tipo        TEXT NOT NULL DEFAULT 'info',  -- 'info' | 'warning' | 'success'
  activo      BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.soporte_mensajes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id      UUID REFERENCES public.empresas(id) ON DELETE CASCADE,
  usuario_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  mensaje         TEXT NOT NULL,
  es_admin        BOOLEAN NOT NULL DEFAULT false,
  leido           BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.avisos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.soporte_mensajes ENABLE ROW LEVEL SECURITY;

-- Avisos: todos pueden leer los activos
CREATE POLICY "avisos_read" ON public.avisos
  FOR SELECT USING (activo = true);

-- Soporte: usuario solo ve sus propios mensajes
CREATE POLICY "soporte_read_own" ON public.soporte_mensajes
  FOR SELECT USING (usuario_id = auth.uid());

CREATE POLICY "soporte_insert_own" ON public.soporte_mensajes
  FOR INSERT WITH CHECK (usuario_id = auth.uid() AND es_admin = false);

-- ══════════════════════════════════════════════════════════════
-- RPCs (SECURITY DEFINER = bypass RLS para admin)
-- ══════════════════════════════════════════════════════════════

-- 1) Obtener todas las conversaciones (admin)
CREATE OR REPLACE FUNCTION public.admin_get_all_mensajes()
RETURNS TABLE(
  empresa_id UUID, empresa_nombre TEXT,
  usuario_id UUID, usuario_correo TEXT,
  ultimo_mensaje TEXT, ultimo_at TIMESTAMPTZ,
  no_leidos BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT
    sm.empresa_id,
    e.nombre AS empresa_nombre,
    sm.usuario_id,
    u.correo AS usuario_correo,
    (SELECT sm2.mensaje FROM soporte_mensajes sm2 WHERE sm2.empresa_id = sm.empresa_id ORDER BY sm2.created_at DESC LIMIT 1) AS ultimo_mensaje,
    (SELECT sm3.created_at FROM soporte_mensajes sm3 WHERE sm3.empresa_id = sm.empresa_id ORDER BY sm3.created_at DESC LIMIT 1) AS ultimo_at,
    COUNT(sm4.id) FILTER (WHERE sm4.leido = false AND sm4.es_admin = false) AS no_leidos
  FROM soporte_mensajes sm
  JOIN empresas e ON e.id = sm.empresa_id
  JOIN usuarios u ON u.id = sm.usuario_id
  LEFT JOIN soporte_mensajes sm4 ON sm4.empresa_id = sm.empresa_id AND sm4.leido = false AND sm4.es_admin = false
  GROUP BY sm.empresa_id, e.nombre, sm.usuario_id, u.correo;
END;
$$;

-- 2) Conversacion completa por empresa (admin)
CREATE OR REPLACE FUNCTION public.admin_get_conversacion(p_empresa_id UUID)
RETURNS TABLE(id UUID, mensaje TEXT, es_admin BOOLEAN, leido BOOLEAN, created_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT sm.id, sm.mensaje, sm.es_admin, sm.leido, sm.created_at
  FROM soporte_mensajes sm
  WHERE sm.empresa_id = p_empresa_id
  ORDER BY sm.created_at ASC;
END;
$$;

-- 3) Responder como admin
CREATE OR REPLACE FUNCTION public.admin_responder_soporte(p_empresa_id UUID, p_mensaje TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO soporte_mensajes(empresa_id, usuario_id, mensaje, es_admin, leido)
  SELECT p_empresa_id, u.id, p_mensaje, true, true
  FROM usuarios u WHERE u.empresa_id = p_empresa_id LIMIT 1;
END;
$$;

-- 4) Publicar aviso (admin)
CREATE OR REPLACE FUNCTION public.admin_publicar_aviso(p_titulo TEXT, p_mensaje TEXT, p_tipo TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO avisos(titulo, mensaje, tipo) VALUES (p_titulo, p_mensaje, p_tipo);
END;
$$;

-- 5) Desactivar aviso (admin)
CREATE OR REPLACE FUNCTION public.admin_desactivar_aviso(p_aviso_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE avisos SET activo = false WHERE id = p_aviso_id;
END;
$$;

-- 6) Marcar mensajes como leidos
CREATE OR REPLACE FUNCTION public.admin_marcar_leidos(p_empresa_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE soporte_mensajes SET leido = true
  WHERE empresa_id = p_empresa_id AND es_admin = false;
END;
$$;

-- 7) Contar no leidos de un usuario
CREATE OR REPLACE FUNCTION public.admin_contar_no_leidos(p_empresa_id UUID)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count BIGINT;
BEGIN
  SELECT COUNT(id) INTO v_count FROM soporte_mensajes
  WHERE empresa_id = p_empresa_id AND es_admin = true AND leido = false;
  RETURN v_count;
END;
$$;

-- 8) Eliminar conversacion completa (admin)
CREATE OR REPLACE FUNCTION public.admin_eliminar_conversacion(p_empresa_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM soporte_mensajes WHERE empresa_id = p_empresa_id;
END;
$$;

-- 9) Eliminar mensaje individual (admin)
CREATE OR REPLACE FUNCTION public.admin_eliminar_mensaje(p_mensaje_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM soporte_mensajes WHERE id = p_mensaje_id;
END;
$$;
