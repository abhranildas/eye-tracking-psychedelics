% ANALYZE  Free-viewing analysis helpers.
%
% Call these as analyze.<name>, e.g. analyze.free_view_measures(...). The
% +analyze folder sits inside free_view/, so free_view/ has to be on the MATLAB
% path -- nothing in this repo puts it there (Tier C item 0.3.8 in
% docs/repo-cleanup.md).
%
% Per-recording measures
%   free_view_measures  - Reduce one free-viewing recording to four per-trial
%                         measures over the 3x3 grid of IAPS images: dwell time
%                         by sample count (seconds, rescaled to 10 s per
%                         trial), dwell time by summed fixation duration
%                         (seconds), mean pupil size (arbitrary EyeLink area
%                         units) and scanpath length (pixels). Takes the
%                         calibrated, blink-masked gaze and fixation positions
%                         produced by lib.preprocess_gaze. The outputs are
%                         named to match the frozen struct fields of
%                         free_view/data/free_view_results.mat.
%
% Known bug, not fixed in the Tier A/B pass: free_view_measures uses two
% different analysis windows within one call -- the full ~10.1 s window for
% dwell_tot and pupil, the first 3 s for dwell and scan. That is bug 0.3.14.5.
%
% See also LIB.PREPROCESS_GAZE, SPEM_MEASURES, FREE_VIEW_ANALYZE
