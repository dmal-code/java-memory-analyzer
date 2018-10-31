#--------- helper functions ----------------

#check if required tools are available
check_required_tools () {
    if [ -x "$(command -v docker-compose)" ] && \
       [ -x "$(command -v awk)" ] && \
       [ -x "$(command -v sort)" ] && \
       [ -x "$(command -v tail)" ] && \
       [ -x "$(command -v join)" ] && \
       [ -x "$(command -v sed)" ] && \
       [ -x "$(command -v openssl)" ] && \
       [ -x "$(command -v sha512sum)" ] && \
       [ -x "$(command -v docker)" ] 
    then
        return 1
    else
        return 0
    fi
}

#Search for a file via $2 regex pattern in all git branches of git repo $1
find_file_in_git_repo() {
  for branch in $(git -C "$1" for-each-ref --format="%(refname)" refs/heads); do
    echo $branch :; git ls-tree -r --name-only $branch | grep "$2"
  done
}

#Replace line $1 in file $2 with $3.
replace_line() {
    sed -i "$1s/.*/$3/" "$2"
}

#Add key-value pair ($1 $2) to db file $3, the file must exist.
add_db_entry() {
    echo "$1 $2" >> "$3"
}

#Add key-value pair ($1 $2) to db file $3, the file must exist.
add_db_entry_with_line_break() {
    printf "$1 $2\n" >> "$3"
}

#Retrieve key of $1-th line from file $2.
get_db_entry_key_by_line() {
    echo $(awk -F " " "NR==$1{print \$1}" "$2")
}

#Retrieve value of $1-th line from file $2.
get_db_entry_value_by_line() {
    echo $(awk -F " " "NR==$1{print \$2}" "$2")
}

#Retrieve value for key $1 from file $2.
get_db_entry_value_by_key() {
    echo $(grep -hr "$1" "$2" | awk -F " " "{print \$2}" -)
}

#Add the first (i.e. header) column $1 to log file $2, will create the file if it does not exist.
#Should the file exist it will simply return.
init_log_file() {
    if [ ! -f $2 ]; then
        echo "$1"  > "$2"
    fi
}

#Add $1 as key-value column to log file $2 and use $3 as a temporary file 
#Always use a script-instance-specific temporary file in order to avoid problems with parallel script invocations. 
add_log_column() {
    echo "$1" | join "$2" - > "$3" && rm "$2" && mv "$3" "$2"	
}

#rotate the file, parameters are $1=logfile, $2=logthreshold, $3=logfile_count, $4=log_db_file $5=row_in_db.
rotate_file() {
    columns_in_file=$(awk -F "," '{print NF}' "$1" | sort -nu | tail -n 1)

    if [ $columns_in_file -ge $2 ]; then
      rotation_count=$(get_db_entry_value_by_line "$5" "$4")
      file_suffix=$(( rotation_count % $3))
      replace_line "$5" "$4" "rotation_count $((rotation_count+1))"
      mv "$1" "$1$file_suffix"
    fi
}