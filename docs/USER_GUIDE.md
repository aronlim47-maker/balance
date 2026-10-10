# Balance — User Guide for Judges

Balance helps a student whose plan no longer fits the day. It shows the overload,
compares safe ways to fix it, changes nothing until the student confirms, and can undo
every confirmed change.

**Time needed:** about 10 minutes. **Help needed:** none.

## Quick path

| Step | Page | What you will do | Time |
| --- | --- | --- | --- |
| 1 | — | Install the app and sign in | 2 min |
| 2 | TODAY | See a 2-hour overload and five workload bars | 1 min |
| 3 | QUESTS | Look at the two tasks behind the overload | 1 min |
| 4 | COUNCIL | Compare options and confirm a plan | 2 min |
| 5 | COUNCIL | Undo the plan from Plan history | 1 min |
| 6 | SANCTUARY | Protect 30 minutes of rest, then remove it | 2 min |
| 7 | JOURNEY | Read the weekly summary and achievements | 1 min |

## Before you start

| You need | Where to get it |
| --- | --- |
| An Android phone (Android 7.0 or later) with internet | — |
| The Balance app | [Latest release](https://github.com/aronlim47-maker/balance/releases/latest) → download `app-release.apk` |
| The judge account email and password | In our submission form. They are never stored in this repository. |
| The **sample date** | In our submission form, next to the account details. |

The bottom bar has five pages: **TODAY, QUESTS, COUNCIL, SANCTUARY, JOURNEY**. Each page
shows a practical name with a game-style label beside it, for example
*Workload Overview · World Status*.

## 1. Install and sign in

1. On the phone, open the release link and download `app-release.apk`.
2. Open the downloaded file. If Android asks, allow installing apps from this source,
   then tap **Install**.
3. Open **Balance**, enter the judge email and password, and tap **Sign in**.

You should see the **TODAY** page. If a "Local preview" banner appears at the top, this
is not the release build; reinstall from the release link.

## 2. See the overload (TODAY)

1. Use the **Previous day / Next day** arrows to open the **sample date**.
2. The **Time capacity** card shows **5h planned** against **3h available** (09:00–12:00)
   and a red **2h over** tag. The planned work does not fit.
3. The **World Status** card shows five bars in a fixed order: **Mental, Time, Physical,
   Social, Errands**. Bars without enough data say **Unknown**. Balance never treats
   missing data as zero or guesses it.
4. Optional: the daily review asks for energy and hours of rest. Tap **Save review** or
   **Skip for now**. Skipping has no penalty.

## 3. Look at the tasks (QUESTS)

The sample day has two study tasks:

| Task | Length | When | Deadline |
| --- | --- | --- | --- |
| Judge demo: flexible report | 3h | Scheduled 09:00–12:00 on the sample date | The next day, 17:00 |
| Judge demo: deadline work | 2h | Not scheduled | The sample date, 17:00 |

Together they need 5 hours, but only 3 hours are available.

- Each task card shows its category (Study, Errand, Social, Exercise or Other), its
  flexibility, and whether it is **Protected**. Protected commitments such as a work shift,
  family duty or sleep minimum are never moved to make a plan fit.
- Optional: tap **Add task**, then **Cancel**. A new task cannot be saved without a
  category.

## 4. Compare and confirm a plan (COUNCIL)

1. Open **COUNCIL** and go to the sample date. The page says
   *Suggestions only. Nothing moves until confirmed.*
2. Read the suggested option. It moves **2 hours of the flexible report to the next
   day**, where 2 hours are free (09:00–11:00) and the report's deadline is still met. Each
   option lists the **Cost**, what stays **Protected**, the **Room created**, and anything
   to **Check before confirming**.
3. Tap **Compare plans** to see the options and the capacity of every affected day.
4. Select the option and tap **Confirm selected plan**, then confirm in the final preview.
5. The plan-updated screen lists the moved work. Tap **Return to Today**: the sample date
   now fits, and the next day shows the moved 2 hours.

## 5. Undo the plan (COUNCIL)

1. Open **COUNCIL** and tap the **Plan history** icon (clock) at the top right.
2. Open the plan marked **Confirmed** and tap **Undo this plan**.
3. Plan history now marks it **Undone**. On **TODAY**, the sample date is **2h over**
   again and the next day is free.

If the tasks were edited after confirming, Undo is refused with an explanation instead
of overwriting the newer changes.

**Please always undo your plan**, so the sample day stays ready for the next judge.

## 6. Protect rest time (SANCTUARY)

Recovery time is optional. Balance only lets you protect time that is genuinely free.

1. Open **SANCTUARY** and tap **Add recovery time**.
2. Choose the **day after the sample date**, from 09:00 to 09:30, and tap **Save**.
   The slot appears as **Protected time**. Choosing an activity is optional.
3. Try the same on a day with no available time: the app explains that recovery time must
   fit inside available time and offers **Go to Today**.
4. Marking an activity done does not change any workload score. Rest is not graded.
5. **Please remove the slot afterwards**: open its menu (⋮) → **Remove**. It occupies the
   free time that the Council plan in step 4 needs.

## 7. Weekly summary and achievements (JOURNEY)

1. Open **JOURNEY**. It shows a private weekly summary for the selected week. Days without
   a record say **No record**; past scores are never invented.
2. Optional: tap **Add optional reflection**, write one sentence and tap **Save**. The
   **My reflections** icon (clock) at the top lists reflections from earlier weeks.
3. Scroll to **Achievements**: seven cards, each with its unlock condition. Your steps
   above can unlock **Safe Trade-off**, **Deadline Safety**, **Protected Rest** and
   **Reflection**. Each badge is awarded once per account, so cards may already be
   unlocked if another judge used this account first.
4. **Team Coordination** stays **Locked**. It needs shared tasks, which are planned for a
   later version.

There are no streaks, rankings or penalties for skipping.

## If something goes wrong

| What you see | What to do |
| --- | --- |
| "Could not connect" with **Try again** | Check the internet connection, then tap **Try again**. Data already on screen stays visible. |
| The sample date is not 2h over | Check that you are on the sample date. If a plan is still confirmed, undo it in **COUNCIL → Plan history**. |
| Council shows **No Feasible Plan** | A recovery slot may be occupying the next day. Remove it in **SANCTUARY** (step 6.5). |
| Sign-in fails | Check the email and password from the submission form for typing errors. |
| "Can't install app" | Uninstall any earlier Balance test build first, then install again. |

## What Balance does not claim

- Scores describe recorded planning data. Balance is not a medical, diagnostic or
  mental-health tool.
- Android is the supported platform. iOS has not been tested on a device, and the web
  build is not part of this submission.
- Every task needs a deadline; a "No deadline" option is not available yet.
- The app is currently English-only. Bahasa Melayu and Chinese are planned.
- Shared tasks and the Team Coordination achievement are planned for a later version.
