# Repo-wide cleanup blueprint

Readability, then optimizations and bug fixes.

Read every `.m` file in the repo and clean it in place — better names, complete header docs, consistent conventions, reflowed long lines. The first phase of this operation is **behaviour-preserving**: no output changes, a constraint that is **mechanically checkable**, so the diff does not need to be trusted, only verified. Three tiers of change, defined fully in section 3: Tier A, Tier B, Tier C. Tier A and Tier B are this behaviour-preserving readability pass; Tier C is the next step of the same overall operation — structural cleanups, optimizations, and bug fixes found along the way, done once the readability pass is complete.

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">0. Status</h2></summary>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">0.1 Tier A — not started</h3></summary>

<div style="margin-left:1.5em">

Comments, header docs, whitespace, reflow, file-local renames. Checked by `isequal` on a canonical AST fingerprint — no execution needed.

- [ ] **0.1.0.** Tooling: `canon`/`check_tier_a`/`assert_rename_bijection`, golden-output harness. Version control and `.gitignore` are **done** — see section 1.
- [ ] **0.1.1.** Analysis chain: `+lib/preprocess_gaze.m`, `spem/downsample_traj.m`, `spem/true_target_traj.m`, `spem/spem_measures.m`, `free_view/+analyze/free_view_measures.m` — 544 lines.
- [ ] **0.1.2.** Template experiment file: `saccade/saccade_exp.m` — 481 lines.
- [ ] **0.1.3.** Apply the template: `saccade/saccade_lr/saccade_lr_exp.m`, `spem/spem_exp.m`, `spem/spem_solo_exp.m` — 1427 lines.
- [ ] **0.1.4.** Apply the template: `fixate/fixate_exp.m`, `free_view/free_view_exp.m` — 796 lines.
- [ ] **0.1.5.** Setup, driver and scratch scripts: `saccade/saccade_setup.m`, `free_view/setup/free_view_setup.m`, `pre_process.m`, `+lib/animate_trial.m`, `movie_test.m` — 322 lines.
- [ ] **0.1.6.** Analysis drivers: `spem/spem_analyze.m`, `free_view/free_view_analyze.m` — 730 lines.

Full detail, tranche sequencing, and per-tranche findings: section 4.1.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">0.2 Tier B — not started</h3></summary>

<div style="margin-left:1.5em">

Semicolon insertion, preallocation, `find`→logical indexing, deleting a provably unused assignment. Checked by a whitelisted-pattern diff **plus** a runtime golden-output match.

- [ ] **0.2.0.** Build `tools/golden_harness.m` covering the three runnable entry points (section 2).
- [ ] **0.2.1.** Preallocate `t`/`xv`/`yv` in `spem/true_target_traj.m:14-23` — the one growth site with both a real fix and runtime coverage.
- [ ] **0.2.2.** Preallocate `dist_pos` in `spem/spem_exp.m:316-317` — pattern check only, no runtime coverage.
- [ ] **0.2.3.** Delete the unused `hcb` assignments at `free_view/free_view_analyze.m:346,360,377,596,638,657` and replace the unused `windowrect` output at `saccade/saccade_lr/saccade_lr_exp.m:64` with `~`.
- [ ] **0.2.4.** The 7 missing semicolons are **deliberate and stay** (decided; see section 4.2). Add a short comment at each so a later pass does not suppress them. Adding only a comment is Tier A, not B, so this rides along with whichever tranche owns the file.

Coverage gaps found while extending the harness, and the fixes made, are detailed in section 4.2.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">0.3 Tier C — next step, done after the readability pass</h3></summary>

<div style="margin-left:1.5em">

Bug fixes, signature changes, merging duplicate functions, reordering statements — not part of the behaviour-preserving Tier A/B pass, done afterward as the next step of the overall cleanup. Bugs found during Tier A/B are recorded here as they're found, then fixed in this tier.

Left unchecked until actually done. Full rationale in section 3.

- [ ] **0.3.1.** Structural consolidation of the five experiment scripts: merge `saccade_lr_exp.m` into `saccade_exp.m` (466 of 481 lines already identical), merge `spem_solo_exp.m` into `spem_exp.m` (340 identical lines), then factor the ~290 lines of EyeLink/Psychtoolbox boilerplate that all five share into one `+lib` helper.
- [ ] **0.3.2.** Signature changes: replace `inputParser` with an `arguments` block in `preprocess_gaze.m`, add validation to the four helper functions that have none, and rename the four name-value literals (`'corners'`, `'calib_sz'`, `'exp_type'`, `'animate'`) if the zone-2 decision in section 4.1.1 says to.
- [ ] **0.3.3.** Turn scripts into functions, or explicitly document the required workspace variables and working directory for the four that stay cell-driven.
- [ ] **0.3.4.** Delete commented-out code — 181 code-like comment lines, concentrated in `free_view_analyze.m` (45), `free_view_setup.m` (27), `free_view_exp.m` (26).
- [ ] **0.3.5.** Reorder statements, even when it looks purely cosmetic.
- [ ] **0.3.6.** Rename the zone-2 cross-file vocabulary listed in section 4.1.1 that `canon` cannot cover — the `'...'` name-value literals and the `exp_type` values `'free_view'`/`'spem'`.
- [ ] **0.3.7.** Rename any zone-3 frozen `save`/`load` name listed in section 4.1.1 — needs a migration script for `free_view_results.mat` (97 subjects, 22 fields) and `spem_results.mat` (102 subjects, 7 fields).
- [ ] **0.3.8.** Add a `setup_path.m` and a `Contents.m` per package. Nothing currently puts `free_view/`, `spem/` or `saccade/` on the path, yet `+lib/preprocess_gaze.m` and `free_view_analyze.m` both need them (verified: with only the repo root on the path, `which true_target_traj` and `which analyze.free_view_measures` are both empty).
- [ ] **0.3.9.** Resolve the missing `colorbarpzn` dependency — `free_view_analyze.m` calls it 9 times and `which colorbarpzn` returns nothing on this machine, so that file cannot run at all right now. Either vendor it or replace it.
- [ ] **0.3.10.** Seed the RNG in `free_view_setup.m` and `saccade_setup.m`. There is no `rng` or `RandStream` call anywhere in the repo, so neither trial list is reproducible.
- [ ] **0.3.11.** Un-hardcode the magic constants: `n_trials = 73` (`free_view_measures.m:3`), `n_trials = 5` (`spem_measures.m:3`, `spem_exp.m:21`), `nTrials = 100` (`saccade_setup.m:1`), and `1920`/`1080` in four separate files.
- [ ] **0.3.12.** Replace the `%%%%%%%%%%` STEP banners. Each such line is a MATLAB section divider, so every experiment file currently has 18 spurious code sections.
- [ ] **0.3.13.** Resolve `movie_test.m`'s deliberate abort at line 14 (bug 0.3.14.15) and its dead `mType == 1` branch. Decided: the file stays in the repo and is cleaned like the rest in tranche 5; only the abort and the dead branch are Tier C work.
- [ ] **0.3.14.** Fix any bug found along the way — recorded here instead:
  - [ ] **0.3.14.1.** `spem/spem_measures.m:60` — `pupil_this = edf_mat.Samples.pupilSize(start_frame:end_frame)` indexes the raw 151246-sample array with indices computed against the 9007-sample downsampled `t_ds`. Measured on `spem/gss004_pre.edf`: trial 1's window should be 1048083-1078089 ms but the code reads 1047962-1049762 ms — 1.8 s of the wrong data instead of 30 s of the right data. Every one of the 102 `pupil_sz_mean` values in `spem_results.mat` is computed from the wrong samples. Reachable on every call.
  - [ ] **0.3.14.2.** `+lib/preprocess_gaze.m:230` — calls `downsample_traj(t_target, t_gaze, traj_gaze, blink_mask)` against the signature `downsample_traj(t_target, traj_target, t_gaze, traj_gaze, blink_gaze)`, so every argument after the first is shifted one position left. The third output then returns `blink_mask(ib)`, an Nx1 vector, which line 232 indexes as `traj_gaze(:,2)` — an out-of-bounds error. Reachable whenever `animate` is true and `exp_type` is `'spem'`.
  - [ ] **0.3.14.3.** `+lib/preprocess_gaze.m:225,230` — calls `true_target_traj` and `downsample_traj`, which live in `spem/`, not in `+lib/`. Verified: with only the repo root on the MATLAB path, `which true_target_traj` is empty, so both calls fail unless the caller has separately added `spem/`.
  - [ ] **0.3.14.4.** `saccade/saccade_setup.m:9` — `save('setup.mat','target_ang')` overwrites `saccade/setup.mat`, which currently holds both `target_ang` and `saccade_type` (verified with `whos -file`). `saccade_exp.m:10` loads both. Re-running the setup script silently breaks the experiment. Needs `-append`, or generating and saving both.
  - [ ] **0.3.14.5.** `free_view/+analyze/free_view_measures.m:40-50,89-96` — two different analysis windows in one function. `end_time` is reassigned at line 42 to `start_time + 3000`, but `end_frame` was already computed at line 33 from the *original* end time, so `dwell_tot` and `pupil` use the full ~10.1 s window while `dwell` and `scan` use only the first 3 s. The comment on line 42 says "first 1.5 s", which matches neither.
  - [ ] **0.3.14.6.** `free_view/free_view_analyze.m:67,306` — `gap` is read at line 67 (`date_EL + gap`) with no assignment anywhere above it, and reassigned at line 306 from a `duration` to a plain number of days. Running the section at line 58 a second time, or at any point after line 306 has executed, silently shifts every `date_EL` by a days-valued number.
  - [ ] **0.3.14.7.** `free_view/free_view_exp.m:13` — the filename pattern `'^[a-z]{3}\d{3}_(pre|post)$'` rejects `_post_control`, yet `fixate/ibo027_post_control.edf` exists and `free_view_analyze.m:31` handles `_post_control` explicitly. The experiment script cannot produce a filename the analysis expects.
  - [ ] **0.3.14.8.** `free_view/setup/free_view_setup.m:87,112` — `load setup.mat`, but `free_view/setup/` holds only `setup_pre.mat` and `setup_post.mat`. The only `setup.mat` in the repo is `saccade/setup.mat`, so if `saccade/` is on the path this silently loads the saccade trial list. The `save('setup.mat',...)` on line 109 is commented out, so the file it expects can no longer be produced either.
  - [ ] **0.3.14.9.** `free_view/setup/free_view_setup.m:48,86,101,131,143` — relative paths of the form `'IAPS/...'`, but IAPS lives at `free_view/data/IAPS/`. The script sits in `free_view/setup/`, so these resolve only with the working directory set to `free_view/data`.
  - [ ] **0.3.14.10.** `free_view/setup/free_view_setup.m:111-127` — the post-shuffle section computes `exp_IAPS_ids_post`, `exp_arousals_post`, `exp_valences_post` and never saves them, while `setup_post.mat` on disk stores those arrays under the *un*-suffixed names plus `post_img_idx` and `post_screen_idx`. As written the script cannot reproduce `setup_post.mat`.
  - [ ] **0.3.14.11.** `spem/spem_exp.m:1` and `spem/spem_solo_exp.m:1` — declare `function smooth_pursuit_exp` and `function smooth_pursuit_solo_exp` in files named `spem_exp.m` and `spem_solo_exp.m` (checkcode `FNDEF`).
  - [ ] **0.3.14.12.** `+lib/preprocess_gaze.m:2,9` — the header reads `PLOT_GAZE(...)` and `parser.FunctionName = 'plot_gaze'`, but the function is `preprocess_gaze`, so `inputParser` error messages name a function that does not exist. Separately, outputs 5 and 6 (`traj_target`, `t_target`) are assigned only inside `if animate` and `exp_type == 'spem'`, so requesting them on any other path errors.
  - [ ] **0.3.14.13.** `+lib/preprocess_gaze.m:264` — the `set(hBase,'XData',xB,'YData',yB)` call is commented out, so the black base trace never draws while `xB`/`yB` still grow by one element per frame (checkcode `NASGU` at line 263). Roughly a quarter of the animation loop's work produces nothing.
  - [ ] **0.3.14.14.** `free_view/free_view_exp.m:135` — `if Eyelink('IsConnected')~=1 && ~dummymode` with `dummymode = 1` set at line 41, so the body is unreachable (checkcode `UNRCH`) and the connection check is dead.
  - [ ] **0.3.14.15.** `movie_test.m:14` — a bare `thfgfgg`, an undefined identifier, aborts the script. The comment above it reads "For dmeo only".
  - [ ] **0.3.14.16.** `+lib/animate_trial.m:9-13` — `trial_num = 70` exceeds the trial count of every spem and fixate recording in the repo (5 `Start` events, verified on `fixate/ibo031_pre.edf`), and the frame arithmetic uses `edf.timeline(1)` whose length (5131) does not match `Samples.gx` (320693 rows), so the index arithmetic is wrong regardless. The script also depends on an undocumented `edf` variable already existing in the caller's workspace.
  - [ ] **0.3.14.17.** `free_view/free_view_analyze.m:6-10` versus `:110-126` — `arousals` and `valences` are sorted once by `setup_pre.mat`'s `exp_IAPS_ids` and then used against both pre and post sessions, while the loop at 107-132 re-sorts each session by its own IDs. Whether the two orderings agree is never checked. Needs verifying, then either a fix or a comment saying why it is fine. Same section, line 124: `dwell = dwell(sort_idx)` linear-indexes an Nx9 matrix with an index built column-major over a 73x9 array; correct only if the `reshape(permute(...))` on line 120 produces exactly that layout, which is nowhere asserted.
  - [ ] **0.3.14.18.** `free_view/free_view_analyze.m:113` — `idxVec = eval(['idx_' sess_this])`, whose trailing comment refers to `idxPre`/`idxPost`, the names used in `spem_analyze.m`, not the `idx_pre`/`idx_post` used here.
  - [ ] **0.3.14.19.** `saccade/saccade_exp.m:255,325,327` — `target_colour` is assigned three times and never read; the `FillOval` and `DrawLine` calls all use literal colour vectors.
  - [ ] **0.3.14.20.** `free_view/free_view_analyze.m:457-458` — the same `plot(valences_rep, z_res, '.k', 'MarkerSize',1)` runs twice in a row, the first without capturing its handle.

Tier C's work log (section 4.3) fills in as each item here is actually done.

</div>

</details>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">1. Scope and measurements</h2></summary>

<div style="margin-left:1.5em">

Every number in this document was measured on the repo as it stands (MATLAB 24.2.0.2923080, R2024b Update 6), not estimated. Re-measure before trusting any of them after substantial changes.

**Scope, precisely.** Excluded: `notes/` (186 MB of talks, posters, videos — no code), all `*.edf` recordings (346 files, ~2.9 GB, in `fixate/`, `free_view/data/`, `saccade/`, `saccade/saccade_lr/`, `spem/`), `free_view/data/IAPS/` (about 1000 stimulus JPEGs plus four spreadsheets), and the seven `.mat` artifacts. That leaves **all 18 `.m` files, 4300 lines** in scope, none excluded. `movie_test.m` (67 lines) is a lightly-edited Psychtoolbox demo that nothing calls, and excluding it was considered and rejected — it is cleaned like the rest, in tranche 5.

Per directory:

| Directory | Files | Lines |
|---|---|---|
| repo root | 2 | 134 |
| `+lib/` | 2 | 322 |
| `fixate/` | 1 | 339 |
| `free_view/` | 2 | 1132 |
| `free_view/+analyze/` | 1 | 137 |
| `free_view/setup/` | 1 | 149 |
| `saccade/` | 2 | 491 |
| `saccade/saccade_lr/` | 1 | 477 |
| `spem/` | 6 | 1119 |

The line count badly misrepresents where the work is. The five `*_exp.m` files are 2703 lines, 63% of the repo, and are 70-97% mutually identical Psychtoolbox/EyeLink boilerplate: `saccade_exp.m` and `saccade_lr_exp.m` share 466 identical lines out of 481, `spem_exp.m` and `spem_solo_exp.m` share 340, `saccade_exp.m` and `spem_exp.m` share 366, `free_view_exp.m` and `saccade_exp.m` share 290. All the actual science sits in 544 lines of analysis chain plus 730 lines of analysis driver.

**Version control, resolved.** The survey was carried out on `G:\My Drive\Eye-tracking`, which had no `.git` at all. The code has since been moved to `G:\My Drive\eye-tracking-psychedelics`, a GitHub repo on branch `main` with an initial commit of `LICENSE`, `README.md` and `.gitattributes`. All 18 `.m` files came across unchanged — line counts and byte-level line-ending counts match the survey exactly — so every number in this document still applies. Tranche 0 added a `.gitignore` (excluding `*.edf`, `*.mat`, `free_view/data/IAPS/`, `notes/`, and MATLAB editor leftovers) and committed the 18 files plus this document as the pass's baseline: 4789 lines, no file over 200 kB. The ~3 GB of recordings, stimuli and talks stay on Drive, outside the repo.

**One line-ending caveat that follows from that.** `.gitattributes` sets `* text=auto` and this machine has `core.autocrlf=true`, so git stores LF in the index and hands back CRLF on checkout. The five LF files listed under **Formatting** below will therefore be rewritten to CRLF by git the next time it touches them — a whole-file byte change git makes on its own, unrelated to the cleanup. `check_tier_a` is immune, because `mtree` reparses the file and `tree2str` normalises whitespace; a byte-level comparison against a pre-edit backup is *not* immune. Normalise line endings on both sides before any such comparison.

**What is actually wrong with the files**, measured, not assumed:

- **Lint.** 53 `checkcode` messages across the 18 files; 8 files are clean. By id: 19 `SAGROW`, 14 `AGROW`, 8 `NASGU`, 7 `NOPTS`, 2 `FNDEF`, 1 each of `ASGLU`, `CLALL`, `UNRCH`. Concentration: `free_view_analyze.m` 22, `preprocess_gaze.m` 14, `spem_analyze.m` 6, `free_view_setup.m` 3, `spem_exp.m` 3.
- **Formatting.** No tab-indented files — indentation is uniformly spaces. 62 lines exceed 100 characters, worst offender `spem/spem_solo_exp.m:300` at 184 characters; next worst `free_view_analyze.m:310` at 141. Concentration: `free_view_analyze.m` 12, `spem_solo_exp.m` 12, `free_view_exp.m` 7, `saccade_exp.m` 7, `saccade_lr_exp.m` 7, `spem_exp.m` 6, `fixate_exp.m` 5, `preprocess_gaze.m` 4. **Line endings are mixed**: 13 files are CRLF and 5 are LF — `free_view_exp.m`, `saccade_exp.m`, `saccade_lr_exp.m`, `spem_exp.m`, `spem_solo_exp.m`, which is four of the five experiment scripts plus one, while `fixate_exp.m` is CRLF. This is why a byte-level `diff` between `saccade_exp.m` and `fixate_exp.m` reports **zero** identical lines: every line differs by its terminator alone. Strip CR before any file-level comparison — normalised, those two share 292 identical lines. 200 lines carry trailing whitespace, concentrated in `free_view_exp.m` (86 of 457) and `spem_solo_exp.m` (76 of 462); `fixate_exp.m`, `preprocess_gaze.m`, `spem_exp.m`, `movie_test.m`, `pre_process.m`, `downsample_traj.m` and `true_target_traj.m` have none.
- **Header docs.** **Zero** files have an `Inputs` block. **One** has an output block (`spem/true_target_traj.m`, headed `Returns:`). **Zero** have a `See also`. **Zero** `Contents.m` files exist. Four experiment files carry an identical decorative banner with a one-line task description, and `fixate_exp.m`'s says "Pro-saccade and anti-saccade task" — copied verbatim from `saccade_exp.m` and wrong for a 5-minute fixation task. `free_view_measures.m`, `spem_measures.m` and `saccade_setup.m` have no header comment at all.
- **Names.** The abbreviation counts, code only with comments stripped: `el` 63, `edf_mat` 42, `iTrial` 40, `edf_default` 35, `idx` 34, `winWidth` 32, `winHeight` 30, `iScreen` 28, `edf_file` 26, `V` 21, `ulim` 18, `llim` 18, `iCorner` 18, `n_trials` 16, `vs` 15, `log_f_corr_dwell` 15, `n_screens` 14, `fix_pos` 14, `corr_dwell` 13, `vsn` 12, `v` 12, `res` 12, `n_imgs` 12, `labEff` 11, `calib_sz` 11, `Pp` 10. Then a long tail of single and double capitals inside `preprocess_gaze.m`'s homography block — `A`, `H`, `P`, `Pp`, `U`, `V`, `VV`, `hvec`, `L`, `C`, `S` — which is the densest naming problem in the repo per line.
- **Names diverge across call boundaries.** `free_view_analyze.m` uses `idx_pre`/`idx_post`/`isPre`/`isPost`; `spem_analyze.m` uses `idxPre`/`idxPost`/`isPre`/`isPost` for exactly the same concept in near-identical code (both derive matched pre/post pairs from `regexprep` of the name list). `n_trials` (16 occurrences) and `nTrials` (8) coexist for the same quantity. Screen dimensions appear as `screen_w`/`screen_h` (`preprocess_gaze.m`, `pre_process.m`), `screen_width`/`screen_height` (`free_view_measures.m`), `screenWidth`/`screenHeight` (`free_view_exp.m`) and `winWidth`/`winHeight` (all five experiment files) — four spellings of two quantities.
- **Convention splits.** Not a directory split, which is what the layout suggests; the two conventions are mixed inside single files. snake_case dominates (roughly 370 distinct identifiers) with a persistent camelCase minority (85 distinct) inherited from Psychtoolbox demo code: `iTrial`, `winWidth`, `winHeight`, `screenNumber`, `numRows`/`numCols`, `lineWidth`, plus a home-grown camelCase cluster in `preprocess_gaze.m` (`cornerIntervals`, `cornerIdx`, `cornerStartsT`, `trialEndsT`, `isCornerStart`, `isTrialEnd`, `msgT`, `msgS`, `labEff`, `prevLabEff`, `maskCorner`) and in `pre_process.m` (`edfFiles`, `allNames`, `doneNames`, `todoNames`, `grpRank`, `numID`, `phaseRank`, `initPos`).
- **Builtin shadows.** `type` (`free_view_exp.m:22-23`, holding the session phase), `err` (`spem_measures.m`, `spem_analyze.m`), `res` (6 assignments across the experiment files, holding the `Eyelink('Openfile')` status), `i` (5 loop assignments), `beta` (`free_view_analyze.m:424`), and `gap` / `scan` / `pupil` which shadow nothing builtin but collide with frozen struct field names (section 4.1.1).
- **Commented-out code.** 181 code-like lines out of 1458 total comment lines. Concentration: `free_view_analyze.m` 45 of 146, `free_view_setup.m` 27 of 53 (an entire deprecated binning algorithm, lines 1-44), `free_view_exp.m` 26 of 186, `spem_solo_exp.m` 15, `saccade_exp.m` 14, `saccade_lr_exp.m` 14, `spem_exp.m` 13, `spem_measures.m` 13 of 27. Not removed — Tier C, item 0.3.4.
- **Argument validation.** No `arguments` block anywhere. One `inputParser`, in `preprocess_gaze.m:9-19`, and it names the wrong function. The other four helper functions (`free_view_measures`, `spem_measures`, `downsample_traj`, `true_target_traj`) validate nothing. Adding validation is Tier C, item 0.3.2.
- **Other measured facts that shape the plan.** No `parfor` anywhere, so no worker-order float-accumulation risk. No `rng` or `RandStream` anywhere, so nothing in the repo is reproducible; RNG draws occur only in `free_view_setup.m` (lines 59, 65, 79, 116, 123) and `saccade_setup.m` (line 8). One `eval`, at `free_view_analyze.m:113`. Seven of the 18 files are scripts, not functions — `movie_test.m`, `pre_process.m`, `free_view_analyze.m`, `free_view_setup.m`, `+lib/animate_trial.m`, `saccade_setup.m`, `spem_analyze.m` — and four of those are cell-divided interactive workflows that must be run section by section with workspace carryover. No two `.m` files share a basename, so there are no filename-conflict copies to resolve.

**The style target already exists** — do not invent a new one. The exemplar named by the `matlab-repo-cleanup` skill is `vislab-common/+vislab/+lib/watson_otf.m`, whose shape is: a summary line, a fully-qualified signature, an `Inputs`/`Output` block with units on every entry, and a `See also`. That file is **not reachable on this machine** — searches of `G:\My Drive`, `C:\Users\Abhranil\Documents` and `C:\Users\Abhranil\Desktop` found no `watson_otf.m` and no `vislab-common` repo (the `G:\My Drive\claude-projects\vislab-common` hit is a Claude session directory, not the repo). So the target has to be reconstructed from that description. The closest in-repo approximation is `spem/true_target_traj.m`, the only file with a documented output block and an example of the input it parses; it still lacks a signature line, units, and a `See also`. No in-scope file shares a name with anything in a sibling repo or an ancestral-code tree, because no sibling repo is present here at all.

</div>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">2. The check (Tier A) and what the repo affords for Tier B</h2></summary>

<div style="margin-left:1.5em">

`mtree` parses a `.m` file into MATLAB's own syntax tree, and `tree2str` prints it back in canonical form: comments stripped, whitespace/bracket spacing normalised, missing `end` supplied.

```matlab
canon = @(f) tree2str(mtree(f,'-file'));
```

This gives a fingerprint blind to exactly what Tier A is allowed to change, sensitive to everything else. **Verified: succeeds on all 18 in-scope files.** Fingerprint sizes, which double as a cheap sanity check that the right file was read:

| File | canon chars | File | canon chars |
|---|---|---|---|
| `movie_test.m` | 1273 | `saccade/saccade_exp.m` | 9116 |
| `pre_process.m` | 1461 | `saccade/saccade_setup.m` | 91 |
| `+lib/animate_trial.m` | 605 | `saccade/saccade_lr/saccade_lr_exp.m` | 8832 |
| `+lib/preprocess_gaze.m` | 9439 | `spem/downsample_traj.m` | 517 |
| `fixate/fixate_exp.m` | 5974 | `spem/spem_analyze.m` | 1479 |
| `free_view/free_view_analyze.m` | 16870 | `spem/spem_exp.m` | 9294 |
| `free_view/free_view_exp.m` | 7848 | `spem/spem_measures.m` | 1169 |
| `free_view/+analyze/free_view_measures.m` | 3740 | `spem/spem_solo_exp.m` | 7880 |
| `free_view/setup/free_view_setup.m` | 2989 | `spem/true_target_traj.m` | 533 |

Reverse-rename check: clean a file (renames, header, reflow), then undo the rename map on the canonical form of the new file and assert it's identical to the canonical form of the old one:

```matlab
c_new = canon(new_file);
for k = 1:size(renames,1)   % renames = {new_name, old_name}
    c_new = regexprep(c_new, ['(?<![A-Za-z0-9_.])' renames{k,1} '(?![A-Za-z0-9_])'], renames{k,2});
end
isequal(canon(old_file), c_new)   % must be true
```

The lookahead `(?![A-Za-z0-9_])` matters: without it a short name can wrongly match inside a longer one. This repo has several live instances of that trap — `dwell` inside `dwell_tot`, `dwell_raw`, `corr_dwell`, `d_dwell`, `f_corr_dwell`; `pupil` inside `pupil_raw`, `pupil_dil`, `pupil_sz_mean`, `mean_pupil`; `scan` inside `scan_pre`, `scan_post`, `scan_all`, `d_scan`, `d_tot_scan`; `fix_x` inside `fix_x_bin`; `gaze_x` inside `gaze_x_bin` and `gaze_x_this`; `err` inside `err_this`, `d_err`, `avg_d_err`. The rename map itself must be a bijection with disjoint domain/range — assert this before using it:

```matlab
dom = renames(:,1); ran = renames(:,2);
assert(numel(unique(dom)) == numel(dom));
assert(numel(unique(ran)) == numel(ran));
assert(isempty(intersect(dom, ran)));
```

Caveat: `mtree`/`tree2str` are undocumented MATLAB APIs — pin the MATLAB version (R2024b Update 6) in every commit message that depends on the check.

**Two consequences of `canon`'s blindness that bite specifically here.** First, `canon` does *not* strip string literals, so `preprocess_gaze.m`'s four name-value names (`'exp_type'`, `'animate'`, `'corners'`, `'calib_sz'`) and the `exp_type` values (`'free_view'`, `'spem'`) appear in the fingerprint; changing any of them shows up as a real diff and is therefore Tier C, not Tier A, even though it looks like a rename. Second, `check_tier_a` excludes dot-qualified names, so a local variable can be renamed while a struct field of the same original name cannot. This repo has three live instances: local `scan` versus frozen field `.scan`, local `gap` versus frozen field `.gap`, local `dwell`/`corr_dwell`/`pupil` versus the frozen fields of the same names in `free_view_results.mat`. Where a rename creates that mismatch, note it in-file so the next reader is not confused.

**Version control has to come first, before any tranche.** There is no git repo, so there is no HEAD baseline for anything. Two options, and this needs the user's decision:

1. **Recommended: `git init` in the repo root, with a `.gitignore` for `*.edf`, `*.mat`, `notes/`, `free_view/data/`, and commit the 18 `.m` files.** That gives a real baseline, a real per-tranche diff, and the "one commit per tranche" discipline the pass is built around. The ~2.9 GB of recordings and ~1 GB of stimuli stay out of the repo and stay where they are on Drive.
2. **Fallback: a pre-edit backup copy tree per tranche**, diffed with `check_tier_a` against the backup rather than against HEAD. Workable, but there is then no cumulative history, and a mistake spanning two tranches is much harder to see.

Either way, take the backup copy of each file's current on-disk content before editing it, because Google Drive sync can touch files underneath the working session.

**Tier B's extra requirement: runtime golden output.** Some of this repo executes and some of it cannot, and the split is stark. Measured, not assumed:

**Covered by a real runtime golden — 5 files, 544 lines, 13% of the repo.** `Edf2Mat` is installed (`...\MATLAB Add-Ons\Collections\uzh_edf-converter\@Edf2Mat\Edf2Mat.m`) and parses the repo's recordings in about 2.3 s each, and the whole analysis chain runs headless under `set(0,'DefaultFigureVisible','off')`. Three entry points, called directly and never through a top-level driver, with the golden values already captured:

| Entry point | Input | Golden output |
|---|---|---|
| `lib.preprocess_gaze` | `fixate/ibo031_pre.edf`, no corners | gaze checksum `457109205.8`, size `[320693 1]` |
| `lib.preprocess_gaze` + `analyze.free_view_measures` | `free_view/data/gss005_pre.edf` with `free_view_results(1).corners` | `dwell_tot` 730, `dwell` 166.395, `pupil` 603787.894, `scan` 210754.3934 |
| `lib.preprocess_gaze` + `spem_measures` | `spem/gss004_pre.edf` with `results(1).corners`, `calib_sz = 2/3` | `err` `[53.4347 80.9181 41.8239 49.6224 76.914]`, `pupil_sz_mean` `[2309.65 2488.99 2469.25 2711.86 2573.73]` |

The third entry point exercises `true_target_traj.m` and `downsample_traj.m` internally, which is how those two small files get covered. Nothing on this path touches the RNG (verified: `rand`, `randn`, `randi`, `randperm`, `randsample` appear only in the two setup scripts), so no seeding is needed for replay — but seed anyway, once the Tier C item 0.3.10 adds seeds, so the harness stays valid. Reduce every output to a checksum or a size vector with an explicit `'all'`, not the whole array, so the golden `.mat` stays small. Gate the `Edf2Mat` calls on `exist` and warn rather than error, since the recordings are not in version control and may not be present on another machine.

**Pattern-check only, no runtime golden — 13 files, 3756 lines, 87% of the repo.** This is a deliberate decision, written down here rather than left as an omission, because it is the pass's main weakness:

- The five `*_exp.m` files need Psychtoolbox *and* a live EyeLink host. Psychtoolbox 3.0.19 is installed, but four of the five set `dummymode = 0`, so they cannot even be dry-run. These are 2703 lines, 63% of the repo, verified by `check_tier_a` and the four-pattern check alone.
- `free_view_analyze.m` (675 lines) calls `colorbarpzn` nine times and `which colorbarpzn` returns nothing, so the file cannot execute on this machine at all until Tier C item 0.3.9 resolves it. It is also a cell script that depends on `gap` pre-existing in the workspace (bug 0.3.14.6), so even with the dependency installed there is no top-to-bottom run.
- `spem_analyze.m` is a cell script whose first section re-parses all 102 subjects through `Edf2Mat` — roughly 10 minutes of disk I/O — and then writes back into `results`. Per the skill's rule, never run this as a verification step; if a runtime check is ever wanted here, build an isolated synthetic replica of the loop with the same iteration count instead.
- `free_view_setup.m` and `saccade_setup.m` draw unseeded RNG and write `.mat` artifacts that shipped analyses depend on. Running them *is* the destructive act (bug 0.3.14.4). No runtime check; pattern check only.
- `pre_process.m` requires interactive polygon-dragging (`drawpolygon`) and `+lib/animate_trial.m` requires an undocumented `edf` variable in the caller's workspace. Neither has a callable entry point.
- `movie_test.m` aborts by design at line 14.

**No `parfor` loops anywhere in the repo**, so there is no reduction-versus-sliced-output question to resolve and no worker-order effect on float accumulation. If a later Tier C change introduces one, that change is Tier C by definition.

</div>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">3. Three tiers of change, in full</h2></summary>

<div style="margin-left:1.5em">

| Tier | Change | Canonical diff | Verification |
|---|---|---|---|
| **A** | Comments, header docs, whitespace, reflow, blank-line grouping, file-local renames | empty (after reverse rename) | `isequal` — fully automatic, no execution |
| **B** | Adding a suppressing `;`, preallocation, `find`→logical indexing, deleting a provably unused assignment | non-empty but must match a whitelisted pattern | pattern check **plus** runtime golden output |
| **C** | Bug fixes, signature changes, adding `arguments` blocks, merging duplicate functions, reordering statements, changing accumulation order in a float reduction, anything touching the RNG stream, **deleting commented-out code** | — | **not part of the behaviour-preserving pass** — reviewed and done individually, once Tier A/B is done |

Semicolon insertion is Tier B, not A: `tree2str` preserves display-vs-suppress, so the canonical diff is exactly `X` → `X;` — trivially whitelisted, but not invisible.

Tier C matters most. The tempting changes are all Tier C (see section 0.3's list). Every one of them changes output, call sites, or validation behaviour, so none of them belong in the behaviour-preserving pass — keeping them out is what makes that pass's diff skimmable instead of line-by-line. They are the next step of the same overall cleanup, not abandoned.

In this repo the temptation is unusually strong, and worth naming explicitly so it can be resisted: 2703 of the 4300 lines are near-duplicate boilerplate that is *obviously* mergeable, and the merge would cut the repo by roughly a third in one commit. Do not do it during Tier A. It is item 0.3.1, done after the readability pass, with individual review — because the five copies have quietly diverged (`dummymode` differs, `screenNumber` differs, the drift-correction call is commented out in some and not others, `free_view_exp.m` alone uses a `'data/'` subdirectory prefix), and a merge has to decide each of those. That decision is invisible to `canon` and cannot be checked mechanically.

When the pass uncovers a *bug* — and it already has, twenty times over, see section 0.3.14 — **record it in the findings list first**, so the recording survives even before the fix happens; the fix itself comes later, as a Tier C item. Two of those twenty (0.3.14.1 and 0.3.14.2) invalidate published numbers or crash on a reachable path, and the pull to fix them immediately will be strong. Resist it: a bug fix in the middle of a Tier A tranche makes that tranche's `check_tier_a` fail, and a failing check that is *expected* to fail is worthless as a check.

Statement reordering is kept out of Tier A/B even though it looks cosmetic, purely because the check cannot distinguish a safe reorder from an unsafe one — it gets the same individual review as the rest of Tier C.

</div>

</details>

---

<details>
<summary><h2 style="display:inline; margin:0; font-size:1.15em">4. Tier-by-tier details and work log</h2></summary>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">4.1 Tier A — renaming zones, tranches, and findings log</h3></summary>

<div style="margin-left:1.5em">

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">4.1.1 Renaming: three zones</h4></summary>

<div style="margin-left:1.5em">

The rename map is the pass's most valuable artifact and its main divergence risk — build it first, once, repo-wide, before any tranche.

**1. File-local variables — free.** These are file-local, so `canon` makes them completely safe. The dense cases first, since `+lib/preprocess_gaze.m` alone holds most of the repo's single-capital naming:

| Old | New | Where | Note |
|---|---|---|---|
| `S` | `samples` | `preprocess_gaze.m:22` | |
| `L` | `corner_label` | `preprocess_gaze.m:92-94` | 0 = base, 1-4 = corner interval id |
| `C` | `corner_colors` | `preprocess_gaze.m:98` | 4x3 RGB |
| `U`, `V` | `observed_px`, `ideal_px` | `preprocess_gaze.m:123-124` | homography correspondences |
| `A` | `dlt_matrix` | `preprocess_gaze.m:131` | the 2n x 9 DLT system |
| `VV`, `hvec`, `H` | `dlt_null_basis`, `homography_vec`, `homography` | `preprocess_gaze.m:138-140` | `hvec`/`H` already carry "was:" comments from a previous rename — delete those comments |
| `P`, `Pp` | `pts_homog`, `pts_homog_mapped` | `preprocess_gaze.m:147-155` | reused for gaze then fixations |
| `b_st`, `b_en` | `blink_start_ms`, `blink_end_ms` | `preprocess_gaze.m:31-36` | |
| `nb` | `not_blink` | `preprocess_gaze.m:180` | |
| `xb`, `yb`, `xb_nb`, `yb_nb`, `xb_bk`, `yb_bk` | `gaze_x_base`, `gaze_y_base`, `..._noblink`, `..._blink` | `preprocess_gaze.m:169-181` | |
| `msgT`, `msgS` | `msg_time_ms`, `msg_text` | `preprocess_gaze.m:50-56` | |
| `lab`, `labEff`, `prevLabEff` | `label`, `label_eff`, `label_eff_prev` | `preprocess_gaze.m:239-283` | `label_eff` folds blink into class 5 |
| `xB`/`yB`, `xR`/`yR`, `xK`/`yK` | `base_x`/`base_y`, `blink_x`/`blink_y`, `seg_x`/`seg_y` | `preprocess_gaze.m:259-280` | |
| `ulim`, `llim` | `clim_upper`, `clim_lower` | `free_view_analyze.m`, 18 each | colour-axis limits |
| `hcb`, `cb`, `hImg` | `h_colorbar`, `h_colorbar`, `h_image` | `free_view_analyze.m` | six of the `hcb` assignments are unused — Tier B item 0.2.3 |
| `tf`, `loc` | `has_match`, `match_idx` | `free_view_analyze.m`, `spem_analyze.m` | |
| `v`, `vs`, `vsn` | `tracker_version`, `tracker_version_str`, `tracker_version_digits` | all five `*_exp.m` | |
| `res` | `open_file_status` | all five `*_exp.m` | un-shadows builtin `res` |
| `err` | `tracking_err_px` | `spem_measures.m`, `spem_analyze.m` | un-shadows builtin `err`; the frozen field `.err` stays |
| `type` | `session_phase` | `free_view_exp.m:22-23` | un-shadows builtin `type` |
| `gap` | `session_gap_days` at `free_view_analyze.m:306`, `session_gap` at `:67` | `free_view_analyze.m` | the two are different things — see bug 0.3.14.6; the frozen field `.gap` stays |
| `i` | `i_pic`, `i_corner`, `i_sess`, … | 5 sites | name each for what it indexes |
| `beta`, `Y`, `X` | `beta_std`, `design_mem`, `design_std` | `free_view_analyze.m:421-439` | un-shadows builtin `beta` |
| `idx`, `k`, `idxVec` | `i_session`, `i_pair`, `session_idx` | `free_view_analyze.m`, `spem_analyze.m` | |
| `grp`, `grpRank`, `numID`, `phaseRank`, `ord` | `group`, `group_rank`, `subject_num`, `phase_rank`, `sort_order` | `pre_process.m:55-66` | |
| `iTrial`, `iCorner`, `iScreen`, `iPic`, `iBin`, `i_todo`, `i_dist` | `i_trial`, `i_corner`, `i_screen`, `i_pic`, `i_bin`, `i_todo`, `i_dist` | repo-wide | the camelCase-to-snake_case half of the convention decision |
| `winWidth`, `winHeight` | `win_width_px`, `win_height_px` | all five `*_exp.m` | |
| `screenWidth`/`screenHeight`, `screen_w`/`screen_h` | `screen_width_px`, `screen_height_px` | `free_view_exp.m`, `preprocess_gaze.m`, `pre_process.m` | collapses four spellings into one |
| `nTrials` | `n_trials` | `saccade_exp.m`, `saccade_lr_exp.m`, `free_view_exp.m`, `saccade_setup.m` | |
| `numRows`, `numCols`, `quadWidth`, `quadHeight`, `quads` | `n_rows`, `n_cols`, `cell_width_px`, `cell_height_px`, `cell_rects` | `free_view_exp.m:336-345` | they are 3x3 grid cells, not quadrants — the existing name is actively wrong |
| `cornerIntervals`, `cornerIdx`, `cornerStartsT`, `trialEndsT`, `isCornerStart`, `isTrialEnd`, `nextEndIdx`, `maskCorner` | `corner_intervals_ms`, `corner_sample_idx`, `corner_start_ms`, `trial_end_ms`, `is_corner_start`, `is_trial_end`, `next_end_idx`, `is_corner_sample` | `preprocess_gaze.m` | |
| `edfFiles`, `allNames`, `doneNames`, `todoNames`, `initPos` | `edf_files`, `all_names`, `done_names`, `todo_names`, `init_pos_px` | `pre_process.m` | |
| `trialTime`, `sttime`, `amplitudeX`, `amplitudeY`, `phaseX`, `phaseY`, `sine_plot_x` | `trial_end_time`, `trial_start_time`, `amplitude_x_px`, `amplitude_y_px`, `phase_x`, `phase_y`, `sine_plot_x_px` | `spem_exp.m`, `spem_solo_exp.m` | |
| `doMovie`, `mType`, `moviePtr`, `windowRect`, `xyPos`, `middleX`, `middleY` | `do_movie`, `movie_type`, `movie_ptr`, `window_rect`, `xy_pos_px`, `middle_x_px`, `middle_y_px` | `movie_test.m` | |
| `participantGrid`, `valenceGrid`, `nColors`, `cmap` | `participant_grid`, `valence_grid`, `n_colors`, `red_to_blue` | `free_view_analyze.m:316-320,539` | |
| `fix_this`, `dwell_this`, `pupil_sz_this`, `dwell_fix_this`, `gaze_x_this` | keep `_this` suffix, it reads fine | `free_view_measures.m` | deliberately left alone |

**2. Cross-file vocabulary — repo-wide, or not at all.** Two sub-vocabularies:

- **The parameter names of `lib.preprocess_gaze`, which are string literals at every call site.** Four of them: `'exp_type'`, `'animate'`, `'corners'`, `'calib_sz'`, read at `free_view_analyze.m:76`, `spem_analyze.m:9`, `pre_process.m:41`. Because `canon` keeps string literals, renaming these produces a real canonical diff and so is **Tier C, item 0.3.2 — deferred, its own pass**. The same applies to the `exp_type` *values* `'free_view'` and `'spem'`, compared with `strcmpi` at `preprocess_gaze.m:189,208,223,250`. The local variables that *hold* these values are zone 1 and free.
- **Function arguments named consistently across the repo.** `edf_mat` (42 occurrences, the `Edf2Mat` object, first argument of four of the five helper functions) and the output contract of `preprocess_gaze` — `gaze_x`, `gaze_y`, `fix_x`, `fix_y` — passed straight into `free_view_measures` and `spem_measures`. These are positional, so renaming them is safe under `canon`, but it must be done in the same tranche across every file that touches them or not at all. All five files live in tranche 1 for exactly this reason. Recommended: keep `edf_mat` as is (it is short, accurate, and 42 occurrences of churn buys nothing), and keep `gaze_x`/`gaze_y`/`fix_x`/`fix_y` while adding the `_px` unit to the header docs rather than to the names, since these appear in tight arithmetic where longer names would force reflows. **A half-done rename here is worse than none.**
- **The pre/post index vocabulary**, duplicated between `free_view_analyze.m` (`idx_pre`, `idx_post`, `idx_post_matched`, `basePre`, `basePost`, `isPre`, `isPost`) and `spem_analyze.m` (`idxPre`, `idxPost`, `basePre`, `basePost`, `isPre`, `isPost`). Both sets are file-local, so both are free under `canon`, but they must be unified to one spelling: `idx_pre`, `idx_post`, `base_pre`, `base_post`, `is_pre`, `is_post`. Decided in tranche 6, which holds both files.

**3. Serialised variable names — frozen.** Every name below appears as a variable inside a shipped `.mat` artifact, so renaming it breaks reading that artifact. Enumerated from `whos -file` on all seven `.mat` files, not from the source:

| Artifact | Frozen names |
|---|---|
| `free_view/data/free_view_results.mat` | `free_view_results`, and its 22 struct fields: `name`, `date_manual`, `date_EL`, `gap`, `corners`, `dwell_tot_raw`, `dwell_raw`, `pupil_raw`, `scan`, `corr_dwell_raw`, `dwell`, `corr_dwell`, `pupil`, `mean_pupil`, `pupil_dil_raw`, `pupil_dil`, `d_dwell`, `d_corr_dwell`, `d_scan`, `d_tot_scan`, `f_pupil_dil`, `f_corr_dwell` |
| `spem/spem_results.mat` | `results`, and its 7 struct fields: `name`, `corners`, `err`, `pupil_sz_mean`, `d_err`, `d_pupil_sz_mean`, `f_pupil_sz_mean` |
| `free_view/data/IAPS/IAPS_ratings.mat` | `IAPS_id`, `arousal_avg`, `arousal_sd`, `valence_avg`, `valence_sd`, `dominance_avg`, `dominance_sd` |
| `free_view/setup/setup_pre.mat` | `exp_IAPS_ids`, `exp_arousals`, `exp_valences` |
| `free_view/setup/setup_post.mat` | the same three, plus `post_img_idx`, `post_screen_idx` |
| `saccade/setup.mat` | `target_ang`, `saccade_type` |
| `saccade/saccade_lr/setup_lr.mat` | `target_dir`, `saccade_type` |

Names frozen in one place and free in another, which is where this goes wrong quietly:

- `results` is frozen as the variable name in `spem_results.mat`, and `pre_process.m` and `spem_analyze.m` both use a bare local `results` that holds it. The local is free; the `load`/`save` string is not.
- `scan`, `dwell`, `corr_dwell`, `pupil`, `mean_pupil`, `err`, `gap` are frozen as **struct fields** of the two results structs, and also exist as **free local variables** in `free_view_measures.m`, `spem_measures.m`, `free_view_analyze.m` and `spem_analyze.m`. `check_tier_a` excludes dot-qualified names, so renaming the local while the field keeps its name passes the check and is correct — but it creates a visible mismatch in lines like `free_view_results(idx).scan = scan_len_px;`. Note each such mismatch in-file.
- `exp_ids` (`free_view_setup.m:52`), `exp_IAPS_ids_post`, `exp_arousals_post`, `exp_valences_post` (`free_view_setup.m:117-119`) are **not** in any `.mat` and are free, even though they look exactly like the frozen ones. `post_img_idx` and `post_screen_idx`, two lines away at 116 and 121, **are** frozen.
- `target_ang` versus `target_dir` are frozen in *different* artifacts, which is the whole reason `saccade_exp.m` and `saccade_lr_exp.m` cannot simply be merged during Tier A.

**Units are the other half of naming** — state them in every header, since not one file currently does:

- **Pixels**, screen coordinates with y growing downward: `gaze_x`, `gaze_y`, `fix_x`, `fix_y`, `corners`, `fix_pos`, `target_pos`, `antitarget_pos`, `corner_pos`, `dist_pos`, `screen_width`/`screen_height` (1920 x 1080 throughout), `win_width`/`win_height`, `target_circ_radius`, `dot_radius`, `target_radius`, `half_length`, `amplitude_x`/`amplitude_y`, `scan` (scanpath length, a sum of pixel distances).
- **Milliseconds**, EyeLink tracker clock: `edf_mat.Samples.time`, `Events.Efix.start`, `Events.Efix.duration`, `Events.Eblink.start`/`.end`, `Events.Messages.time`, `Events.Start.time`, `Events.End.time`, `t_gaze`, `t_target`, `t_ds`, `blink_pad_ms`, `start_time`, `end_time`, `corner_intervals`.
- **Seconds**: `dwell`, `dwell_tot`, `fixation_duration`, `target_duration`, `trial_duration`. Note that `fixation_duration` means 0.2 s in `free_view_exp.m:31`, 1 s in `saccade_exp.m:12`, and 300 s in `fixate_exp.m:10` — same name, three orders of magnitude apart. Each header must say so.
- **Radians**: `target_ang`, `phases_target`, `phases_dist`, `phase_x`, `phase_y`.
- **Cycles per trial** (not Hz): `freqs_target`, `freqs_dist`, `freqs`.
- **Dimensionless**: `calib_sz` is a fraction of the screen, not a length — 2/3 in `pre_process.m:28` and `spem_analyze.m:3`, 1 by default. `saccade_type` is a logical, true = pro-saccade. `target_dir` is a logical, not an angle. `arousal_avg`, `valence_avg`, `dominance_avg` are IAPS 1-9 rating scales. `pupil_dil`, `f_pupil_dil`, `f_corr_dwell` are ratios; `f_*` means "fractional change", `d_*` means "difference", and neither prefix is documented anywhere.
- **Arbitrary EyeLink area units**: `pupilSize`, `pupil_raw`, `pupil`, `mean_pupil`, `pupil_sz_mean`. These are not mm and not normalised, which is exactly why `pupil_dil` divides by a per-participant mean.
- **Days as a plain number** after `free_view_analyze.m:306`, a `duration` object before it: `gap`. This is bug 0.3.14.6 and the unit change is the mechanism.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">4.1.2 Tranches, sequencing, and model assignment</h4></summary>

<div style="margin-left:1.5em">

The work is not distributed the way the file count suggests. Eighteen files sounds like a two-session job; the honest picture is that five files hold 63% of the lines and are near-duplicates of each other, five more hold all the science in 13% of the lines, and one file (`free_view_analyze.m`, 675 lines) is the single densest naming problem in the repo. So the batches are sized by lines and by how much each one's decisions bind what follows, not by file count.

| # | Tranche | Files / lines | Model / effort | Why |
|---|---|---|---|---|
| 0 | Rename map + `canon`/`check_tier_a`/`assert_rename_bijection` + golden harness. Version control and `.gitignore` **done** | — | Opus, medium | Every other step trusts this being right |
| 1 | Analysis chain: `+lib/preprocess_gaze.m`, `spem/downsample_traj.m`, `spem/true_target_traj.m`, `spem/spem_measures.m`, `free_view/+analyze/free_view_measures.m` | 5 / 544 | Opus, high | Sets naming conventions for everything downstream; holds the entire zone-2 cross-file contract (`edf_mat`, `gaze_x`/`gaze_y`/`fix_x`/`fix_y`); the densest single-capital naming in the repo; and it is the only tranche with real runtime golden coverage, so get it right while the check is strongest. Helpers before their callers. |
| 2 | Template experiment file: `saccade/saccade_exp.m` | 1 / 481 | Opus, medium | One decision about EyeLink boilerplate, header shape, banner treatment and STEP-comment reflow, made once. `saccade_exp.m` is the newest and cleanest of the five. Its cleaned form becomes the template for tranches 3 and 4. |
| 3 | Apply the template: `saccade/saccade_lr/saccade_lr_exp.m`, `spem/spem_exp.m`, `spem/spem_solo_exp.m` | 3 / 1427 | Sonnet, medium | One decision applied three times; 466, 366 and 340 lines respectively already identical to tranche 2's file. Cheap regardless of size. Watch the `spem` pair's `FNDEF` function-name mismatch — record it, do not fix it. |
| 4 | Apply the template: `fixate/fixate_exp.m`, `free_view/free_view_exp.m` | 2 / 796 | Sonnet, medium | Same template, but each has real local content: `fixate_exp.m` has the wrong task in its banner, and `free_view_exp.m` has the 3x3 image-grid block and the `'data/'` path prefix nothing else uses. |
| 5 | Setup, driver and scratch scripts: `saccade/saccade_setup.m`, `free_view/setup/free_view_setup.m`, `pre_process.m`, `+lib/animate_trial.m`, `movie_test.m` | 5 / 322 | Sonnet, medium | Small, and all five are unverifiable at runtime (unseeded RNG, interactive clicking, undocumented workspace variables, a deliberate abort). Batch the small ones. `free_view_setup.m` is half deprecated commented-out code — leave every line of it, it is Tier C item 0.3.4. |
| 6 | Analysis drivers: `spem/spem_analyze.m`, `free_view/free_view_analyze.m` | 2 / 730 | Opus, high | The user-facing drivers, deliberately last. Most name-dense in the repo, they read the entire frozen `.mat` field vocabulary, they resolve the `idx_pre`/`idxPre` split from both sides at once, and `free_view_analyze.m` cannot be executed at all (missing `colorbarpzn`), so `check_tier_a` is the only check available. Large exploratory file with no callers goes last. |

All 18 files are assigned. `movie_test.m` sits in tranche 5 rather than being excluded, so nothing in the repo is left unread.

**Escalation rule, any tranche:** if `check_tier_a` fails and the cause isn't obvious from the diff — stop, don't retry with a bigger prompt, hand that one file to Opus at medium (high only if that also can't explain it). Don't loosen the check instead. The most likely cause in this repo is a rename that collided inside a longer name — the `dwell`/`pupil`/`scan`/`err`/`fix_x`/`gaze_x` families listed in section 2 all have that shape.

**"Done" checklist for a Tier-A tranche:**

- [ ] `check_tier_a(old, new, renames)` true for every file.
- [ ] Every file has a header matching the exemplar's shape: summary, signature, `Inputs`/`Output` with units, `See also`. Since zero files currently have one, this is a write-from-scratch job in every tranche, not an edit.
- [ ] No line exceeds 100 characters except the documented string-literal exceptions (listed per tranche in section 4.1.3) — each would require turning a string literal into a `horzcat` expression, a real AST change forbidden by Tier A. Expect several of these in the `*_exp.m` files, where the long lines are `Eyelink('command', 'file_sample_data = LEFT,RIGHT,GAZE,...')` filter strings.
- [ ] No zone-3 frozen identifier renamed, no `save`/`load` string literal changed, no `preprocess_gaze` name-value literal changed.
- [ ] Each package touched has a `Contents.m`. Two packages exist (`+lib`, `free_view/+analyze`) and neither has one.
- [ ] Bugs found are written down and not fixed (section 0.3.14, and section 4.1.3 per-tranche).

One commit per tranche, each stating the checker result and "MATLAB R2024b Update 6".

**Housekeeping, done before any tranche starts.** Already done: a `.gitignore` covering `*.edf`, `*.mat`, `notes/`, `free_view/data/IAPS/` and MATLAB editor leftovers — without which the first `git add` pulls in about 3 GB — and a baseline commit of all 18 `.m` files plus `docs/repo-cleanup.md`. Still to do in the tooling commit: create `tools/`. No filename-conflict copies to resolve: no two `.m` files share a basename. One misplaced file to consider: `pre_process.m` sits at the repo root but is the spem calibration driver, reading and writing `spem_results.mat` via a bare `results` variable — moving it into `spem/` is a path change, so Tier C, not housekeeping.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h4 style="display:inline; margin:0; font-size:0.98em">4.1.3 Findings log</h4></summary>

<div style="margin-left:1.5em">

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h5 style="display:inline; margin:0; font-size:0.92em">Step 0 — survey (done); tooling (not started)</h5></summary>

<div style="margin-left:1.5em">

The survey behind sections 1 and 2 is complete and every number in them is measured. `canon` was verified against all 18 in-scope files before anything else, and all 18 parse; the per-file fingerprint sizes are tabulated in section 2, so a future run can confirm it is reading the same files. MATLAB is 24.2.0.2923080 (R2024b Update 6). The three golden entry points were run end to end during the survey and their outputs are recorded in section 2 — that is what establishes, rather than assumes, that Tier B has runtime coverage for the analysis chain.

Three things surfaced during the survey that change the plan rather than just decorating it. First, the surveyed tree (`G:\My Drive\Eye-tracking`) had no version control at all, so the pass had no baseline; the code was then moved to `G:\My Drive\eye-tracking-psychedelics`, a GitHub repo, and tranche 0 added the `.gitignore` and the baseline commit described in section 1. The 18 files were checked byte-for-byte across the move before any of the survey's numbers were trusted. Second, `colorbarpzn` is missing, which means the repo's largest analysis file cannot be executed on this machine at all — the survey found this by resolving every external call with `which`, not by reading the source, and it is the reason tranche 6 is `check_tier_a`-only. Third, the skill's named exemplar `vislab-common/+vislab/+lib/watson_otf.m` is not present on this machine; the style target therefore has to come from the skill's description of it plus `spem/true_target_traj.m` as the in-repo approximation.

**Two survey measurements were wrong on the first pass and are corrected in section 1.** A `grep -c $'\r'` over each file was silently matching every line, not the CR-terminated ones, which produced a false "line endings are uniformly CRLF in all 18 files". The byte-level count (`tr -cd '\r' | wc -c`) shows 13 CRLF files and 5 LF files. That mattered twice over: it was also the real reason a byte-level `diff` between `saccade_exp.m` and `fixate_exp.m` showed zero identical lines, which the first pass wrongly attributed to trailing-whitespace normalisation. The trailing-whitespace count was wrong too, from a `[ \t]` pattern in which `\t` is not a tab under POSIX grep — the corrected figure is 200 lines, concentrated in two files rather than spread evenly. Everything else in the survey was measured with CR stripped first (`sed 's/\r//'` or `gsub(/\r/,"")`) and is unaffected; the duplication figures in section 1 survive because all four file pairs quoted there happen to be LF-to-LF comparisons. **Lesson for the tranches: strip CR on both sides before any file-level comparison, and never trust a shell pattern containing `\r` or `\t` without checking it against a file whose answer is known.**

The tooling itself — `tools/canon.m`, `tools/check_tier_a.m`, `tools/assert_rename_bijection.m`, `tools/golden_harness.m` — has not been copied in or written yet. That is item 0.1.0 and the first thing to do next.

</div>

</details>

</div>

</details>

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">4.2 Tier B — coverage gaps and work log</h3></summary>

<div style="margin-left:1.5em">

**Coverage gaps, decided in advance rather than discovered mid-tranche.** Section 2 has the full accounting; the decisions that follow from it:

- The five `*_exp.m` files (2703 lines, tranches 2-4) need Psychtoolbox plus a live EyeLink host, and four of the five set `dummymode = 0`. **Decision: Tier B edits in these files are verified by pattern check only, with no runtime golden.** This covers the one real preallocation target in them, `dist_pos` at `spem_exp.m:316-317`.
- `free_view_analyze.m` (675 lines) cannot execute until `colorbarpzn` is resolved, and is a cell script that reads `gap` from a pre-existing workspace besides. **Decision: pattern check only.** This covers the six unused `hcb` assignments, item 0.2.3.
- `spem_analyze.m`'s first section re-parses 102 subjects through `Edf2Mat`. **Decision: never run as a verification step.** If a runtime check is ever wanted for it, build an isolated synthetic replica of the loop with the same iteration count and no disk I/O.
- `free_view_setup.m` and `saccade_setup.m` draw unseeded RNG and overwrite shipped `.mat` artifacts — running `saccade_setup.m` is itself bug 0.3.14.4. **Decision: pattern check only, and do not run them.**
- `pre_process.m` and `+lib/animate_trial.m` have no callable entry point at all. **Decision: pattern check only.**

**The four patterns, checked repo-wide during the survey. Reporting the negatives too, because a documented negative is the evidence the repo was actually examined:**

1. **Missing suppressing semicolons — 7 found, all plausibly deliberate, none yet changed.** `pre_process.m:15` (`name = todoNames{i_todo}`), `free_view_analyze.m:73` and `spem_analyze.m:6` (`name = ...(idx).name`) print the current subject as progress while a long loop runs. `free_view_analyze.m:426,427,430,431` (`beta_x_std`, `beta_y_std`, `beta_corr(1)`, `beta_corr(2)`) print regression results that the surrounding comment explicitly asks the reader to compare — "check that betas match the formulas based on correlation coefficients". All seven are a script's only way to show a number when run interactively. **Asked and decided: all seven stay displaying.** Each gets a short comment saying the display is intentional, so a later pass does not suppress it. Adding only a comment is a Tier A change, so it rides along with whichever tranche owns the file rather than needing a Tier B pattern check. **No Tier B edits from this pattern.**
2. **`find(...)` that could be logical indexing — none found.** Every `find` in the repo produces a numeric index that is then used in a way logical indexing cannot replace: as a scalar bound (`preprocess_gaze.m:70,83,84`; `free_view_measures.m:33,47`; `spem_measures.m:28,29` — all of the form `find(t >= t0, 1)` feeding a `start:end` range), as an index into a *second* array (`free_view_analyze.m:18,19,32,43,49,55` — `idx_post = find(isPost)` then `free_view_results(idx_post)` and `ismember`/`loc` arithmetic), or as a loop range (`spem_analyze.m:39`). The two in `free_view_setup.m:14,26` are inside commented-out code. **No targets.**
3. **Unpreallocated growth — 33 `checkcode` hits, of which exactly 2 are targets.** The targets: `true_target_traj.m:14-23`, where `t`, `xv` and `yv` grow one element per message with `%#ok<AGROW>` already applied, i.e. known and suppressed rather than fixed — and it is inside the golden harness's coverage, so it gets both a pattern check and a runtime match; and `spem_exp.m:316-317`, where `dist_pos` grows over `n_dist = 4`. Not targets, with reasons: `preprocess_gaze.m:73,86` grow `corner_intervals`/`corner_sample_idx` by one element at most four times per *call*, which the skill excludes explicitly; `preprocess_gaze.m:261-279` grows the animation traces by one per frame, but rewriting `get`/`set` round-trips into indexed fills is a real restructure and two of those six sites are dead anyway (bug 0.3.14.13), so it is Tier C; `free_view_setup.m:73-75` is element *deletion* (`IAPS_id(ids_thistrial) = []`) inside an RNG-coupled loop, not growth, and touching it changes the draw sequence; the 19 `SAGROW` hits in `free_view_analyze.m` and `spem_analyze.m` are struct-array field growth (`free_view_results(idx).field = ...`), which is how those scripts accumulate results — preallocating means building the struct array up front, a restructure, so Tier C. Neither target makes an RNG draw, so no re-sequencing precaution is needed; still capture the real output before the edit and assert `isequal` after, then re-run the golden harness in replay mode.
4. **Unused assignments `checkcode` flags — 8, of which 7 are Tier B targets.** Six `hcb = colorbarpzn(...)` returns never read (`free_view_analyze.m:346,360,377,596,638,657`), and one `windowrect` output that can become `~` (`saccade_lr_exp.m:64`, `ASGLU`) — it is referenced only inside commented-out `AddFrameToMovie` lines. The eighth, `NASGU` on `xB`/`yB` at `preprocess_gaze.m:263`, is **not** a Tier B target: it is unused only because the `set` call on line 264 was commented out, so deleting the assignment would silently make the dead animation trace permanent. That one is bug 0.3.14.13 and belongs in Tier C.

**Per-tranche work log:** empty — Tier B has not started.

</div>

</details>

<details style="margin:0.7em 0 0.7em 1.5em">
<summary><h3 style="display:inline; margin:0; font-size:1.05em">4.3 Tier C — work log</h3></summary>

<div style="margin-left:1.5em">

Fills in as each Tier C item (section 0.3) is actually done. Bugs discovered while doing Tier A/B are recorded in section 0.3.14's bug sublist as they're found; their fixes, once done, get logged here.

Empty — Tier C has not started, and must not start until Tier A and Tier B are complete and committed.

Two items in the list deserve flagging now, as the ones most likely to change published results rather than just tidy the code: **0.3.14.1** (every `pupil_sz_mean` in `spem_results.mat` computed from the wrong samples) and **0.3.14.5** (`dwell_tot`/`pupil` measured over a ~10.1 s window while `dwell`/`scan` use 3 s, with a comment claiming 1.5 s). Both require re-running the analysis over all subjects after the fix, so budget for that, and expect the numbers in `spem_results.mat` and `free_view_results.mat` to move.

</div>

</details>

</details>
