#!/bin/bash

user="username"
pass="password"
artifacts=('SUFFIX_URL_TO_JAR1'
  'SUFFIX_URL_TO_JAR2')

for artifact in "${artifacts[@]}";do 
  echo "Measuring $artifact"
  curl "https://{$user}:{$pass}@SERVER/$artifact" --output temp/eval.jar
  ./java_evaluation.sh temp/eval.jar 120 400 "$artifact" "java.log"
  rm temp/eval.jar
done