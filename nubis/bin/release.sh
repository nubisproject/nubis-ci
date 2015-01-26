#!/bin/bash
#
# This script will bump the build and/or the release numbers in $file, which is
# a json file that's consumed by packer. It's currently called from the Makefile
# to do this for you, allowing you to build a series of AMIs quickly without
# an additional step.
#

usage(){
   echo "Usage: $0 -f|--file <file> [-r|--release]" 1>&2
   echo
   echo "Script is invoked automagically via make, but open me up and read"
   echo "comments for more information."
   exit 1
}

while [[ ! -z "$1" ]]; do
   case "$1" in
      -f | --file )
         file="$2"
         shift
         ;;
      -r | --release )
         increment_release=1
         ;;
      *)
         echo wtf $1
         usage
    esac
    shift
done

# Required argument.
if [[ -z "$file" ]]; then
echo erp
   usage
fi

umask 077
if [ -f $file ]; then
   # Poor mans json parsing
   release=$(grep release $file | cut -d ':' -f 2 | cut -d '"' -f 2)
   build=$(grep build $file | cut -d ':' -f 2 | cut -d '"' -f 2)

   if [ ${increment_release:-0} -eq 1 ]; then
      release=$(($release + 1))
      build=0
   else
      build=$(($build + 1))
   fi
else
   release=0
   build=1
fi

rm -f $file
# Poor mans json writer
cat << EOF > $file
{
  "release": "$release",
  "build": "$build"
}
EOF
