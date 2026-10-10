# Chong：评审账号与示例数据操作指南（10 月 10 日）

**目标：** 明天（10/11）中午前，让评审账号登录后能看到用户指南里的示例日：
示例日 09:00–12:00 有 3 小时、计划 5 小时、超载 2 小时；第二天 09:00–11:00 有 2 小时空档。

**总时间：** 约 20–30 分钟。全部在 Supabase 网页上完成，不需要安装 psql。

> ⚠️ 规则
> - 只操作**全新的评审账号**，不要对任何队员的账号跑脚本。
> - 评审账号的邮箱和密码**只私信给 Lim**，不发群、不写进 Git 或任何文档。
> - 用 publishable key 的地方照旧，**绝不使用 service_role key**。

---

## 第 0 步：示例日期（demo_date）

- **评审账号用 `2026-11-01`**，也就是主办方的 Finals Judging Day。评审当天打开 App，Today 会直接显示超载画面。
- 脚本不接受过去的日期；日期过了以后，示例任务会变成逾期。
- **建两个评审账号，都用 `2026-11-01`**：一个给评审，一个当备用。评审前如果第一个账号被弄乱，可以改用第二个。
- 如果需要在 11/1 之前先自己测试，可以另建一个测试账号，用今天或明天的日期，**不要用评审账号测**。

## 第 1 步：建评审账号

1. 打开 Supabase 项目 → **Authentication** → **Users**
2. 点 **Add user** → **Create new user**
3. 填：
   - Email：一个**新的、专门给评审用**的邮箱（例如团队新开的 Gmail，或 `balance.judge1@...`）
   - Password：至少 8 位的强密码
   - ✅ 勾选 **Auto Confirm User**（这样评审不用点验证邮件）
4. 点 **Create user**
5. 在用户列表点开这个账号，**复制 User UID**（一串 UUID），等一下要用

## 第 2 步：设置时区（⚠️ 一定要在第 3 步之前做完）

> **脚本会用账号「当时」的时区来计算时间。** 如果先跑脚本再改时区，所有时间都会错，而且之后改时区也不会修正。
>
> 在 App 里检查时，手机或模拟器也要设成马来西亚时间：App 按手机时区显示时间。Android 模拟器默认是 GMT，会把正确的 9:00 AM 显示成 1:00 AM。

新账号的时区默认是 `UTC`，评审的手机是马来西亚时间，不改的话日期和时段会对不上。

在 **SQL Editor** 新开一个查询，把 `UUID` 换成第 1 步复制的 User UID，执行：

```sql
update public.profiles
set time_zone = 'Asia/Kuala_Lumpur'
where id = 'UUID';

select id, time_zone from public.profiles where id = 'UUID';
```

结果**必须**显示 `Asia/Kuala_Lumpur`，确认后才能进行第 3 步。如果查不到这一行，说明 profile 没有自动建立，先停下来告诉 Lim。

## 第 3 步：预览示例数据（不会真的写入）

原本的 `supabase/manual/20261008_judge_demo.sql` 是 psql 脚本，不能直接贴进 SQL Editor。下面是**内容完全相同**、改成 SQL Editor 能用的版本。

在 SQL Editor 新开查询，贴上下面整段，然后**只改最上面三行**：

- `UUID` → 第 1 步的 User UID
- `EMAIL` → 评审账号的邮箱（要和 Auth 里完全一样）
- `YYYY-MM-DD` → 第 0 步定的示例日期

```sql
begin;
select set_config('balance.judge_user', 'UUID', true);
select set_config('balance.judge_email', 'EMAIL', true);
select set_config('balance.demo_date', 'YYYY-MM-DD', true);
do $$
declare u uuid := current_setting('balance.judge_user')::uuid;
  d date := current_setting('balance.demo_date')::date;
  zone text;
  a timestamptz;
  b timestamptz;
begin
  if not exists(select 1 from auth.users where id=u and email=current_setting('balance.judge_email')) then
    raise exception 'Judge UUID/email do not match an existing Auth account';
  end if;
  select time_zone into zone from public.profiles where id=u for update;
  if zone is null then raise exception 'Judge profile missing'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text,0));
  if d < (now() at time zone zone)::date then raise exception 'Demo day must not be in the past'; end if;
  if exists(select 1 from public.tasks where user_id=u)
    or exists(select 1 from public.availability_blocks where user_id=u)
    or exists(select 1 from public.recovery_slots where user_id=u)
    or exists(select 1 from public.plan_changes where user_id=u)
    or exists(select 1 from public.user_achievements where user_id=u)
    or exists(select 1 from public.world_status_snapshots where user_id=u)
    or exists(select 1 from public.exercise_logs where user_id=u)
    or exists(select 1 from public.social_events where user_id=u)
    or exists(select 1 from public.reflections where user_id=u)
    or exists(select 1 from public.check_ins where user_id=u)
    or exists(select 1 from public.planning_events where user_id=u) then
    raise exception 'Use an empty dedicated judge account; existing data is never cleared or overwritten';
  end if;
  a := (d + time '09:00') at time zone zone;
  b := ((d+1) + time '09:00') at time zone zone;
  insert into public.availability_blocks(user_id,start_at,end_at,block_type,label) values
    (u,a,a+interval '3 hours','available','Judge demo: day 1'),
    (u,b,b+interval '2 hours','available','Judge demo: day 2');
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,
    scheduled_start,scheduled_end,load_category) values
    (u,'Judge demo: flexible report',180,180,b+interval '8 hours',a,a+interval '3 hours','study');
  insert into public.tasks(user_id,title,estimated_minutes,remaining_minutes,due_at,load_category)
    values(u,'Judge demo: deadline work',120,120,a+interval '8 hours','study');
  if public.calculate_day_overload(u,d) <> 120 then
    raise exception 'Fixture must produce 300 planned minus 180 available = 120 overload';
  end if;
end $$;
select current_setting('balance.judge_user') as judge_user,
  current_setting('balance.demo_date') as demo_date, 300 as planned_minutes,
  180 as available_minutes, 120 as overload_minutes;
rollback; -- 预览：全部撤销。第 4 步才改成 commit
```

**执行后：**

- ✅ 成功：**没有出现红色错误**（SQL Editor 可能只显示 `Success. No rows returned`）。脚本内部会检查超载是否刚好 120 分钟，不对就会报错，所以没报错就代表数据正确。这时什么都没写入，因为最后是 `rollback`。
- ❌ 如果报错，对照下表：

| 错误信息 | 原因 | 怎么办 |
| --- | --- | --- |
| `Judge UUID/email do not match an existing Auth account` | UUID 或邮箱填错 | 重新复制 User UID 和邮箱 |
| `Judge profile missing` | 账号没有 profile | 停下来告诉 Lim |
| `Demo day must not be in the past` | 日期是过去的 | 换成今天或之后的日期 |
| `Use an empty dedicated judge account` | 这个账号已经有数据 | 换一个全新的账号，不要删数据 |
| `Fixture must produce ... 120 overload` | 服务器算出的超载不是 120 | 截图错误信息发给 Lim，先不要继续 |

## 第 4 步：正式写入

预览成功后，**把最后一行 `rollback;` 改成 `commit;`**，其他不动，再执行一次。

没有红色错误就是写入成功。再执行下面这句确认（把 `UUID` 换掉），应该看到 2 个任务和 2 个可用时段：

```sql
select (select count(*) from public.tasks where user_id = 'UUID') as tasks,
       (select count(*) from public.availability_blocks where user_id = 'UUID') as blocks;
```

⚠️ 这一步每个账号只能做一次。要重做的话，换一个新账号，不要手动删数据。

## 第 5 步：用 App 确认（时间一定要对）

先用 SQL 确认写入的时间是马来西亚时间（把 `UUID` 换掉）：

```sql
select title, due_at at time zone 'Asia/Kuala_Lumpur' as due_local
from public.tasks where user_id = 'UUID';

select start_at at time zone 'Asia/Kuala_Lumpur' as start_local,
       end_at   at time zone 'Asia/Kuala_Lumpur' as end_local
from public.availability_blocks where user_id = 'UUID';
```

| 必须看到 | |
| --- | --- |
| deadline work 截止 | 示例日 **17:00** |
| flexible report 截止 | 示例日第二天 **17:00** |
| 可用时间 | 示例日 **09:00–12:00**，第二天 **09:00–11:00** |

时间不对（例如 01:00 或 09:00 截止）→ 这个账号不要用，换新账号从第 1 步重来，**先改时区**。

然后在 App 里确认：

1. 装 Lim 发的**新版 APK**（旧版要先卸载，因为 App ID 改了）
2. 用评审账号登录
3. 按 `docs/USER_GUIDE.md` 第 2–5 步检查：
   - Today 切到示例日期：显示 **5h planned / 3h available / 2h over**
   - Quests：两个 `Judge demo` 任务
   - Council：确认计划后，再从右上角 **Plan history** 撤销，回到 2h over
4. **最后一定要撤销计划**，让账号回到初始状态
5. 登出

## 第 6 步：交给 Lim（私信）

- 评审账号邮箱和密码
- 示例日期
- 第 5 步的结果（正常，或截图哪里不对）

---

## 第 7 步（等 Lim 通知后才做）：上线类别强制迁移 `202610080001`

**现在不要做。** 要等 Lim 发布新版 APK、全队都换成新版之后再执行，否则旧版 App 会存不了新任务。

收到通知后：

1. 先确认还没执行过。在 SQL Editor 执行：

   ```sql
   select tgname from pg_trigger where tgname = 'tasks_require_category';
   ```

   有结果 → 已经执行过，不要重复执行，告诉 Lim 就好。没有结果 → 继续。

2. 打开 `supabase/migrations/202610080001_require_task_category.sql`，整份内容贴进 SQL Editor 执行。
3. 再执行第 1 点的查询，应该有一行 `tasks_require_category`。
4. 用新版 App 建一个有类别的任务，应该能存；然后告诉 Lim 已完成。

---

## 完成清单（做完一项打一个勾，在群里回 ✅）

- [ ] 第 0 步：和 Lim 定好示例日期
- [ ] 第 1 步：评审账号已建，并且已经 Auto Confirm
- [ ] 第 2 步：时区是 `Asia/Kuala_Lumpur`
- [ ] 第 3 步：预览成功（300 / 180 / 120）
- [ ] 第 4 步：`commit` 写入成功
- [ ] 第 5 步：App 上确认超载画面正确，并且已经撤销计划
- [ ] 第 6 步：账号、密码和日期已私信 Lim
- [ ] 第 7 步：等通知后再上线迁移
