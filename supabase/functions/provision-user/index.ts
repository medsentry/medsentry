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
  return password.length >= 12 && /[A-Z]/.test(password) && /[a-z]/.test(password) &&
    /\d/.test(password) && /[^A-Za-z0-9]/.test(password);
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

  const { data: actor, error: actorError } = await adminClient
    .from('users')
    .select('id, role, is_active')
    .eq('auth_user_id', authData.user.id)
    .maybeSingle();
  if (actorError || actor?.role !== 'admin' || actor.is_active !== true) {
    return jsonResponse({ error: 'Administrator access required' }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ error: 'Invalid request body' }, 400);
  }

  const userClient = createClient(url, apiKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  if (body.action === 'set_password') {
    const targetProfileId = body.target_user_id;
    const password = body.password;
    if (typeof targetProfileId !== 'string' || typeof password !== 'string' || !isStrongPassword(password)) {
      return jsonResponse({ error: 'Invalid password request' }, 400);
    }

    const { data: target, error: targetError } = await adminClient
      .from('users')
      .select('auth_user_id')
      .eq('id', targetProfileId)
      .maybeSingle();
    if (targetError || !target?.auth_user_id) return jsonResponse({ error: 'User not found' }, 404);

    const { error } = await adminClient.auth.admin.updateUserById(target.auth_user_id, { password });
    if (error) return jsonResponse({ error: 'Unable to update Auth credentials' }, 400);
    const { error: auditError } = await userClient.rpc('medsentry_audit_password_reset', {
      target_user_id: targetProfileId,
    });
    if (auditError) return jsonResponse({ error: 'Password reset completed; audit write needs retry' }, 503);
    return jsonResponse({ updated: true });
  }

  if (body.action !== 'create') return jsonResponse({ error: 'Unsupported action' }, 400);

  const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body.password === 'string' ? body.password : '';
  const firstName = typeof body.first_name === 'string' ? body.first_name.trim() : '';
  const lastName = typeof body.last_name === 'string' ? body.last_name.trim() : '';
  const role = body.role;
  if (
    !email.includes('@') || !isStrongPassword(password) || !firstName || !lastName ||
    (role !== 'admin' && role !== 'staff')
  ) {
    return jsonResponse({ error: 'Invalid user details' }, 400);
  }

  const { data: created, error: createError } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { first_name: firstName, last_name: lastName },
  });
  if (createError || !created.user) {
    return jsonResponse({ error: createError?.message ?? 'Unable to create Auth identity' }, 400);
  }

  const { data: profile, error: profileError } = await adminClient
    .from('users')
    .select('id')
    .eq('auth_user_id', created.user.id)
    .single();
  if (profileError || !profile) {
    await adminClient.from('users').delete().eq('auth_user_id', created.user.id);
    await adminClient.auth.admin.deleteUser(created.user.id);
    return jsonResponse({ error: 'Unable to create user profile' }, 500);
  }

  const { error: accountError } = await userClient.rpc('medsentry_update_user_account', {
    target_user_id: profile.id,
    requested_role: role,
    requested_active: true,
    requested_first_name: firstName,
    requested_last_name: lastName,
    requested_license_number: typeof body.license_number === 'string' ? body.license_number : null,
    requested_specialization: typeof body.specialization === 'string' ? body.specialization : null,
    requested_contact_number: typeof body.contact_number === 'string' ? body.contact_number : null,
  });
  if (accountError) {
    await adminClient.from('users').delete().eq('id', profile.id);
    await adminClient.auth.admin.deleteUser(created.user.id);
    return jsonResponse({ error: 'Unable to assign account access' }, 403);
  }

  return jsonResponse({ id: profile.id });
});