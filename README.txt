# Image_Reconstruction

Purpose:
  Take the raw Dicoms from a Siemen's scanner and transfer them to NIFTI format, and do some basic preproccessing
  depending on the scan type.
Parameters:
  i=input directory (where the raw subject data folder resides)
  o=output directory (where the NIFTI data will go)
  l=user made .csv file (contains subject information)
  v=user made .csv file (contains scan information)
  S=quotation ("") enclosed list of scans to reconstruct (optional, default is complete all scans)
Produces:
  Dependent on scan being processed, but the general output will resemble the following directory/file structure.
  
  Definitions
  ${Scan}= placeholder for scan type, what you would actually see is something like slicesdir_MPRAGE, slicesdir_DTI, etc.
  ${num}= subject number (conventionally) like 10, 1001, 423, etc.
  ${cond}= useful when participants have multiple visits (i.e. pre/ post/)
  Func.png= pictures of the relative and absolute motion parameters for each functional scan for each subject
  Scan.png= pictures of the scan at various slices to make sure nothing looks grossly wrong with the image.
  Scan_RPI.nii.gz= the scan in NIFTI format and RPI orientation
  Dicoms= The original raw data, in case you need to reconstruct it differently
  
  TEXT REPRESENTATION OF OUTPUT STRUCTURE
  OutputDir -> Func_Motion_check -> Func.png
            -> slicesdir_${Scan} -> Scan.png
            -> sub${num}->${Cond} -> ${Scan} -> Scan_RPI.nii.gz
                                             -> Raw -> Dicoms
Preconditions:
  dependent on the following programs being installed and defined in your $PATH variable
  afni http://afni.nimh.nih.gov/afni/download/afni/releases
  fsl http://fsl.fmrib.ox.ac.uk/fsldownloads/fsldownloadmain.html
  freesurfer https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall
  dcm2niix https://www.nitrc.org/plugins/mwiki/index.php/dcm2nii:MainPage#General_Usage
  
  
Notes on how to organize the .csv files
  scanlog.csv example
  Column1     Column2     Column3     Column4
  SUB_ID      SCAN_DATE   CONDITION   PROCESSED?
  10          20150923    pre         1
  10          20151023    post        0
  
  Definitions
  SUB_ID= the subject ID
  SCAN_DATE= more specifically the name of the Raw data folder for that subject
  CONDITION= whether it's pre or post or session1,2,3, etc.
  PROCESSED?= whether the subject's scans have been reconstructed (0=not done, 1=done)
  
  scanvol.csv example
  Column1     Column2
  SCAN_TYPE   SCAN_VOLS
  MPRAGE      176
  DTI         70
  REST        315
  
  Definitions
  SCAN_TYPE= this is the type of scan that was completed in your study
  SCAN_VOLS= this is the number of expected dicoms for that scan (the script will not reconstruct scans with the wrong number of dicoms)
  
