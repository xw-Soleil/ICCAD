#!/bin/bash

show_menu() {
 echo "1. Print a Hello World!"
 echo "2. List top 10 largest files recursively in a user-input directory"
 echo "3. Show the first 16 bytes of a user-input file, if it is executable"
 echo "4. Try our typing exercise and return"
 echo "5. Report your typing speed measured per character, in red color"
 echo "q. Report menu usages (how many times on which choices) and quit"
 echo "Your choice:"
}

count=0

while true
do 
	
	show_menu;
	read input
	echo "You choose: " $input; echo

	if [ $input == "q" ] ; then
		echo "Here I report the menu usages below:$count"; echo
	  break
	elif [ $input == "1" ] ; then
		echo "Hello World!" ;echo
	elif [ $input == "2" ] ; then
		echo "Please input a  file dir"
		read inputdir
		# convert the "~" to $HOME
		inputdir="${inputdir/#\~/$HOME}"
		# Normalized the path -> / -> /; /home -> /home; /home/ -> /home
		inputdir="${inputdir%/}/"
		echo "Input dir is $inputdir"
		echo "The 10 largest files are" ;echo
		find $inputdir -type f -print0 2>/dev/null \
		| xargs -0 du -h 2>/dev/null \
		| sort -hr \
		| head -n 10
	# 	du -sh "$inputdir"/* 2>/dev/null | sort -rh | head -n 10; echo
	elif [ $input == "3" ] ; then 
		echo "Please input file dir"
		read inputdir
		echo "Do you want to Display with both Hex mode and ASCII mode? Which in EFL files." ; echo "Please input [y/n]"
		while true ; do
			read mode
			case $mode in 
				"y") 
					head -c 16 "$inputdir"  | hd -Cv
					echo
					break
					;;
				"n")
					head -c 16 "$inputdir"
					echo
					break
					;;
				*)
					echo "Please input the right Format y/n" ; echo
					;;
			esac
		done
	elif [ $input == "4" ] ; then
		script="../tasks/type.sh/typeNew.sh"

                echo "Typing exercise:"
                echo "  y  : start (random 10 words)"
                echo "  r  : re-type last time (-r)"
                echo "  f  : fixed sentence (-f)"
                echo "  b  : back to menu"
                echo
		 while true; do
                        read -r -p "Your choice [y/r/f/b]: " mode
                        case "$mode" in
                                y)
                                        chmod +x "$script" 2>/dev/null
                                        ( cd ../tasks/type.sh && bash ./typeNew.sh )
                                        break
                                        ;;
                                r)
                                        chmod +x "$script" 2>/dev/null
                                        ( cd ../tasks/type.sh && bash ./typeNew.sh -r )
                                        break
                                        ;;
                                f)
                                        chmod +x "$script" 2>/dev/null
                                        ( cd ../tasks/type.sh && bash ./typeNew.sh -f )
                                        break
                                        ;;
                                b)
                                        break
                                        ;;
                                *)
                                        echo "Please input y/r/f/b"
                                        ;;
                        esac
                done
	fi
	((count++))
done
