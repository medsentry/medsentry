import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function isStrongPassword(password: string): boolean {
  return password.length >= 8 && /[A-Za-z]/.test(password) && /\d/.test(password);
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  const authorization = request.headers.get('Authorization');
  const token = authorization?.replace(/^Bearer\s+/i, '');
  const apiKey = request.headers.get('apikey');
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!token || !apiKey || !url || !serviceKey) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const adminClient = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: authData, error: authError } = await adminClient.auth.getUser(token);
  if (authError || !authData.user) return jsonResponse({ error: 'Unauthorized' }, 401);

  let { data: actor } = await adminClient
    .from('users')
    .select('id, role, clinic_id, is_active, auth_user_id')
    .eq('auth_user_id', authData.user.id)
    .maybeSingle();

  if (!actor && authData.user.email) {
    const { data: byEmail } = await adminClient
      .from('users')
      .select('id, role, clinic_id, is_active, auth_user_id')
      .ilike('email', authData.user.email)
      .maybeSingle();

    if (byEmail) {
      actor = byEmail;
      if (byEmail.auth_user_id !== authData.user.id) {
        await adminClient
          .from('users')
          .update({ auth_user_id: authData.user.id })
          .eq('id', byEmail.id);
      }
    }
  }

  const isEmailSuperAdmin = authData.user.email?.toLowerCase() === 'superadmin@gmail.com';
  const isMetaSuperAdmin =
    authData.user.user_metadata?.role === 'super_admin' ||
    authData.user.app_metadata?.role === 'super_admin';

  if (!actor && (isEmailSuperAdmin || isMetaSuperAdmin)) {
    const { data: createdSuperAdmin } = await adminClient
      .from('users')
      .upsert(
        {
          auth_user_id: authData.user.id,
          email: authData.user.email ?? 'superadmin@gmail.com',
          first_name: authData.user.user_metadata?.first_name ?? 'System',
          last_name: authData.user.user_metadata?.last_name ?? 'SuperAdmin',
          role: 'super_admin',
          clinic_id: null,
          is_active: true,
        },
        { onConflict: 'auth_user_id' }
      )
      .select('id, role, clinic_id, is_active, auth_user_id')
      .maybeSingle();
    if (createdSuperAdmin) {
      actor = createdSuperAdmin;
    }
  }

  const actorRole = (actor?.role || '').toLowerCase();
  const isAdminOrSuper =
    actorRole === 'admin' ||
    actorRole === 'super_admin' ||
    actorRole === 'superadmin' ||
    isEmailSuperAdmin;

  if (!actor || !isAdminOrSuper || actor.is_active === false) {
    return jsonResponse({ error: 'Administrator access required' }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ error: 'Invalid request body' }, 400);
  }

  if (body.action === 'set_password') {
    const targetProfileId = body.target_user_id;
    const password = body.password;
    if (typeof targetProfileId !== 'string' || typeof password !== 'string' || !isStrongPassword(password)) {
      return jsonResponse({ error: 'Invalid password request' }, 400);
    }

    const { data: target, error: targetError } = await adminClient
      .from('users')
      .select('auth_user_id, clinic_id, role')
      .eq('id', targetProfileId)
      .maybeSingle();
    if (targetError || !target?.auth_user_id) return jsonResponse({ error: 'User not found' }, 404);

    if (actorRole === 'admin' && target.clinic_id !== actor.clinic_id) {
      return jsonResponse({ error: 'Cannot manage users from other clinics' }, 403);
    }

    const { error } = await adminClient.auth.admin.updateUserById(target.auth_user_id, { password });
    if (error) return jsonResponse({ error: 'Unable to update Auth credentials' }, 400);

    try {
      await adminClient.from('audit_logs').insert({
        clinic_id: target.clinic_id,
        user_id: actor.id,
        action: 'RESET_PASSWORD',
        entity_type: 'users',
        entity_id: targetProfileId,
      });
    } catch (auditErr) {
      console.error('Audit reset password write error:', auditErr);
    }
    return jsonResponse({ updated: true });
  }

  if (body.action !== 'create') return jsonResponse({ error: 'Unsupported action' }, 400);

  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const firstName = typeof body.first_name === 'string' ? body.first_name.trim() : '';
  const lastName = typeof body.last_name === 'string' ? body.last_name.trim() : '';
  const role = typeof body.role === 'string' ? body.role.trim() : '';
  const clinicId =
    typeof body.clinic_id === 'string' && body.clinic_id.trim().length > 0
      ? body.clinic_id.trim()
      : null;
  const licenseNumber =
    typeof body.license_number === 'string' && body.license_number.trim().length > 0
      ? body.license_number.trim()
      : null;
  const specialization =
    typeof body.specialization === 'string' && body.specialization.trim().length > 0
      ? body.specialization.trim()
      : null;
  const contactNumber =
    typeof body.contact_number === 'string' && body.contact_number.trim().length > 0
      ? body.contact_number.trim()
      : null;

  if (
    !email.includes('@') ||
    !isStrongPassword(password) ||
    !firstName ||
    !lastName ||
    (role !== 'admin' && role !== 'staff' && role !== 'super_admin')
  ) {
    return jsonResponse({ error: 'Invalid user details' }, 400);
  }

  if (actorRole === 'admin') {
    if (role === 'super_admin') {
      return jsonResponse({ error: 'Administrator cannot create super administrators' }, 403);
    }
    if (clinicId !== actor.clinic_id) {
      return jsonResponse({ error: 'Administrator can only create users in their assigned clinic' }, 403);
    }
  }

  if ((role === 'admin' || role === 'staff') && !clinicId) {
    return jsonResponse({ error: 'A clinic must be selected for admin and staff roles' }, 400);
  }

  if (role === 'super_admin' && clinicId) {
    return jsonResponse({ error: 'Super administrators cannot have a clinic assigned' }, 400);
  }

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      first_name: firstName,
      last_name: lastName,
      role: role,
      clinic_id: clinicId,
    },
  });
  if (createError || !created.user) {
    return jsonResponse({ error: createError?.message ?? 'Unable to create Auth identity' }, 400);
  }

  const { data: profile, error: profileError } = await adminClient
    .from('users')
    .upsert(
      {
        auth_user_id: created.user.id,
        email: email,
        first_name: firstName,
        last_name: lastName,
        role: role,
        clinic_id: clinicId,
        license_number: licenseNumber,
        specialization: specialization,
        contact_number: contactNumber,
        is_active: true,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'auth_user_id' }
    )
    .select('id')
    .single();

  if (profileError || !profile) {
    await adminClient.from('users').delete().eq('auth_user_id', created.user.id);
    await adminClient.auth.admin.deleteUser(created.user.id);
    return jsonResponse({ error: profileError?.message ?? 'Unable to create user profile' }, 500);
  }

  try {
    await adminClient.from('audit_logs').insert({
      clinic_id: clinicId,
      user_id: actor.id,
      action: 'CREATE_USER',
      entity_type: 'users',
      entity_id: profile.id,
      new_values: {
        email,
        role,
        clinic_id: clinicId,
        first_name: firstName,
        last_name: lastName,
      },
    });
  } catch (auditErr) {
    console.error('Audit log write error:', auditErr);
  }

  return jsonResponse({ id: profile.id });
});
});