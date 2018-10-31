#!/bin/bash

#---------------- include helper scripts --------
. ./helper_functions.sh

#params: $1=calculated heap, $2=measured heap, returns the minimal required heap as integer in kb
get_minimal_heap() {
  var0=$(bc <<< "scale=0;$1/1")
  var1=$(bc <<< "scale=0;$2/1")
  minimal_heap=$(($var0>$var1 & $var0>0?$var0:$var1))
  echo $minimal_heap
}

#params: $1=calculated heap, $2=measured heap, returns 1 if calculated heap is negative
is_calculated_heap_negative() {
  var0=$(bc <<< "scale=0;$1/1")
  var1=$(bc <<< "scale=0;$2/1")
  res=$(($var0>0?0:1))
  echo $res
}

#params: $1=jvm pid
get_loaded_classes() {
  var=$(jstat -class $pid | awk 'NR==2{print $1}')
  echo $var
}

#params: $1=jvm pid, returns kB
get_heap_usage() {
  var=$(jstat -gc $pid | awk 'NR==2{print $3+$4+$6+$8}')
  echo $var
}

#params: $1=jvm pid, returns kB
get_metaspace_usage() {
  var=$(jstat -gc $pid | awk 'NR==2{print $10}')
  echo $var
}

#params: $1=jvm pid, returns kB
get_metaspace_capacity() {
  var=$(jstat -gc $pid | awk 'NR==2{print $9}')
  echo $var
}

#params: $1=jvm pid, returns bytes
get_jar_size() {
  var=$(stat -c '%s' $jar_file)
  echo $var
}

#params: $1=jvm pid
get_thread_count() {
  var=$(cat /proc/$pid/status | grep Threads: | awk 'BEGIN {FS ="\t"} {print $2}')
  echo $var
}

#params: $1=value in MB, returns integer in kB
get_kB_from_MB() {
  echo $(bc <<< "scale=0;($1*1024)/1")
}

#params: $1=value, returns the value as integer
make_integer() {
  echo $(bc <<< "scale=0;$1/1")
}

print_usage() {
  echo "java_evaluation.sh jarfile(in MB) evaluation_time(in s) total_system_mem db_file"
}

jar_file=$1
wait_time=$2
total_memory=$3
log_entry_name=$4
log_db_file=$5

echo "measuring application resources"
java -jar $jar_file &> /dev/null &
pid=$!
sleep $wait_time
loaded_classes=$(get_loaded_classes $pid)
heap_usage=$(get_heap_usage $pid)
metaspace_usage=$(get_metaspace_usage $pid)
metaspace_capacity=$(get_metaspace_capacity $pid)
jar_size=$(get_jar_size $pid)
thread_count=$(get_thread_count $pid)
kill $pid
echo -e "Resource consumption:\t loaded $loaded_classes classes, running $thread_count threads, heap usage $heap_usage kB, meta space $metaspace_usage/$metaspace_capacity kB, jar size $jar_size"

direct_memory=100
code_cache=240
metaspace=$(bc <<< "scale=6;($loaded_classes * 5800+14000000)/(1024*1024)")
stack_size=1
heap=$(bc <<< "scale=6;$total_memory - $direct_memory - $thread_count * $stack_size - $code_cache - $metaspace")
minimal_heap=$(get_minimal_heap $heap $heap_usage)
echo -e "Optimal settings:\t code_cache=$code_cache MB, metaspace=$metaspace MB, stack_size=$stack_size MB, heap=$heap MB, minimal heap=$minimal_heap kB"


echo "evaluating settings"
var0=$(get_kB_from_MB $heap)
var0=$(($var0>0?$var0:$minimal_heap))
var1=$(get_kB_from_MB $metaspace)
java -Xmx${var0}K -Xss${stack_size}M -XX:ReservedCodeCacheSize=${code_cache}M -XX:MaxMetaspaceSize=${var1}K -jar $jar_file &> /dev/null &
pid=$!
sleep $wait_time
loaded_classes=$(get_loaded_classes $pid)
heap_usage=$(get_heap_usage $pid)
metaspace_usage=$(get_metaspace_usage $pid)
metaspace_capacity=$(get_metaspace_capacity $pid)
jar_size=$(get_jar_size $pid)
thread_count=$(get_thread_count $pid)
kill $pid
echo -e "Resource consumption:\t loaded $loaded_classes classes, running $thread_count threads, heap usage $heap_usage kB, meta space $metaspace_usage/$metaspace_capacity kB, jar size $jar_size"

is_heap_negative=$(is_calculated_heap_negative $heap $heap_usage)
if [ $is_heap_negative == 1 ]; then
  var0=$(make_integer $heap)
  memory_delta=$(($var0*(-1)))
  total_memory=$(($total_memory+$memory_delta))
  echo "please increase system memory by ${memory_delta}MB to ${total_memory}MB" 
  echo "The application uses ${heap_usage}kB heap memory"
  var0=$(get_kB_from_MB $heap)
  add_db_entry "$log_entry_name" "-Xmx${var0}K -Xss${stack_size}M -XX:ReservedCodeCacheSize=${code_cache}M -XX:MaxMetaspaceSize=${var1}K || increase memory to ${total_memory}MB" $log_db_file
else
  var0=$(get_kB_from_MB $heap)
  echo "Optimal values:"
  echo "-Xmx${var0}K -Xss${stack_size}M -XX:ReservedCodeCacheSize=${code_cache}M -XX:MaxMetaspaceSize=${var1}K"
  add_db_entry "$log_entry_name" "-Xmx${var0}K -Xss${stack_size}M -XX:ReservedCodeCacheSize=${code_cache}M -XX:MaxMetaspaceSize=${var1}K" $log_db_file
fi
