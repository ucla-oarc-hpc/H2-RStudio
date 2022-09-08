#!/bin/bash
## This script will run Rstudio server on Hoffman2
## This uses an Apptainer container with R/Rstudio
# Author Charlie Peterson <cpeterson@oarc.ucla.edu>
# Date Created: 2/2/2022
# Date Modified: 3/9/2022 - change to apptainer

## TO DO:
##
## extra qrsh check
## multiple core check
##

echo -e $'\e[37;42m@--------------------------------------------------------------------------------------@\e[0m'
echo -e $'\e[37;42m|                     H O F F M A N 2  -  R S T U D I O                                |\e[0m'
echo -e $'\e[37;42m@--------------------------------------------------------------------------------------@\e[0m' 
echo -e $'\E[32m                                                                          ctrl+c to quit \e[0m'
tput sgr0
GREEN='\033[0;32m'

NOCOLOR='\033[0m'
## USAGE ##
usage ()
{
echo "
##	This Script will create a Rstudio session on a compute node on Hoffman2

	-h       Show this message  
	OPTIONS:
	REQUIRED
	-u [username]   Hoffman2 user name
	OPTIONAL:
        -m [MEMORY]       Memory requirments in GB, default 2GB
	-t [TIME]	Time of RSTUDIO job in HH:MM:SS, default 2:00:00
"
exit
}

## CLEANING UP ##
function cleaning()
{
	if [ -f rstudiotmp ] ; then rm rstudiotmp ; fi
	exit 1
}


## GETTING COMMAND LINE OPTIONS ###
while getopts ":u:t:m:e:h" options ; do
        case $options in
                h ) usage; exit ;;
                u ) H2USERNAME=$OPTARG  ;;
		t ) JOBTIME=$OPTARG ;;
		m ) JOBMEM=$OPTARG ;;
		e ) EXTRA_ARG=$OPTARG ;;
                : ) echo "-$OPTARG requires an argument"; usage; exit ;;
                ? ) echo "-$OPTARG is not an option"; usage ; exit;;
        esac
done

## CHECK FOR EXPECT ##
if ! command -v expect &> /dev/null
then
        echo "You MUST have the expect command installed on your system... Exiting"
	exit
fi

## CHECK ARGS ##

## CHECK USERNAME ##
if [ -z ${H2USERNAME} ] ; then
	echo "MUST ENTER Hoffman2 USER NAME"
	usage
fi

## CHECK MEM ##
if [ -z ${JOBMEM} ] ; then JOBMEM=3 ; fi

## CHECK RUN TIME ##
if [ -z ${JOBTIME} ] ; then JOBTIME="2:00:00" ; fi
WALLTIME=`echo "$JOBTIME" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }'`

## CHECK FOR SSH PASSWORD

## PASSWORDLESS CHECK
echo "Checking for Hoffman2 password..."
if ! ssh -o BatchMode=yes "${H2USERNAME}@hoffman2.idre.ucla.edu" true 2>/dev/null; then
        echo "Please enter your Hoffman2 Password for User: ${H2USERNAME}"
	read -s H2PASSWORD
else 
	H2PASSWORD=""
	PASSWORDLESS="true"
	PASSWORD_CHECK="true"
fi
if [[ "${PASSWORDLESS}"  != "true" ]] ; then
PASSWORD_CHECK=false
expect <<- eof3 > rstudiotmp  
set timeout $WALLTIME
spawn ssh -o NumberOfPasswordPrompts=1 ${H2USERNAME}@hoffman2.idre.ucla.edu
     expect "*assword:" 
     send "${H2PASSWORD}\r"
     expect "$ "
eof3
check_pass=`cat rstudiotmp | grep "Permission denied" | wc -l`
rm rstudiotmp
for itr in 1 2 3 ; do
if [[ "${check_pass}" -ne "0" ]] ; then
	echo "Incorrect Password: Please enter your Hoffman2 Password for User: ${H2USERNAME}"
	read -s H2PASSWORD
else
	PASSWORD_CHECK=true
	break
fi

expect <<- eof3 > rstudiotmp
set timeout $WALLTIME
spawn ssh -o NumberOfPasswordPrompts=1 ${H2USERNAME}@hoffman2.idre.ucla.edu
     expect "*assword:"
     send "${H2PASSWORD}\r"
     expect "$ "
eof3
check_pass=`cat rstudiotmp | grep "Permission denied" | wc -l`
rm rstudiotmp
done
if [[ "$PASSWORD_CHECK"  != "true" ]] ; then
	echo "Password is invaild"
	exit 1
fi
fi

## CHECK EXTRA ARGS ##

## STARING RSTUDIO JOB ##
sleep 2
trap cleaning EXIT
mktmp_cmd=`echo 'mkdir -p \\\${SCRATCH}/rstudiotmp/var/run ; mkdir -p \\\${SCRATCH}/rstudiotmp/var/lib ; mkdir -p \\\${SCRATCH}/rstudiotmp/tmp'`

qrsh_cmd=`echo 'source /u/local/Modules/default/init/modules.sh ; module purge ; module load apptainer ; module list ; echo HOSTNAME ; echo \\\$HOSTNAME ; apptainer run -B \\\$SCRATCH/rstudiotmp/var/lib:/var/lib/rstudio-server -B \\\$SCRATCH/rstudiotmp/var/run:/var/run/rstudio-server -B \\\$SCRATCH/rstudiotmp/tmp:/tmp \\\$H2_CONTAINER_LOC/h2-rstudio_4.1.0.sif'`

ssh_cmd="echo starting ; ${mktmp_cmd} ; qrsh -N RSTUDIO -l ${EXTRA_ARG}h_data=${JOBMEM}G,h_rt=${JOBTIME} '${qrsh_cmd}'"
expect <<- eof1 > rstudiotmp  &
set timeout $WALLTIME
spawn ssh ${H2USERNAME}@hoffman2.idre.ucla.edu
expect  {
        "assword:" { send "${H2PASSWORD}\r";exp_continue}
	send "export PS1='$ '\r"
	"$ " {send "$env(${ssh_cmd})\r";exp_continue}
	send "sleep $WALLTIME"
	expect "$ "
}
eof1
  

## CHECK if SSH WORKED ##
start_bool=`cat rstudiotmp | grep starting | wc -l`
while [[ ${start_bool} -eq 0 ]]; do
	sleep 1
	start_bool=`cat rstudiotmp | grep starting | wc -l`
done 

## WAITING FOR RSTUDIO TO START ##
out_tmp=""
sp="/-\|"
printf "Waiting for job to start running....."
while [[ ${out_tmp} -ne 2 ]]
do 
	JOBID=`cat rstudiotmp | grep JOBID | awk '{print $2}'`
	out_tmp=`cat rstudiotmp | grep ssh | wc -l`
	printf "\b${sp:i++%${#sp}:1}"
	sleep 1
done

### OPEN UP PORT
echo ".....Job started!!"
echo ""
out_tmp2=`cat rstudiotmp | grep ssh |  sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g"`
out_port=`grep "running on PORT" rstudiotmp | awk '{print $7}'`
out_host=`cat rstudiotmp | awk '/HOSTNAME/{getline; print}' | tail -1 | tr -d $'\r'`
out2=`echo "${out_port}:${out_host}:${out_port}"`
expect <<- eof2 > /dev/null  &
set timeout $WALLTIME
spawn ssh -N -L ${out_port}:${out_host}:${out_port} ${H2USERNAME}@hoffman2.idre.ucla.edu
     expect "*assword:"
     send "${H2PASSWORD}\r"
     expect "$ "
eof2


## CHECK TO SEE IF PORT IS OPEN ##
port_bool=`lsof -i -P -n | grep LISTEN | grep ${out_port} | wc -l`
while [[ ${port_bool} -eq 0 ]] ; do port_bool=`lsof -i -P -n | grep LISTEN | grep ${out_port} | wc -l` ; sleep 1 ; done

## OPENING UP BROWSER ##
echo -e $"You can now open your web browser to ${GREEN} http://localhost:${out_port} ${NOCOLOR}"

if command -v xdg-open &> /dev/null
then 
	xdg-open http://localhost:${out_port}
elif command -v open &> /dev/null
then 
	open http://localhost:${out_port}
fi

### WAITING UNTIL WALLTIME ##
sleep $WALLTIME



