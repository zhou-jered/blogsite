if [ $# -lt 1 ]
then
	echo "no tips, exit"
fi

FILES=source/_posts/Programer-Tips.md

echo '- ' >> $FILES

echo $* >> $FILES
echo 'Done'
