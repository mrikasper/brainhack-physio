% Script cubric_physio_main
% Main preproc/analysis script lernit to create PhysIO regressors and
% assess them via a nuisance-only GLM
%
%  cubric_physio_main
%
%
%   See also
 
% Author:   Lars Kasper
% Created:  2022-11-20
% Copyright (C) 2022
 
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Setup paths - #MOD# Modify to your own environment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

subjectId = 'sub-02';
 % if true, only the SPM batch jobs are loaded, but you have to run them manually in the batch editor (play button)
isInteractive = true;
hasStruct = false; % if false, uses (bias-corrected) mean of fmri.nii for visualizations

pathProject     = 'C:\Users\kasperla\OneDrive - UHN\Collaborations\PhysIO\CUBRICTalk';
pathCode        = fullfile(pathProject, 'code');
pathResults     = fullfile(pathProject, 'results');
pathSubject     = fullfile(pathResults, subjectId);


switch subjectId
    case 'sub-01'
        nSlices = 96/4; % nSlicesTotal/MB factor
        TR = 1.5; % seconds
        nVolumes = 400;
    case 'sub-02'
        nSlices = 46; % nSlicesTotal/MB factor
        TR = 9; % seconds
        nVolumes = 150;
end

addpath(genpath(pathCode));
pathNow = pwd;


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

spm_jobman(jobMode, matlabbatch)

if isInteractive, input('Press Enter to continue'); end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% GLM w/o smoothing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

spm_jobman(jobMode, 'glm_spm_job.m')
if isInteractive, input('Press Enter to continue'); end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Visualize PhysIO contrasts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% automatic contrast creation using PhysIO
visualize_physio