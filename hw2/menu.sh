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
cnt1=0
cnt2=0
cnt3=0
cnt4=0
cnt5=0
LAST_DURATION=""
LAST_CHARS=""

while true
do 
    show_menu
    read input
    echo "You choose: $input"; echo

    if [ "$input" == "q" ]; then
        echo "Here I report the menu usages below:"; echo
        echo "Choice 1 was chosen $cnt1 times."
        echo "Choice 2 was chosen $cnt2 times."
        echo "Choice 3 was chosen $cnt3 times."
        echo "Choice 4 was chosen $cnt4 times."
        echo "Choice 5 was chosen $cnt5 times."
        count=$((cnt1 + cnt2 + cnt3 + cnt4 + cnt5))
        echo "Total menu accesses: $count times."
        break
    elif [ "$input" == "1" ]; then
        ((cnt1++))
        echo "Hello World!" ; echo
    elif [ "$input" == "2" ]; then
        ((cnt2++))
        echo "Please input a file dir"
        read inputdir
        # convert the "~" to $HOME
        inputdir="${inputdir/#\~/$HOME}"
        inputdir="${inputdir%/}/"
        echo "Input dir is $inputdir"
        echo "The 10 largest files are" ;echo
        find "$inputdir" -type f -print0 2>/dev/null \
        | xargs -0 du -h 2>/dev/null \
        | sort -hr \
        | head -n 10
    elif [ "$input" == "3" ]; then 
        ((cnt3++))
        echo "Please input file dir"
        read inputdir
        echo "Do you want to Display with both Hex mode and ASCII mode? Which in ELF files." ; echo "Please input [y/n]"
        while true; do
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
    elif [ "$input" == "4" ]; then
        ((cnt4++))
        script="./type.sh/typeNew.sh"
		scriptDir="./type.sh/"

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
                    ( cd $scriptDir && bash ./typeNew.sh )

                    if [ -f "$scriptDir/time.sav.txt" ]; then
                        LAST_DURATION=$(cat "$scriptDir/time.sav.txt")
                    else
                        LAST_DURATION=""
                    fi

                    if [ -f "$scriptDir/typed.sav.txt" ]; then
                        LAST_CHARS=$(tr -d '\n' < "$scriptDir/typed.sav.txt" | wc -c)
                    else
                        LAST_CHARS=""
                    fi
                    break
                    ;;
                r)
                    chmod +x "$script" 2>/dev/null
                    ( cd $scriptDir && bash ./typeNew.sh -r )

                    if [ -f "$scriptDir/time.sav.txt" ]; then
                        LAST_DURATION=$(cat "$scriptDir/time.sav.txt")
                    else
                        LAST_DURATION=""
                    fi

                    if [ -f "$scriptDir/typed.sav.txt" ]; then
                        LAST_CHARS=$(tr -d '\n' < "$scriptDir/typed.sav.txt" | wc -c)
                    else
                        LAST_CHARS=""
                    fi
                    break
                    ;;
                f)
                    chmod +x "$script" 2>/dev/null
                    ( cd $scriptDir && bash ./typeNew.sh -f )

                    if [ -f "$scriptDir/time.sav.txt" ]; then
                        LAST_DURATION=$(cat "$scriptDir/time.sav.txt")
                    else
                        LAST_DURATION=""
                    fi

                    if [ -f "$scriptDir/typed.sav.txt" ]; then
                        LAST_CHARS=$(tr -d '\n' < "$scriptDir/typed.sav.txt" | wc -c)
                    else
                        LAST_CHARS=""
                    fi
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
    elif [ "$input" == "5" ]; then
        ((cnt5++))
        if [ -z "$LAST_DURATION" ] || [ -z "$LAST_CHARS" ] || [ "$LAST_CHARS" -eq 0 ]; then
            echo "No typing record yet. Please run option 4 first."
            echo
        else
            echo "Your last typing speed record is:"
            spc=$(echo "scale=6; $LAST_DURATION / $LAST_CHARS" | bc)
            cps=$(echo "scale=3; $LAST_CHARS / $LAST_DURATION" | bc)

            printf "\e[31mTyping speed: %s sec/char, %s chars/sec (chars=%d, time=%.3fs)\e[0m\n\n" \
                   "$spc" "$cps" "$LAST_CHARS" "$LAST_DURATION"
        fi
    fi
    ((count++))
done
