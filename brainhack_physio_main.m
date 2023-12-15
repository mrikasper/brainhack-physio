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

subjectId = 'sub-46';
 % if true, only the SPM batch jobs are loaded, but you have to run them manually in the batch editor (play button)
isInteractive = true;
hasStruct = false; % if false, uses (bias-corrected) mean of fmri.nii for visualizations
doSmooth = true;


pathProject     = 'C:\Users\kasperla\polybox\Shared\PhysioUserData\BrainHack23PhysIOMACS';
pathCode        = fullfile(pathProject, 'code');
pathResults     = fullfile(pathProject, 'results');
pathSubject     = fullfile(pathResults, subjectId);

%% TODO: read from .sub-46_task-NAconf_run-01_bold.json
switch subjectId
    case 'sub-46'
        nSlices = 28/2; % nSlicesTotal/MB factor; nSlices from SliceTiming info?
        TR = 1.25; % seconds
        nVolumes = 488;
    case 'sub-45' %TODO!
        nSlices = 28/2; % nSlicesTotal/MB factor; nSlices from SliceTiming info?
        TR = 1.25; % seconds
        nVolumes = 488;
end

addpath(genpath(pathCode));
pathNow = pwd;


if ~isfolder(pathSubject), mkdir(pathSubject); end
cd(pathSubject);

% folder structure created with in results folder of subject to hold
% different preprocessed data
mkdir('glm')
mkdir('nifti')
mkdir('glm_s3')
mkdir('physio_out')


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
    cellstr(spm_select('ExtFPList', 'nifti', '^fmri.*', 1:nVolumes));

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
matlabbatch{1}.spm.tools.physio.scan_timing.sqpar.Nscans = nVolumes;
matlabbatch{1}.spm.tools.physio.scan_timing.sqpar.Nslices = nSlices;
matlabbatch{1}.spm.tools.physio.scan_timing.sqpar.TR = TR;
matlabbatch{1}.spm.tools.physio.scan_timing.sqpar.onset_slice = nSlices/2;

switch subjectId
    case 'sub-01'
        % defaults OK in file
    case 'sub-02'
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