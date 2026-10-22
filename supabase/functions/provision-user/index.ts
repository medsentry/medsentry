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

  // The profile table is the only authority for roles. Email addresses and
  // user_metadata are user-controlled and must never grant privileges.
  let { data: actor } = await adminClient
    .from('users')
    .select('id, role, clinic_id, is_active, auth_user_id')
    .eq('auth_user_id', authData.user.id)
    .maybeSingle();

  // Re-link a profile whose Auth identity was recreated, but only when the
  // profile is unlinked; a linked profile always belongs to another identity.
  if (!actor && authData.user.email) {
    const { data: byEmail } = await adminClient
      .from('users')
      .select('id, role, clinic_id, is_active, auth_user_id')
      .eq('email', authData.user.email.toLowerCase())
      .is('auth_user_id', null)
      .maybeSingle();

    if (byEmail) {
      const { error: linkError } = await adminClient
        .from('users')
        .update({ auth_user_id: authData.user.id })
        .eq('id', byEmail.id)
        .is('auth_user_id', null);
      if (!linkError) actor = { ...byEmail, auth_user_id: authData.user.id };
    }
  }

  const actorRole = actor?.role ?? '';
  const isAdminOrSuper = actorRole === 'admin' || actorRole === 'super_admin';

  if (!actor || !isAdminOrSuper || actor.is_active === false) {
    return jsonResponse({ error: 'Administrator access required' }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ error: 'Invalid request body' }, 400);
  }

  const action = typeof body.action === 'string' ? body.action.trim().toLowerCase() : '';

  if (['delete', 'delete_user', 'delete-user', 'remove_user', 'remove-user'].includes(action)) {
    const targetProfileId = body.target_user_id;
    if (typeof targetProfileId !== 'string' || !targetProfileId.trim()) {
      return jsonResponse({ error: 'Invalid user request' }, 400);
    }

    const { data: target, error: targetError } = await adminClient
      .from('users')
      .select('id, auth_user_id, clinic_id, role')
      .eq('id', targetProfileId)
      .maybeSingle();
    if (targetError || !target) {
      return jsonResponse({ error: 'User not found' }, 404);
    }
    if (target.id === actor.id) {
      return jsonResponse({ error: 'You cannot delete your own account' }, 403);
    }
    if (actorRole === 'admin') {
      if (target.role === 'super_admin') {
        return jsonResponse({ error: 'Administrator cannot delete super administrators' }, 403);
      }
      if (target.clinic_id !== actor.clinic_id) {
        return jsonResponse({ error: 'Cannot manage users from other clinics' }, 403);
      }
      // Only a Super Admin manages Admin accounts; otherwise one RHU Admin
      // could remove another.
      if (target.role !== 'staff') {
        return jsonResponse({ error: 'Only a super administrator can delete administrator accounts' }, 403);
      }
    }

    // audit_logs has no description column; an unknown column made every
    // deletion fail here with a 500 before the account was touched.
    const { error: auditError } = await adminClient.from('audit_logs').insert({
      clinic_id: target.clinic_id,
      user_id: actor.id,
      action: 'DELETE_USER',
      entity_type: 'users',
      entity_id: target.id,
      new_values: {
        description: `Permanent deletion requested for user account ${target.id}`,
      },
    });
    if (auditError) {
      console.error('Account deletion audit error:', auditError);
      return jsonResponse({ error: 'Unable to record the account deletion' }, 500);
    }

    if (target.auth_user_id) {
      const { error: authDeleteError } = await adminClient.auth.admin.deleteUser(
        target.auth_user_id
      );
      if (authDeleteError) {
        console.error('Auth account deletion error:', authDeleteError);
        return jsonResponse({ error: 'Unable to delete the authentication account' }, 500);
      }
    }

    const { error: profileDeleteError } = await adminClient
      .from('users')
      .delete()
      .eq('id', target.id);
    if (profileDeleteError) {
      console.error('User profile deletion error:', profileDeleteError);
      return jsonResponse({ error: 'Unable to delete the user profile' }, 500);
    }

    return jsonResponse({ deleted: true });
  }

  if (['set_password', 'set-password', 'reset_password', 'reset-password'].includes(action)) {
    const targetProfileId = body.target_user_id;
    const password = body.password;
    if (typeof targetProfileId !== 'string' || typeof password !== 'string' || !isStrongPassword(password)) {
      return jsonResponse({ error: 'Invalid password request' }, 400);
    }

    const { data: target, error: targetError } = await adminClient
      .from('users')
      .select('id, auth_user_id, clinic_id, role')
      .eq('id', targetProfileId)
      .maybeSingle();
    if (targetError || !target?.auth_user_id) return jsonResponse({ error: 'User not found' }, 404);

    if (actorRole === 'admin' && (target.role === 'super_admin' || target.clinic_id !== actor.clinic_id)) {
      return jsonResponse({ error: 'Cannot manage users from other clinics' }, 403);
    }
    // Setting another Admin's password would let one RHU Admin take over a
    // peer's account; only a Super Admin manages Admin accounts.
    if (actorRole === 'admin' && target.role !== 'staff' && target.id !== actor.id) {
      return jsonResponse({ error: 'Only a super administrator can reset administrator passwords' }, 403);
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

  if (['update_email', 'update-email'].includes(action)) {
    const targetProfileId = body.target_user_id;
    const newEmail = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
    if (typeof targetProfileId !== 'string' || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(newEmail)) {
      return jsonResponse({ error: 'Invalid email request' }, 400);
    }
    if (actorRole !== 'super_admin') {
      return jsonResponse({ error: 'Only a super administrator can change account email addresses' }, 403);
    }

    const { data: target, error: targetError } = await adminClient
      .from('users')
      .select('id, auth_user_id, clinic_id')
      .eq('id', targetProfileId)
      .maybeSingle();
    if (targetError || !target) return jsonResponse({ error: 'User not found' }, 404);

    if (target.auth_user_id) {
      const { error } = await adminClient.auth.admin.updateUserById(target.auth_user_id, {
        email: newEmail,
        email_confirm: true,
      });
      if (error) return jsonResponse({ error: error.message }, 400);
    }

    const { error: profileError } = await adminClient
      .from('users')
      .update({ email: newEmail })
      .eq('id', target.id);
    if (profileError) return jsonResponse({ error: profileError.message }, 400);

    await adminClient.from('audit_logs').insert({
      clinic_id: target.clinic_id,
      user_id: actor.id,
      action: 'UPDATE_USER',
      entity_type: 'users',
      entity_id: target.id,
      new_values: { email: newEmail },
    });
    return jsonResponse({ updated: true });
  }

  if (!['create', 'create_user', 'create-user'].includes(action)) {
    return jsonResponse({ error: 'Unsupported action' }, 400);
  }

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
  // Inline image data URL, already shrunk by the app (same limit as the
  // medsentry_update_user_account RPC).
  const profileImageUrl =
    typeof body.profile_image_url === 'string' &&
    body.profile_image_url.startsWith('data:image/') &&
    body.profile_image_url.length <= 1000000
      ? body.profile_image_url
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
    },
    // app_metadata is writable only with the service role, so the profile
    // trigger can trust it.
    app_metadata: {
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
        profile_image_url: profileImageUrl,
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