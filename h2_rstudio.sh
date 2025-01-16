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

# Function to print the banner
print_banner() {
  local RESET=$'\e[0m'
  local HEADER_BG=$'\e[44;97m'  # White text on blue background
  local BORDER_BG=$'\e[46;97m'  # White text on cyan background
  local TEXT_COLOR=$'\e[93m'    # Yellow text
  local QUIT_MSG=$'\e[31m'      # Red text

  clear  # Clears the terminal to make it clean

  # Top border
  echo -e "${BORDER_BG}══════════════════════════════════════════════════════════════════════════════════════${RESET}"

  # Title
  echo -e "${HEADER_BG}                                HOFFMAN 2 - RSTUDIO                                    ${RESET}"

  # Middle separator
  echo -e "${BORDER_BG}══════════════════════════════════════════════════════════════════════════════════════${RESET}"

  # Subtext
  echo -e "${TEXT_COLOR}                      Welcome! Please make sure to follow the usage guidelines.        ${RESET}"

  # Quit message
  echo -e "${QUIT_MSG}                                                   Press ctrl+c to quit                ${RESET}"

  # Bottom border
  echo -e "${BORDER_BG}══════════════════════════════════════════════════════════════════════════════════════${RESET}"
}

# Call the banner function
print_banner
tput sgr0

# Capitalized color variables
CYAN=$'\e[1;36m'
BLUE=$'\e[1;34m'
GREEN=$'\e[1;32m'
YELLOW=$'\e[1;33m'
WHITE=$'\e[1;37m'
PURPLE=$'\e[1;35m'
RESET=$'\e[0m'
## USAGE ##
usage ()
{
  echo -e "${CYAN}#######################################################################################${RESET}"
  echo -e "${BLUE}##                              HOFFMAN2 RSTUDIO USAGE GUIDE                         ##${RESET}"
  echo -e "${CYAN}#######################################################################################${RESET}"

  echo -e "\n${GREEN}This script will create an RStudio session on a compute node on Hoffman2.${RESET}\n"

  echo -e "${YELLOW}REQUIRED OPTIONS:${RESET}"
  echo -e "  ${WHITE}-u${RESET} [username]    Your Hoffman2 username (mandatory)\n"

  echo -e "${YELLOW}OPTIONAL PARAMETERS:${RESET}"
  echo -e "  ${WHITE}-m${RESET} [MEMORY]     Memory requirements in GB (default: 10 GB)"
  echo -e "  ${WHITE}-t${RESET} [TIME]       Time of RStudio job in HH:MM:SS (default: 2:00:00)"
  echo -e "  ${WHITE}-v${RESET} [VERSION]    RStudio version (default: 4.1.0)"
  echo -e "  ${WHITE}-p${RESET}              Request high-priority queue (highp)"
  echo -e "  ${WHITE}-g${RESET} [GPUTYPE]    Request GPU resources, where GPUTYPE can be 'V100', 'A100', A6000, etc.\n"

  echo -e "${PURPLE}HELP:${RESET}"
  echo -e "  ${WHITE}-h${RESET}              Show this usage message\n"

  echo -e "${CYAN}#######################################################################################${RESET}"
  exit
}

# Example: Uncomment this to test calling the usage function
# usage
## CLEANING UP ##
function cleaning()
{
        if [ -f rstudiotmp ] ; then rm rstudiotmp ; fi
        exit 1
}


## GETTING COMMAND LINE OPTIONS ###
while getopts ":u:t:m:e:v:g:ph" options ; do
  case $options in
    h ) usage; exit ;;               # Show usage guide
    u ) H2USERNAME=$OPTARG  ;;        # Hoffman2 username
    t ) JOBTIME=$OPTARG ;;            # Job time
    m ) JOBMEM=$OPTARG ;;             # Job memory
    v ) RSTUDIO_VERSION=$OPTARG ;;    # RStudio version
    p ) HIGHP="TRUE" ;;               # Set high priority (HIGHP) to TRUE
    g ) GPUTYPE=$OPTARG ;;            # Set GPUTYPE to the specified value
    : ) echo "-$OPTARG requires an argument"; usage; exit ;;  # Missing argument case
    ? ) echo "-$OPTARG is not an option"; usage ; exit ;;     # Unknown option case
  esac
done

## If -v wasn't provided, default to 4.1.0
if [ -z "${RSTUDIO_VERSION}" ] ; then
  RSTUDIO_VERSION="4.1.0"
fi

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
if [ -z ${JOBMEM} ] ; then JOBMEM=10 ; fi

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
EXTRA_ARG=""
# Add "highp" if HIGHP is true
if [[ "$HIGHP" == "TRUE" ]]; then
  EXTRA_ARG+="highp,"
fi
# Add GPU type if GPUTYPE exists
if [[ -n "$GPUTYPE" ]]; then
  EXTRA_ARG+="${GPUTYPE},gpu,cuda=1,"
fi

## STARING RSTUDIO JOB ##
sleep 2
trap cleaning EXIT
mktmp_cmd=`echo 'mkdir -p \\\${SCRATCH}/rstudiotmp/var/run ; mkdir -p \\\${SCRATCH}/rstudiotmp/var/lib ; mkdir -p \\\${SCRATCH}/rstudiotmp/tmp'`

qrsh_cmd=`echo 'source /u/local/Modules/default/init/modules.sh ; module purge ; module load apptainer ; module list ; echo HOSTNAME ; echo \\\$HOSTNAME ; apptainer run -B \\\$SCRATCH/rstudiotmp/var/lib:/var/lib/rstudio-server -B \\\$SCRATCH/rstudiotmp/var/run:/var/run/rstudio-server -B \\\$SCRATCH/rstudiotmp/tmp:/tmp \\\$H2_CONTAINER_LOC/h2-rstudio_'${RSTUDIO_VERSION}'.sif'`

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
#sp="/-\|"
#printf "Waiting for job to start running....."
#while [[ ${out_tmp} -ne 2 ]]
#do 
#        JOBID=`cat rstudiotmp | grep JOBID | awk '{print $2}'`
#        out_tmp=`cat rstudiotmp | grep ssh | wc -l`
#        printf "\b${sp:i++%${#sp}:1}"
#        sleep 1
#done
spinner=("🔄" "🚀" "🌟" "🔥" "✨" "🌀" "💫")
printf "Waiting for RStudio to start..."
while [[ ${out_tmp} -ne 2 ]]
do
  for emoji in "${spinner[@]}"; do
    printf "\r%s Waiting for Rstudio job to start on Hoffman2..." "$emoji" 
    out_tmp=`cat rstudiotmp | grep ssh | wc -l`
    sleep 0.3
  done
done
echo -e "\n🚀 RStudio is now ready!"

### OPEN UP PORT
out_tmp2=$(cat rstudiotmp | grep ssh | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g")
out_port=$(grep "running on PORT" rstudiotmp | awk '{print $6}' | tr -d '\r' | tr -d '\n' | xargs)
out_host=$(awk '/HOSTNAME/{getline; print $1}' rstudiotmp | tail -1 | tr -d '\r' | tr -d '\n')

out2="${out_port}:${out_host}:${out_port}"
expect <<- eof2 > /dev/null  &
set timeout $WALLTIME
spawn ssh -N -L ${out_port}:${out_host}:${out_port} ${H2USERNAME}@hoffman2.idre.ucla.edu
     expect "*assword:"
     send "${H2PASSWORD}\r"
     expect "$ "
eof2

RSTUDIOPWD=$(grep "Your Rstudio PASSWORD" rstudiotmp | awk '{print $5}' | tr -d '\r' | tr -d '\n' | xargs)

## CHECK TO SEE IF PORT IS OPEN ##
port_bool=`lsof -i -P -n | grep LISTEN | grep ${out_port} | wc -l`
while [[ ${port_bool} -eq 0 ]] ; do port_bool=`lsof -i -P -n | grep LISTEN | grep ${out_port} | wc -l` ; sleep 1 ; done

## OPENING UP BROWSER ##
echo -e $"You can now open your web browser to ${GREEN} http://localhost:${out_port} ${RESET}"
echo -e $"Your Rstudio USERNAME is: ${GREEN} ${H2USERNAME} ${RESET}"
echo -e $"Your Rstudio PASSWORD is: ${GREEN} ${RSTUDIOPWD} ${RESET}"

if command -v xdg-open &> /dev/null
then 
        xdg-open http://localhost:${out_port}
elif command -v open &> /dev/null
then 
        open http://localhost:${out_port}
fi

### WAITING UNTIL WALLTIME ##
sleep $WALLTIME
