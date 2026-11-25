-- 8) Eliminar conversación completa
CREATE OR REPLACE FUNCTION public.admin_eliminar_conversacion(p_empresa_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS '
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION ''No autorizado''; END IF;
  DELETE FROM soporte_mensajes WHERE empresa_id = p_empresa_id;
END;
';

-- 9) Eliminar un mensaje
CREATE OR REPLACE FUNCTION public.admin_eliminar_mensaje(p_mensaje_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS '
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION ''No autorizado''; END IF;
  DELETE FROM soporte_mensajes WHERE id = p_mensaje_id;
END;
';

-- 10) Activar plan (también incluida aquí por si no corriste el otro archivo)
CREATE OR REPLACE FUNCTION public.admin_activar_plan(
  p_empresa_id UUID, p_plan TEXT, p_vence TIMESTAMPTZ
)
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS '
DECLARE filas INTEGER;
BEGIN
  IF NOT es_admin_actual() THEN RAISE EXCEPTION ''No autorizado''; END IF;
  UPDATE empresas SET plan_activo = p_plan, suscripcion_vence = p_vence
   WHERE id = p_empresa_id;
  GET DIAGNOSTICS filas = ROW_COUNT;
  RETURN filas;
END;
';
GRANT EXECUTE ON FUNCTION public.admin_activar_plan(UUID, TEXT, TIMESTAMPTZ) TO authenticated;
