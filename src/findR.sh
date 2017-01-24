#!/bin/bash
echo 'Enter the number of PIXOUT directories.'
read dir_num

for n in `seq 1 $dir_num`
do
  N=`printf %06d ${n}`
  echo $N >> RLIST.PIX
  tac ./PIXOUT_$N/CORRECT.LP | grep -m 1 'SUBSET OF INTENSITY DATA' -B 14 | tac >> RLIST.PIX
  echo -e "\n" >> RLIST.PIX
done
