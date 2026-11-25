-- 11) Que el usuario pueda marcar como leídas las respuestas del admin
--     (sin esto el puntito rojo de soporte nunca se apagaba)
DROP POLICY IF EXISTS "soporte_update_leido_own" ON public.soporte_mensajes;
CREATE POLICY "soporte_update_leido_own" ON public.soporte_mensajes
  FOR UPDATE
  USING (empresa_id = get_mi_empresa_id())
  WITH CHECK (empresa_id = get_mi_empresa_id());
