#!/bin/bash
#

COUNTGW1=0
COUNTGW2=0
COUNTNOSRV=0
COUNTHTTPOK=0
FULLCOUNT_CLIENT_REQUEST=0
FULLCOUNT_SERVER_RESPONSE=0
FULLCOUNT_TOTALSESSION_DURATION=0

while read line 
do 
  #echo $line
  #echo $line | grep "GW1"
  GW1=`echo $line | grep "GW1" | grep ProductionDeployment`
  if ! [ -z "$GW1" ]; then
     #echo "$line"
     COUNTGW1=`expr $COUNTGW1 + 1`
     #echo "$COUNTGW1"
  fi

  GW2=`echo $line | grep "GW2" | grep ProductionDeployment`
  if ! [ -z "$GW2" ]; then
     COUNTGW2=`expr $COUNTGW2 + 1`
     #echo "$COUNTGW2"
  fi

  NOSRV=`echo $line | grep "NOSRV" | grep ProductionDeployment`
  if ! [ -z "$NOSRV" ]; then
     COUNTNOSRV=`expr $COUNTNOSRV + 1`
     #echo "$NOSRV"
  fi

  HTTPOK=`echo $line | grep " 200 "`
  if ! [ -z "$HTTPOK" ]; then
      CLIENT_REQUEST=`echo $HTTPOK | awk '{print $10}' | sed 's|\([0-9]\)\/.*|\1|'`
      SERVER_RESPONSE=`echo $HTTPOK | awk '{print $10}' | awk 'BEGIN { FS = "/" } ; { print $4 }'`
      TOTAL_SESSION_DURATION=`echo $HTTPOK | awk '{print $10}' | sed 's|.*\/\([0-9]\)|\1|'`
      # Count the number of HTTP OK Sessions
      COUNTHTTPOK=`expr $COUNTHTTPOK + 1`

      # Put these number in files so that we can use the values later to calculate
      # the 90th percentiles for each
      echo $CLIENT_REQUEST >> client_requests
      echo $SERVER_RESPONSE >> server_responses
      echo $TOTAL_SESSION_DURATION >> session_durations

      # Caculate the Full count for all of thenm so that at the end we can caculate the averages
      FULLCOUNT_CLIENT_REQUEST=`expr $FULLCOUNT_CLIENT_REQUEST + $CLIENT_REQUEST`
      FULLCOUNT_SERVER_RESPONSE=`expr $FULLCOUNT_SERVER_RESPONSE + $SERVER_RESPONSE`
      FULLCOUNT_TOTAL_SESSION_DURATION=`expr $FULLCOUNT_TOTAL_SESSION_DURATION + $TOTAL_SESSION_DURATION`
  fi

done < "/var/log/haproxy.log"

echo "GW1 Error Number: $COUNTGW1"
echo "GW2 Error Number: $COUNTGW2"
echo "NOSRV Error Number $COUNTNOSRV"

# Calculate percentages of errors GW1, GW2 and NOSRV

# Total number of errors
FULLCOUNT=`expr $COUNTGW1 + $COUNTGW2 + $COUNTNOSRV`

# Calculate Actual percentages
GW1PRCT=$[ $COUNTGW1 * 100 ]
GW1PRCT=$[ $GW1PRCT / $FULLCOUNT]
GW2PRCT=$[ $COUNTGW2 * 100 ]
GW2PRCT=$[ $GW2PRCT / $FULLCOUNT]
NOSRVPRCT=$[ $COUNTNOSRV * 100 ]
NOSRVPRCT=$[ $NOSRVPRCT / $FULLCOUNT]

# Output percentages
echo "GW1 Percentage is $GW1PRCT"
echo "GW2 Percentage is $GW2PRCT"
echo "NOSRV Percentage is $NOSRVPRCT"

# Caculate the averages for client request, server reponses and total duration times
AVERAGE_CLIENT_REQUEST=$[ $FULLCOUNT_CLIENT_REQUEST / $COUNTHTTPOK ]
AVERAGE_SERVER_RESPONSE=$[ $FULLCOUNT_SERVER_RESPONSE / $COUNTHTTPOK ]
AVERAGE_TOTAL_SESSION_DURATION=$[ $FULLCOUNT_TOTAL_SESSION_DURATION / $COUNTHTTPOK ]

# Output averages
echo "The Average for Client Requests HTTP OK is $AVERAGE_CLIENT_REQUEST"
echo "The Average for Server Responses HTTP OK is $AVERAGE_SERVER_RESPONSE"
echo "The Average Total Session Durations HTTP OK is $AVERAGE_TOTAL_SESSION_DURATION"

# Caculate the percentiles and output them.
# Caculate the actual percentile based on the number of samples (n or $COUNTHTTPOK in our case)
NINETIETH_PERCENTILE=`echo "$COUNTHTTPOK * 0.9" | bc | sed -e "s/\(\.[0-9]\)//g"`
# Round off to next highest
NINETIETH_PERCENTILE=`expr $NINETIETH_PERCENTILE + 1`

echo "The 90th percentile rank is $NINETIETH_PERCENTILE"

# Sort the data (numeric sort)
sort -n < client_requests > client_requests_sorted
sort -n < server_responses > server_responses_sorted
sort -n < session_durations > session_durations_sorted

CLIENT_REQUESTS_NINETIETH_PERCENTILE=`awk -v NPCT=$NINETIETH_PERCENTILE 'NR==NPCT {print; exit}' < client_requests_sorted`
SERVER_RESPONSES_NINETIETH_PERCENTILE=`awk -v NPCT=$NINETIETH_PERCENTILE 'NR==NPCT {print; exit}' < server_responses_sorted`
SESSION_DURATIONS_NINETIETH_PERCENTILE=`awk -v NPCT=$NINETIETH_PERCENTILE 'NR==NPCT {print; exit}' < session_durations_sorted`

echo "The 90th percentile for client requests is $CLIENT_REQUESTS_NINETIETH_PERCENTILE"
echo "The 90th percentile for server responses is $SERVER_RESPONSES_NINETIETH_PERCENTILE"
echo "The 90th percentile for session durations is $SESSION_DURATIONS_NINETIETH_PERCENTILE"

# Clean up files
rm -f client_requests 
rm -f client_requests_sorted 
rm -f server_responses
rm -f server_responses_sorted
rm -f session_durations
rm -f session_durations_sorted

