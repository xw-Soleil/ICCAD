for name in $@; do
echo $name
done
echo "*****"

i=1
echo "1=$i"
let i=$i+1
echo "2=$i"

echo $1
echo $2
echo $[$i] #could not output $2
echo "*****#####"

read -p input: name
echo $name

if [[ "$name" =~ "/etc/passwd" ]]; then
    echo "user"
elif [[ "$name" =~ "/dev" ]]; then
    echo "device"
elif [[ -f "$name" ]]; then
    echo "file"
else
    echo "seems no body"
fi

