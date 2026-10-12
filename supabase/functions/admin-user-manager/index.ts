import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Verificar JWT del caller
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'No autorizado' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Cliente con el JWT del usuario que llama
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )

    // Cliente con service role para operaciones admin
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // 2. Obtener usuario autenticado
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'No autorizado' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 3. Verificar que el caller tiene es_admin = true
    const { data: usuarioData, error: adminError } = await supabaseAdmin
      .from('usuarios')
      .select('es_admin')
      .eq('id', user.id)
      .single()

    if (adminError || !usuarioData?.es_admin) {
      return new Response(
        JSON.stringify({ error: 'No autorizado — se requiere rol de administrador' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 4. Leer el body
    const body = await req.json()
    const { accion, usuario_id, nuevo_correo, nueva_contrasena } = body

    if (!accion || !usuario_id) {
      return new Response(
        JSON.stringify({ error: 'Faltan parámetros: accion y usuario_id son requeridos' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 5. Ejecutar acción
    if (accion === 'actualizar') {
      const updates: Record<string, string> = {}
      if (nuevo_correo) updates.email = nuevo_correo
      if (nueva_contrasena) updates.password = nueva_contrasena

      if (Object.keys(updates).length === 0) {
        return new Response(
          JSON.stringify({ error: 'Debes enviar nuevo_correo o nueva_contrasena' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
        usuario_id,
        updates
      )

      if (updateError) {
        return new Response(
          JSON.stringify({ error: updateError.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Si cambió el correo, también actualizarlo en la tabla usuarios
      if (nuevo_correo) {
        await supabaseAdmin
          .from('usuarios')
          .update({ correo: nuevo_correo })
          .eq('id', usuario_id)
      }

      return new Response(
        JSON.stringify({ success: true, mensaje: 'Usuario actualizado correctamente' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (accion === 'eliminar') {
      // Primero obtener la empresa del usuario para limpiar datos
      const { data: usuarioRow } = await supabaseAdmin
        .from('usuarios')
        .select('empresa_id')
        .eq('id', usuario_id)
        .single()

      const empresaId = usuarioRow?.empresa_id

      // Eliminar el usuario de auth (cascade debería limpiar el resto con RLS/triggers)
      const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(usuario_id)

      if (deleteError) {
        return new Response(
          JSON.stringify({ error: deleteError.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Limpiar datos de la empresa si existe
      if (empresaId) {
        await supabaseAdmin.from('usuarios').delete().eq('id', usuario_id)
        await supabaseAdmin.from('empresas').delete().eq('id', empresaId)
      }

      return new Response(
        JSON.stringify({ success: true, mensaje: 'Usuario eliminado correctamente' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ error: `Acción desconocida: ${accion}` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
