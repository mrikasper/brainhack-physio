% Script brainhack_physio_main
% Main preproc/analysis script lernit to create PhysIO regressors and
% assess them via a nuisance-only GLM
%
%  brainhack_physio_main
%
%
%   See also
 
% Author:   Lars Kasper
% Created:  2023-12-25
% Copyright (C) 2023
 
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Setup paths - #MOD# Modify to your own environment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

iResults = 2; % if multiple processing pipelines are tested, incremenent this index to write results out in a different folder
iRun = 1; %1,2,3,4
subjectId = 'sub-46';
 % if true, only the SPM batch jobs are loaded, but you have to run them manually in the batch editor (play button)
isInteractive = true;


doOverwriteResults = true;
hasStruct = false; % if false, uses (bias-corrected) mean of fmri.nii for visualizations
doSmooth = true;


resultsId = sprintf('results-%02d', iResults);
paths.projects     = 'C:\Users\kasperla\polybox\Shared\PhysioUserData\BrainHack23PhysIOMACS';
paths.code        = fullfile(paths.projects, 'code');
paths.results     = fullfile(paths.projects, resultsId);
paths.data     = fullfile(paths.projects, 'data');
paths.subject.results     = fullfile(paths.results, subjectId);
paths.subject.data     = fullfile(paths.data, subjectId);
if doSmooth
    paths.subject.glm = fullfile(paths.subject.results, 'glm_s3');
else
    paths.subject.glm = fullfile(paths.subject.results, 'glm');
end
paths.subject.physio = fullfile(paths.subject.results, 'physio');

files.anat = sprintf('%s_run-01_T1w.nii', subjectId);
for r = 1:4
    dirs.physio_out{r} = sprintf('physio_out_run%d', r);
    files.func{r} = sprintf('%s_task-NAconf_run-%02d_bold', subjectId, iRun);
end

paths.subject.func = fullfile(paths.subject.results, 'func');
paths.subject.anat = fullfile(paths.subject.results, 'anat');
paths.subject.physio_out = strcat(paths.subject.results, filesep, ...
    dirs.physio_out);

%% TODO: read from .sub-46_task-NAconf_run-01_bold.json
switch subjectId
    case 'sub-46'
        nSlices = 28; % hack for now, because of bug in tapas_physio_get_onsets_from_locs should be nSlicesTotal/MB factor; nSlices from SliceTiming info?
        TR = 1.25; % seconds
        nVolumes = 488;
    case 'sub-45' %TODO!
        nSlices = 28; % nSlicesTotal/MB factor; nSlices from SliceTiming info?
        TR = 1.25; % seconds
        nVolumes = 488;
end

addpath(genpath(paths.code));
pathNow = pwd;

if doOverwriteResults
    if isfolder(paths.subject.results), rmdir(paths.subject.results, 's');end
end
% folder structure created with in results folder of subject to hold
% different preprocessed data; copy raw data from data folder
if ~isfolder(paths.subject.results)
    mkdir(paths.subject.results);
    copyfile(paths.subject.data, paths.subject.results);
end
% for each run created separately
mkdir(paths.subject.glm);
mkdir(paths.subject.physio_out{iRun});

cd(paths.subject.results);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Setup SPM Batch editor
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% spm_jobman('initcfg')
spm fmri

if isInteractive
    jobMode = 'interactive';
else
    jobMode = 'run';
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Spatial Preproc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if hasStruct
    fileJobPreproc = 'preproc_minimal_spm_job.m';
else
    fileJobPreproc = 'preproc_minimal_no_struct_spm_job.m';
end

% loads matlabbatch and adapts subject-specific data
clear matlabbatch
run(fileJobPreproc)
matlabbatch{1}.spm.spatial.realign.estwrite.data{1} = ...
    cellstr(spm_select('ExtFPList',  ...
    paths.subject.func, ...
    sprintf('^%s.nii',files.func{iRun}), 1:nVolumes));

spm_jobman(jobMode, matlabbatch)

if isInteractive, input('Press Enter to continue'); end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Physio
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% loads matlabbatch and adapts subject-specific data
clear matlabbatch

fileJobPhysio = 'physio_spm_job.m';
clear matlabbatch
run(fileJobPhysio)
matlabbatch{1}.spm.tools.physio.save_dir = cellstr(paths.subject.physio_out{iRun});
matlabbatch{1}.spm.tools.physio.log_files.cardiac = cellstr(...
    spm_select('FPList', paths.subject.physio, ...
    sprintf('^Physio_.*_sess%d_PULS.log', iRun)));
matlabbatch{1}.spm.tools.physio.log_files.respiration = cellstr(...
    spm_select('FPList', paths.subject.physio, ...
    sprintf('^Physio_.*_sess%d_RESP.log', iRun)));
matlabbatch{1}.spm.tools.physio.log_files.scan_timing = cellstr(...
    spm_select('FPList', paths.subject.physio, ...
    sprintf('^Physio_.*_sess%d_Info.log', iRun)));
matlabbatch{1}.spm.tools.physio.scan_timing.sqpar.Nscans = nVolumes;
matlabbatch{1}.spm.tools.physio.scan_timing.sqpar.Nslices = nSlices;
matlabbatch{1}.spm.tools.physio.scan_timing.sqpar.TR = TR;
matlabbatch{1}.spm.tools.physio.scan_timing.sqpar.onset_slice = nSlices/2;

switch subjectId
    case 'sub-46'
        % defaults OK in file
    case 'sub-XX'
        matlabbatch{1}.spm.tools.physio.log_files.align_scan = 'first';
        % only 150 volumes, we don't want to reduce degrees of freedom too much
        matlabbatch{1}.spm.tools.physio.model.movement.yes.censoring_threshold = 2;

        % too noisy cardiac data, has to be bandpass-filtered (default
        % values)
        matlabbatch{1}.spm.tools.physio.preproc.cardiac.filter = rmfield(...
            matlabbatch{1}.spm.tools.physio.preproc.cardiac.filter, 'no');
        matlabbatch{1}.spm.tools.physio.preproc.cardiac.filter.yes.type = 'cheby2';
        matlabbatch{1}.spm.tools.physio.preproc.cardiac.filter.yes.passband = [0.3 9];
        matlabbatch{1}.spm.tools.physio.preproc.cardiac.filter.yes.stopband = [];
end

spm_jobman(jobMode, matlabbatch)

if isInteractive, input('Press Enter to continue'); end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% GLM with or w/o smoothing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if doSmooth
    fileJobGlm = 'glm_s3_spm_job.m';
else
    fileJobGlm = 'glm_spm_job.m';
end
clear matlabbatch
run(fileJobGlm)

if doSmooth
    matlabbatch{1}.spm.stats.fmri_spec.sess.scans = ...
        cellstr(spm_select('ExtFPList', 'nifti', '^srfmri.*', 1:nVolumes));
else
    matlabbatch{1}.spm.stats.fmri_spec.sess.scans = ...
        cellstr(spm_select('ExtFPList', 'nifti', '^rfmri.*', 1:nVolumes));
end

matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = nSlices;
matlabbatch{1}.spm.stats.fmri_spec.timing.RT = TR;
matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = nSlices/2;

spm_jobman(jobMode, matlabbatch)

if isInteractive, input('Press Enter to continue'); end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Visualize PhysIO contrasts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% automatic contrast creation using PhysIO
visualize_physio