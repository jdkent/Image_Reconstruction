#!/bin/bash


#Function to make sure commands are not run if their output already exists
#unless specified to overwrite by user
function clobber()
{
	for arg in "$@"; do
		if [ -e $1 ] && [ "${clob}" = true ]; then
			rm $1
			return 0
		elif [ -e $1 ] && [ "${clob}" = false ]; then
			return 1
		elif [ ! -e $1 ]; then
			return 0
		else
			echo "How did you get here?"
			return 1
		fi
	done
}

#See the following link to do this manually/set up a protocol file: https://www.nitrc.org/plugins/mwiki/index.php/dtiprep:MainPage#Option_1_—_Define_a_new_data_acquisition_protocol_file


#Check to see if proper commands are in the path
DTIPrep_check=$(which DTIPrep)
DWIConvert_check=$(which DWIConvert)
if [ -z "${DTIPrep_check}" ] || [ -z "${DWIConvert_check}" ]; then
	echo "One (or more) of the commands necessary to run this script aren't in your PATH"
	echo "DTIPrep: ${DTIPrep_check}"
	echo "DWIConvert: ${DWIConvert_check}"
	echo "Please find the command(s) that aren't listed above"
	exit 1
fi

#defaults
clob=false #false

#Argument collection
while getopts "d:o:p:f:hc" OPTION
do
	case $OPTION in
		d)
			DicomDir=${OPTARG}
			;;
		o)
			outputDir=${OPTARG}
			;;
		f)
			filePrefix=${OPTARG}
			;;
		p)
			protocol=${OPTARG}
			;;
		c)
			clob=true
			;;
		h)
			echo "this is help"
			;;
	esac
done


#check for inputs
if [ -z "${DicomDir}" ]; then
	echo "-d (DicomDir) is not set, exiting"
	exit 1
fi

if [ -z "${outputDir}" ]; then
	echo "Warning: output directory not set, using current directory"
	outputDir=`pwd`
fi

if [ -z "${protocol}" ]; then
	echo "-p (protocol) is not set, exiting"
	exit 1
fi

if [ -z "${filePrefix}" ]; then
	echo "Warning: -n (filePrefix) not set, using default"
	filePrefix="DTI_file"
fi


#run DTIPrep
mkdir -p ${outputDir}/intermediateFiles
bulkDir=${outputDir}/intermediateFiles

clobber ${bulkDir}/${filePrefix}.nhdr &&\
DWIConvert --conversionMode DicomToNrrd -i ${DicomDir} --outputVolume ${bulkDir}/${filePrefix}.nhdr

clobber ${bulkDir}/${filePrefix}_QCed.nrrd &&\
DTIPrep --DWINrrdFile ${bulkDir}/${filePrefix}.nhdr --xmlProtocol ${protocol} --check --outputFolder ${bulkDir}

clobber ${outputDir}/${filePrefix}_QCed.nii.gz &&\
DWIConvert --conversionMode NrrdToFSL \
 --inputVolume ${bulkDir}/${filePrefix}_QCed.nrrd \
 --outputVolume ${outputDir}/${filePrefix}_QCed.nii.gz \
 --outputBValues ${outputDir}/${filePrefix}.bvals \
 --outputBVectors ${outputDir}/${filePrefix}.bvecs

 echo "Finished processing ${filePrefix}"
