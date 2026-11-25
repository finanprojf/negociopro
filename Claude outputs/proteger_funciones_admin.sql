-- ═══════════════════════════════════════════════════════════════
-- PROTEGER LAS FUNCIONES DEL ADMIN
-- Antes, cualquier usuario con conocimientos podía llamarlas desde
-- fuera de la app (leer todos los chats, publicar avisos, borrar
-- mensajes…). Ahora cada una revisa que quien la usa sea admin.
-- Se puede correr varias veces sin problema.
-- ═══════════════════════════════════════════════════════════════

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
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION 'No autorizado'; END IF;
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

-- 2) Conversación de una empresa
CREATE OR REPLACE FUNCTION public.admin_get_conversacion(p_empresa_id UUID)
RETURNS TABLE(id UUID, mensaje TEXT, es_admin BOOLEAN, leido BOOLEAN, created_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION 'No autorizado'; END IF;
  RETURN QUERY
  SELECT sm.id, sm.mensaje, sm.es_admin, sm.leido, sm.created_at
  FROM soporte_mensajes sm
  WHERE sm.empresa_id = p_empresa_id
  ORDER BY sm.created_at ASC;
END;
$$;

-- 3) Responder como admin
CREATE OR REPLACE FUNCTION public.admin_responder_soporte(p_empresa_id UUID, p_mensaje TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION 'No autorizado'; END IF;
  INSERT INTO soporte_mensajes(empresa_id, usuario_id, mensaje, es_admin, leido)
  SELECT p_empresa_id, u.id, p_mensaje, true, false
  FROM usuarios u WHERE u.empresa_id = p_empresa_id LIMIT 1;
END;
$$;

-- 4) Publicar aviso
CREATE OR REPLACE FUNCTION public.admin_publicar_aviso(p_titulo TEXT, p_mensaje TEXT, p_tipo TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION 'No autorizado'; END IF;
  INSERT INTO avisos(titulo, mensaje, tipo) VALUES (p_titulo, p_mensaje, p_tipo);
END;
$$;

-- 5) Desactivar aviso
CREATE OR REPLACE FUNCTION public.admin_desactivar_aviso(p_aviso_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION 'No autorizado'; END IF;
  UPDATE avisos SET activo = false WHERE id = p_aviso_id;
END;
$$;

-- 6) Marcar como leídos los mensajes del usuario (lo usa el admin)
CREATE OR REPLACE FUNCTION public.admin_marcar_leidos(p_empresa_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION 'No autorizado'; END IF;
  UPDATE soporte_mensajes SET leido = true
  WHERE empresa_id = p_empresa_id AND es_admin = false;
END;
$$;

-- 7) Contar respuestas sin leer.
--    OJO: esta la usa CADA USUARIO para su puntito rojo de soporte,
--    así que se permite al admin o al dueño de ESA empresa.
CREATE OR REPLACE FUNCTION public.admin_contar_no_leidos(p_empresa_id UUID)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count BIGINT;
BEGIN
  IF NOT (es_admin_actual() OR p_empresa_id = get_mi_empresa_id()) THEN
    RETURN 0;
  END IF;
  SELECT COUNT(id) INTO v_count FROM soporte_mensajes
  WHERE empresa_id = p_empresa_id AND es_admin = true AND leido = false;
  RETURN v_count;
END;
$$;

-- 8) Eliminar conversación completa
CREATE OR REPLACE FUNCTION public.admin_eliminar_conversacion(p_empresa_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION 'No autorizado'; END IF;
  DELETE FROM soporte_mensajes WHERE empresa_id = p_empresa_id;
END;
$$;

-- 9) Eliminar un mensaje
CREATE OR REPLACE FUNCTION public.admin_eliminar_mensaje(p_mensaje_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION 'No autorizado'; END IF;
  DELETE FROM soporte_mensajes WHERE id = p_mensaje_id;
END;
$$;

-- 10) Activar plan (también incluida aquí por si no corriste el otro archivo)
CREATE OR REPLACE FUNCTION public.admin_activar_plan(
  p_empresa_id UUID, p_plan TEXT, p_vence TIMESTAMPTZ
)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE filas INTEGER;
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION 'No autorizado'; END IF;
  UPDATE empresas SET plan_activo = p_plan, suscripcion_vence = p_vence
   WHERE id = p_empresa_id;
  GET DIAGNOSTICS filas = ROW_COUNT;
  RETURN filas;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_activar_plan(UUID, TEXT, TIMESTAMPTZ) TO authenticated;

-- 11) Que el usuario pueda marcar como leídas las respuestas del admin
--     (sin esto el puntito rojo de soporte nunca se apagaba)
DROP POLICY IF EXISTS "soporte_update_leido_own" ON public.soporte_mensajes;
CREATE POLICY "soporte_update_leido_own" ON public.soporte_mensajes
  FOR UPDATE
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());
