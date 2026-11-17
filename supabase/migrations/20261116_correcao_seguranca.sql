-- Correção de segurança — 16/11/2026
-- 1) Contas novas nascem DESATIVADAS (a tela de administração ativa ao criar).
-- 2) Usuário não altera mais o próprio perfil (role/active) direto pela API.
-- 3) Quem não fez login (anon) perde acesso a tabelas e funções.
-- 4) Escrita nas tabelas só pelas funções controladas (save/delete/lock).
-- A plataforma só faz SELECT nas tabelas e usa as funções RPC; nada do uso atual muda.

-- 1) Novos usuários desativados por padrão
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare
  proposed_username text;
  proposed_name text;
begin
  proposed_username := coalesce(
    nullif(lower(trim(new.raw_user_meta_data ->> 'username')), ''),
    split_part(new.email, '@', 1),
    'usuario_' || left(new.id::text, 8)
  );
  proposed_name := coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), proposed_username);
  insert into public.profiles (id, username, full_name, cpf, role, active)
  values (new.id, proposed_username, proposed_name, nullif(trim(new.raw_user_meta_data ->> 'cpf'), ''), 'user', false)
  on conflict (id) do nothing;
  return new;
end;
$function$;

-- 2) Perfis: só leitura pela API; alterações apenas pela função admin-users (service role)
drop policy if exists profiles_update_self_or_admin on public.profiles;
drop policy if exists profiles_admin_insert on public.profiles;

-- 3) e 4) Tabelas
revoke all on public.app_entities, public.app_locks, public.app_state, public.audit_log, public.profiles from anon;
revoke all on public.app_entities, public.app_locks, public.app_state, public.audit_log, public.profiles from authenticated;
grant select on public.app_entities, public.app_locks, public.app_state, public.audit_log, public.profiles to authenticated;

-- Funções: somente usuários logados
revoke execute on function public.acquire_app_lock(text, text, text, integer) from public, anon;
revoke execute on function public.renew_app_lock(text, integer)               from public, anon;
revoke execute on function public.release_app_lock(text)                      from public, anon;
revoke execute on function public.save_app_entity(text, text, jsonb, bigint)  from public, anon;
revoke execute on function public.delete_app_entity(text, text, bigint)       from public, anon;
revoke execute on function public.current_user_is_active()                    from public, anon;
revoke execute on function public.current_user_is_admin()                     from public, anon;
grant  execute on function public.acquire_app_lock(text, text, text, integer) to authenticated;
grant  execute on function public.renew_app_lock(text, integer)               to authenticated;
grant  execute on function public.release_app_lock(text)                      to authenticated;
grant  execute on function public.save_app_entity(text, text, jsonb, bigint)  to authenticated;
grant  execute on function public.delete_app_entity(text, text, bigint)       to authenticated;
grant  execute on function public.current_user_is_active()                    to authenticated;
grant  execute on function public.current_user_is_admin()                     to authenticated;

-- Função de gatilho não deve ser chamável pela API
revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;

-- Aviso do Supabase: search_path fixo
alter function public.touch_profile_updated_at() set search_path = '';
