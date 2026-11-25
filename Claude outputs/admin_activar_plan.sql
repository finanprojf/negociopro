-- ═══════════════════════════════════════════════════════════════
-- Activar plan desde el Panel Admin
-- Problema: la regla de seguridad (RLS) de "empresas" solo deja a
-- cada usuario modificar SU PROPIA empresa. Cuando el admin activaba
-- el plan de otro negocio, Supabase no cambiaba nada (0 filas) y
-- tampoco daba error → la app decía "¡Plan activado!" pero no.
-- Solución: una función que corre con permisos de servidor, pero que
-- SOLO funciona si quien la llama es admin (usuarios.es_admin = true).
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.admin_activar_plan(
  p_empresa_id UUID,
  p_plan       TEXT,
  p_vence      TIMESTAMPTZ
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  filas INTEGER;
BEGIN
  -- Solo administradores
  IF NOT EXISTS (
    SELECT 1 FROM usuarios WHERE id = auth.uid() AND es_admin = true
  ) THEN
    RAISE EXCEPTION 'No autorizado';
  END IF;

  UPDATE empresas
     SET plan_activo = p_plan,
         suscripcion_vence = p_vence
   WHERE id = p_empresa_id;

  GET DIAGNOSTICS filas = ROW_COUNT;
  RETURN filas;  -- 1 = activado, 0 = no se encontró la empresa
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_activar_plan(UUID, TEXT, TIMESTAMPTZ) TO authenticated;
