if [ $# -lt 1 ]
then
echo "please enter command: start stop"
exit 0
fi

case $1 in  

"start")
	hexo server -p 18899  &
	;;

esac
