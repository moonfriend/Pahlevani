# Usage study — event catalogue

The only events the app logs. Source of truth in code:
`lib/domain/entities/usage/usage_event.dart` (+ its `usage_events_*.dart` parts).
`test/domain/entities/usage/usage_event_test.dart` fails if this table and the code disagree.

Strategy and research questions (RQ1–RQ6): `~/.claude/plans/read-the-context-of-frolicking-pizza.md`.

## Columns on every row (`public.usage_events`)

| Column | Meaning |
|---|---|
| `id` | uuid made on the device; duplicates are dropped on upload |
| `install_id` | random per install; links events from before sign-in |
| `user_id` | filled by the database (`auth.uid()`) on upload |
| `visit_id`, `seq` | one visit = foreground until 30 min in the background; `seq` orders events inside a visit |
| `occurred_at` | device time of the event |
| `event` | `area.action` name below |
| `screen` | the screen visible when it happened |
| `props` | the event's details (JSON, keys below) |
| `app_version`, `platform` | e.g. `1.7.0+17`, `android` / `ios` / `web` / `linux` |

Seconds are rounded to 0.1. Enum values are snake_case. No typed text is ever logged.
`movement_id` is the move's id as the app knows it (`Exercise.id`, the key of the Library,
the learning cards and session items); `session_id` is `training_session.id`.

## A — visits (RQ1, RQ6)

| Event | Props | Logged by |
|---|---|---|
| `app.first_open` | – | tracker, when the install id is first created |
| `app.opened` | `start` cold/warm · `since_last_visit_s` · `device_class` phone/tablet/desktop · `os` · `os_version` · `locale` · `network` wifi/mobile/none/other | usage root, at each new visit |
| `app.backgrounded` | `visit_s` | usage root |
| `app.foregrounded` | `away_s` · `new_visit` | usage root |

Visit length, screens per visit and events per visit come from the `usage_visits` view.

## B — screens and navigation (RQ3, RQ4)

| Event | Props | Logged by |
|---|---|---|
| `nav.screen_viewed` | `screen` · `previous` · `via` tab/button/back/gate/system | screen tracker |
| `nav.screen_left` | `screen` · `seconds` · `scroll_depth_pct` | screen tracker |
| `nav.tab_selected` | `from` · `to` · `reselected` | app shell |
| `nav.back` | `kind` system/app_bar/swipe · `from` | navigator observer |
| `nav.dialog_shown` | `dialog` | navigator observer |
| `nav.dialog_closed` | `dialog` · `result` confirmed/cancelled/dismissed · `seconds` | navigator observer |
| `nav.sheet_shown` | `sheet` | navigator observer |
| `nav.sheet_closed` | `sheet` · `result` · `seconds` | navigator observer |
| `nav.link_opened` | `link` meel_guide/activation_info/terms/privacy/announcement/onboarding/store · `url_host` | `openExternalLink()` |

## C — login, consent, activation (RQ2, RQ3)

| Event | Props | Logged by |
|---|---|---|
| `auth.screen_mode` | `mode` create_account/sign_in | account page |
| `auth.submit` | `mode` · `seconds_on_screen` · `corrections` · `attempt` | account page |
| `auth.result` | `mode` · `ok` · `error` wrong_credentials/email_taken/code_invalid/weak_password/rate_limited/network/other · `seconds` | AuthCubit |
| `auth.consent_shown` | `is_update` | consent page |
| `auth.consent_accepted` | `seconds` · `opened_terms` · `opened_privacy` | consent page |
| `auth.consent_declined` | `seconds` | consent page |
| `auth.signed_out` | – | AuthCubit |
| `auth.account_deleted` | – | AuthCubit |
| `access.code_entered` | `result` ok/invalid/offline (invalid includes used up) · `attempt` | ActivationCubit |
| `access.locked_screen_action` | `action` link/sign_out | locked page |

## C — first open, Home, Library, learning card, Profile (RQ3, RQ4)

| Event | Props | Logged by |
|---|---|---|
| `splash.begin_tapped` | `seconds` | splash |
| `onboarding.card_viewed` | `index` (from 1; card 0 is the screen view) · `of` · `previous_card_s` · `via` swipe/button | onboarding |
| `onboarding.finished` | `at_card` · `seconds` | onboarding |
| `onboarding.skipped` | `at_card` · `seconds` | onboarding |
| `home.session_card_tapped` | `slot` · `session_id` · `target` card/start_button | Home |
| `home.session_menu_opened` | `session_id` | Home (long-press) |
| `home.announcement_tapped` | – | Home |
| `home.today_page_changed` | `index` · `via` swipe/dot | Home |
| `library.move_opened` | `movement_id` · `position` | Library |
| `library.session_opened` | `session_id` · `position` | Library |
| `learning_card.opened` | `movement_id` · `from` library/preview/player | learning card |
| `learning_card.video_played` | `movement_id` · `video` learning/follow_along | learning card |
| `learning_card.video_toggled` | `to` | learning card |
| `learning_card.fullscreen` | `on` | learning card |
| `learning_card.action` | `movement_id` · `action` | learning card |
| `learning_card.learnt_toggled` | `movement_id` · `learnt` | learnt toggle |
| `profile.entry_tapped` | `entry` language_fa/sign_out/delete_account/trainer_tools | Profile |
| `profile.tracking_toggled` | `on` | Profile switch (turning off is the last event sent) |
| `settings.theme_changed` | `mode` | SettingsCubit |
| `morshed.chosen` | `morshed_id` · `from` profile/preview/other | chooseMorshed |

## C — session preview, downloads, session outcome (RQ5)

| Event | Props | Logged by |
|---|---|---|
| `session.previewed` | `session_id` · `source` home/library/other · `moves` | preview |
| `preview.move_opened` | `session_id` · `movement_id` · `position` | preview |
| `preview.mode_tapped` | `session_id` · `mode` learning/athlete | preview |
| `preview.left` | `session_id` · `how` start/back · `seconds` · `moves_opened` | preview |
| `session.started` | `session_id` · `mode` learning/athlete/zoorkhaneh · `morshed_id` · `downloaded` · `moves` | SessionPlayerCubit |
| `session.completed` | `session_id` · `seconds` · `played_s` · `pauses` · `replays` · `seeks` | SessionPlayerCubit |
| `session.abandoned` | `session_id` · `last_index` · `played_s` · `how` back/killed | SessionPlayerCubit; `killed` (with a `player.move_ended` how=app_killed) is logged at the next cold start from the open-session marker |
| `download.started` | `target` session/morshed_pack · `id` · `tier` · `bytes` | MediaDownloadCubit |
| `download.finished` | `target` · `id` · `tier` · `bytes` · `seconds` | MediaDownloadCubit |
| `download.failed` | `target` · `id` · `tier` · `error` network/storage/other | MediaDownloadCubit |
| `download.declined` | `target` · `id` | download dialog |
| `complete.action` | `action` return_home · `seconds` | Complete screen |

## C — the player (RQ5)

| Event | Props | Logged by |
|---|---|---|
| `player.move_reached` | `index` · `movement_id` · `waiting_for_go` | SessionPlayerCubit |
| `player.go_tapped` | `index` · `waited_s` | SessionPlayerCubit |
| `player.paused` | `index` · `position_s` · `source` screen/media_session | SessionPlayerCubit |
| `player.resumed` | `index` · `position_s` · `source` | SessionPlayerCubit |
| `player.next` | `from` · `to` · `position_s` · `source` | SessionPlayerCubit |
| `player.prev` | `from` · `to` · `position_s` · `source` | SessionPlayerCubit |
| `player.replay` | `from_index` | SessionPlayerCubit |
| `player.seek` | `index` · `from_s` · `to_s` · `source` | SessionPlayerCubit |
| `player.muted` | `on` | SessionPlayerCubit |
| `player.move_list_jump` | `from` · `to` | SessionPlayerCubit |
| `player.how_to_opened` | `index` · `movement_id` | player page |
| `player.fullscreen` | `on` | player page |
| `player.progress_toggled` | `visible` | player page |
| `player.move_ended` | `index` · `movement_id` · `played_s` · `planned_s` · `reached_pct` · `reps_reached` · `reps_planned` · `pauses` · `seeks` · `how` played_to_end/next/prev/replay/list_jump/left_session/app_killed | MoveUsageRecorder via SessionPlayerCubit |
| `player.rep_logged` | `index` · `reps` · `target` | SessionPlayerCubit (rep log on) |
| `player.rep_log_skipped` | `index` · `target` | SessionPlayerCubit (rep log on) |

## D — friction (RQ2, RQ4, RQ5)

| Event | Props | Logged by |
|---|---|---|
| `ui.error_shown` | `kind` snackbar/dialog/inline · `message_key` | error helpers, auth/activation error states |
| `ui.dead_tap` | `element` (TapProbe id) · `cell` · `x_pct` · `y_pct` · `disabled_control` | usage root tap listener |

Derived in SQL only (never stored): rage taps (3+ dead taps within 2 s in one cell), tap-then-leave,
ping-pong between two screens, screen visits under 2 s, a screen re-entered within a visit,
login retried more than twice.
