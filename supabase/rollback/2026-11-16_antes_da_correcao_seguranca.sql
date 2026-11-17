-- Estado das permissões ANTES da correção de segurança de 16/11/2026.
-- Rodar este arquivo DESFAZ a correção (reabre as falhas). Usar só em emergência.

-- Tabelas: privilégios que existiam
grant delete, insert, references, select, trigger, truncate, update on public.app_entities to anon, authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.app_locks    to anon, authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.app_state    to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.audit_log    to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.profiles     to authenticated;

-- Funções: execute para anon e authenticated
grant execute on function public.acquire_app_lock(text, text, text, integer) to anon, authenticated;
grant execute on function public.renew_app_lock(text, integer)               to anon, authenticated;
grant execute on function public.release_app_lock(text)                      to anon, authenticated;
grant execute on function public.save_app_entity(text, text, jsonb, bigint)  to anon, authenticated;
grant execute on function public.delete_app_entity(text, text, bigint)       to anon, authenticated;
grant execute on function public.current_user_is_active()                    to anon, authenticated;
grant execute on function public.current_user_is_admin()                     to anon, authenticated;
grant execute on function public.handle_new_auth_user()                      to anon, authenticated;

-- Políticas de profiles que existiam
create policy profiles_admin_insert on public.profiles for insert to authenticated
  with check (current_user_is_admin());
create policy profiles_update_self_or_admin on public.profiles for update to authenticated
  using ((id = auth.uid()) or current_user_is_admin())
  with check ((id = auth.uid()) or current_user_is_admin());

-- Trigger de novos usuários: perfil nascia ATIVO
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
  values (new.id, proposed_username, proposed_name, nullif(trim(new.raw_user_meta_data ->> 'cpf'), ''), 'user', true)
  on conflict (id) do nothing;
  return new;
end;
$function$;

-- touch_profile_updated_at não tinha search_path fixo
alter function public.touch_profile_updated_at() reset search_path;
