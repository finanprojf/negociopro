-- 0) Ayudante: ¿el usuario actual es admin?
CREATE OR REPLACE FUNCTION public.es_admin_actual()
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS 'SELECT EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND es_admin = true)';

-- 1) Todas las conversaciones
CREATE OR REPLACE FUNCTION public.admin_get_all_mensajes()
RETURNS TABLE(
  empresa_id UUID, empresa_nombre TEXT,
  usuario_id UUID, usuario_correo TEXT,
  ultimo_mensaje TEXT, ultimo_at TIMESTAMPTZ,
  no_leidos BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS '
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION ''No autorizado''; END IF;
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
';

-- 2) Conversación de una empresa
CREATE OR REPLACE FUNCTION public.admin_get_conversacion(p_empresa_id UUID)
RETURNS TABLE(id UUID, mensaje TEXT, es_admin BOOLEAN, leido BOOLEAN, created_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS '
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION ''No autorizado''; END IF;
  RETURN QUERY
  SELECT sm.id, sm.mensaje, sm.es_admin, sm.leido, sm.created_at
  FROM soporte_mensajes sm
  WHERE sm.empresa_id = p_empresa_id
  ORDER BY sm.created_at ASC;
END;
';

-- 3) Responder como admin
CREATE OR REPLACE FUNCTION public.admin_responder_soporte(p_empresa_id UUID, p_mensaje TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS '
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION ''No autorizado''; END IF;
  INSERT INTO soporte_mensajes(empresa_id, usuario_id, mensaje, es_admin, leido)
  SELECT p_empresa_id, u.id, p_mensaje, true, false
  FROM usuarios u WHERE u.empresa_id = p_empresa_id LIMIT 1;
END;
';
