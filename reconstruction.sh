#!/bin/bash

#Assumption:
#1) the excel files (.csv) are filled out and have the appropiate information
#2) this script is dependent on fslreorient.sh, please have that script in the same directory for this script to work.
function printCommandLine {
    echo "Usage: reconstruction.sh -i XNAT Folder Directory -o Preprocessed Directory -l scanLog (.csv) -v scanVol (.csv) -S userScanList (optional) -c clobber (optional)"
    echo " where:"
    echo "-i    Directory where the scans from XNAT are downloaded"
    echo -e "\n"
    echo "-o    Directory where you want the preprocessed data"
    echo -e "\n"
    echo "-l    A user made excel file (.csv) where subject information is organized as follows"
    echo "      SUB_ID    SCAN_DATE    CONDITION    PROCESSED?"
    echo "       where:"
    echo "        SUB_ID is the subject ID"
    echo "        SCAN_DATE is the name of the XNAT folder (i.e. 20140924)"
    echo "        CONDITION is the condition the participant's scans are from (i.e. Active Passive Pre Post)"
    echo "        note: there must be at least one condition, but there can be as many conditions as needed"
    echo "        PROCESSED? is whether the subject scans have been reconstructed into NIFTI format (represented by 1)"
    echo "        or if they have not (represented by 0)"
    echo -e "\n"
    echo "-v    A user made excel file (.csv) where scan information is organized as follows"
    echo "      SCAN_TYPE    VOLUMES"
    echo "       where"
    echo "        SCAN_TYPE is the type of scan being processed (i.e. DTI REST, etc.)"
    echo "        VOLUMES is the expected number of volumes for that scan (i.e. 31,180, etc)"
    echo -e "\n"
    echo "-S    An optional list for which scans to reconstruct, otherwise all scans will be reconstructed"
    echo "      The list must be enclosed by double quotes && the scan types you use must exist in your scanVol.csv"
    echo -e "\n"
    echo "        If you have questions/comments, please contact james-kent@uiowa.edu"
    exit 1
}


while getopts “h:l:i:v:o:S:dc” OPTION
do
    case $OPTION in
	l)
	    scanLog=$OPTARG
	    ;;
	i)
	    rawDir=$OPTARG
	    ;;
	v)
	    scanVol=$OPTARG
	    ;;
	o)
	    preProcDataDir=$OPTARG
	    ;;
	S)
	    userScanList=$OPTARG
	    ;;
	d)
	    skipSlicesDir=1
	    ;;
	c)
		clobber=1
		;;
	h)
	    printCommandLine
	    ;;
	?)
	    echo "ERROR: Invalid option"
	    printCommandLine
	    ;;
    esac
done

#Using this as the file for all subjects makes it not compatible with parallel processing.
touch preprocessing.log
echo "############################################" >> preprocessing.log
echo "############################################" >> preprocessing.log
echo "############################################" >> preprocessing.log
echo "############################################" >> preprocessing.log
echo "############################################" >> preprocessing.log

echo "preprocessing Log" >> preprocessing.log
date >> preprocessing.log


#create readable .csvs for updating
#WARNING: this prevents parallel processing!!!
#WARNING: presumes running on MAC OS
tr '\015' '\012' < ${scanLog} > tmp_scanLog.csv
tr '\015' '\012' < ${scanVol} > tmp_scanVol.csv

   #scans we want to be reconstructed
if [ ! "${userScanList}" == "" ]; then
    scans="${userScanList}"
else
    scans=`awk -F"," 'NR>1 {print $1}' tmp_scanVol.csv`
fi

#Begin Subject Iteration
####################################################
#for the subjects in the Raw files Directory
for sub in `ls ${rawDir}`; do

    echo "#######################################" >> preprocessing.log

    #get the subID from the raw folder name
    name=`awk -F"," '($2=="'"${sub}"'") {print $1}' tmp_scanLog.csv`
    #list the condition(s) the subject scans are for (i.e. Active/pre)
   
    
    echo "sub${name} is being converted from directory ${sub} in ${rawDir}" >> preprocessing.log
    #see if subject has already been run
    if [ ${clobber} -eq 1 ]; then
    	completed=0
    else
   		completed=`awk -F"," '($2=="'"${sub}"'") {print $(NF)}' tmp_scanLog.csv`
	fi

    #check the output from completed, which can either be:
    #0: this subject's scan hasn't been reconstituted yet
    #1: this subject's scan has been reconstituted
    #?: either there's nothing, or some random character, or subject scan does not exist in the .csv
    case $completed in
	1)
	    #the condition(s) that has already been completed.
	    #maybe print wrong condition (and/or not complete condition) if a subject has more than 2 scans.
	    cond=`awk -F"," '($2=="'"${sub}"'") {for (i=3; i < NF; i++) print $i}' tmp_scanLog.csv | tr '\n' '/'`
	    echo "${sub}, which corresponds to ${name} for condition ${cond}, has already been preprocessed"
	    echo "Processed: YES" >> preprocessing.log
	    echo "Skipping sub${sub}" >> preprocessing.log
	    continue 2
	    ;;
	0)
	    #probably dont need '&& ($(\NF)==0)', but I am using it as a double check
	    cond=`awk -F"," '($2=="'"${sub}"'") && ($(NF)==0) {for (i=3; i < NF; i++) print $i}' tmp_scanLog.csv | tr '\n' '/'`
	    echo "running ${sub} which corresponds to ${name}"
	    echo "Processed: NO" >> preprocessing.log
	    echo "Processing sub${name}" >> preprocessing.log 
	    ;;
	?)
	    echo "${sub} does not exist in ${scanLog} or is formatted incorrectly"
	    echo "Processed: N/A" >> preprocessing.log
	    echo "Please make sure the excel sheet is formatted correctly" >> preprocessing.log
	    echo "Skipping sub${sub}" >> preprocessing.log
	    continue 2
	    ;;
    esac
    
    #make the directory for the subject in the preProcDataDir    
    mkdir -p ${preProcDataDir}/sub${name}/

 	#Begin scan iteration
    ##############################################
    #For each scan we want to have reconstructed...
    for scan in ${scans}; do

		#check to see if the reconstructed scan already exists
		#Default behavior is to skip the scan if the user does not provide input
		
		if [ -e ${preProcDataDir}/sub${name}/${cond}/${scan}/sub${name}_${scan}.nii.gz ]; then
		    echo "${scan} exists for sub${name}, do you want to overwrite? yes/no"
		    read -t 10 ans
		    if [ "${ans}" == "yes" ]; then
			echo "rewriting scan ${scan}..."
		    elif [ "${ans}" == "no" ]; then
			echo "skipping scan ${scan}"
			echo "SKIPPING ${scan} for sub${name}" >> preprocessing.log
			continue
		    else
			echo "skipping scan ${scan}"
			echo "SKIPPING ${scan} for sub${name}" >> preprocessing.log
			continue
		    fi
		fi

		echo "running ${name}: ${scan}"
		echo -e "\n" >> preprocessing.log
		echo "sub${name}: Finding ${scan}" >> preprocessing.log

		#make the directories necessary in preProcDataDir 
		#notice the ${cond}${scan} adjacency without a '/'
		#this is because cond has the following '/' automatically inserted
		mkdir -p ${preProcDataDir}/sub${name}/${cond}${scan}/Raw
		

		#Get the number of Dicoms that are supposed to be in the Dicom folder
		#(This is used to compare to the actual number found in the participant's scan folder)
		scanVol_num=$(awk -F"," '($1=="'"${scan}"'") {print $2}' tmp_scanVol.csv)

		#In case you have multiple scans of the same type that you want to keep
		scan_strip=${scan%_*}
		#Find the scan Directory in the Raw Folders for the subject
		sub_scan_folders=$(find $rawDir/${sub} -name *${scan_strip})

		
		#Index to keep track of how many Scan Directories have the same name
		#(i.e. if there exists 9-DTI and 10-DTI)
		x=0
		
		#Have a for loop even if there is only one scan directory for the subject
		for sub_scan_folder in ${sub_scan_folders}; do
		    #Get the number of Dicoms in the subject's scan directory
		    dicom_num=`ls ${sub_scan_folder}/resources/DICOM/files/*.dcm | wc -w`
		    
		    #Compare the subject Dicom number to the number of Dicoms that are supposed to be in the file
		    if [ ! ${dicom_num} -eq ${scanVol_num} ]; then
			echo "Error: the number of DICOMs in ${sub_scan_folder} directory for sub${name} do not match the number specified by ${scanVol}"
			echo "Number Found: ${dicom_num}"
			echo "Number Needed: ${scanVol_num}"
			echo "${sub_scan_folder}: INCORRECT DICOMS" >> preprocessing.log
		    else
			correct_dir=${sub_scan_folder}
			echo "${sub_scan_folder}: CORRECT DICOMS" >> preprocessing.log
		    fi
		    #increment the index to count the number of folders a particular scan has (i.e. 9-DTI 10-DTI)
		    x=$((${x}+1))
		done

		#Let the user know if there were multiple Directories.
		if [ ${x} -gt 1 ]; then
		    echo "Warning, more than two scans for ${scan} were detected"
		    echo "If multiple scans had the correct number of DICOMS, the last scan will be used"
		fi
		
		#if none of the scan dirs have the correct number of dicoms, don't convert the scan and skip to the next one.
		if [ "${correct_dir}" == "" ]; then
		    echo "none of the directories for ${scan} contain the correct number of Dicoms"
		    echo "skipping scan"
		    echo "NO FOLDER WITH CORRECT DICOMS" >> preprocessing.log
		    echo "skipping ${scan}" >> preprocessing.log
		    continue 
		fi

		echo "CONVERTING DICOMS FROM ${correct_dir} FOR sub${name}" >> preprocessing.log

		
		#Special processing for DTI images to get bvals and bvecs
	####################################################################
		#mri_convert does not generate the .bvec or .bval file, so I'm using dcm2nii instead.
		if [ "${scan_strip}" == "DTI" ]; then
		    echo "OUTPUT FROM dcm2nii:" >> preprocessing.log

		    if [ `ls ${preProcDataDir}/sub${name}/${cond}${scan}/ | wc -l` -gt 1 ]; then
			rm -f ${preProcDataDir}/sub${name}/${cond}${scan}/*.*
		    fi
		    dcm2nii -g y -o ${preProcDataDir}/sub${name}/${cond}${scan}/ ${correct_dir}/resources/DICOM/files/*.dcm >> preprocessing.log
		    mv ${preProcDataDir}/sub${name}/${cond}${scan}/*.bval ${preProcDataDir}/sub${name}/${cond}${scan}/sub${name}_${scan}.bval
		    mv ${preProcDataDir}/sub${name}/${cond}${scan}/*.bvec ${preProcDataDir}/sub${name}/${cond}${scan}/sub${name}_${scan}.bvec
		    mv ${preProcDataDir}/sub${name}/${cond}${scan}/*.nii.gz ${preProcDataDir}/sub${name}/${cond}${scan}/sub${name}_${scan}.nii.gz
	       #Special processing for DTI images complete
	####################################################################
	        else

		#mri_convert needs a dicom file to read to work
		#ASSUMPTION: I assume after the scan directory (i.e. 9-DTI/) there is a consistant folder structure
		#such that 9-DTI/resources/DICOM/files is generalizable to all scans.
		    DICOM_FILE_EX=`ls ${correct_dir}/resources/DICOM/files/*.dcm | head -n 1`
		    
		#use mri_convert in the original Raw directory and output the NIFTI into the preProcDataDir
		#DOES NOT WORK WITH DTI DATA TO GET BVECS & BVALS
		    echo "OUTPUT FROM mri_convert:" >> preprocessing.log

			#remove any files if they exist in the directory
		    if [ `ls ${preProcDataDir}/sub${name}/${cond}${scan}/ | wc -l` -gt 1  ]; then
			rm -f ${preProcDataDir}/sub${name}/${cond}${scan}/*.*
		    fi
		    mri_convert -it siemens_dicom -ot nii ${DICOM_FILE_EX} ${preProcDataDir}/sub${name}/${cond}${scan}/sub${name}_${scan}.nii.gz >> preprocessing.log	
		fi

		     #change orientation of image to what we use
		     #ORIENTATION CODE HERE
		     ############################################################
		     infile=${preProcDataDir}/sub${name}/${cond}${scan}/sub${name}_${scan}.nii.gz
		     #Determine qform-orientation to properly reorient file to RPI (MNI) orientation
			xorient=`fslhd ${infile} | grep "^qform_xorient" | awk '{print $2}' | cut -c1`
			yorient=`fslhd ${infile} | grep "^qform_yorient" | awk '{print $2}' | cut -c1`
			zorient=`fslhd ${infile} | grep "^qform_zorient" | awk '{print $2}' | cut -c1`


			native_orient=${xorient}${yorient}${zorient}


			echo "native orientation = ${native_orient}"


			if [ "${native_orient}" != "RPI" ]; then
				
			  case ${native_orient} in

				#L PA IS
				LPI) 
					flipFlag="-x y z"
					;;
				LPS) 
					flipFlag="-x y -z"
			    		;;
				LAI) 
					flipFlag="-x -y z"
			    		;;
				LAS) 
					flipFlag="-x -y -z"
			    		;;

				#R PA IS
				RPS) 
					flipFlag="x y -z"
			    		;;
				RAI) 
					flipFlag="x -y z"
			    		;;
				RAS) 
					flipFlag="x -y -z"
			    		;;

				#L IS PA
				LIP) 
					flipFlag="-x z y"
			    		;;
				LIA) 
					flipFlag="-x -z y"
			    		;;
				LSP) 
					flipFlag="-x z -y"
			    		;;
				LSA) 
					flipFlag="-x -z -y"
			    		;;

				#R IS PA
				RIP) 
					flipFlag="x z y"
			    		;;
				RIA) 
					flipFlag="x -z y"
			    		;;
				RSP) 
					flipFlag="x z -y"
			    		;;
				RSA) 
					flipFlag="x -z -y"
			    		;;

				#P IS LR
				PIL) 
					flipFlag="-z x y"
			    		;;
				PIR) 
					flipFlag="z x y"
			    		;;
				PSL) 
					flipFlag="-z x -y"
			    		;;
				PSR) 
					flipFlag="z x -y"
			    		;;

				#A IS LR
				AIL) 
					flipFlag="-z -x y"
			    		;;
				AIR) 
					flipFlag="z -x y"
			    		;;
				ASL) 
					flipFlag="-z -x -y"
			    		;;
				ASR) 
					flipFlag="z -x -y"
			    		;;

				#P LR IS
				PLI) 
					flipFlag="-y x z"
			    		;;
				PLS) 
					flipFlag="-y x -z"
			    		;;
				PRI) 
					flipFlag="y x z"
			    		;;
				PRS) 
					flipFlag="y x -z"
			    		;;

				#A LR IS
				ALI) 
					flipFlag="-y -x z"
			    		;;
				ALS) 
					flipFlag="-y -x -z"
			    		;;
				ARI) 
					flipFlag="y -x z"
			    		;;
				ARS) 
					flipFlag="y -x -z"
			    		;;

				#I LR PA
				ILP) 
					flipFlag="-y z x"
			    		;;
				ILA) 
					flipFlag="-y -z x"
			    		;;
				IRP) 
					flipFlag="y z x"
			    		;;
				IRA) 
					flipFlag="y -z x"
			    		;;

				#S LR PA
				SLP) 
					flipFlag="-y z -x"
			    		;;
				SLA) 
					flipFlag="-y -z -x"
			    		;;
				SRP) 
					flipFlag="y z -x"
			    		;;
				SRA) 
					flipFlag="y -z -x"
			    		;;

				#I PA LR
				IPL) 
					flipFlag="-z y x"
			    		;;
				IPR) 
					flipFlag="z y x"
			    		;;
				IAL) 
					flipFlag="-z -y x"
			    		;;
				IAR) 
					flipFlag="z -y x"
			    		;;

				#S PA LR
				SPL) 
					flipFlag="-z y -x"
			    		;;
				SPR) 
					flipFlag="z y -x"
			    		;;
				SAL) 
					flipFlag="-z -y -x"
			    		;;
				SAR) 
					flipFlag="z -y -x"
			    		;;
			  esac

			  echo "flipping by ${flipFlag}"


			  #Reorienting image and checking for warning messages
			  warnFlag=`fslswapdim ${infile} ${flipFlag} ${infile%.nii.gz}_MNI.nii.gz`
			  warnFlagCut=`echo ${warnFlag} | awk -F":" '{print $1}'`


			  #Reorienting the file may require swapping out the flag orientation to match the .img block
			  if [[ $warnFlagCut == "WARNING" ]]; then
				fslorient -swaporient ${infile%.nii.gz}_MNI.nii.gz
			  fi

			else

			  echo "No need to reorient.  Dataset already in RPI orientation."

			  if [ ! -e ${infile%.nii.gz}_MNI.nii.gz ]; then

			    cp ${infile} ${infile%.nii.gz}_MNI.nii.gz

			  fi

			fi


			#Output should now be in RPI orientation and ready for analysis

		     #fslreorient.sh ${preProcDataDir}/sub${name}/${cond}${scan}/sub${name}_${scan}.nii.gz
	        #mv ${preProcDataDir}/sub${name}/${cond}${scan}/sub${name}_${scan}_MNI.nii.gz ${preProcDataDir}/sub${name}/${cond}${scan}/sub${name}_${scan}.nii.gz
	        #############################################################
	        #END ORIENTATION CODE

		#copy the raw dicoms into the preProcDataDir for ease of access in case some specific analysis needs to be done.
		cp  ${correct_dir}/resources/DICOM/files/*.dcm ${preProcDataDir}/sub${name}/${cond}/${scan}/Raw/

	#Special Processing for Functional Scans
	####################################################################
		    #if the scan is a functional scan (i.e. SPATIAL_N_BACK or REST), get motion parameters
		    #note: try to find if there is some other way to identify functional scans
		
		#answer to note: use repetition times and echo times to identify functional scans
		#repetition time
		tr=$(dicom_hdr $(ls ${preProcDataDir}/sub${name}/${cond}${scan}/Raw/*.dcm | head -n 1) | grep Repetition\ Time | awk -F"//" '{print $3}')
		#echo time
		te=$(dicom_hdr $(ls ${preProcDataDir}/sub${name}/${cond}${scan}/Raw/*.dcm | head -n 1) | grep Echo\ Time | awk -F"//" '{print $3}')
		echo "the repetition time is ${tr}"
		echo "the echo time is ${te}"


		#Or I can use the scan sequence?
		scan_type=$(dicom_hdr $(ls ${preProcDataDir}/sub${name}/${cond}${scan}/Raw/*.dcm | head -n 1) | grep -o epfid2d1_64)
		#if [ "${scan_type}" == "epfid2d1_64" ]; then

		#May wish to use previous check instead of the one below
		if [ ${tr} -gt 1500 ] && [ ${tr} -lt 2500 ] && [ ${te} -lt 50 ]; then
		    
			#note move everything into the motion directory
		    if [ -e ${preProcDataDir}/sub${name}/${cond}${scan}/motion ]; then
			rm -rf  ${preProcDataDir}/sub${name}/${cond}${scan}/motion
		    fi

		    mkdir -p ${preProcDataDir}/{Func_Motion_Check,sub${name}/${cond}${scan}/motion}
			 #Determine halfway point of dataset to use as a target for registration
		    halfPoint=`fslhd ${preProcDataDir}/sub${name}/${cond}${scan}/sub${name}_${scan}.nii.gz | grep "^dim4" | awk '{print int($2/2)}'`
		    
			#Run 3dvolreg, save matrices and parameters
	      #Saving "raw" AFNI output for possible use later (motionscrubbing?)
		    3dvolreg -verbose -tshift 0 -Fourier -zpad 4 -prefix ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg.nii.gz -base $halfPoint -dfile ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_raw.par -1Dmatrix_save ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg.mat ${preProcDataDir}/sub${name}/${cond}${scan}/sub${name}_${scan}.nii.gz

	     #Create a mean volume
		    fslmaths ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg.nii.gz -Tmean ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImgMean.nii.gz

	     #Save out mcImg.par (like fsl) with only the translations and rotations
	      #mcflirt appears to have a different rotation/translation order.  Reorder 3dvolreg output to match "RPI" FSL ordering
	      ##AFNI ordering
		#roll  = rotation about the I-S axis }
		#pitch = rotation about the R-L axis } degrees CCW
		#yaw   = rotation about the A-P axis }
		#dS  = displacement in the Superior direction  }
		#dL  = displacement in the Left direction      } mm
		#dP  = displacement in the Posterior direction }

		    cat ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_raw.par | awk '{print ($3 " " $4 " " $2 " " $6 " " $7 " " $5)}' >> ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_deg.par

	    #Need to convert rotational parameters from degrees to radians
	      #rotRad= (rotDeg*pi)/180
		#pi=3.14159

		    cat ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_deg.par | awk -v pi=3.14159 '{print (($1*pi)/180) " " (($2*pi)/180) " " (($3*pi)/180) " " $4 " " $5 " " $6}' > ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg.par


	    #Need to create a version where ALL (rotations and translations) measurements are in mm.  Going by Power 2012 Neuroimage paper, radius of 50mm.
	      #Convert degrees to mm, leave translations alone.
	      #rotDeg= ((2r*Pi)/360) * Degrees = Distance (mm)
		#d=2r=2*50=100
		#pi=3.14159

		    cat ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_deg.par | awk -v pi=3.14159 -v d=100 '{print (((d*pi)/360)*$1) " " (((d*pi)/360)*$2) " " (((d*pi)/360)*$3) " " $4 " " $5 " " $6}' > ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_mm.par


	    #Cut motion parameter file into 6 distinct TR parameter files
		    for i in 1 2 3 4 5 6
		    do
			cat ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg.par | awk -v var=${i} '{print $var}' > ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mc${i}.par
		    done

	 ##Need to create the absolute and relative displacement RMS measurement files
	      #From the FSL mailing list (https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;2ce58db1.1202):
		#rms = sqrt(0.2*R^2*((cos(theta_x)-1)^2+(sin(theta_x))^2 + (cos(theta_y)-1)^2 + (sin(theta_y))^2 + (cos(theta_z)-1)^2 + (sin(theta_z)^2)) + transx^2+transy^2+transz^2)
		#where R=radius of spherical ROI = 80mm used in rmsdiff; theta_x, theta_y, theta_z are the three rotation angles from the .par file; and transx, transy, transz are the three translations from the .par file.

	    #Absolute Displacement
		    cat ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg.par | awk '{print (sqrt(0.2*80^2*((cos($1)-1)^2+(sin($1))^2 + (cos($2)-1)^2 + (sin($2))^2 + (cos($3)-1)^2 + (sin($3)^2)) + $4^2+$5^2+$6^2))}' >> ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_abs.rms

	    #Relative Displacement
	    #Create the relative displacement .par file from the input using AFNI's 1d_tool.py to first calculate the derivatives
		    1d_tool.py -infile ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg.par -set_nruns 1 -derivative -write ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_deriv.par
		    cat ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_deriv.par | awk '{print (sqrt(0.2*80^2*((cos($1)-1)^2+(sin($1))^2 + (cos($2)-1)^2 + (sin($2))^2 + (cos($3)-1)^2 + (sin($3)^2)) + $4^2+$5^2+$6^2))}' >> ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_rel.rms


	    #Create images of the motion correction (translation, rotations, displacement), mm and radians
	      #switched from "MCFLIRT estimated...." title
		    fsl_tsplot -i ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg.par -t '3dvolreg estimated rotations (radians)' -u 1 --start=1 --finish=3 -a x,y,z -w 800 -h 300 -o ${preProcDataDir}/sub${name}/${cond}${scan}/motion/rot.png
		    fsl_tsplot -i ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg.par -t '3dvolreg estimated translations (mm)' -u 1 --start=4 --finish=6 -a x,y,z -w 800 -h 300 -o ${preProcDataDir}/sub${name}/${cond}${scan}/motion/trans.png
		    fsl_tsplot -i ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_mm.par -t '3dvolreg estimated rotations (mm)' -u 1 --start=1 --finish=3 -a x,y,z -w 800 -h 300 -o ${preProcDataDir}/sub${name}/${cond}${scan}/motion/rot_mm.png
		    fsl_tsplot -i ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_mm.par -t '3dvolreg estimated rotations and translations (mm)' -u 1 --start=1 --finish=6 -a "x(rot),y(rot),z(rot),x(trans),y(trans),z(trans)" -w 800 -h 300 -o ${preProcDataDir}/sub${name}/${cond}${scan}/motion/rot_trans.png
		    fsl_tsplot -i ${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_abs.rms,${preProcDataDir}/sub${name}/${cond}${scan}/motion/mcImg_rel.rms -t '3dvolreg estimated mean displacement (mm)' -u 1 -w 800 -h 300 -a absolute,relative -o ${preProcDataDir}/sub${name}/${cond}${scan}/motion/disp.png
		    
		    mv ${preProcDataDir}/sub${name}/${cond}${scan}/motion/disp.png ${preProcDataDir}/sub${name}/${cond}${scan}/motion/${scan}_${name}_disp.png 
		    cp ${preProcDataDir}/sub${name}/${cond}${scan}/motion/${scan}_${name}_disp.png ${preProcDataDir}/Func_Motion_Check/
		fi

	#Finished with getting motion parameters for functional data
	####################################################################

		

		echo "FINISHED ${scan} for sub${name}" >> preprocessing.log
		#Done with the particilar scan for the subject.
	done

#update Log
    echo "updating the log"
    #I honestly don't understand sed very well, but this should replace the last field, the done? column, with a 1 for the subject
    sed -ie 's/\('"$name"'\)\(,.*,\).*/\1\21/' tmp_scanLog.csv
    echo "FINISHED sub${name}" >> preprocessing.log



done #Done with all the subjects

#Make .html files for easy viewing of scans to check for FOV
if [ ! ${skipSlicesDir} -eq 1 ]; then
for scan in ${scans}; do
    #use slicesdir on all subjects in all conditions
    if [ -e ${preProcDataDir}/slicesdir_${scan} ]; then
	rm -rf ${preProcDataDir}/slicesdir_${scan} 
    fi
    slicesdir ${preProcDataDir}/sub*/*/${scan}/*_${scan}.nii.gz
    mv slicesdir slicesdir_${scan}
    mv -f slicesdir_${scan} ${preProcDataDir}
done
fi

#final update
#report the end findings to the final log
mv tmp_scanLog.csv ${scanLog}

#rm temporary files if necessary
if [ -e tmp_scanLog.csve ]; then
    rm tmp_scanLog.csve
fi

if [ -e tmp_scanVol.csv ]; then
    rm tmp_scanVol.csv
fi


################################################
#another way I can try to update the tmp_scanLog.csv
#sed -ie '/'"${name}"'/s/,0/,1/' tmp_scanLog.csv
################################################

################################################
#Failed method of updating the tmp_scanLog.csv
#awk  'BEGIN{FS=OFS=","} ($2=="'"${sub}"'") {$(\NF)=1}1' tmp_scanLog.csv > tmp2_scanLog.csv
#mv tmp2_scanLog.csv tmp_scanLog.csv
#cat tmp_scanLog.csv
################################################

 #   cond=`awk -F"," '($2=="'"${sub}"'") && ($(\NF)==0) {for (i=3; i < NF; i++) print $i}' tmp_scanLog.csv | tr '\n' '/'`        