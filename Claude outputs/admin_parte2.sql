-- 4) Publicar aviso
CREATE OR REPLACE FUNCTION public.admin_publicar_aviso(p_titulo TEXT, p_mensaje TEXT, p_tipo TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS '
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION ''No autorizado''; END IF;
  INSERT INTO avisos(titulo, mensaje, tipo) VALUES (p_titulo, p_mensaje, p_tipo);
END;
';

-- 5) Desactivar aviso
CREATE OR REPLACE FUNCTION public.admin_desactivar_aviso(p_aviso_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS '
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION ''No autorizado''; END IF;
  UPDATE avisos SET activo = false WHERE id = p_aviso_id;
END;
';

-- 6) Marcar como leídos los mensajes del usuario (lo usa el admin)
CREATE OR REPLACE FUNCTION public.admin_marcar_leidos(p_empresa_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS '
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION ''No autorizado''; END IF;
  UPDATE soporte_mensajes SET leido = true
  WHERE empresa_id = p_empresa_id AND es_admin = false;
END;
';

-- 7) Contar respuestas sin leer.
--    OJO: esta la usa CADA USUARIO para su puntito rojo de soporte,
--    así que se permite al admin o al dueño de ESA empresa.
CREATE OR REPLACE FUNCTION public.admin_contar_no_leidos(p_empresa_id UUID)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS '
DECLARE v_count BIGINT;
BEGIN
  IF NOT (es_admin_actual() OR p_empresa_id = get_mi_empresa_id()) THEN
    RETURN 0;
  END IF;
  SELECT COUNT(id) INTO v_count FROM soporte_mensajes
  WHERE empresa_id = p_empresa_id AND es_admin = true AND leido = false;
  RETURN v_count;
END;
';
