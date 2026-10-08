-- Deploy only after all supported clients submit a task category.
-- Apply after 202610040002. Existing NULL categories remain unknown.
begin;
create function public.require_task_category()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
  if new.load_category is null then
    if tg_op = 'INSERT' then
      raise exception using errcode = '23514', message = 'Task category required';
    elsif old.load_category is not null then
      raise exception using errcode = '23514', message = 'Task category required';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.require_task_category() from public, anon, authenticated;
create trigger tasks_require_category
before insert or update of load_category on public.tasks
for each row execute function public.require_task_category();
commit;
